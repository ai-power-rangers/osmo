//
//  TangramPlayView.swift
//  osmo
//
//  Play view for Tangram puzzles with puzzle selection
//

import SwiftUI
import SpriteKit

struct TangramPlayView: View {
    @State private var viewModel: TangramViewModel
    @State private var showingPuzzleSelector = false
    @State private var showingHint = false
    
    init(puzzle: TangramPuzzle? = nil) {
        _viewModel = State(initialValue: TangramViewModel(
            puzzle: puzzle,
            editorMode: nil
        ))
    }
    
    var body: some View {
        ZStack {
            // Background
            AppColors.gameBackground
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
        .navigationTitle("Tangram")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingPuzzleSelector = true }) {
                        Label("Choose Puzzle", systemImage: "puzzlepiece")
                    }
                    
                    Button(action: { viewModel.resetToInitial() }) {
                        Label("Reset Puzzle", systemImage: "arrow.counterclockwise")
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $viewModel.showGrid) {
                        Label("Show Grid", systemImage: "grid")
                    }
                    
                    Toggle(isOn: $viewModel.snapToGrid) {
                        Label("Snap to Grid", systemImage: "square.grid.3x3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingPuzzleSelector) {
            PuzzleSelectorSheet(
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
                            .foregroundColor(Color(puzzle.difficulty.color))
                        
                        // Progress
                        Text("\(viewModel.currentState.pieces.count)/7")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Hint button
            if viewModel.currentPuzzle?.hintImageName != nil {
                Button(action: { showingHint.toggle() }) {
                    Image(systemName: showingHint ? "lightbulb.fill" : "lightbulb")
                        .foregroundColor(.yellow)
                }
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
            // Reset button
            Button(action: {
                viewModel.resetToInitial()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.orange))
                    .shadow(radius: 2)
            }
            
            Spacer()
            
            // Check solution button
            Button(action: {
                viewModel.checkSolution()
            }) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.green))
                    .shadow(radius: 2)
            }
        }
    }
    
    private var completionOverlay: some View {
        VStack(spacing: 20) {
            Text("🎉")
                .font(.system(size: 80))
            
            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Great job solving \(viewModel.currentPuzzle?.name ?? "the puzzle")!")
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
                    Label("New Puzzle", systemImage: "puzzlepiece")
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
    
    private func createScene(size: CGSize) -> TangramScene {
        let scene = TangramScene(size: size)
        scene.scaleMode = .resizeFill
        scene.viewModel = viewModel
        return scene
    }
}

// MARK: - Puzzle Selector

struct PuzzleSelectorSheet: View {
    let puzzles: [TangramPuzzle]
    let currentPuzzle: TangramPuzzle?
    let onSelect: (TangramPuzzle) -> Void
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

// Removed duplicate PuzzleCard - now using unified PuzzleCardView from Core/GameBase/Views/

#Preview {
    NavigationStack {
        TangramPlayView()
    }
}