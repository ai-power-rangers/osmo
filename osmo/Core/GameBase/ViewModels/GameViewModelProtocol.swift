import Foundation
import SwiftUI
import Combine

/// Protocol defining the interface for game view models
/// Ensures consistent behavior across all game implementations
/// Uses modern @Observable pattern (iOS 17+)
@MainActor
public protocol GameViewModelProtocol: AnyObject {
    
    // MARK: - Associated Types
    
    /// The puzzle type this view model works with
    associatedtype PuzzleType: GamePuzzleProtocol
    
    // MARK: - Required Properties
    
    /// The current puzzle being played
    var currentPuzzle: PuzzleType? { get set }
    
    /// Current game state
    var gameState: GameState { get set }
    
    /// Whether the current puzzle is completed
    var isComplete: Bool { get }
    
    /// Current elapsed time in seconds
    var elapsedTime: TimeInterval { get }
    
    /// Current score (game-specific interpretation)
    var score: Int { get set }
    
    /// Number of moves/actions taken
    var moveCount: Int { get set }
    
    /// Whether the timer is running
    var isTimerRunning: Bool { get }
    
    /// Error message to display to user
    var errorMessage: String? { get set }
    
    /// Whether the game is in a valid state for saving
    var canSave: Bool { get }
    
    /// Whether undo is available
    var canUndo: Bool { get }
    
    /// Whether redo is available
    var canRedo: Bool { get }
    
    /// Storage service for saving/loading puzzles
    var storageService: (any PuzzleStorageProtocol)? { get set }
    
    /// Game context for accessing services
    var gameContext: GameContext? { get set }
    
    // MARK: - Game Lifecycle Methods
    
    /// Starts a new game with the given puzzle
    /// - Parameter puzzle: The puzzle to play
    func startGame(with puzzle: PuzzleType)
    
    /// Transitions from ready to playing state
    func transitionToPlaying()
    
    /// Pauses the current game
    func pauseGame()
    
    /// Resumes a paused game
    func resumeGame()
    
    /// Ends the current game
    func endGame()
    
    /// Resets the game to initial state
    func resetGame()
    
    // MARK: - Undo/Redo Methods
    
    /// Saves the current puzzle state to the undo stack
    func saveUndoState()
    
    /// Undoes the last action
    func undo()
    
    /// Redoes the last undone action
    func redo()
    
    // MARK: - Save/Load Methods
    
    /// Saves the current puzzle state
    func savePuzzle() async throws
    
    /// Loads a puzzle by ID
    /// - Parameter id: The puzzle ID to load
    func loadPuzzle(id: String) async throws
    
    /// Auto-saves the current state if enabled
    func autoSave()
    
    // MARK: - Validation Methods
    
    /// Validates the current move or state
    /// - Returns: True if the current state is valid
    func validateCurrentState() -> Bool
    
    /// Called when a move is made to update game state
    func recordMove()
    
    // MARK: - Error Handling
    
    /// Clears the current error
    func clearError()
    
    // MARK: - Scoring Methods
    
    /// Updates the score
    /// - Parameter points: Points to add to the score
    func updateScore(points: Int)
    
    /// Calculates final score
    /// - Returns: The final score for the game
    func calculateFinalScore() -> Int
    
    // MARK: - Completion Handling
    
    /// Called when puzzle is completed
    func onPuzzleCompleted()
}

// MARK: - Default Implementations
// Note: Implementations moved to BaseGameViewModel to avoid recursive constraint

// MARK: - Convenience Extensions

public extension GameViewModelProtocol {
    
    /// Whether the game is currently active (playing or paused)
    var isGameActive: Bool {
        return gameState.isActive || gameState == .paused
    }
    
    /// Whether the game has finished (completed, ended, or error)
    var isGameFinished: Bool {
        return gameState.isFinished
    }
    
    /// Whether moves can be made in the current state
    var canMakeMove: Bool {
        return gameState.acceptsInput && !isComplete
    }
    
    /// Formatted elapsed time string
    var elapsedTimeFormatted: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    /// Default implementation returns 1.0 if complete, 0.0 otherwise
    /// Override in specific view models for more granular progress
    var progress: Double {
        return isComplete ? 1.0 : 0.0
    }
    
    /// Whether the current game session has any progress
    var hasProgress: Bool {
        return moveCount > 0 || elapsedTime > 0
    }
    
    /// Summary of current game status
    var gameStatusSummary: String {
        if let error = errorMessage {
            return "Error: \(error)"
        }
        
        switch gameState {
        case .initializing:
            return "Initializing game..."
        case .ready:
            return "Ready to play"
        case .playing:
            return "Playing - \(elapsedTimeFormatted)"
        case .paused:
            return "Paused - \(elapsedTimeFormatted)"
        case .completed:
            return "Completed in \(elapsedTimeFormatted)!"
        case .ended:
            return "Game ended"
        case .error:
            return "Game error"
        }
    }
}