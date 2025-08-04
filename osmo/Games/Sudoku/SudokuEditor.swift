//
//  SudokuEditor.swift
//  osmo
//
//  Editor for creating and editing Sudoku puzzles with initial and target states
//

import SwiftUI
import SpriteKit

struct SudokuEditor: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: SudokuViewModel?
    @State private var showingSaveDialog = false
    @State private var puzzleName = ""
    @State private var selectedDifficulty: PuzzleDifficulty = .medium
    @State private var showingMetadata = false
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    private let puzzle: SudokuPuzzle?
    private let initialEditorMode: EditorMode
    
    init(puzzle: SudokuPuzzle? = nil, editorMode: EditorMode = .initial) {
        self.puzzle = puzzle
        self.initialEditorMode = editorMode
        if let puzzle = puzzle {
            _puzzleName = State(initialValue: puzzle.name)
            _selectedDifficulty = State(initialValue: puzzle.difficulty)
            _tags = State(initialValue: Array(puzzle.tags))
        } else {
            _puzzleName = State(initialValue: "")
        }
    }
    
    var editorModeBinding: Binding<EditorMode> {
        Binding(
            get: { viewModel?.editorMode ?? .initial },
            set: { viewModel?.switchEditorMode($0) }
        )
    }
    
    var body: some View {
        Group {
            if let vm = viewModel {
                editorContent(vm: vm)
            } else {
                ProgressView("Loading editor...")
                    .onAppear {
                        viewModel = SudokuViewModel(
                            puzzle: puzzle,
                            editorMode: initialEditorMode,
                            services: services
                        )
                    }
            }
        }
    }
    
    @ViewBuilder
    private func editorContent(vm: SudokuViewModel) -> some View {
        VStack(spacing: 0) {
            // Editor Mode Selector
            Picker("Editor Mode", selection: editorModeBinding) {
                Text("Initial State").tag(EditorMode.initial)
                Text("Target State").tag(EditorMode.target)
                Text("Test Play").tag(EditorMode.testing)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Mode Description
            HStack {
                switch vm.editorMode {
                case .initial:
                    Label("Editing Initial State", systemImage: "square.grid.3x3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Set the starting puzzle configuration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                case .target:
                    Label("Editing Target State", systemImage: "checkmark.square.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Define the complete solution")
                        .font(.caption)
                        .foregroundColor(.secondary)
                case .testing:
                    Label("Test Mode", systemImage: "play.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Play test your puzzle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                default:
                    EmptyView()
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Game Scene
            GeometryReader { geometry in
                ZStack {
                    Color.gray.opacity(0.1)
                    
                    SudokuGameHost(viewModel: vm)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding()
            
            // Control Buttons
            HStack(spacing: 20) {
                if vm.editorMode != EditorMode.testing {
                    // Clear Board
                    Button(action: {
                        vm.clearBoard()
                    }) {
                        Label("Clear", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    if vm.editorMode == .target {
                        Button(action: {
                            vm.fillAllCells()
                        }) {
                            Label("Auto Fill", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Show/Hide target overlay (for initial state editing)
                    if vm.editorMode == .initial {
                        Button(action: {
                            vm.showTargetOverlay.toggle()
                        }) {
                            Label(
                                vm.showTargetOverlay ? "Hide Target" : "Show Target",
                                systemImage: vm.showTargetOverlay ? "eye.slash" : "eye"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Test mode controls
                    Button(action: {
                        vm.resetToInitial()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        vm.provideHint()
                    }) {
                        Label("Hint", systemImage: "lightbulb")
                    }
                    .buttonStyle(.bordered)
                    
                    if vm.isComplete {
                        Text("✅ Puzzle Solved!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // Validation Status
                if vm.conflicts.count > 0 {
                    Label("\(vm.conflicts.count) conflicts", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Sudoku Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingSaveDialog = true }) {
                        Label("Save Puzzle", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showingMetadata = true }) {
                        Label("Edit Metadata", systemImage: "info.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            SavePuzzleSheet(
                puzzleName: $puzzleName,
                onSave: { name in
                    savePuzzle(vm: vm)
                },
                onCancel: {
                    showingSaveDialog = false
                }
            )
        }
        .sheet(isPresented: $showingMetadata) {
            MetadataEditor(
                puzzleName: $puzzleName,
                difficulty: $selectedDifficulty,
                tags: $tags,
                newTag: $newTag,
                onSave: {
                    savePuzzle(vm: vm)
                    showingMetadata = false
                }
            )
        }
    }
    
    private var canSave: Bool {
        guard let vm = viewModel else { return false }
        return !puzzleName.isEmpty && validatePuzzle(vm: vm)
    }
    
    private func savePuzzle(vm: SudokuViewModel) {
        vm.currentPuzzle?.name = puzzleName
        vm.currentPuzzle?.difficulty = selectedDifficulty
        vm.currentPuzzle?.tags = Set(tags)
        vm.savePuzzle(name: puzzleName)
        showingSaveDialog = false
    }
    
    private func validatePuzzle(vm: SudokuViewModel) -> Bool {
        guard let puzzle = vm.currentPuzzle else {
            return false
        }
        return puzzle.validate().isEmpty
    }
    
    private var filledCellCount: Int {
        viewModel?.currentBoard.flatMap { $0 }.compactMap { $0 }.count ?? 0
    }
    
    private var totalCells: Int {
        let gridSize = viewModel?.gridSize ?? .nineByNine
        return gridSize.rawValue * gridSize.rawValue
    }
}

// MARK: - Supporting Views

struct SavePuzzleSheet: View {
    @Binding var puzzleName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Puzzle Name") {
                    TextField("Enter puzzle name", text: $puzzleName)
                }
            }
            .navigationTitle("Save Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(puzzleName)
                        dismiss()
                    }
                    .disabled(puzzleName.isEmpty)
                }
            }
        }
    }
}

struct MetadataEditor: View {
    @Binding var puzzleName: String
    @Binding var difficulty: PuzzleDifficulty
    @Binding var tags: [String]
    @Binding var newTag: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Puzzle Info") {
                    TextField("Puzzle Name", text: $puzzleName)
                    
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(PuzzleDifficulty.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }
                
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { indices in
                        tags.remove(atOffsets: indices)
                    }
                    
                    HStack {
                        TextField("Add tag", text: $newTag)
                        Button("Add") {
                            if !newTag.isEmpty {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                    }
                }
            }
            .navigationTitle("Puzzle Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SudokuGameHost

struct SudokuGameHost: View {
    let viewModel: SudokuViewModel
    
    var body: some View {
        GeometryReader { geometry in
            SpriteView(
                scene: createScene(size: geometry.size),
                options: [.allowsTransparency]
            )
        }
    }
    
    private func createScene(size: CGSize) -> SKScene {
        let scene = SudokuScene(size: size)
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .clear
        scene.gameContext = services
        // Scene will be updated via SceneUpdateProtocol
        return scene
    }
    
    @Environment(ServiceContainer.self) private var services
}

// SudokuEditorLauncher is defined in SudokuGameModule.swift

// PuzzleDifficulty.displayName is already defined in PuzzleDifficulty.swift