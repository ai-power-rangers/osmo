import Foundation
import Observation

@Observable
final class TangramViewModel {
    // MARK: - Game State
    private(set) var gamePhase: GamePhase = .waiting
    private(set) var currentPuzzle: Puzzle?
    private(set) var placedPieces: Set<String> = []  // pieceIds
    private(set) var piecesPlaced: Int = 0
    private(set) var totalPieces: Int = 7
    private(set) var isComplete = false
    
    // MARK: - Timer State
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var timerActive = false
    private var timerTask: Task<Void, Never>?
    
    // MARK: - Feedback State
    private(set) var lastHint: HintType?
    private(set) var attemptCount: [String: Int] = [:]  // pieceId -> attempts
    
    // MARK: - Dependencies
    private let context: GameContext?
    private var audioService: AudioServiceProtocol? { context?.audioService }
    private var analyticsService: AnalyticsServiceProtocol? { context?.analyticsService }
    private var persistenceService: PersistenceServiceProtocol? { context?.persistenceService }
    
    // MARK: - Types
    enum GamePhase {
        case waiting
        case playing
        case completed
        case paused
    }
    
    enum HintType {
        case needsRotation
        case wrongPiece
        case almostThere
    }
    
    // MARK: - Initialization
    init(context: GameContext?) {
        self.context = context
    }
    
    // MARK: - Game Management
    func loadPuzzle(_ puzzle: Puzzle) {
        self.currentPuzzle = puzzle
        self.totalPieces = puzzle.pieces.count
        self.placedPieces.removeAll()
        self.piecesPlaced = 0
        self.attemptCount.removeAll()
        self.gamePhase = .waiting
        
        // Analytics
        analyticsService?.logEvent("tangram_puzzle_loaded", parameters: [
            "puzzle_id": puzzle.id,
            "puzzle_name": puzzle.name
        ])
    }
    
    func startGame() {
        guard gamePhase == .waiting else { return }
        gamePhase = .playing
        startTimer()
        
        analyticsService?.logEvent("tangram_game_started", parameters: [
            "puzzle_id": currentPuzzle?.id ?? "unknown"
        ])
    }
    
    func pauseGame() {
        guard gamePhase == .playing else { return }
        gamePhase = .paused
        pauseTimer()
    }
    
    func resumeGame() {
        guard gamePhase == .paused else { return }
        gamePhase = .playing
        resumeTimer()
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        guard !timerActive else { return }
        timerActive = true
        
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.1))
                await MainActor.run { [weak self] in
                    self?.elapsedTime += 0.1
                }
            }
        }
    }
    
    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerActive = false
    }
    
    private func resumeTimer() {
        startTimer()
    }
    
    func stopTimer() {
        pauseTimer()
    }
    
    // MARK: - Piece Placement
    func recordSuccessfulPlacement(pieceId: String) {
        placedPieces.insert(pieceId)
        piecesPlaced = placedPieces.count
        
        analyticsService?.logEvent("tangram_piece_placed", parameters: [
            "piece": pieceId,
            "attempts": attemptCount[pieceId] ?? 1,
            "time_elapsed": elapsedTime
        ])
        
        // Check completion
        if piecesPlaced == totalPieces {
            completeGame()
        }
    }
    
    func recordFailedAttempt(pieceId: String) {
        attemptCount[pieceId, default: 0] += 1
    }
    
    // MARK: - Game Completion
    private func completeGame() {
        gamePhase = .completed
        stopTimer()
        isComplete = true
        
        // Save best time
        Task { [weak self] in
            guard let self, let puzzleId = currentPuzzle?.id else { return }
            await self.saveBestTime(for: puzzleId, time: self.elapsedTime)
        }
        
        analyticsService?.logEvent("tangram_puzzle_completed", parameters: [
            "puzzle_id": currentPuzzle?.id ?? "unknown",
            "time": elapsedTime,
            "total_attempts": attemptCount.values.reduce(0, +)
        ])
    }
    
    // MARK: - Persistence
    private func saveBestTime(for puzzleId: String, time: TimeInterval) async {
        // Save to persistence service
        var progress = GameProgress(gameId: "tangram")
        progress.levelsCompleted.insert(puzzleId)
        progress.totalPlayTime = time
        progress.lastPlayed = Date()
        
        try? await persistenceService?.saveGameProgress(progress)
    }
    
    // MARK: - Reset
    func resetPuzzle() {
        placedPieces.removeAll()
        piecesPlaced = 0
        attemptCount.removeAll()
        elapsedTime = 0
        isComplete = false
        gamePhase = .waiting
        lastHint = nil
        
        analyticsService?.logEvent("tangram_puzzle_reset", parameters: [
            "puzzle_id": currentPuzzle?.id ?? "unknown"
        ])
    }
}