import Foundation

/// Represents the current state of a game
/// Used by all games to track their lifecycle and user interaction state
public enum GameState: String, CaseIterable, Codable {
    
    // MARK: - Game Lifecycle States
    
    /// Game is being initialized
    case initializing = "initializing"
    
    /// Game is ready to start
    case ready = "ready"
    
    /// Game is actively being played
    case playing = "playing"
    
    /// Game is temporarily paused
    case paused = "paused"
    
    /// Game has been completed successfully
    case completed = "completed"
    
    /// Game ended without completion (user quit, etc.)
    case ended = "ended"
    
    /// Game encountered an error
    case error = "error"
    
    // MARK: - Computed Properties
    
    /// Whether the game is in an active playing state
    public var isActive: Bool {
        switch self {
        case .playing:
            return true
        default:
            return false
        }
    }
    
    /// Whether the game can be resumed
    public var canResume: Bool {
        switch self {
        case .paused, .ready:
            return true
        default:
            return false
        }
    }
    
    /// Whether the game is in a finished state
    public var isFinished: Bool {
        switch self {
        case .completed, .ended, .error:
            return true
        default:
            return false
        }
    }
    
    /// Whether the game can be reset
    public var canReset: Bool {
        switch self {
        case .initializing:
            return false
        default:
            return true
        }
    }
    
    /// Whether the game can accept user input
    public var acceptsInput: Bool {
        switch self {
        case .playing:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Display Properties
    
    /// Human-readable description of the state
    public var displayName: String {
        switch self {
        case .initializing:
            return "Initializing..."
        case .ready:
            return "Ready to Play"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed!"
        case .ended:
            return "Game Ended"
        case .error:
            return "Error"
        }
    }
    
    /// Icon name for the state (SF Symbols)
    public var iconName: String {
        switch self {
        case .initializing:
            return "clock"
        case .ready:
            return "play.circle"
        case .playing:
            return "pause.circle"
        case .paused:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .ended:
            return "stop.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    // MARK: - State Transitions
    
    /// Returns valid next states from the current state
    public var validTransitions: [GameState] {
        switch self {
        case .initializing:
            return [.ready, .error]
        case .ready:
            return [.playing, .error]
        case .playing:
            return [.paused, .completed, .ended, .error]
        case .paused:
            return [.playing, .ended, .error]
        case .completed:
            return [.ready, .ended]
        case .ended:
            return [.ready]
        case .error:
            return [.ready, .ended]
        }
    }
    
    /// Checks if a transition to another state is valid
    /// - Parameter newState: The state to transition to
    /// - Returns: True if the transition is valid
    public func canTransition(to newState: GameState) -> Bool {
        return validTransitions.contains(newState)
    }
}

// MARK: - State Transition Error

/// Error thrown when an invalid state transition is attempted
public struct GameStateTransitionError: Error, LocalizedError {
    public let fromState: GameState
    public let toState: GameState
    
    public var errorDescription: String? {
        return "Invalid transition from \(fromState.displayName) to \(toState.displayName)"
    }
    
    public var validTransitions: [GameState] {
        return fromState.validTransitions
    }
}