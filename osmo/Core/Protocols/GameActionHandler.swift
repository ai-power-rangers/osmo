//
//  GameActionHandler.swift
//  osmo
//
//  Architecture: Command pattern for Scene → ViewModel communication
//

import Foundation
import CoreGraphics

/// Input source tracking for analytics and future CV integration
public enum InputSource: String, Codable {
    case touch      // Current: Direct touch input
    case keyboard   // Current: Keyboard shortcuts
    case cv         // Future: Computer vision input
    case automated  // Testing or AI
}

/// Protocol for handling game actions from scenes
/// Scenes send commands, ViewModels make decisions
public protocol GameActionHandler: AnyObject {
    /// Handle a move from one position to another
    func handleMove(from: CGPoint, to: CGPoint, source: InputSource)
    
    /// Handle selection at a point
    func handleSelection(at point: CGPoint, source: InputSource)
    
    /// Handle a gesture
    func handleGesture(_ gesture: GameGesture, source: InputSource)
    
    /// Handle piece rotation
    func handleRotation(at point: CGPoint, angle: Float, source: InputSource)
    
    /// Handle piece release
    func handleRelease(at point: CGPoint, source: InputSource)
    
    // MARK: - Future CV Extensions
    // func handleCVEvent(_ event: CVGameEvent)
    // func handlePhysicalStateChange(_ state: PhysicalState)
}

/// Default implementations for optional methods
public extension GameActionHandler {
    func handleRotation(at point: CGPoint, angle: Float, source: InputSource) {
        // Default: no rotation support
    }
    
    func handleRelease(at point: CGPoint, source: InputSource) {
        // Default: treat as end of move
    }
    
    func handleGesture(_ gesture: GameGesture, source: InputSource) {
        // Default: no gesture support
    }
}

/// Game gestures that can be recognized
public enum GameGesture {
    case tap(location: CGPoint)
    case doubleTap(location: CGPoint)
    case longPress(location: CGPoint)
    case swipe(direction: SwipeDirection, location: CGPoint)
    case pinch(scale: Float, location: CGPoint)
    case rotate(angle: Float, location: CGPoint)
    case pan(translation: CGPoint, location: CGPoint)
}

/// Swipe directions
public enum SwipeDirection {
    case up, down, left, right
}

/// Game actions that can be performed (CV-ready abstraction)
public enum GameAction {
    case movePiece(id: String, to: CGPoint)
    case selectPiece(id: String)
    case releasePiece(id: String)
    case rotatePiece(id: String, angle: Float)
    case undo
    case redo
    case reset
    case hint
}

/// Protocol for processing different input types into game actions
public protocol GameInputProcessor {
    /// Process input at a point into a game action
    func processInput(at point: CGPoint, source: InputSource) -> GameAction?
    
    /// Validate if an input is valid
    func validateInput(_ input: GameInput) -> Bool
    
    /// Convert gesture to game action
    func processGesture(_ gesture: GameGesture, source: InputSource) -> GameAction?
}

/// Represents any game input
public struct GameInput {
    public let point: CGPoint
    public let source: InputSource
    public let timestamp: TimeInterval
    public let metadata: [String: Any]?
    
    public init(point: CGPoint, 
                source: InputSource, 
                timestamp: TimeInterval = Date().timeIntervalSince1970,
                metadata: [String: Any]? = nil) {
        self.point = point
        self.source = source
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Future CV Support

/// CV-specific game event (future)
public struct CVGameEvent {
    let type: CVGameEventType
    let position: CGPoint
    let confidence: Float
    let objectId: String?
}

/// CV event types for game actions (future)
public enum CVGameEventType {
    case pieceDetected(id: String)
    case pieceMoved(id: String, from: CGPoint, to: CGPoint)
    case pieceRemoved(id: String)
    case gestureRecognized(type: String)
}

/// Physical game state (future)
public struct PhysicalState {
    let detectedPieces: [String: CGPoint]
    let confidence: Float
    let timestamp: TimeInterval
}