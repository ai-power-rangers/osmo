//
//  RPSModels.swift
//  osmo
//
//  Models and data structures for Rock-Paper-Scissors game
//

import Foundation
import CoreGraphics

// MARK: - Game Types

enum RPSHandPose: String, CaseIterable {
    case rock
    case paper
    case scissors
    case unknown
    
    var emoji: String {
        switch self {
        case .rock: return "✊"
        case .paper: return "✋"
        case .scissors: return "✌️"
        case .unknown: return "❓"
        }
    }
    
    var displayName: String {
        switch self {
        case .rock: return "Rock"
        case .paper: return "Paper"
        case .scissors: return "Scissors"
        case .unknown: return "Unknown"
        }
    }
    
    func beats(_ other: Self) -> Bool {
        switch (self, other) {
        case (.rock, .scissors), (.paper, .rock), (.scissors, .paper):
            return true
        default:
            return false
        }
    }
    
    var winningMove: Self {
        switch self {
        case .rock: return .paper
        case .paper: return .scissors
        case .scissors: return .rock
        case .unknown: return .unknown
        }
    }
}

enum RoundResult: String {
    case playerWin = "player_win"
    case aiWin = "ai_win"
    case tie
    
    var displayText: String {
        switch self {
        case .playerWin: return "You Win!"
        case .aiWin: return "AI Wins!"
        case .tie: return "It's a Tie!"
        }
    }
}

enum RoundPhase: Equatable {
    case waiting
    case countdown(Int)
    case reveal
    case result
    
    var isActive: Bool {
        switch self {
        case .countdown, .reveal:
            return true
        default:
            return false
        }
    }
}

enum MatchResult {
    case playerWin(playerScore: Int, aiScore: Int)
    case aiWin(playerScore: Int, aiScore: Int)
    case ongoing
    
    var isComplete: Bool {
        switch self {
        case .playerWin, .aiWin:
            return true
        case .ongoing:
            return false
        }
    }
}

// MARK: - AI Types

enum Difficulty: String, CaseIterable {
    case easy
    case medium
    case hard
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "Random moves"
        case .medium: return "Basic patterns"
        case .hard: return "Adaptive AI"
        }
    }
}

enum AIStrategy {
    case random
    case frequency
    case markov
    case adaptive
}

// MARK: - Game Configuration

struct GameConfiguration {
    let winsNeeded: Int  // First to X wins
    let countdownDuration: Int
    let gestureLockDelay: TimeInterval
    let confidenceThreshold: Float
    
    static let `default` = GameConfiguration(
        winsNeeded: 3,  // First to 3 wins
        countdownDuration: 3,
        gestureLockDelay: 0.2,
        confidenceThreshold: 0.4  // Lowered to 0.4 for better detection
    )
}

// MARK: - CV Integration Types

struct GestureDetection {
    let pose: RPSHandPose
    let confidence: Float
    let timestamp: Date
    let handPosition: CGPoint?
    
    var isConfident: Bool {
        return confidence >= GameConfiguration.default.confidenceThreshold
    }
}

struct HandMetrics {
    let fingerCount: Int
    let handOpenness: Float
    let stability: Float
    let position: CGPoint
    
    var inferredPose: RPSHandPose {
        // Simple finger-count based detection with openness validation
        
        switch fingerCount {
        case 0, 1:
            // 0-1 fingers = Rock (fist or nearly closed)
            return .rock
            
        case 2:
            // 2 fingers = Scissors
            return .scissors
            
        case 3, 4, 5:
            // 3-5 fingers = Paper (open hand)
            // Note: 3 fingers included for cases where detection misses some fingers
            return .paper
            
        default:
            // Shouldn't happen, but use openness as fallback
            if handOpenness < 0.3 {
                return .rock
            } else if handOpenness > 0.6 {
                return .paper
            } else {
                return .scissors
            }
        }
    }
    
    // Confidence score for the inferred gesture
    var gestureConfidence: Float {
        let pose = inferredPose
        
        switch pose {
        case .rock:
            // High confidence for 0 fingers with low openness
            if fingerCount == 0 && handOpenness < 0.3 {
                return 0.95
            } else if fingerCount <= 1 && handOpenness < 0.4 {
                return 0.85
            }
            return 0.7
            
        case .paper:
            // High confidence for 4-5 fingers with high openness
            if fingerCount >= 4 && handOpenness > 0.6 {
                return 0.95
            } else if fingerCount >= 3 && handOpenness > 0.5 {
                return 0.85
            }
            return 0.7
            
        case .scissors:
            // High confidence for exactly 2 fingers
            if fingerCount == 2 {
                // Boost confidence if openness is in expected range
                if handOpenness > 0.3 && handOpenness < 0.7 {
                    return 0.95
                }
                return 0.85
            }
            return 0.7
            
        case .unknown:
            return 0.0
        }
    }
}

// MARK: - Game State

struct RoundState {
    let roundNumber: Int
    var playerGesture: RPSHandPose?
    var aiGesture: RPSHandPose?
    var result: RoundResult?
    let startTime: Date
    var endTime: Date?
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isComplete: Bool {
        return result != nil
    }
}

struct MatchState {
    var rounds: [RoundState] = []
    var playerScore: Int = 0
    var aiScore: Int = 0
    let configuration: GameConfiguration
    
    var currentRound: Int {
        return rounds.count
    }
    
    var matchResult: MatchResult {
        if playerScore >= configuration.winsNeeded {
            return .playerWin(playerScore: playerScore, aiScore: aiScore)
        } else if aiScore >= configuration.winsNeeded {
            return .aiWin(playerScore: playerScore, aiScore: aiScore)
        } else {
            return .ongoing
        }
    }
    
    mutating func recordRound(player: RPSHandPose, ai: RPSHandPose) -> RoundResult {
        print("[RPS] Recording round - Player: \(player), AI: \(ai)")
        
        let result: RoundResult
        if player.beats(ai) {
            result = .playerWin
            playerScore += 1
        } else if ai.beats(player) {
            result = .aiWin
            aiScore += 1
        } else {
            result = .tie
        }
        
        print("[RPS] Result: \(result) - Player beats AI: \(player.beats(ai)), AI beats Player: \(ai.beats(player))")
        
        if var currentRound = rounds.last {
            currentRound.playerGesture = player
            currentRound.aiGesture = ai
            currentRound.result = result
            currentRound.endTime = Date()
            rounds[rounds.count - 1] = currentRound
        }
        
        return result
    }
}

// MARK: - Analytics

struct GameStats {
    let totalRounds: Int
    let playerWins: Int
    let aiWins: Int
    let ties: Int
    let averageRoundDuration: TimeInterval
    let mostUsedGesture: RPSHandPose
    let gestureFrequency: [RPSHandPose: Int]
    
    var winRate: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(playerWins) / Double(totalRounds)
    }
}
