//
//  TangramGame.swift
//  osmo
//
//  Main Tangram game view - Simple and direct
//

import SwiftUI
import SpriteKit

struct TangramGame: View {
    let puzzleId: String?
    
    @State private var puzzle: TangramPuzzle = .default
    @State private var scene: TangramScene?
    @State private var isLoading = true
    @State private var showComplete = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading puzzle...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if let scene = scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            GameKit.audio.play(.buttonTap)
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                    }
            }
            
            if showComplete {
                PuzzleCompleteOverlay(
                    onContinue: loadNextPuzzle,
                    onExit: { dismiss() }
                )
            }
        }
        .task {
            await loadPuzzle()
            createScene()
        }
    }
    
    private func loadPuzzle() async {
        if let id = puzzleId {
            do {
                if let loaded = try await GameKit.storage.loadPuzzle(id, type: TangramPuzzle.self) {
                    puzzle = loaded
                } else {
                    puzzle = .default
                }
            } catch {
                print("[TangramGame] Failed to load puzzle: \(error)")
                puzzle = .default
            }
        } else {
            puzzle = .default
        }
        isLoading = false
    }
    
    private func createScene() {
        let sceneSize = CGSize(width: UIScreen.main.bounds.width, 
                               height: UIScreen.main.bounds.height)
        
        scene = TangramScene(
            size: sceneSize,
            puzzle: puzzle,
            onPieceMove: handlePieceMove,
            onComplete: handleComplete
        )
        
        scene?.scaleMode = .aspectFill
    }
    
    private func handlePieceMove() {
        GameKit.audio.play(.pieceDrop)
        GameKit.haptics.playHaptic(.light)
    }
    
    private func handleComplete() {
        GameKit.audio.play(.success)
        GameKit.haptics.notification(.success)
        
        Task {
            try? await GameKit.storage.saveProgress(
                gameId: "tangram",
                level: puzzleId ?? "default",
                completed: true
            )
            
            GameKit.analytics.logEvent("puzzle_complete", parameters: [
                "game": "tangram",
                "puzzle_id": puzzleId ?? "default"
            ])
        }
        
        withAnimation {
            showComplete = true
        }
    }
    
    private func loadNextPuzzle() {
        // In a real app, load the next puzzle
        showComplete = false
        dismiss()
    }
}

// MARK: - Puzzle Complete Overlay

struct PuzzleCompleteOverlay: View {
    let onContinue: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "star.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("Puzzle Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                Button("Next Puzzle") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Exit") {
                    onExit()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

// MARK: - Preview

#Preview {
    TangramGame(puzzleId: nil)
}