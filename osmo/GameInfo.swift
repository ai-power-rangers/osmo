//
//  GameInfo.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation

// MARK: - Game Category
enum GameCategory: String, CaseIterable, Codable {
    case literacy
    case math
    case creativity
    case spatialReasoning
    case problemSolving
    
    var displayName: String {
        switch self {
        case .literacy: return "Reading & Writing"
        case .math: return "Math & Numbers"
        case .creativity: return "Art & Creativity"
        case .spatialReasoning: return "Shapes & Space"
        case .problemSolving: return "Logic & Puzzles"
        }
    }
    
    var iconName: String {
        switch self {
        case .literacy: return "text.book.closed"
        case .math: return "number.square"
        case .creativity: return "paintbrush"
        case .spatialReasoning: return "cube"
        case .problemSolving: return "puzzlepiece"
        }
    }
}

// MARK: - Game Info
struct GameInfo: Identifiable, Codable {
    let id: String // Same as gameId for Identifiable
    let gameId: String
    let displayName: String
    let description: String
    let iconName: String
    let minAge: Int
    let maxAge: Int
    let category: GameCategory
    let isLocked: Bool
    let bundleSize: Int // in MB
    let requiredCVEvents: [String] // Simplified for codable
    
    init(gameId: String,
         displayName: String,
         description: String,
         iconName: String,
         minAge: Int,
         maxAge: Int = 8,
         category: GameCategory,
         isLocked: Bool = false,
         bundleSize: Int = 50,
         requiredCVEvents: [String] = []) {
        self.id = gameId
        self.gameId = gameId
        self.displayName = displayName
        self.description = description
        self.iconName = iconName
        self.minAge = minAge
        self.maxAge = maxAge
        self.category = category
        self.isLocked = isLocked
        self.bundleSize = bundleSize
        self.requiredCVEvents = requiredCVEvents
    }
}

// MARK: - Game Progress
struct GameProgress: Codable {
    let gameId: String
    var levelsCompleted: Set<String>
    var totalPlayTime: TimeInterval
    var lastPlayed: Date
    
    init(gameId: String) {
        self.gameId = gameId
        self.levelsCompleted = []
        self.totalPlayTime = 0
        self.lastPlayed = Date()
    }
}
