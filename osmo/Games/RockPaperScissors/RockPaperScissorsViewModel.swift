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
    private(set) var countdownValue = 3
    
    // MARK: - CV State
    
    private(set) var isHandDetected = false
    private(set) var currentGesture: RPSHandPose = .unknown
    private(set) var gestureConfidence: Float = 0.0
    private(set) var recentDetections: [GestureDetection] = []
    
    // Gesture locking for countdown
    private var lockedGesture: RPSHandPose?
    private var lastKnownGoodGesture: RPSHandPose = .unknown
    private var lastKnownGoodTimestamp: Date = Date()
    private let handLostGracePeriod: TimeInterval = 1.0  // Keep gesture for 1 second after hand lost
    
    // Gesture confidence buffer
    private let gestureConfidenceWindow: TimeInterval = 0.3  // Look at last 300ms for stability
    private let minConfidenceForLock: Float = 0.4  // Lowered minimum confidence to lock gesture
    
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
        
        // Don't clear recent detections - keep them for gesture locking
        // Just reset the current gesture display
        currentGesture = .unknown
        
        // Start countdown
        startCountdown()
    }
    
    func processHandMetrics(_ metrics: HandMetrics) {
        // Don't process during reveal phase - gesture is already locked
        guard roundPhase != .reveal else {
            print("[RPS] Ignoring metrics during reveal phase")
            return
        }
        
        // Update hand detection state
        isHandDetected = true
        
        // Infer gesture from finger count
        let inferredPose = metrics.inferredPose
        
        print("[RPS] Processing metrics - Fingers: \(metrics.fingerCount), Openness: \(metrics.handOpenness), Inferred: \(inferredPose)")
        
        // Add to recent detections
        let detection = GestureDetection(
            pose: inferredPose,
            confidence: metrics.stability,
            timestamp: Date(),
            handPosition: metrics.position
        )
        recentDetections.append(detection)
        
        // Keep only recent detections (last 0.5 seconds)
        let cutoff = Date().addingTimeInterval(-0.5)
        recentDetections.removeAll { $0.timestamp < cutoff }
        
        // Update current gesture if stable
        updateStableGesture()
        
        print("[RPS] Current gesture after update: \(currentGesture) with confidence: \(gestureConfidence)")
    }
    
    func handleHandLost() {
        isHandDetected = false
        
        // Don't immediately clear gesture - use grace period
        let timeSinceLastGood = Date().timeIntervalSince(lastKnownGoodTimestamp)
        
        // Only clear gesture if we're past the grace period AND not in active countdown
        if timeSinceLastGood > handLostGracePeriod && !roundPhase.isActive {
            currentGesture = .unknown
            gestureConfidence = 0.0
        }
        // During active rounds, keep the last known good gesture
    }
    
    // MARK: - Private Methods
    
    private func startCountdown() {
        roundPhase = .countdown(3)
        countdownValue = 3
        lockedGesture = nil  // Reset locked gesture for new round
        
        countdownTimer?.cancel()
        countdownTimer = Task { [weak self] in
            for i in (1...3).reversed() {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.countdownValue = i
                    self?.roundPhase = .countdown(i)
                    self?.audioService?.playSound("countdown_tick")
                    
                    // Lock gesture when countdown reaches 1
                    if i == 1 {
                        self?.lockGestureForReveal()
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
        
        print("[RPS] === REVEAL PHASE ===")
        print("[RPS] Current gesture: \(currentGesture), confidence: \(gestureConfidence)")
        print("[RPS] Recent detections count: \(recentDetections.count)")
        
        // Lock in player gesture
        let playerGesture = lockInPlayerGesture()
        
        // Generate AI gesture
        let aiGesture = generateAIMove()
        
        print("[RPS] Player: \(playerGesture), AI: \(aiGesture)")
        
        // Calculate result
        let result = matchState.recordRound(player: playerGesture, ai: aiGesture)
        
        print("[RPS] Result: \(result)")
        
        // Update history for AI learning
        if playerGesture != .unknown {
            playerHistory.append(playerGesture)
            updateAILearning(playerMove: playerGesture)
        }
        
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
                "result": result.rawValue,
                "confidence": gestureConfidence
            ]
        )
        
        // Check for match completion
        if matchState.matchResult.isComplete {
            handleMatchComplete()
        }
    }
    
    private func lockGestureForReveal() {
        // Get stable gesture from confidence window
        let stableGesture = getStableGestureFromWindow()
        
        if let (gesture, confidence) = stableGesture, confidence >= minConfidenceForLock {
            lockedGesture = gesture
            print("[RPS] Pre-locked stable gesture at countdown 1: \(gesture) with confidence \(confidence)")
            audioService?.playSound("gesture_lock")
            audioService?.playHaptic(.light)
        } else if currentGesture != .unknown && gestureConfidence > 0.5 {
            // Fallback to current gesture if no stable gesture found
            lockedGesture = currentGesture
            print("[RPS] Pre-locked current gesture: \(currentGesture) with confidence \(gestureConfidence)")
            audioService?.playSound("gesture_lock")
            audioService?.playHaptic(.light)
        } else {
            // Final fallback to best gesture from history
            let bestGesture = getBestGestureFromHistory()
            if bestGesture != .unknown {
                lockedGesture = bestGesture
                print("[RPS] Pre-locked gesture from history: \(bestGesture)")
            }
        }
    }
    
    private func lockInPlayerGesture() -> RPSHandPose {
        print("[RPS] === LOCK IN PLAYER GESTURE ===")
        print("[RPS] Locked gesture: \(String(describing: lockedGesture))")
        print("[RPS] Current gesture: \(currentGesture), confidence: \(gestureConfidence)")
        print("[RPS] Last known good: \(lastKnownGoodGesture)")
        print("[RPS] Recent detections count: \(recentDetections.count)")
        
        // First priority: Use pre-locked gesture if available
        if let locked = lockedGesture, locked != .unknown {
            print("[RPS] ✅ Using pre-locked gesture: \(locked)")
            return locked
        }
        
        // Second priority: Use current stable gesture if we have good confidence
        if currentGesture != .unknown && gestureConfidence > 0.5 {
            print("[RPS] Locking in current gesture: \(currentGesture) with confidence \(gestureConfidence)")
            audioService?.playSound("gesture_lock")
            audioService?.playHaptic(.medium)
            return currentGesture
        }
        
        // Third priority: Use last known good gesture if within grace period
        let timeSinceLastGood = Date().timeIntervalSince(lastKnownGoodTimestamp)
        if lastKnownGoodGesture != .unknown && timeSinceLastGood < handLostGracePeriod {
            print("[RPS] Using last known good gesture: \(lastKnownGoodGesture) from \(timeSinceLastGood)s ago")
            return lastKnownGoodGesture
        }
        
        // Final fallback: Use the most stable recent gesture
        let fallbackGesture = getBestGestureFromHistory()
        print("[RPS] Using fallback gesture from history: \(fallbackGesture)")
        
        if fallbackGesture != .unknown {
            audioService?.playSound("gesture_lock")
            audioService?.playHaptic(.medium)
        }
        
        return fallbackGesture
    }
    
    private func getBestGestureFromHistory() -> RPSHandPose {
        guard !recentDetections.isEmpty else {
            return .unknown
        }
        
        // Count occurrences of each gesture in recent detections
        var gestureCounts: [RPSHandPose: Int] = [:]
        for detection in recentDetections where detection.isConfident && detection.pose != .unknown {
            gestureCounts[detection.pose, default: 0] += 1
        }
        
        // Return most frequent confident gesture
        return gestureCounts.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
    
    private func getStableGestureFromWindow() -> (gesture: RPSHandPose, confidence: Float)? {
        // Get detections within confidence window
        let cutoff = Date().addingTimeInterval(-gestureConfidenceWindow)
        let windowDetections = recentDetections.filter { $0.timestamp >= cutoff && $0.isConfident }
        
        guard !windowDetections.isEmpty else { return nil }
        
        // Count gestures and calculate average confidence
        var gestureStats: [RPSHandPose: (count: Int, totalConfidence: Float)] = [:]
        
        for detection in windowDetections where detection.pose != .unknown {
            let current = gestureStats[detection.pose, default: (0, 0)]
            gestureStats[detection.pose] = (current.count + 1, current.totalConfidence + detection.confidence)
        }
        
        // Find most stable gesture (highest occurrence with good average confidence)
        var bestGesture: RPSHandPose?
        var bestScore: Float = 0
        
        for (gesture, stats) in gestureStats where gesture != .unknown {
            let avgConfidence = stats.totalConfidence / Float(stats.count)
            let occurrence = Float(stats.count) / Float(windowDetections.count)
            let score = avgConfidence * occurrence  // Combined score
            
            if score > bestScore {
                bestScore = score
                bestGesture = gesture
            }
        }
        
        if let gesture = bestGesture {
            let stats = gestureStats[gesture]!
            let avgConfidence = stats.totalConfidence / Float(stats.count)
            return (gesture, avgConfidence)
        }
        
        return nil
    }
    
    private func updateStableGesture() {
        // Calculate most common gesture in recent detections
        guard !recentDetections.isEmpty else {
            currentGesture = .unknown
            gestureConfidence = 0.0
            return
        }
        
        // Count confident detections by gesture
        var gestureCounts: [RPSHandPose: Int] = [:]
        var totalConfident = 0
        
        print("[RPS] UpdateStableGesture - Total detections: \(recentDetections.count)")
        
        for detection in recentDetections {
            print("[RPS] Detection: \(detection.pose), confidence: \(detection.confidence), isConfident: \(detection.isConfident)")
            if detection.isConfident && detection.pose != .unknown {
                gestureCounts[detection.pose, default: 0] += 1
                totalConfident += 1
            }
        }
        
        // Find most common gesture
        if let (gesture, count) = gestureCounts.max(by: { $0.value < $1.value }) {
            currentGesture = gesture
            gestureConfidence = Float(count) / Float(max(recentDetections.count, 1))
            
            // Update last known good gesture if this is a confident detection
            if gesture != .unknown && gestureConfidence > 0.5 {
                lastKnownGoodGesture = gesture
                lastKnownGoodTimestamp = Date()
            }
        } else {
            currentGesture = .unknown
            gestureConfidence = 0.0
        }
    }
    
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
    }
    
    // MARK: - Cleanup
    
    deinit {
        countdownTimer?.cancel()
        gestureStabilityTimer?.cancel()
    }
}
