//
//  SudokuViewModel.swift
//  osmo
//
//  ViewModel for Sudoku game logic
//

import Foundation
import CoreGraphics
import Observation

@Observable
final class SudokuViewModel {
    
    // MARK: - Game State
    
    private(set) var gameState: SudokuGameState
    private(set) var board: SudokuBoard
    private(set) var gridSize: GridSize
    
    // MARK: - CV State
    
    private(set) var isBoardDetected = false
    private(set) var boardConfidence: Float = 0.0
    private(set) var boardDetection: BoardDetection?
    private(set) var detectionState: BoardDetectionState = .searching
    
    // Detection buffers for temporal consistency
    private var recentBoardDetections: [BoardDetection] = []
    private var recentTileDetections: [Position: [TileDetection]] = [:]
    private var stableDetectionFrames = 0
    
    // Virtual board state (what we display)
    private(set) var virtualBoard: [[Int?]]
    private(set) var detectionConfidences: [[Float]]
    
    // MARK: - UI State
    
    private(set) var lastPlacedPosition: Position?
    private(set) var validationResult: ValidationResult?
    var feedbackAnimation: FeedbackAnimation?
    
    // MARK: - Dependencies
    
    private weak var cvService: CVServiceProtocol?
    private weak var audioService: AudioServiceProtocol?
    private weak var analyticsService: AnalyticsServiceProtocol?
    
    // MARK: - Timers
    
    private var gameTimer: Task<Void, Never>?
    private let detectionBufferDuration: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    init(gridSize: GridSize, context: GameContext?) {
        self.gridSize = gridSize
        self.cvService = context?.cvService
        self.audioService = context?.audioService
        self.analyticsService = context?.analyticsService
        
        // Initialize based on grid size
        let config = gridSize == .fourByFour ? SudokuConfiguration.fourByFour : SudokuConfiguration.nineByNine
        self.gameState = SudokuGameState(configuration: config)
        self.board = SudokuBoard(size: gridSize)
        
        // Initialize virtual board
        let dimension = gridSize.rawValue
        self.virtualBoard = Array(repeating: Array(repeating: nil, count: dimension), count: dimension)
        self.detectionConfidences = Array(repeating: Array(repeating: 0.0, count: dimension), count: dimension)
    }
    
    // MARK: - Public Methods
    
    func startSetupMode() {
        gameState.mode = .setup
        board = SudokuBoard(size: gridSize)
        clearVirtualBoard()
        
        analyticsService?.logEvent(
            "sudoku_setup_started",
            parameters: ["grid_size": gridSize.rawValue]
        )
    }
    
    func confirmSetup() {
        // Lock current board state as the puzzle
        board.lockCurrentState()
        gameState.mode = .solving
        gameState.startTime = Date()
        
        // Start game timer
        startGameTimer()
        
        // Play start sound
        audioService?.playSound("game_start")
        audioService?.playHaptic(.medium)
        
        analyticsService?.logEvent(
            "sudoku_game_started",
            parameters: [
                "grid_size": gridSize.rawValue,
                "initial_tiles": countFilledCells()
            ]
        )
    }
    
    func stopGame() {
        gameTimer?.cancel()
        gameState.endTime = Date()
        
        analyticsService?.logEvent(
            "sudoku_game_stopped",
            parameters: [
                "grid_size": gridSize.rawValue,
                "duration": gameState.elapsedTime,
                "completed": board.isSolved()
            ]
        )
    }
    
    // MARK: - CV Processing
    
    func processBoardDetection(_ detection: BoardDetection) {
        // Add to recent detections
        recentBoardDetections.append(detection)
        
        // Keep only recent detections
        let cutoff = Date().addingTimeInterval(-detectionBufferDuration)
        recentBoardDetections.removeAll { $0.timestamp < cutoff }
        
        // Update board state if we have consistent detection
        if recentBoardDetections.count >= gameState.configuration.temporalConsistencyFrames {
            updateBoardDetection()
        }
    }
    
    func processTileDetection(_ detection: TileDetection) {
        // Only process during appropriate modes
        guard gameState.mode == .setup || gameState.mode == .solving else { return }
        
        // Add to position-specific buffer
        if recentTileDetections[detection.position] == nil {
            recentTileDetections[detection.position] = []
        }
        recentTileDetections[detection.position]?.append(detection)
        
        // Keep only recent detections
        let cutoff = Date().addingTimeInterval(-detectionBufferDuration)
        recentTileDetections[detection.position]?.removeAll { $0.timestamp < cutoff }
        
        // Update if we have consistent detection
        if let detections = recentTileDetections[detection.position],
           detections.count >= gameState.configuration.temporalConsistencyFrames {
            updateTileAtPosition(detection.position)
        }
    }
    
    func handleBoardLost() {
        boardConfidence = 0.0
        
        // Update state machine
        if detectionState == .confirmed {
            // Give some grace period before losing confirmation
            stableDetectionFrames = max(0, stableDetectionFrames - 2)
            
            if stableDetectionFrames <= 0 {
                detectionState = .searching
                isBoardDetected = false
            }
        } else {
            detectionState = .searching
            stableDetectionFrames = 0
            isBoardDetected = false
        }
        
        // Don't immediately clear - keep showing last known state
        // Just reduce confidence gradually
        updateDetectionConfidences(multiplier: 0.8)
    }
    
    // MARK: - Private Methods
    
    private func updateBoardDetection() {
        // Calculate average confidence and position
        let avgConfidence = recentBoardDetections.reduce(0) { $0 + $1.confidence } / Float(recentBoardDetections.count)
        
        // Use most recent detection with smoothing
        if let latest = recentBoardDetections.last {
            boardDetection = latest
            boardConfidence = avgConfidence
            
            // Update detection state machine
            switch detectionState {
            case .searching:
                // Found a board, move to detecting
                detectionState = .detecting
                stableDetectionFrames = 0
                
            case .detecting:
                // Check if board is valid
                if avgConfidence > gameState.configuration.detectionConfidenceThreshold {
                    detectionState = .stabilizing
                    stableDetectionFrames = 0
                } else {
                    // Not confident enough, stay in detecting
                    stableDetectionFrames = 0
                }
                
            case .stabilizing:
                // Build confidence
                if avgConfidence > gameState.configuration.detectionConfidenceThreshold {
                    stableDetectionFrames += 1
                    
                    // Move to confirmed after 10 stable frames
                    if stableDetectionFrames >= 10 {
                        detectionState = .confirmed
                        isBoardDetected = true
                        
                        // Play confirmation sound
                        audioService?.playSound("board_detected")
                        audioService?.playHaptic(.medium)
                    }
                } else {
                    // Lost confidence, back to detecting
                    detectionState = .detecting
                    stableDetectionFrames = 0
                }
                
            case .confirmed:
                // Monitor for board loss
                if avgConfidence < gameState.configuration.detectionConfidenceThreshold * 0.7 {
                    // Significant drop in confidence
                    detectionState = .detecting
                    stableDetectionFrames = 0
                }
                // Otherwise stay confirmed
            }
        }
    }
    
    private func updateTileAtPosition(_ position: Position) {
        guard let detections = recentTileDetections[position] else { return }
        
        // Count occurrences of each number
        var numberCounts: [Int: Int] = [:]
        var totalConfidence: Float = 0
        
        for detection in detections {
            if let number = detection.number {
                numberCounts[number, default: 0] += 1
                totalConfidence += detection.confidence
            }
        }
        
        // Find most frequent number
        if let (number, _) = numberCounts.max(by: { $0.value < $1.value }) {
            let confidence = totalConfidence / Float(detections.count)
            
            // Update virtual board if confident enough
            if confidence > gameState.configuration.detectionConfidenceThreshold {
                updateVirtualBoard(number: number, at: position, confidence: confidence)
                
                // In solving mode, validate placement
                if gameState.mode == .solving {
                    validatePlacement(number: number, at: position)
                }
            }
        } else {
            // No number detected - might be empty cell
            updateVirtualBoard(number: nil, at: position, confidence: 0.5)
        }
    }
    
    private func updateVirtualBoard(number: Int?, at position: Position, confidence: Float) {
        // Update virtual board with smooth transitions
        let oldNumber = virtualBoard[position.row][position.col]
        virtualBoard[position.row][position.col] = number
        detectionConfidences[position.row][position.col] = confidence
        
        // Trigger animation if number changed
        if oldNumber != number {
            lastPlacedPosition = position
            
            // Play sound for tile placement
            if number != nil {
                audioService?.playSound("tile_place")
                audioService?.playHaptic(.light)
            }
        }
    }
    
    private func validatePlacement(number: Int, at position: Position) {
        // Check if it's an original tile
        if board.isOriginalTile(at: position) {
            feedbackAnimation = .originalTileWarning
            audioService?.playSound("warning")
            audioService?.playHaptic(.warning)
            return
        }
        
        // Try to place on actual board
        let result = board.place(number: number, at: position)
        
        switch result {
        case .valid:
            feedbackAnimation = .correctPlacement
            audioService?.playSound("correct_placement")
            audioService?.playHaptic(.success)
            
            // Check if puzzle is solved
            if board.isSolved() {
                handlePuzzleComplete()
            }
            
        case .invalid(let reason):
            feedbackAnimation = .incorrectPlacement
            validationResult = board.validate(number: number, at: position)
            audioService?.playSound("incorrect_placement")
            audioService?.playHaptic(.error)
            print("[Sudoku] Invalid placement: \(reason)")
            
        case .alreadyFilled, .originalTile:
            // These are handled differently
            break
        }
    }
    
    private func handlePuzzleComplete() {
        gameState.mode = .completed
        gameState.endTime = Date()
        feedbackAnimation = .puzzleComplete
        
        // Stop timer
        gameTimer?.cancel()
        
        // Play celebration
        audioService?.playSound("puzzle_complete")
        audioService?.playHaptic(.success)
        
        // Analytics
        analyticsService?.logEvent(
            "sudoku_completed",
            parameters: [
                "grid_size": gridSize.rawValue,
                "duration": gameState.elapsedTime,
                "moves": countFilledCells() - countOriginalTiles()
            ]
        )
    }
    
    private func startGameTimer() {
        gameTimer?.cancel()
        gameTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                await MainActor.run {
                    // Timer updates are handled by computed property
                    // @Observable automatically handles updates
                    _ = self?.gameState.formattedTime
                }
            }
        }
    }
    
    private func clearVirtualBoard() {
        let dimension = gridSize.rawValue
        for row in 0..<dimension {
            for col in 0..<dimension {
                virtualBoard[row][col] = nil
                detectionConfidences[row][col] = 0.0
            }
        }
    }
    
    private func updateDetectionConfidences(multiplier: Float) {
        let dimension = gridSize.rawValue
        for row in 0..<dimension {
            for col in 0..<dimension {
                detectionConfidences[row][col] *= multiplier
            }
        }
    }
    
    private func countFilledCells() -> Int {
        var count = 0
        for row in board.grid {
            for cell in row {
                if cell != nil {
                    count += 1
                }
            }
        }
        return count
    }
    
    private func countOriginalTiles() -> Int {
        var count = 0
        let dimension = gridSize.rawValue
        for row in 0..<dimension {
            for col in 0..<dimension {
                if board.isOriginalTile(at: Position(row: row, col: col)) {
                    count += 1
                }
            }
        }
        return count
    }
    
    // MARK: - Cleanup
    
    deinit {
        gameTimer?.cancel()
    }
}