import Foundation
import SpriteKit
import SwiftUI

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
        requiredCVEvents: [] // No CV in Phase 1
    )
    
    required init() {}
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = TangramGameScene(size: size)
        scene.gameContext = context
        scene.scaleMode = .aspectFill
        
        // Configure scene for device type
        scene.deviceType = UIDevice.current.userInterfaceIdiom
        
        // Default to first available puzzle
        // TODO: In the future, load puzzle from navigation context
        scene.puzzle = createDefaultPuzzle()
        
        return scene
    }
    
    func cleanup() {
        // Release any resources if needed
    }
    
    // Default puzzle with cat data
    private func createDefaultPuzzle() -> Puzzle {
        // Load the cat puzzle data
        let pieces = [
            PieceDefinition(pieceId: "square", targetPosition: SIMD2(3.2, 5.5), targetRotation: 0.785398, isMirrored: false),
            PieceDefinition(pieceId: "smallTriangle1", targetPosition: SIMD2(2.8, 6.5), targetRotation: 2.356194, isMirrored: false),
            PieceDefinition(pieceId: "smallTriangle2", targetPosition: SIMD2(3.6, 6.5), targetRotation: 0.785398, isMirrored: false),
            PieceDefinition(pieceId: "largeTriangle1", targetPosition: SIMD2(3.2, 3.5), targetRotation: 3.926991, isMirrored: false),
            PieceDefinition(pieceId: "mediumTriangle", targetPosition: SIMD2(2.0, 3.5), targetRotation: 4.712389, isMirrored: false),
            PieceDefinition(pieceId: "largeTriangle2", targetPosition: SIMD2(4.4, 2.5), targetRotation: 1.570796, isMirrored: false),
            PieceDefinition(pieceId: "parallelogram", targetPosition: SIMD2(5.8, 2.5), targetRotation: 0.000000, isMirrored: true)
        ]
        
        return Puzzle(
            id: "cat",
            name: "Cat",
            imageName: "cat_icon",
            pieces: pieces,
            difficulty: "easy"
        )
    }
}