//
//  GestureSmoothing.swift
//  osmo
//
//  Temporal smoothing for stable gesture detection
//

import Foundation

// MARK: - Gesture Smoothing
final class GestureSmoother {
    
    // MARK: - Configuration
    private let historySize: Int = 10  // Keep last 10 frames
    private let confidenceThreshold: Float = 0.7
    private let minimumConsistency: Int = 6  // Need 6/10 frames to agree
    
    // MARK: - State
    private var gestureHistory: [(gesture: RPSHandPose, confidence: Float, timestamp: TimeInterval)] = []
    private var lastStableGesture: RPSHandPose = .rock
    private var lastStableTimestamp: TimeInterval = 0
    
    // MARK: - Public Methods
    
    /// Add a new gesture observation and get the smoothed result
    func addObservation(gesture: RPSHandPose, confidence: Float) -> (gesture: RPSHandPose, confidence: Float) {
        let timestamp = Date().timeIntervalSince1970
        
        // Add to history
        gestureHistory.append((gesture, confidence, timestamp))
        
        // Maintain history size
        if gestureHistory.count > historySize {
            gestureHistory.removeFirst()
        }
        
        // Calculate smoothed gesture
        return calculateSmoothedGesture()
    }
    
    /// Reset the smoother (e.g., when hand is lost)
    func reset() {
        gestureHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func calculateSmoothedGesture() -> (gesture: RPSHandPose, confidence: Float) {
        guard !gestureHistory.isEmpty else {
            return (lastStableGesture, 0.0)
        }
        
        // Remove old observations (older than 0.5 seconds)
        let currentTime = Date().timeIntervalSince1970
        gestureHistory.removeAll { currentTime - $0.timestamp > 0.5 }
        
        // Count gesture occurrences weighted by confidence
        var gestureScores: [RPSHandPose: Float] = [:]
        
        for observation in gestureHistory {
            let weight = observation.confidence
            gestureScores[observation.gesture, default: 0.0] += weight
        }
        
        // Find the gesture with highest weighted score
        var bestGesture = lastStableGesture
        var bestScore: Float = 0
        
        for (gesture, score) in gestureScores {
            if score > bestScore {
                bestScore = score
                bestGesture = gesture
            }
        }
        
        // Calculate confidence based on consistency
        let totalWeight = gestureHistory.reduce(0) { $0 + $1.confidence }
        let normalizedScore = totalWeight > 0 ? bestScore / totalWeight : 0
        
        // Require minimum consistency to change gesture
        let recentGestures = gestureHistory.suffix(5)
        let matchingRecent = recentGestures.filter { $0.gesture == bestGesture }.count
        
        if matchingRecent >= 3 || normalizedScore > 0.8 {
            // Strong consensus - update stable gesture
            lastStableGesture = bestGesture
            lastStableTimestamp = currentTime
            return (bestGesture, normalizedScore)
        } else {
            // Not enough consensus - return last stable with reduced confidence
            let timeSinceStable = currentTime - lastStableTimestamp
            let decayedConfidence = max(0.5, normalizedScore * 0.7)
            return (lastStableGesture, decayedConfidence)
        }
    }
}

// MARK: - Gesture Transition Validator
final class GestureTransitionValidator {
    
    // Valid transitions (helps filter out impossible transitions)
    private let validTransitions: [RPSHandPose: Set<RPSHandPose>] = [
        .rock: [.paper, .scissors, .rock],
        .paper: [.rock, .scissors, .paper],
        .scissors: [.rock, .paper, .scissors],
        .unknown: [.rock, .paper, .scissors, .unknown]
    ]
    
    private var lastValidGesture: RPSHandPose = .unknown
    
    func validateTransition(from: RPSHandPose, to: RPSHandPose) -> Bool {
        // Unknown can transition to anything
        if from == .unknown || to == .unknown {
            return true
        }
        
        // Check if transition is valid
        return validTransitions[from]?.contains(to) ?? false
    }
    
    func getValidatedGesture(newGesture: RPSHandPose, confidence: Float) -> RPSHandPose {
        // High confidence overrides transition validation
        if confidence > 0.85 {
            lastValidGesture = newGesture
            return newGesture
        }
        
        // Check if transition is valid
        if validateTransition(from: lastValidGesture, to: newGesture) {
            lastValidGesture = newGesture
            return newGesture
        }
        
        // Invalid transition with low confidence - keep last valid
        return lastValidGesture
    }
    
    func reset() {
        lastValidGesture = .unknown
    }
}