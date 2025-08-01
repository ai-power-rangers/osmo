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
    let roundsToWin: Int
    let countdownDuration: Int
    let gestureLockDelay: TimeInterval
    let confidenceThreshold: Float
    
    static let `default` = GameConfiguration(
        roundsToWin: 3,
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
        switch fingerCount {
        case 0: 
            // Rock: closed fist
            return .rock
        case 5:
            // Paper: 5 fingers detected
            // Lower threshold for paper detection since CV service might not provide accurate openness
            return handOpenness > 0.5 ? .paper : .paper  // Always paper for 5 fingers for now
        case 2:
            // Scissors: 2 fingers extended
            return .scissors
        case 1, 3, 4:
            // Could be transitioning or unclear gesture
            // If 4 fingers with reasonable openness, might be trying for paper
            if fingerCount >= 4 && handOpenness > 0.4 {
                return .paper  // Likely attempting paper
            }
            return .unknown
        default:
            return .unknown
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
        if playerScore >= configuration.roundsToWin {
            return .playerWin(playerScore: playerScore, aiScore: aiScore)
        } else if aiScore >= configuration.roundsToWin {
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
