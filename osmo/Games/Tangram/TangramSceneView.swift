//
//  TangramSceneView.swift
//  osmo
//
//  SpriteKit scene wrapper for Tangram game
//

import SwiftUI
import SpriteKit

struct TangramSceneView: UIViewRepresentable {
    let puzzle: TangramPuzzle
    @Binding var isComplete: Bool
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.showsFPS = false
        view.showsNodeCount = false
        
        // Get the view size
        let size = CGSize(width: UIScreen.main.bounds.width, 
                         height: UIScreen.main.bounds.height)
        
        // Create and present the scene
        let scene = TangramScene(
            size: size,
            puzzle: puzzle,
            onPieceMove: {
                // Optional: Add haptic feedback on piece move
                GameKit.haptics.playHaptic(.light)
            },
            onComplete: {
                isComplete = true
                GameKit.haptics.notification(.success)
                GameKit.audio.play(.levelComplete)
            }
        )
        
        view.presentScene(scene)
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        // If puzzle changes, recreate the scene
        if context.coordinator.currentPuzzleId != puzzle.id {
            let size = uiView.bounds.size
            let scene = TangramScene(
                size: size,
                puzzle: puzzle,
                onPieceMove: {
                    GameKit.haptics.playHaptic(.light)
                },
                onComplete: {
                    isComplete = true
                    GameKit.haptics.notification(.success)
                    GameKit.audio.play(.levelComplete)
                }
            )
            uiView.presentScene(scene)
            context.coordinator.currentPuzzleId = puzzle.id
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var currentPuzzleId: String?
    }
}