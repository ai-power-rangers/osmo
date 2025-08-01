//
//  RockPaperScissorsGameModule.swift
//  osmo
//
//  GameModule implementation for Rock-Paper-Scissors
//

import Foundation
import SpriteKit

final class RockPaperScissorsGameModule: GameModule {
    
    // MARK: - Static Properties
    
    static let gameId = "rock-paper-scissors"
    
    static let gameInfo = GameInfo(
        gameId: gameId,
        displayName: "Rock Paper Scissors",
        description: "Classic hand gesture game - make rock, paper, or scissors with your hand to beat the AI!",
        iconName: "hand.raised",
        minAge: 4,
        maxAge: 99,
        category: .problemSolving,
        isLocked: false,
        bundleSize: 10,
        requiredCVEvents: ["handDetected", "fingerCountDetected"]
    )
    
    // MARK: - Initialization
    
    required init() {
        // Lightweight initialization
        // Heavy resources loaded only when game starts
    }
    
    // MARK: - GameModule Protocol
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = RockPaperScissorsGameScene(size: size)
        scene.gameContext = context
        scene.scaleMode = .aspectFill
        return scene
    }
    
    func cleanup() {
        // Release any resources
        // This is called when leaving the game
    }
}
