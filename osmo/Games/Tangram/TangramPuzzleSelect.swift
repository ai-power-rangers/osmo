//
//  TangramPuzzleSelect.swift
//  osmo
//
//  Tangram puzzle selection view
//

import SwiftUI

struct TangramPuzzleSelect: View {
    @State private var puzzles: [TangramPuzzle] = []
    @State private var isLoading = true
    @State private var selectedPuzzle: TangramPuzzle?
    @State private var showingEditor = false
    @State private var navigateToGame = false
    
    let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    // Create new puzzle card
                    Button {
                        showingEditor = true
                    } label: {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text("Create New")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Existing puzzles
                    ForEach(puzzles) { puzzle in
                        PuzzleCard(puzzle: puzzle) {
                            selectedPuzzle = puzzle
                            navigateToGame = true
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Tangram Puzzles")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToGame) {
            if let puzzle = selectedPuzzle {
                TangramGame(puzzleId: puzzle.id)
            }
        }
        .sheet(isPresented: $showingEditor) {
            ImprovedTangramEditor(puzzleId: nil)
                .onDisappear {
                    Task {
                        await loadPuzzles()
                    }
                }
        }
        .task {
            await loadPuzzles()
        }
    }
    
    private func loadPuzzles() async {
        isLoading = true
        
        do {
            let loaded = try await SimplePuzzleStorage().loadAll()
            puzzles = loaded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("[TangramPuzzleSelect] Failed to load puzzles: \(error)")
            // Add default puzzles
            puzzles = [
                TangramPuzzle.default
            ]
        }
        
        isLoading = false
    }
}

struct PuzzleCard: View {
    let puzzle: TangramPuzzle
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Puzzle preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundGradient)
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "square.on.square")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                    )
                
                // Puzzle info
                VStack(alignment: .leading, spacing: 4) {
                    Text(puzzle.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Label(puzzle.difficulty.rawValue, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(puzzle.createdAt, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.2, green: 0.6, blue: 0.9),
                Color(red: 0.1, green: 0.4, blue: 0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    NavigationStack {
        TangramPuzzleSelect()
    }
}