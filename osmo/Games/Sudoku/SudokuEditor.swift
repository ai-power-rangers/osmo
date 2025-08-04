//
//  SudokuEditor.swift
//  osmo
//
//  Editor for creating and editing Sudoku puzzles with initial and target states
//

import SwiftUI
import SpriteKit

struct SudokuEditor: View {
    @State private var viewModel: SudokuViewModel
    @State private var showingSaveDialog = false
    @State private var puzzleName = ""
    @State private var selectedDifficulty: PuzzleDifficulty = .medium
    @State private var showingMetadata = false
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    init(puzzle: SudokuPuzzle? = nil) {
        let services = ServiceContainer.shared
        if let puzzle = puzzle {
            _viewModel = State(initialValue: SudokuViewModel(puzzle: puzzle, editorMode: .initial, services: services))
            _puzzleName = State(initialValue: puzzle.name)
            _selectedDifficulty = State(initialValue: puzzle.difficulty)
            _tags = State(initialValue: Array(puzzle.tags))
        } else {
            _viewModel = State(initialValue: SudokuViewModel(editorMode: .initial, services: services))
            _puzzleName = State(initialValue: "")
        }
    }
    
    var editorModeBinding: Binding<EditorMode> {
        Binding(
            get: { viewModel.editorMode ?? .initial },
            set: { viewModel.switchEditorMode($0) }
        )
    }
    
    var body: some View {
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
            modeDescription
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            // Game Scene
            GeometryReader { geometry in
                SpriteView(
                    scene: createScene(size: geometry.size),
                    options: [.allowsTransparency]
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            
            // Control Panel
            controlPanel
                .padding()
                .background(Color.gray.opacity(0.1))
        }
        .navigationTitle("Sudoku Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingMetadata = true }) {
                        Label("Edit Metadata", systemImage: "info.circle")
                    }
                    Button(action: { showingSaveDialog = true }) {
                        Label("Save Puzzle", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            saveDialog
        }
        .sheet(isPresented: $showingMetadata) {
            metadataEditor
        }
    }
    
    @ViewBuilder
    private var modeDescription: some View {
        Group {
            switch viewModel.editorMode {
            case .initial:
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Set the starting numbers that players will see")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            case .target:
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.green)
                    Text("Define the complete solution for the puzzle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            case .testing:
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.orange)
                    Text("Test your puzzle by playing through it")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            default:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private var controlPanel: some View {
        VStack(spacing: 15) {
            if viewModel.editorMode != EditorMode.testing {
                // Editor controls
                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.clearBoard()
                    }) {
                        Label("Clear Board", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    if viewModel.editorMode == .target {
                        Button(action: {
                            viewModel.fillAllCells()
                        }) {
                            Label("Fill Solution", systemImage: "wand.and.stars")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    
                    Button(action: {
                        viewModel.showTargetOverlay.toggle()
                    }) {
                        Label(
                            viewModel.showTargetOverlay ? "Hide Target" : "Show Target",
                            systemImage: viewModel.showTargetOverlay ? "eye.slash" : "eye"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Testing controls
                HStack(spacing: 20) {
                    Button(action: {
                        viewModel.resetToInitial()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.provideHint()
                    }) {
                        Label("Hint", systemImage: "lightbulb")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                    
                    if viewModel.isComplete {
                        Label("Complete!", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption.bold())
                    }
                }
            }
            
            // Statistics
            HStack {
                Label("\(filledCellCount) / \(totalCells) cells", systemImage: "square.grid.3x3")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.conflicts.count > 0 {
                    Label("\(viewModel.conflicts.count) conflicts", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var saveDialog: some View {
        NavigationStack {
            Form {
                Section(header: Text("Puzzle Name")) {
                    TextField("Enter puzzle name", text: $puzzleName)
                }
                
                Section(header: Text("Difficulty")) {
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(PuzzleDifficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.rawValue).tag(difficulty)
                        }
                    }
                }
                
                Section(header: Text("Validation")) {
                    if let errors = validationErrors {
                        ForEach(errors, id: \.self) { error in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Puzzle is valid")
                        }
                    }
                }
            }
            .navigationTitle("Save Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingSaveDialog = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePuzzle()
                    }
                    .disabled(puzzleName.isEmpty || validationErrors != nil)
                }
            }
        }
    }
    
    private var metadataEditor: some View {
        NavigationStack {
            Form {
                Section(header: Text("Basic Info")) {
                    TextField("Puzzle Name", text: $puzzleName)
                    
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(PuzzleDifficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.rawValue).tag(difficulty)
                        }
                    }
                }
                
                Section(header: Text("Tags")) {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button(action: {
                                tags.removeAll { $0 == tag }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add tag", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Add") {
                            if !newTag.isEmpty {
                                tags.append(newTag)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.isEmpty)
                    }
                }
            }
            .navigationTitle("Puzzle Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingMetadata = false
                    }
                }
            }
        }
    }
    
    private func createScene(size: CGSize) -> SKScene {
        let scene = SudokuScene(size: size)
        scene.viewModel = viewModel
        scene.gameContext = nil  // No game context needed for editor
        scene.scaleMode = .aspectFill
        return scene
    }
    
    private func savePuzzle() {
        viewModel.currentPuzzle?.name = puzzleName
        viewModel.currentPuzzle?.difficulty = selectedDifficulty
        viewModel.currentPuzzle?.tags = Set(tags)
        viewModel.savePuzzle(name: puzzleName)
        showingSaveDialog = false
    }
    
    private var validationErrors: [String]? {
        guard let puzzle = viewModel.currentPuzzle else {
            return ["No puzzle to validate"]
        }
        
        let errors = puzzle.validate()
        return errors.isEmpty ? nil : errors
    }
    
    private var filledCellCount: Int {
        viewModel.currentBoard.flatMap { $0 }.compactMap { $0 }.count
    }
    
    private var totalCells: Int {
        viewModel.gridSize.rawValue * viewModel.gridSize.rawValue
    }
}

#Preview {
    NavigationStack {
        SudokuEditor()
    }
}