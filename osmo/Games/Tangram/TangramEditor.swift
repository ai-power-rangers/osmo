//
//  TangramEditor.swift
//  osmo
//
//  Refactored editor with initial and target state editing
//

import SwiftUI
import SpriteKit

struct TangramEditor: View {
    @State private var viewModel: TangramViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: EditorMode = .target
    @State private var showingPieceMenu = false
    @State private var showingNewPuzzleAlert = false
    
    init(puzzle: TangramPuzzle? = nil) {
        _viewModel = State(initialValue: TangramViewModel(
            puzzle: puzzle ?? TangramPuzzle.empty(),
            editorMode: .target
        ))
    }
    
    var body: some View {
        ZStack {
            // Background
            AppColors.gameBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Mode selector
                VStack(spacing: 8) {
                    editorModeSelector
                    
                    // Help text
                    Text("Tap to select • Tap again or double-tap to rotate • Use flip button for mirror")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.white)
                
                // Scene
                GeometryReader { geometry in
                    SpriteView(scene: createScene(size: geometry.size))
                        .ignoresSafeArea(edges: .horizontal)
                }
                
                // Bottom controls
                bottomControls
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
                    if viewModel.selectedPieceId != nil && selectedMode != .testing {
                        Button(action: {
                            if let id = viewModel.selectedPieceId {
                                viewModel.flipPiece(id)
                            }
                        }) {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        }
                    }
                    
                    // Toggle target overlay
                    if selectedMode == .initial {
                        Button(action: {
                            viewModel.toggleTargetOverlay()
                        }) {
                            Image(systemName: viewModel.showTargetOverlay ? "eye.fill" : "eye.slash")
                        }
                    }
                    
                    // Save button
                    Button(action: {
                        viewModel.showingSaveDialog = true
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSaveDialog) {
            SavePuzzleSheet(
                puzzleName: $viewModel.puzzleName,
                onSave: { name in
                    viewModel.savePuzzle(name: name)
                },
                onCancel: {
                    viewModel.showingSaveDialog = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingLoadDialog) {
            LoadPuzzleSheet(
                puzzles: viewModel.getAllPuzzles(),
                onLoad: { puzzle in
                    viewModel.loadPuzzle(puzzle)
                    viewModel.showingLoadDialog = false
                },
                onDelete: { puzzle in
                    viewModel.deletePuzzle(puzzle)
                },
                onCancel: {
                    viewModel.showingLoadDialog = false
                }
            )
        }
        .confirmationDialog("Add Piece", isPresented: $showingPieceMenu) {
            ForEach(viewModel.availableShapes, id: \.self) { shape in
                Button(action: {
                    viewModel.addPiece(shape, at: CGPoint(x: 0, y: -3))
                }) {
                    Text(displayName(for: shape))
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Select a piece to add")
        }
        .alert("New Puzzle", isPresented: $showingNewPuzzleAlert) {
            TextField("Puzzle Name", text: $viewModel.puzzleName)
            Button("Create") {
                if !viewModel.puzzleName.isEmpty {
                    viewModel.currentPuzzle = TangramPuzzle(
                        name: viewModel.puzzleName,
                        initialState: TangramState(),
                        targetState: TangramState()
                    )
                    viewModel.clearAll()
                    viewModel.puzzleName = ""
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var editorModeSelector: some View {
        Picker("Editor Mode", selection: $selectedMode) {
            Text("Initial State").tag(EditorMode.initial)
            Text("Target State").tag(EditorMode.target)
            Text("Test Play").tag(EditorMode.testing)
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedMode) { newMode in
            viewModel.switchEditorMode(newMode)
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: 8) {
            // Clear button
            BottomBarButton(
                icon: "trash",
                title: "Clear",
                color: .red,
                action: { viewModel.clearAll() }
            )
            
            Spacer()
            
            // Piece count indicator (centered)
            HStack(spacing: 4) {
                Image(systemName: "puzzlepiece.fill")
                    .font(.system(size: 14))
                Text("\(viewModel.currentState.pieces.count)/7")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Mode-specific buttons
            if selectedMode != .testing {
                // Add piece button
                if !viewModel.availableShapes.isEmpty {
                    BottomBarButton(
                        icon: "plus.circle.fill",
                        title: "Add",
                        color: AppColors.gamePrimary,
                        action: {
                            if viewModel.availableShapes.count == 1 {
                                viewModel.addPiece(viewModel.availableShapes[0], at: CGPoint(x: 0, y: -3))
                            } else {
                                showingPieceMenu = true
                            }
                        }
                    )
                }
                
                // Add all button (for target state)
                if selectedMode == .target && viewModel.availableShapes.count == 7 {
                    BottomBarButton(
                        icon: "square.stack.fill",
                        title: "Add All",
                        color: AppColors.gamePrimary,
                        action: { viewModel.addAllRemainingPieces() }
                    )
                }
            } else {
                // Reset button (for test mode)
                BottomBarButton(
                    icon: "arrow.counterclockwise",
                    title: "Reset",
                    color: .blue,
                    action: { viewModel.resetToInitial() }
                )
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var canSave: Bool {
        guard let puzzle = viewModel.currentPuzzle else { return false }
        
        // Need at least a complete target state
        return puzzle.targetState.isComplete
    }
    
    private func createScene(size: CGSize) -> TangramScene {
        let scene = TangramScene(size: size)
        scene.scaleMode = .resizeFill
        scene.viewModel = viewModel
        return scene
    }
    
    private func displayName(for shape: TangramShape) -> String {
        switch shape {
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

// MARK: - Save Dialog

struct SavePuzzleSheet: View {
    @Binding var puzzleName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Puzzle Information") {
                    TextField("Puzzle Name", text: $puzzleName)
                        .focused($isFocused)
                }
                
                Section {
                    Text("This puzzle will be saved with both initial and target states.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !puzzleName.isEmpty {
                            onSave(puzzleName)
                        }
                    }
                    .disabled(puzzleName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Load Dialog

struct LoadPuzzleSheet: View {
    let puzzles: [TangramPuzzle]
    let onLoad: (TangramPuzzle) -> Void
    let onDelete: (TangramPuzzle) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if puzzles.isEmpty {
                    ContentUnavailableView(
                        "No Puzzles",
                        systemImage: "puzzlepiece.extension",
                        description: Text("Create and save puzzles to see them here")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(puzzles) { puzzle in
                        TangramPuzzleRow(puzzle: puzzle) {
                            onLoad(puzzle)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(puzzle)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

struct TangramPuzzleRow: View {
    let puzzle: TangramPuzzle
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Label("\(puzzle.difficulty.rawValue)", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(Color(puzzle.difficulty.colorName))
                        
                        Label("\(puzzle.initialState.pieces.count)/7 initial", systemImage: "puzzlepiece")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(puzzle.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Bar Button

struct BottomBarButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundColor(color)
            .frame(minWidth: 50)
        }
    }
}

#Preview {
    NavigationStack {
        TangramEditor()
    }
}