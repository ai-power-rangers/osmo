//
//  TangramPlayView.swift
//  osmo
//
//  Play view for Tangram puzzles with puzzle selection
//

import SwiftUI
import SpriteKit

struct TangramPlayView: View {
    @State private var currentPuzzle: TangramPuzzle?
    @State private var showingPuzzleSelector = false
    @State private var showingHint = false
    @State private var isComplete = false
    
    private let initialPuzzle: TangramPuzzle?
    
    init(puzzle: TangramPuzzle? = nil) {
        self.initialPuzzle = puzzle
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6)
                .ignoresSafeArea()
            
            // Game scene
            GeometryReader { geometry in
                if let puzzle = currentPuzzle {
                    TangramSceneView(puzzle: puzzle, isComplete: $isComplete)
                } else {
                    ProgressView("Loading puzzle...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Top controls
            VStack {
                HStack {
                    // Puzzle selector
                    Button(action: { showingPuzzleSelector = true }) {
                        Label("Puzzles", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Spacer()
                    
                    // Progress indicator
                    if isComplete {
                        Text("✅ Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Hint button
                    Button(action: { showingHint = true }) {
                        Label("Hint", systemImage: "lightbulb")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                
                Spacer()
            }
        }
        .navigationTitle(currentPuzzle?.name ?? "Tangram")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPuzzleSelector) {
            TangramPuzzleSelector { selectedPuzzle in
                currentPuzzle = selectedPuzzle
                isComplete = false
                showingPuzzleSelector = false
            }
        }
        .sheet(isPresented: $showingHint) {
            HintView(puzzle: currentPuzzle)
        }
        .task {
            if let puzzle = initialPuzzle {
                currentPuzzle = puzzle
            } else {
                // Load a default puzzle or the last played one
                await loadDefaultPuzzle()
            }
        }
    }
    
    private func loadDefaultPuzzle() async {
        // Try to load default puzzles
        do {
            let puzzles = try await SimplePuzzleStorage().loadAll()
            if let firstPuzzle = puzzles.first {
                await MainActor.run {
                    currentPuzzle = firstPuzzle
                }
            }
        } catch {
            print("[TangramPlayView] Failed to load puzzles: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct TangramPuzzleSelector: View {
    let onSelect: (TangramPuzzle) -> Void
    @State private var puzzles: [TangramPuzzle] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(puzzles, id: \.id) { puzzle in
                Button(action: { onSelect(puzzle) }) {
                    VStack(alignment: .leading) {
                        Text(puzzle.name)
                            .font(.headline)
                        HStack {
                            Text("Difficulty: \(puzzle.difficulty.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Select Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                // Load puzzles
                do {
                    puzzles = try await SimplePuzzleStorage().loadAll()
                } catch {
                    print("Failed to load puzzles: \(error)")
                }
            }
        }
    }
}

struct HintView: View {
    let puzzle: TangramPuzzle?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if puzzle != nil {
                    Text("Target Shape")
                        .font(.headline)
                        .padding()
                    
                    // Show the target shape outline
                    // This would be a visual representation of the target
                    GeometryReader { geometry in
                        // Placeholder for target shape visualization
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                            .overlay(
                                Text("Target shape visualization here")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .padding()
                } else {
                    Text("No hint available")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Hint")
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