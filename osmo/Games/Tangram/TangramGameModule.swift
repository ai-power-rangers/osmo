//
//  TangramGameModule.swift
//  osmo
//
//  Refactored Game Module using new architecture
//

import Foundation
import SwiftUI
import SpriteKit

final class TangramGameModule: GameModule {
    static let gameId = "tangram"
    
    static let gameInfo = GameInfo(
        gameId: gameId,
        displayName: "Tangram Puzzles",
        description: "Classic shape puzzles - arrange colorful pieces to match the target",
        iconName: "square.on.square",
        minAge: 5,
        maxAge: 99,
        category: .spatialReasoning,
        isLocked: false,
        bundleSize: 15,
        requiredCVEvents: []
    )
    
    required init() {
        // Ensure default puzzles exist
        _ = TangramPuzzleStorage.shared
    }
    
    // GameModule protocol requirement - for gameplay
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        // Create scene with new architecture
        let scene = TangramScene(size: size)
        scene.scaleMode = .aspectFill
        
        // View model will be created in scene's didMove method
        // to handle MainActor requirements
        
        return scene
    }
    
    func cleanup() {
        // Release any resources if needed
    }

}

// MARK: - Navigation Views

/// Main launcher for Tangram game (play mode)
struct TangramGameLauncher: View {
    var body: some View {
        TangramPlayView()
    }
}

/// Editor launcher for creating/editing puzzles (accessed from Settings)
struct TangramEditorLauncher: View {
    @State private var selectedPuzzle: TangramPuzzle?
    @State private var showingPuzzleList = false
    @State private var showingNewEditor = false
    @State private var showingEditEditor = false
    
    var body: some View {
        VStack(spacing: 20) {
                // Header
                Text("Tangram Puzzle Editor")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Create and edit Tangram puzzles with initial and target states")
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
                    
                    Text("• Set initial piece positions (hints for players)")
                    Text("• Define target solution state")
                    Text("• Test puzzles before saving")
                    Text("• Organize with difficulty levels and tags")
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
        .navigationTitle("Tangram Editor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPuzzleList) {
            EditPuzzleSelector(selectedPuzzle: $selectedPuzzle)
                .onChange(of: selectedPuzzle) { puzzle in
                    if puzzle != nil {
                        showingEditEditor = true
                    }
                }
        }
        .navigationDestination(isPresented: $showingNewEditor) {
            TangramEditor()
        }
        .navigationDestination(isPresented: $showingEditEditor) {
            if let puzzle = selectedPuzzle {
                TangramEditor(puzzle: puzzle)
            }
        }
    }
}

struct EditPuzzleSelector: View {
    @Binding var selectedPuzzle: TangramPuzzle?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(TangramPuzzleStorage.shared.loadAll()) { puzzle in
                Button(action: {
                    selectedPuzzle = puzzle
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(puzzle.name)
                                .font(.headline)
                            Text("\(puzzle.difficulty.rawValue) • \(puzzle.initialState.pieces.count) initial pieces")
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