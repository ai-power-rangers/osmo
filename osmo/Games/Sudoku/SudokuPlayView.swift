//
//  SudokuPlayView.swift
//  osmo
//
//  Play view for Sudoku puzzles with puzzle selection
//

import SwiftUI
import SpriteKit

struct SudokuPlayView: View {
    @State private var viewModel: SudokuViewModel
    @State private var showingPuzzleSelector = false
    @State private var showingHint = false
    
    init(puzzle: SudokuPuzzle? = nil) {
        _viewModel = State(initialValue: SudokuViewModel(
            puzzle: puzzle,
            editorMode: nil
        ))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.white
                .ignoresSafeArea()
            
            // Game scene
            GeometryReader { geometry in
                SpriteView(scene: createScene(size: geometry.size))
                    .ignoresSafeArea()
            }
            
            // Overlay UI
            VStack {
                // Top bar
                topBar
                    .padding()
                
                Spacer()
                
                // Bottom controls
                bottomControls
                    .padding()
            }
            
            // Completion overlay
            if viewModel.isComplete {
                completionOverlay
            }
        }
        .navigationTitle("Sudoku")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingPuzzleSelector = true }) {
                        Label("Choose Puzzle", systemImage: "square.grid.3x3")
                    }
                    
                    Button(action: { viewModel.resetToInitial() }) {
                        Label("Reset Puzzle", systemImage: "arrow.counterclockwise")
                    }
                    
                    Divider()
                    
                    Button(action: { viewModel.provideHint() }) {
                        Label("Get Hint", systemImage: "lightbulb")
                    }
                    
                    Toggle(isOn: $viewModel.showingCandidates) {
                        Label("Show Candidates", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingPuzzleSelector) {
            SudokuPuzzleSelectorSheet(
                puzzles: viewModel.getAllPuzzles(),
                currentPuzzle: viewModel.currentPuzzle,
                onSelect: { puzzle in
                    viewModel.loadPuzzle(puzzle)
                    showingPuzzleSelector = false
                }
            )
        }
    }
    
    private var topBar: some View {
        HStack {
            // Puzzle info
            if let puzzle = viewModel.currentPuzzle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        // Difficulty
                        Label(puzzle.difficulty.rawValue, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(difficultyColor(puzzle.difficulty))
                        
                        // Timer
                        Text(viewModel.formattedTime)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .foregroundColor(.secondary)
                        
                        // Move count
                        Text("\(viewModel.moveCount) moves")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Conflicts indicator
            if !viewModel.conflicts.isEmpty {
                Label("\(viewModel.conflicts.count)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .shadow(radius: 2)
        )
    }
    
    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Undo button
            Button(action: {
                viewModel.undo()
            }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title2)
                    .foregroundColor(viewModel.canUndo ? .white : .gray)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(viewModel.canUndo ? Color.blue : Color.gray.opacity(0.3)))
                    .shadow(radius: viewModel.canUndo ? 2 : 0)
            }
            .disabled(!viewModel.canUndo)
            
            Spacer()
            
            // Hint button
            Button(action: {
                viewModel.provideHint()
            }) {
                Image(systemName: "lightbulb")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.yellow))
                    .shadow(radius: 2)
            }
            
            Spacer()
            
            // Redo button
            Button(action: {
                viewModel.redo()
            }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title2)
                    .foregroundColor(viewModel.canRedo ? .white : .gray)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(viewModel.canRedo ? Color.blue : Color.gray.opacity(0.3)))
                    .shadow(radius: viewModel.canRedo ? 2 : 0)
            }
            .disabled(!viewModel.canRedo)
        }
    }
    
    private var completionOverlay: some View {
        VStack(spacing: 20) {
            Text("🎉")
                .font(.system(size: 80))
            
            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Solved in \(viewModel.formattedTime) with \(viewModel.moveCount) moves")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.resetToInitial()
                }) {
                    Label("Play Again", systemImage: "arrow.counterclockwise")
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingPuzzleSelector = true
                }) {
                    Label("New Puzzle", systemImage: "square.grid.3x3")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(radius: 10)
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    private func createScene(size: CGSize) -> SudokuScene {
        let scene = SudokuScene(size: size)
        scene.scaleMode = .resizeFill
        scene.viewModel = viewModel
        return scene
    }
    
    private func difficultyColor(_ difficulty: PuzzleDifficulty) -> Color {
        switch difficulty {
        case .tutorial: return .blue
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        case .expert: return .purple
        case .custom: return .gray
        }
    }
}

// MARK: - Puzzle Selector

struct SudokuPuzzleSelectorSheet: View {
    let puzzles: [SudokuPuzzle]
    let currentPuzzle: SudokuPuzzle?
    let onSelect: (SudokuPuzzle) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(puzzles) { puzzle in
                        PuzzleCardView(
                            puzzle: puzzle,
                            onPlay: { selectedPuzzle in
                                onSelect(selectedPuzzle)
                            }
                        )
                        .opacity(puzzle.id == currentPuzzle?.id ? 1.0 : 0.7)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(puzzle.id == currentPuzzle?.id ? Color.blue : Color.clear, lineWidth: 3)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Removed duplicate SudokuPuzzleCard - now using unified PuzzleCardView from Core/GameBase/Views/

#Preview {
    NavigationStack {
        SudokuPlayView()
    }
}