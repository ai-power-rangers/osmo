//
//  TangramEditor.swift
//  osmo
//
//  Refactored editor with initial and target state editing
//

import SwiftUI
import SpriteKit

struct TangramEditor: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: TangramViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: EditorMode = .target
    @State private var showingPieceMenu = false
    @State private var showingNewPuzzleAlert = false
    @State private var showingSaveDialog = false
    @State private var puzzleName = ""
    
    private let puzzle: TangramPuzzle?
    private let initialEditorMode: EditorMode
    
    init(puzzle: TangramPuzzle? = nil, editorMode: EditorMode = .target) {
        self.puzzle = puzzle
        self.initialEditorMode = editorMode
        if let puzzle = puzzle {
            _puzzleName = State(initialValue: puzzle.name)
        }
    }
    
    var body: some View {
        Group {
            if let vm = viewModel {
                editorContent(vm: vm)
            } else {
                ProgressView("Loading editor...")
                    .onAppear {
                        viewModel = TangramViewModel(
                            puzzle: puzzle ?? TangramPuzzle.empty(),
                            editorMode: initialEditorMode,
                            services: services
                        )
                    }
            }
        }
    }
    
    @ViewBuilder
    private func editorContent(vm: TangramViewModel) -> some View {
        ZStack {
            // Background
            AppColors.gameBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Mode selector
                VStack(spacing: 8) {
                    editorModeSelector(vm: vm)
                    
                    // Help text
                    Text("Tap to select • Tap again or double-tap to rotate • Use flip button for mirror")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.white)
                
                // Scene
                GeometryReader { geometry in
                    TangramGameHost(viewModel: vm, services: services)
                }
                
                // Bottom controls
                bottomControls(vm: vm)
                    .padding()
                    .background(Color.white)
            }
        }
        .navigationTitle("Puzzle Editor")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Flip button (when piece selected)
                    if vm.selectedPieceId != nil && selectedMode != .testing {
                        Button(action: {
                            if let id = vm.selectedPieceId {
                                vm.flipPiece(id)
                            }
                        }) {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        }
                    }
                    
                    // Toggle target overlay
                    if selectedMode == .initial {
                        Button(action: {
                            vm.toggleTargetOverlay()
                        }) {
                            Image(systemName: vm.showTargetOverlay ? "eye.fill" : "eye.slash")
                        }
                    }
                    
                    // Save button
                    Button(action: {
                        showingSaveDialog = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(!canSave(vm: vm))
                }
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            SavePuzzleSheet(
                puzzleName: $puzzleName,
                onSave: { name in
                    vm.savePuzzle(name: name)
                },
                onCancel: {
                    showingSaveDialog = false
                }
            )
        }
        .sheet(isPresented: $showingPieceMenu) {
            PieceSelectionMenu(
                availableShapes: vm.availableShapes,
                onSelect: { shape in
                    vm.addPiece(shape)
                    showingPieceMenu = false
                }
            )
        }
        .alert("New Puzzle", isPresented: $showingNewPuzzleAlert) {
            TextField("Puzzle Name", text: $puzzleName)
            Button("Create") {
                if !puzzleName.isEmpty {
                    vm.clearAll()
                    vm.currentPuzzle?.name = puzzleName
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new puzzle")
        }
    }
    
    @ViewBuilder
    private func editorModeSelector(vm: TangramViewModel) -> some View {
        Picker("Mode", selection: $selectedMode) {
            Text("Initial").tag(EditorMode.initial)
            Text("Target").tag(EditorMode.target)
            Text("Test").tag(EditorMode.testing)
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedMode) { newMode in
            vm.switchEditorMode(newMode)
        }
    }
    
    @ViewBuilder
    private func bottomControls(vm: TangramViewModel) -> some View {
        HStack(spacing: 16) {
            // Mode-specific controls
            switch selectedMode {
            case .initial, .target:
                Button(action: {
                    showingPieceMenu = true
                }) {
                    Label("Add Piece", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    vm.clearAll()
                }) {
                    Label("Clear All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button(action: {
                    vm.addAllRemainingPieces()
                }) {
                    Label("Add All", systemImage: "square.grid.3x3.fill")
                }
                .buttonStyle(.bordered)
                
            case .testing:
                Button(action: {
                    vm.resetToInitial()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                
                if vm.isComplete {
                    Text("✅ Solved!")
                        .foregroundColor(.green)
                        .font(.headline)
                }
            }
            
            Spacer()
            
            // Piece count
            Text("\(vm.currentState.pieces.count)/7 pieces")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func canSave(vm: TangramViewModel) -> Bool {
        // Can save if we have a name and at least the target state
        return !puzzleName.isEmpty && vm.currentPuzzle?.targetState.pieces.count ?? 0 > 0
    }
}

// MARK: - TangramGameHost

struct TangramGameHost: View {
    let viewModel: TangramViewModel
    let services: ServiceContainer
    
    var body: some View {
        GeometryReader { geometry in
            SpriteView(
                scene: createScene(size: geometry.size),
                options: [.allowsTransparency]
            )
        }
    }
    
    private func createScene(size: CGSize) -> SKScene {
        let scene = TangramScene(size: size)
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .clear
        scene.gameContext = services
        // Scene will be updated via SceneUpdateProtocol
        return scene
    }
}

// MARK: - Supporting Views

struct PieceSelectionMenu: View {
    let availableShapes: [TangramShape]
    let onSelect: (TangramShape) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(availableShapes, id: \.self) { shape in
                Button(action: {
                    onSelect(shape)
                    dismiss()
                }) {
                    HStack {
                        // Shape preview would go here
                        Text(shape.displayName)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationTitle("Add Piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension TangramShape {
    var displayName: String {
        switch self {
        case .largeTriangle1: return "Large Triangle 1"
        case .largeTriangle2: return "Large Triangle 2"
        case .mediumTriangle: return "Medium Triangle"
        case .smallTriangle1: return "Small Triangle 1"
        case .smallTriangle2: return "Small Triangle 2"
        case .square: return "Square"
        case .parallelogram: return "Parallelogram"
        }
    }
}

// SavePuzzleSheet is shared with SudokuEditor (defined there)