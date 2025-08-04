import Foundation
import SwiftUI
import CoreGraphics

/// Base view model class providing common functionality for all games
/// Generic over PuzzleType to ensure type safety while sharing common logic
@MainActor
@Observable
open class BaseGameViewModel<PuzzleType: GamePuzzleProtocol>: SceneUpdateProvider, GameActionHandler, StateReconciliation {
    
    // MARK: - Observable Properties
    
    /// The current puzzle being played
    public var currentPuzzle: PuzzleType?
    
    /// Current game state
    public var gameState: GameState = .initializing
    
    /// Whether the current puzzle is completed
    public var isComplete: Bool = false
    
    /// Current elapsed time in seconds
    public var elapsedTime: TimeInterval = 0
    
    /// Current score (game-specific interpretation)
    public var score: Int = 0
    
    /// Number of moves/actions taken
    public var moveCount: Int = 0
    
    /// Whether the timer is running
    public var isTimerRunning: Bool = false
    
    /// Error message to display to user
    public var errorMessage: String?
    
    /// Whether the game is in a valid state for saving
    public var canSave: Bool = false
    
    /// Whether undo is available
    public var canUndo: Bool = false
    
    /// Whether redo is available
    public var canRedo: Bool = false
    
    // MARK: - Undo/Redo System
    
    /// Stack of previous states for undo functionality
    private var undoStack: [PuzzleType.StateType] = []
    
    /// Stack of future states for redo functionality
    private var redoStack: [PuzzleType.StateType] = []
    
    /// Maximum number of undo states to keep
    public var maxUndoStates: Int = 50
    
    // MARK: - Dependencies
    
    /// Service container providing all services
    public let services: ServiceContainer
    
    /// Scene receiver for explicit updates
    public weak var sceneReceiver: SceneUpdateReceiver?
    
    /// Track last input source
    public var lastInputSource: InputSource = .touch
    
    // MARK: - Internal State
    
    private var gameTimer: Timer?
    private var startTime: Date?
    
    // MARK: - Initialization
    
    public init(services: ServiceContainer) {
        self.services = services
    }
    
    public init(puzzle: PuzzleType, services: ServiceContainer) {
        self.currentPuzzle = puzzle
        self.services = services
    }
    
    // deinit handled automatically by @MainActor
    
    // MARK: - Setup
    
    /// Update completion status when puzzle changes
    private func checkCompletion() {
        if let puzzle = currentPuzzle {
            let wasComplete = isComplete
            isComplete = puzzle.isCompleted()
            updateCanSave()
            
            if isComplete && !wasComplete {
                handlePuzzleCompletion()
            }
        }
        // Notify scene of state change
        notifySceneUpdate()
    }
    
    // MARK: - SceneUpdateProvider Implementation
    
    /// Register a scene to receive updates
    public func registerSceneReceiver(_ receiver: SceneUpdateReceiver?) {
        self.sceneReceiver = receiver
        // Send initial state if we have one
        if currentPuzzle != nil {
            notifySceneUpdate()
        }
    }
    
    /// Notify the registered scene of state changes
    public func notifySceneUpdate() {
        #if DEBUG
        if sceneReceiver == nil {
            print("[WARNING] notifySceneUpdate called but sceneReceiver is nil")
        }
        #endif
        
        guard let scene = sceneReceiver else { return }
        let snapshot = createStateSnapshot()
        scene.updateDisplay(with: snapshot)
    }
    
    /// Create a snapshot of the current game state
    open func createStateSnapshot() -> GameStateSnapshot {
        GameStateSnapshot(
            pieces: currentPuzzle?.pieces ?? [],
            isComplete: isComplete,
            moveCount: moveCount,
            elapsedTime: elapsedTime,
            currentScore: score,
            inputSource: lastInputSource,
            lastAction: nil,
            metadata: [:],
            confidence: nil,
            physicalPiecesDetected: nil
        )
    }
    
    // MARK: - GameActionHandler Implementation
    
    /// Handle a move from one position to another
    open func handleMove(from: CGPoint, to: CGPoint, source: InputSource) {
        lastInputSource = source
        // Override in subclasses for game-specific move handling
        // After handling, call notifySceneUpdate()
    }
    
    /// Handle selection at a point
    open func handleSelection(at point: CGPoint, source: InputSource) {
        lastInputSource = source
        // Override in subclasses for game-specific selection handling
        // After handling, call notifySceneUpdate()
    }
    
    /// Handle a gesture
    open func handleGesture(_ gesture: GameGesture, source: InputSource) {
        lastInputSource = source
        // Override in subclasses for game-specific gesture handling
        // After handling, call notifySceneUpdate()
    }
    
    // MARK: - Game Lifecycle
    
    /// Starts a new game with the given puzzle
    /// - Parameter puzzle: The puzzle to play
    public func startGame(with puzzle: PuzzleType) {
        guard gameState.canTransition(to: .ready) else {
            setError("Cannot start game from current state: \(gameState.displayName)")
            return
        }
        
        currentPuzzle = puzzle
        gameState = .ready
        resetGameState()
        checkCompletion()
        
        // Create initial undo state
        saveUndoState()
        
        transitionToPlaying()
    }
    
    /// Transitions from ready to playing state
    public func transitionToPlaying() {
        guard gameState.canTransition(to: .playing) else {
            setError("Cannot start playing from current state: \(gameState.displayName)")
            return
        }
        
        gameState = .playing
        startTimer()
        notifySceneUpdate()
    }
    
    /// Pauses the current game
    public func pauseGame() {
        guard gameState.canTransition(to: .paused) else {
            setError("Cannot pause from current state: \(gameState.displayName)")
            return
        }
        
        gameState = .paused
        stopTimer()
        notifySceneUpdate()
    }
    
    /// Resumes a paused game
    public func resumeGame() {
        guard gameState.canTransition(to: .playing) else {
            setError("Cannot resume from current state: \(gameState.displayName)")
            return
        }
        
        gameState = .playing
        startTimer()
        notifySceneUpdate()
    }
    
    /// Ends the current game
    public func endGame() {
        guard gameState.canTransition(to: .ended) else {
            setError("Cannot end game from current state: \(gameState.displayName)")
            return
        }
        
        gameState = .ended
        stopTimer()
        
        // Record the play session
        if var puzzle = currentPuzzle {
            puzzle.recordPlay(completed: isComplete, time: elapsedTime)
            currentPuzzle = puzzle
            checkCompletion()
        }
    }
    
    /// Resets the game to initial state
    public func resetGame() {
        guard gameState.canReset else {
            setError("Cannot reset game from current state: \(gameState.displayName)")
            return
        }
        
        stopTimer()
        currentPuzzle?.reset()
        resetGameState()
        
        // Clear undo/redo stacks
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoState()
        
        gameState = .ready
        
        // Create new initial undo state
        saveUndoState()
    }
    
    private func resetGameState() {
        elapsedTime = 0
        score = 0
        moveCount = 0
        isComplete = false
        isTimerRunning = false
        errorMessage = nil
        startTime = nil
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        guard !isTimerRunning else { return }
        
        startTime = Date()
        isTimerRunning = true
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    private func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
        isTimerRunning = false
    }
    
    private func updateElapsedTime() {
        guard let startTime = startTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Undo/Redo System
    
    /// Saves the current puzzle state to the undo stack
    public func saveUndoState() {
        guard let puzzle = currentPuzzle else { return }
        
        undoStack.append(puzzle.currentState)
        
        // Limit undo stack size
        if undoStack.count > maxUndoStates {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when new action is taken
        redoStack.removeAll()
        
        updateUndoRedoState()
    }
    
    /// Undoes the last action
    public func undo() {
        guard canUndo, var puzzle = currentPuzzle else { return }
        
        // Save current state to redo stack
        redoStack.append(puzzle.currentState)
        
        // Restore previous state
        if let previousState = undoStack.popLast() {
            puzzle.currentState = previousState
            currentPuzzle = puzzle
            checkCompletion()
            moveCount = max(0, moveCount - 1)
        }
        
        updateUndoRedoState()
        notifySceneUpdate()
        sceneReceiver?.playAnimation(.undo)
    }
    
    /// Redoes the last undone action
    public func redo() {
        guard canRedo, var puzzle = currentPuzzle else { return }
        
        // Save current state to undo stack
        undoStack.append(puzzle.currentState)
        
        // Restore future state
        if let futureState = redoStack.popLast() {
            puzzle.currentState = futureState
            currentPuzzle = puzzle
            checkCompletion()
            moveCount += 1
        }
        
        updateUndoRedoState()
        notifySceneUpdate()
        sceneReceiver?.playAnimation(.redo)
    }
    
    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    // MARK: - Save/Load
    
    /// Saves the current puzzle state
    public func savePuzzle() async throws {
        guard let puzzle = currentPuzzle else {
            throw GameViewModelError.missingDependencies
        }
        
        guard canSave else {
            throw GameViewModelError.cannotSave
        }
        
        try await services.storageService.save(puzzle)
    }
    
    /// Loads a puzzle by ID
    public func loadPuzzle(id: String) async throws {
        let storage = services.storageService
        
        guard let puzzle: PuzzleType = try await storage.load(id: id) else {
            throw GameViewModelError.puzzleNotFound(id)
        }
        
        currentPuzzle = puzzle
        gameState = .ready
        checkCompletion()
        resetGameState()
    }
    
    /// Auto-saves the current state if enabled
    public func autoSave() {
        guard canSave else { return }
        
        Task {
            try? await savePuzzle()
        }
    }
    
    private func updateCanSave() {
        canSave = currentPuzzle != nil && 
                  gameState.acceptsInput
    }
    
    // MARK: - Validation
    
    /// Validates the current move or state
    /// Override in subclasses for game-specific validation
    open func validateCurrentState() -> Bool {
        return currentPuzzle?.isValid() ?? false
    }
    
    /// Called when a move is made to update game state
    /// Override in subclasses for game-specific logic
    open func recordMove() {
        moveCount += 1
        saveUndoState()
        
        // Check for completion
        if let puzzle = currentPuzzle, puzzle.isCompleted() {
            isComplete = true
        }
        
        // Auto-save if configured
        autoSave()
        
        // Notify scene of the move
        notifySceneUpdate()
    }
    
    // MARK: - Completion Handling
    
    private func handlePuzzleCompletion() {
        guard gameState.canTransition(to: .completed) else { return }
        
        gameState = .completed
        stopTimer()
        
        // Record completion
        if var puzzle = currentPuzzle {
            puzzle.recordPlay(completed: true, time: elapsedTime)
            currentPuzzle = puzzle
            // Don't call checkCompletion here to avoid recursion
        }
        
        // Notify about completion (override in subclasses for specific behavior)
        onPuzzleCompleted()
    }
    
    /// Called when puzzle is completed - override in subclasses
    open func onPuzzleCompleted() {
        // Override in subclasses for game-specific completion handling
        sceneReceiver?.playAnimation(.puzzleComplete)
    }
    
    // MARK: - Error Handling
    
    private func setError(_ message: String) {
        errorMessage = message
        gameState = .error
        sceneReceiver?.showError(SceneError.custom(message))
    }
    
    /// Clears the current error
    public func clearError() {
        errorMessage = nil
        if gameState == .error {
            gameState = .ready
        }
    }
    
    // MARK: - Scoring
    
    /// Updates the score - override in subclasses for game-specific scoring
    open func updateScore(points: Int) {
        score += points
    }
    
    /// Calculates final score - override in subclasses
    open func calculateFinalScore() -> Int {
        return score
    }
}

// MARK: - StateReconciliation Implementation

extension BaseGameViewModel {
    public typealias StateType = PuzzleType.StateType
    
    /// Capture current state as a memento
    public func captureState() -> GameStateMemento<StateType> {
        // If no puzzle loaded, create empty state memento
        let state: StateType
        if let currentState = currentPuzzle?.currentState {
            state = currentState
        } else {
            // This will need to be overridden in subclasses to provide proper empty state
            fatalError("captureState called without a puzzle loaded. Subclasses must override to provide empty state.")
        }
        return GameStateMemento(
            state: state,
            source: lastInputSource,
            metadata: [
                "gameState": gameState.rawValue,
                "moveCount": "\(moveCount)",
                "elapsedTime": "\(elapsedTime)"
            ]
        )
    }
    
    /// Restore state from a memento
    public func restoreState(_ memento: GameStateMemento<StateType>) {
        guard memento.isValid() else {
            print("[BaseGameViewModel] Invalid memento checksum")
            return
        }
        
        if var puzzle = currentPuzzle {
            puzzle.currentState = memento.state
            currentPuzzle = puzzle
            notifySceneUpdate()
        }
    }
    
    /// Validate a state
    public func validateState(_ state: StateType) -> StateValidation {
        // Default validation - override in subclasses for game-specific rules
        if let puzzle = currentPuzzle {
            if !puzzle.isValid() {
                return StateValidation(
                    isValid: false,
                    errors: [StateValidationError(code: "puzzle_error", message: "Puzzle configuration is invalid")]
                )
            }
        }
        return .valid
    }
    
    /// Calculate difference between two states
    public func calculateStateDiff(_ from: StateType, _ to: StateType) -> StateDiff {
        // This is a simple implementation
        // Subclasses should override for game-specific diff calculation
        
        // Try to get piece counts if available
        let fromPieces = (from as? any Collection)?.count ?? 0
        let toPieces = (to as? any Collection)?.count ?? 0
        
        if fromPieces != toPieces {
            return StateDiff(
                additions: fromPieces < toPieces ? ["pieces_added"] : [],
                removals: fromPieces > toPieces ? ["pieces_removed"] : [],
                modifications: fromPieces == toPieces ? ["pieces_modified"] : []
            )
        }
        
        return StateDiff(unchanged: ["no_changes"])
    }
    
    /// Reconcile with physical state (future CV support)
    public func reconcileWithPhysicalState(_ detected: PhysicalGameState) -> StateType {
        // Default implementation - will be overridden when CV is integrated
        print("[BaseGameViewModel] Physical state reconciliation not yet implemented")
        return captureState().state
    }
    
    /// Resolve conflicts between digital and physical states
    public func resolveConflicts(_ digital: StateType, _ physical: PhysicalGameState) -> ConflictResolution<StateType> {
        // For now, always trust digital state
        // When CV is integrated, this will have sophisticated conflict resolution
        return ConflictResolution(
            resolvedState: digital,
            strategy: .trustDigital,
            conflicts: [],
            confidence: 1.0
        )
    }
}

// MARK: - Errors

public enum GameViewModelError: Error, LocalizedError {
    case missingDependencies
    case cannotSave
    case puzzleNotFound(String)
    case invalidState
    
    public var errorDescription: String? {
        switch self {
        case .missingDependencies:
            return "Required services are not available"
        case .cannotSave:
            return "Cannot save in current state"
        case .puzzleNotFound(let id):
            return "Puzzle with ID '\(id)' not found"
        case .invalidState:
            return "Game is in an invalid state"
        }
    }
}