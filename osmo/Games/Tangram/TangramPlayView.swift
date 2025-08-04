//
//  TangramPlayView.swift
//  osmo
//
//  Play view for Tangram puzzles with puzzle selection
//

import SwiftUI
import SpriteKit

struct TangramPlayView: View {
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: TangramViewModel?
    @State private var showingPuzzleSelector = false
    @State private var showingHint = false
    
    private let puzzle: TangramPuzzle?
    
    init(puzzle: TangramPuzzle? = nil) {
        self.puzzle = puzzle
    }
    
    var body: some View {
        Group {
            if let vm = viewModel {
                playContent(vm: vm)
            } else {
                ProgressView("Loading game...")
                    .onAppear {
                        viewModel = TangramViewModel(
                            puzzle: puzzle,
                            editorMode: nil,
                            services: services
                        )
                    }
            }
        }
    }
    
    @ViewBuilder
    private func playContent(vm: TangramViewModel) -> some View {
        ZStack {
            // Background
            AppColors.gameBackground
                .ignoresSafeArea()
            
            // Game scene
            GeometryReader { geometry in
                TangramGameHost(viewModel: vm, services: services)
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
                    if vm.isComplete {
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
        .navigationTitle(vm.currentPuzzle?.name ?? "Tangram")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPuzzleSelector) {
            TangramPuzzleSelector { selectedPuzzle in
                vm.loadPuzzle(selectedPuzzle)
                showingPuzzleSelector = false
            }
        }
        .sheet(isPresented: $showingHint) {
            HintView(puzzle: vm.currentPuzzle)
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
                            Text("Difficulty: \(puzzle.difficulty.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if puzzle.completionCount > 0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
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
            .onAppear {
                // Load puzzles
                Task {
                    do {
                        puzzles = try await TangramPuzzleStorage.shared.loadAll()
                    } catch {
                        print("Failed to load puzzles: \(error)")
                    }
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
                if let targetState = puzzle?.targetState {
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