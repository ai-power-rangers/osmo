//
//  GameStateSnapshot.swift
//  osmo
//
//  Architecture: Immutable state snapshot for Scene updates
//

import Foundation
import CoreGraphics

/// Immutable snapshot of game state for scene updates
/// This is what gets passed from ViewModel to Scene
public struct GameStateSnapshot {
    // MARK: - Core State
    public let pieces: [any Hashable]
    public let isComplete: Bool
    public let moveCount: Int
    public let elapsedTime: TimeInterval
    public let currentScore: Int
    
    // MARK: - Input Tracking
    public let inputSource: InputSource
    public let lastAction: GameAction?
    
    // MARK: - Game-Specific State
    public let metadata: [String: Any]
    
    // MARK: - Future CV Support
    public let confidence: Float?  // CV detection confidence
    public let physicalPiecesDetected: Int?  // Number of physical pieces seen
    
    public init(pieces: [any Hashable],
                isComplete: Bool,
                moveCount: Int,
                elapsedTime: TimeInterval,
                currentScore: Int,
                inputSource: InputSource = .touch,
                lastAction: GameAction? = nil,
                metadata: [String: Any] = [:],
                confidence: Float? = nil,
                physicalPiecesDetected: Int? = nil) {
        self.pieces = pieces
        self.isComplete = isComplete
        self.moveCount = moveCount
        self.elapsedTime = elapsedTime
        self.currentScore = currentScore
        self.inputSource = inputSource
        self.lastAction = lastAction
        self.metadata = metadata
        self.confidence = confidence
        self.physicalPiecesDetected = physicalPiecesDetected
    }
}

/// State change types for incremental updates
public enum GameStateChange {
    case pieceMoved(id: String, from: CGPoint, to: CGPoint)
    case pieceSelected(id: String)
    case pieceReleased(id: String)
    case scoreChanged(old: Int, new: Int)
    case puzzleCompleted
    case stateReset
    case undoPerformed
    case redoPerformed
}

/// Generic piece state representation
public struct PieceState: Hashable, Codable {
    public let id: String
    public let position: CGPoint
    public let rotation: Float
    public let isLocked: Bool
    public let metadata: [String: String]
    
    public init(id: String,
                position: CGPoint,
                rotation: Float = 0,
                isLocked: Bool = false,
                metadata: [String: String] = [:]) {
        self.id = id
        self.position = position
        self.rotation = rotation
        self.isLocked = isLocked
        self.metadata = metadata
    }
}

/// Extension for convenient state snapshot creation
public extension GameStateSnapshot {
    /// Create a snapshot with just the essential data
    static func basic(pieces: [any Hashable],
                      isComplete: Bool,
                      moveCount: Int) -> GameStateSnapshot {
        GameStateSnapshot(
            pieces: pieces,
            isComplete: isComplete,
            moveCount: moveCount,
            elapsedTime: 0,
            currentScore: 0
        )
    }
    
    /// Create an empty snapshot
    static var empty: GameStateSnapshot {
        GameStateSnapshot(
            pieces: [],
            isComplete: false,
            moveCount: 0,
            elapsedTime: 0,
            currentScore: 0
        )
    }
}