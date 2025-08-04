//
//  SudokuGameModule.swift
//  osmo
//
//  Refactored Game Module using new architecture
//

import Foundation
import SpriteKit
import SwiftUI

final class SudokuGameModule: GameModule {
    
    // MARK: - Static Properties
    
    static let gameId = "sudoku"
    
    static let gameInfo = GameInfo(
        gameId: gameId,
        displayName: "Sudoku",
        description: "Classic number puzzle - place tiles to complete the grid without repeating numbers in rows, columns, or boxes",
        iconName: "square.grid.3x3",
        minAge: 8,
        maxAge: 99,
        category: .problemSolving,
        isLocked: false,
        bundleSize: 50,
        requiredCVEvents: [] // No CV required - touch-based
    )
    
    // MARK: - Initialization
    
    required init() {
        // Ensure default puzzles exist
        _ = SudokuStorage.shared
    }
    
    // MARK: - GameModule Protocol
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = SudokuScene(size: size)
        scene.gameContext = context
        scene.scaleMode = .aspectFill
        
        // View model will be created in scene's didMove method
        // to handle MainActor requirements
        
        return scene
    }
    
    func cleanup() {
        // Release any resources
    }
}

// MARK: - Navigation Views

/// Main launcher for Sudoku game (play mode)
struct SudokuGameLauncher: View {
    var body: some View {
        SudokuPlayView()
    }
}

/// Editor launcher for creating/editing puzzles (accessed from Settings)
struct SudokuEditorLauncher: View {
    @State private var selectedPuzzle: SudokuPuzzle?
    @State private var showingPuzzleList = false
    @State private var showingNewEditor = false
    @State private var showingEditEditor = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Sudoku Puzzle Editor")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("Create and edit Sudoku puzzles with initial and solution states")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Options
            VStack(spacing: 16) {
                // Create new puzzle
                Button(action: {
                    showingNewEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading) {
                            Text("Create New Puzzle")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Start from scratch")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
                
                // Edit existing puzzle
                Button(action: {
                    showingPuzzleList = true
                }) {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading) {
                            Text("Edit Existing Puzzle")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Modify saved puzzles")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange)
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Info box
            VStack(alignment: .leading, spacing: 8) {
                Label("Editor Features", systemImage: "info.circle")
                    .font(.headline)
                
                Text("• Set initial numbers (clues for players)")
                Text("• Define complete solution")
                Text("• Validate puzzle solvability")
                Text("• Test puzzles before saving")
                Text("• Organize with difficulty levels")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Sudoku Editor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPuzzleList) {
            EditSudokuSelector(selectedPuzzle: $selectedPuzzle)
                .onChange(of: selectedPuzzle) { puzzle in
                    if puzzle != nil {
                        showingEditEditor = true
                    }
                }
        }
        .navigationDestination(isPresented: $showingNewEditor) {
            SudokuEditor()
        }
        .navigationDestination(isPresented: $showingEditEditor) {
            if let puzzle = selectedPuzzle {
                SudokuEditor(puzzle: puzzle)
            }
        }
    }
}

struct EditSudokuSelector: View {
    @Binding var selectedPuzzle: SudokuPuzzle?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(SudokuStorage.shared.loadAll()) { (puzzle: SudokuPuzzle) in
                Button(action: {
                    selectedPuzzle = puzzle
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(puzzle.name)
                                .font(.headline)
                            Text("\(puzzle.difficulty.rawValue) • \(puzzle.gridSize.rawValue)x\(puzzle.gridSize.rawValue) • \(puzzle.filledCellCount) clues")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Puzzle")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}