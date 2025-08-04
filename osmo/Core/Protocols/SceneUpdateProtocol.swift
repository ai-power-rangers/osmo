//
//  SceneUpdateProtocol.swift
//  osmo
//
//  Architecture: Scene Update Contract for ViewModel → Scene communication
//

import Foundation
import CoreGraphics

/// Protocol for scenes to receive explicit updates from ViewModels
/// Replaces Combine observation with direct method calls
public protocol SceneUpdateReceiver: AnyObject {
    /// Update the entire display with a new game state
    func updateDisplay(with state: GameStateSnapshot)
    
    /// Show an error to the user
    func showError(_ error: SceneError)
    
    /// Play a specific animation
    func playAnimation(_ animation: GameAnimation)
    
    // MARK: - Future CV Extensions (uncomment when ready)
    // func showCVGuidance(_ guidance: CVGuidance)
    // func updateConfidenceIndicator(_ level: Float)
    // func showPhysicalFeedback(_ feedback: PhysicalGameFeedback)
}

/// Optional protocol methods with default implementations
public extension SceneUpdateReceiver {
    func showError(_ error: SceneError) {
        // Default: log error
        print("Scene Error: \(error)")
    }
    
    func playAnimation(_ animation: GameAnimation) {
        // Default: no animation
    }
}

/// Protocol for ViewModels to provide updates to scenes
public protocol SceneUpdateProvider {
    /// Register a scene to receive updates
    func registerSceneReceiver(_ receiver: SceneUpdateReceiver?)
    
    /// Notify the registered scene of state changes
    func notifySceneUpdate()
}

/// Animation types that can be played
public enum GameAnimation {
    case pieceSnap(position: CGPoint)
    case pieceRelease
    case puzzleComplete
    case invalidMove
    case undo
    case redo
    case custom(String)
}

/// Errors that can be displayed in the scene
public enum SceneError: LocalizedError {
    case invalidMove(reason: String)
    case puzzleLoadFailed
    case saveFailed
    case serviceUnavailable(service: String)
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMove(let reason):
            return "Invalid move: \(reason)"
        case .puzzleLoadFailed:
            return "Failed to load puzzle"
        case .saveFailed:
            return "Failed to save game"
        case .serviceUnavailable(let service):
            return "\(service) service is unavailable"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Future CV Support

/// Guidance for physical game manipulation (future)
public struct CVGuidance {
    let message: String
    let visualHints: [CGPoint]
    let confidence: Float
}

/// Feedback for physical game pieces (future)
public struct PhysicalGameFeedback {
    let detectedPieces: Int
    let placementValid: Bool
    let suggestedPosition: CGPoint?
}