//
//  SudokuPuzzleSelector.swift
//  osmo
//
//  Puzzle selection and management view for Sudoku
//

import SwiftUI

struct SudokuPuzzleSelector: View {
    @Environment(\.dismiss) private var dismiss
    var onGameSelected: ((String, String?) -> Void)? = nil
    @State private var puzzles: [SudokuPuzzle] = []
    @State private var selectedPuzzle: SudokuPuzzle?
    @State private var showingDeleteConfirmation = false
    @State private var puzzleToDelete: SudokuPuzzle?
    
    private let storage = SudokuStorage.shared
    
    var body: some View {
        Group {
            if puzzles.isEmpty {
                EmptySudokuPuzzleView {
                    // Navigation will be handled by NavigationLink in the parent
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200))
                    ], spacing: Spacing.m) {
                        ForEach(puzzles) { puzzle in
                            PuzzleCardView(
                                puzzle: puzzle,
                                onPlay: { selectedPuzzle in
                                    // Launch game with this puzzle
                                    onGameSelected?("sudoku", selectedPuzzle.id)
                                },
                                onEdit: { _ in
                                    // Navigation will be handled by NavigationLink in the parent
                                },
                                onDelete: { _ in
                                    puzzleToDelete = puzzle
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(Spacing.m)
                }
            }
        }
        .navigationTitle("Sudoku Puzzles")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(value: AppRoute.sudokuEditor()) {
                    Image(systemName: "plus")
                }
            }
        }
        .confirmationDialog(
            "Delete Puzzle?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let puzzle = puzzleToDelete {
                    deletePuzzle(puzzle)
                }
            }
            Button("Cancel", role: .cancel) {
                puzzleToDelete = nil
            }
        } message: {
            if let puzzle = puzzleToDelete {
                Text("Delete '\(puzzle.name)'? This cannot be undone.")
            }
        }
        .onAppear {
            loadPuzzles()
        }
    }
    
    private func loadPuzzles() {
        Task {
            do {
                let loadedPuzzles: [SudokuPuzzle] = try await storage.loadAll()
                await MainActor.run {
                    puzzles = loadedPuzzles
                }
            } catch {
                print("[SudokuPuzzleSelector] Failed to load puzzles: \(error)")
            }
        }
    }
    
    private func deletePuzzle(_ puzzle: SudokuPuzzle) {
        Task {
            do {
                try await storage.delete(id: puzzle.id)
                await MainActor.run {
                    loadPuzzles()
                    puzzleToDelete = nil
                }
            } catch {
                print("[SudokuPuzzleSelector] Failed to delete puzzle: \(error)")
            }
        }
    }
}

// Removed duplicate SudokuPuzzleCard - now using unified PuzzleCardView from Core/GameBase/Views/

// MARK: - Empty State

struct EmptySudokuPuzzleView: View {
    let onCreatePuzzle: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Puzzles Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first Sudoku puzzle to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                onCreatePuzzle()
            } label: {
                Label("Create Puzzle", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}