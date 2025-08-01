//
//  SudokuGameModule.swift
//  osmo
//
//  GameModule implementation for Sudoku
//

import Foundation
import SpriteKit

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
        requiredCVEvents: ["rectangleDetected", "textDetected"]
    )
    
    // MARK: - Initialization
    
    required init() {
        // Lightweight initialization
    }
    
    // MARK: - GameModule Protocol
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = SudokuGameScene(size: size)
        scene.gameContext = context
        scene.scaleMode = .aspectFill
        return scene
    }
    
    func cleanup() {
        // Release any resources
    }
}