//
//  RockPaperScissorsViewModel.swift
//  osmo
//
//  ViewModel for Rock-Paper-Scissors game logic
//

import Foundation
import Observation

@Observable
final class RockPaperScissorsViewModel {
    
    // MARK: - Game State
    
    private(set) var matchState: MatchState
    private(set) var roundPhase: RoundPhase = .waiting
    private(set) var countdownValue = 2
    
    // MARK: - CV State
    
    private(set) var isHandDetected = false
    private(set) var currentGesture: RPSHandPose? = nil
    private(set) var gestureConfidence: Float = 0.0
    
    // Gesture locking state
    private var savedGesture: RPSHandPose? = nil
    private var savedGestureTimestamp: Date? = nil
    private var isGestureLocked = false
    private var lockCandidateGesture: RPSHandPose? = nil
    private var lockCandidateFrameCount = 0
    private let framesNeededForLock = 3  // Need 3 consecutive frames of same gesture to lock
    
    // MARK: - AI State
    
    var difficulty: Difficulty = .medium
    private var aiStrategy: AIStrategy = .frequency
    private var playerHistory: [RPSHandPose] = []
    private var transitionMatrix: [[Double]] = Array(
        repeating: Array(repeating: 0.33, count: 3),
        count: 3
    )
    
    // MARK: - Dependencies
    
    private weak var cvService: CVServiceProtocol?
    private weak var audioService: AudioServiceProtocol?
    private weak var analyticsService: AnalyticsServiceProtocol?
    
    // MARK: - Timers
    
    private var countdownTimer: Task<Void, Never>?
    private var gestureStabilityTimer: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(context: GameContext?) {
        self.cvService = context?.cvService
        self.audioService = context?.audioService
        self.analyticsService = context?.analyticsService
        self.matchState = MatchState(configuration: .default)
        
        updateAIStrategy()
    }
    
    // MARK: - Public Methods
    
    func startNewMatch() {
        matchState = MatchState(configuration: .default)
        playerHistory.removeAll()
        roundPhase = .waiting
        
        analyticsService?.logEvent(
            "rps_match_started",
            parameters: ["difficulty": difficulty.rawValue]
        )
    }
    
    func startRound() {
        guard roundPhase == .waiting else { return }
        
        // Start new round
        let newRound = RoundState(
            roundNumber: matchState.currentRound + 1,
            playerGesture: nil,
            aiGesture: nil,
            result: nil,
            startTime: Date(),
            endTime: nil
        )
        matchState.rounds.append(newRound)
        
        // Reset lock state for new round
        isGestureLocked = false
        lockCandidateGesture = nil
        lockCandidateFrameCount = 0
        // Keep current gesture display but allow it to be changed
        
        // Start countdown
        startCountdown()
    }
    
    func processHandMetrics(_ metrics: HandMetrics) {
        isHandDetected = true
        
        let inferredPose = metrics.inferredPose
        let poseConfidence = metrics.gestureConfidence
        
        // Update current gesture for display
        currentGesture = inferredPose
        gestureConfidence = poseConfidence * metrics.stability
        
        // If gesture is already locked, don't process further
        if isGestureLocked {
            return
        }
        
        // Check if we should be in locking phase (countdown at 1 or less)
        let shouldTryToLock = countdownValue <= 1 && roundPhase.isActive
        
        // Process gesture based on confidence
        if poseConfidence >= 0.7 && inferredPose != .unknown {
            if shouldTryToLock {
                // In locking phase - check for stability
                if inferredPose == lockCandidateGesture {
                    lockCandidateFrameCount += 1
                    
                    if lockCandidateFrameCount >= framesNeededForLock && !isGestureLocked {
                        // Lock the gesture!
                        isGestureLocked = true
                        savedGesture = inferredPose
                        savedGestureTimestamp = Date()
                        
                        print("[RPS-VM] GESTURE LOCKED: \(inferredPose) after \(lockCandidateFrameCount) stable frames")
                        
                        // Strong haptic feedback for lock
                        audioService?.playSound("gesture_lock")
                        audioService?.playHaptic(.medium)
                    }
                } else {
                    // Different gesture detected, reset counter
                    lockCandidateGesture = inferredPose
                    lockCandidateFrameCount = 1
                }
            } else {
                // Free phase - just save the gesture
                if savedGesture != inferredPose {
                    print("[RPS-VM] Gesture changed from \(savedGesture?.rawValue ?? "none") to \(inferredPose)")
                }
                
                savedGesture = inferredPose
                savedGestureTimestamp = Date()
                
                // Light haptic for gesture detection
                if poseConfidence >= 0.85 {
                    audioService?.playHaptic(.light)
                }
            }
        } else if savedGesture == nil && poseConfidence >= 0.6 && inferredPose != .unknown {
            // Lower threshold for initial gesture detection
            savedGesture = inferredPose
            savedGestureTimestamp = Date()
            print("[RPS-VM] Initial gesture saved: \(inferredPose)")
        }
    }
    
    func handleHandLost() {
        isHandDetected = false
        // Don't change gestures - keep whatever we had
        print("[RPS] Hand lost but keeping gesture: \(currentGesture)")
    }
    
    // MARK: - Private Methods
    
    private func startCountdown() {
        roundPhase = .countdown(2)
        countdownValue = 2
        
        countdownTimer?.cancel()
        countdownTimer = Task { [weak self] in
            for i in (1...2).reversed() {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.countdownValue = i
                    self?.roundPhase = .countdown(i)
                    self?.audioService?.playSound("countdown_tick")
                    
                    // At countdown 1, we enter the locking phase
                    if i == 1 {
                        print("[RPS-VM] Entering lock phase - gesture must be stable for \(self?.framesNeededForLock ?? 3) frames")
                    }
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self?.revealGestures()
            }
        }
    }
    
    private func revealGestures() {
        roundPhase = .reveal
        
        // Use the saved gesture, or if nothing saved, use current gesture, or rock as last resort
        let playerGesture = savedGesture ?? currentGesture ?? .rock
        let aiGesture = generateAIMove()
        
        print("[RPS] === REVEAL PHASE ===")
        print("[RPS] Player: \(playerGesture), AI: \(aiGesture)")
        
        // Calculate result
        let result = matchState.recordRound(player: playerGesture, ai: aiGesture)
        
        print("[RPS] Result: \(result)")
        
        // Update history for AI learning
        playerHistory.append(playerGesture)
        updateAILearning(playerMove: playerGesture)
        
        // Play result sound
        playResultSound(result)
        
        // Show result
        roundPhase = .result
        
        // Track analytics
        analyticsService?.logEvent(
            "rps_round_played",
            parameters: [
                "round_number": matchState.currentRound,
                "player_gesture": playerGesture.rawValue,
                "ai_gesture": aiGesture.rawValue,
                "result": result.rawValue
            ]
        )
        
        // Check for match completion
        if matchState.matchResult.isComplete {
            handleMatchComplete()
        }
    }
    
    // Removed all complex locking functions - we don't need them anymore
    
    // MARK: - AI Methods
    
    private func generateAIMove() -> RPSHandPose {
        switch difficulty {
        case .easy:
            return generateRandomMove()
        case .medium:
            return generateFrequencyBasedMove()
        case .hard:
            return generateAdaptiveMove()
        }
    }
    
    private func generateRandomMove() -> RPSHandPose {
        [RPSHandPose.rock, .paper, .scissors].randomElement() ?? .rock
    }
    
    private func generateFrequencyBasedMove() -> RPSHandPose {
        guard playerHistory.count >= 3 else {
            return generateRandomMove()
        }
        
        // Count recent moves (last 5)
        let recentMoves = playerHistory.suffix(5)
        var moveCounts: [RPSHandPose: Int] = [:]
        
        for move in recentMoves {
            moveCounts[move, default: 0] += 1
        }
        
        // Find most frequent move
        if let (frequentMove, _) = moveCounts.max(by: { $0.value < $1.value }) {
            // Return counter to most frequent
            return frequentMove.winningMove
        }
        
        return generateRandomMove()
    }
    
    private func generateAdaptiveMove() -> RPSHandPose {
        guard playerHistory.count >= 2 else {
            return generateRandomMove()
        }
        
        // Use transition matrix to predict next move
        guard let lastMove = playerHistory.last else {
            return generateRandomMove()
        }
        let lastIndex = gestureToIndex(lastMove)
        let probabilities = transitionMatrix[lastIndex]
        
        // Weighted random selection
        let random = Double.random(in: 0...1)
        var cumulative = 0.0
        
        for (index, probability) in probabilities.enumerated() {
            cumulative += probability
            if random <= cumulative {
                let predictedMove = indexToGesture(index)
                return predictedMove.winningMove
            }
        }
        
        return generateRandomMove()
    }
    
    private func updateAILearning(playerMove: RPSHandPose) {
        guard playerHistory.count >= 2 else { return }
        
        let previousMove = playerHistory[playerHistory.count - 2]
        let fromIndex = gestureToIndex(previousMove)
        let toIndex = gestureToIndex(playerMove)
        
        // Update transition matrix with decay
        let learningRate = 0.1
        for i in 0..<3 {
            if i == toIndex {
                transitionMatrix[fromIndex][i] += learningRate * (1 - transitionMatrix[fromIndex][i])
            } else {
                transitionMatrix[fromIndex][i] *= (1 - learningRate)
            }
        }
        
        // Normalize
        let sum = transitionMatrix[fromIndex].reduce(0, +)
        if sum > 0 {
            for i in 0..<3 {
                transitionMatrix[fromIndex][i] /= sum
            }
        }
    }
    
    private func updateAIStrategy() {
        switch difficulty {
        case .easy:
            aiStrategy = .random
        case .medium:
            aiStrategy = .frequency
        case .hard:
            aiStrategy = .adaptive
        }
    }
    
    // MARK: - Helper Methods
    
    private func gestureToIndex(_ gesture: RPSHandPose) -> Int {
        switch gesture {
        case .rock: return 0
        case .paper: return 1
        case .scissors: return 2
        case .unknown: return 0 // Default to rock
        }
    }
    
    private func indexToGesture(_ index: Int) -> RPSHandPose {
        switch index {
        case 0: return .rock
        case 1: return .paper
        case 2: return .scissors
        default: return .rock
        }
    }
    
    private func playResultSound(_ result: RoundResult) {
        switch result {
        case .playerWin:
            audioService?.playSound("win_round")
            audioService?.playHaptic(.success)
        case .aiWin:
            audioService?.playSound("lose_round")
            audioService?.playHaptic(.error)
        case .tie:
            audioService?.playSound("tie_round")
            audioService?.playHaptic(.light)
        }
    }
    
    private func handleMatchComplete() {
        // Track completion
        analyticsService?.logEvent(
            "rps_match_completed",
            parameters: [
                "player_score": matchState.playerScore,
                "ai_score": matchState.aiScore,
                "total_rounds": matchState.rounds.count,
                "difficulty": difficulty.rawValue
            ]
        )
        
        // Play match end sound
        switch matchState.matchResult {
        case .playerWin:
            audioService?.playSound("match_victory")
        case .aiWin:
            audioService?.playSound("match_defeat")
        case .ongoing:
            break
        }
    }
    
    func resetToWaiting() {
        roundPhase = .waiting
        // Reset lock state
        isGestureLocked = false
        lockCandidateGesture = nil
        lockCandidateFrameCount = 0
        // Don't reset gestures - keep showing what we have
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        countdownTimer?.cancel()
        countdownTimer = nil
        gestureStabilityTimer?.cancel()
        gestureStabilityTimer = nil
    }
    
    deinit {
        cleanup()
    }
}
