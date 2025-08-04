//
//  GameInfo.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation

// MARK: - Game Category
public enum GameCategory: String, CaseIterable, Codable {
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
public struct GameInfo: Identifiable, Codable {
    public let id: String // Same as gameId for Identifiable
    public let gameId: String
    public let displayName: String
    public let description: String
    public let iconName: String
    public let minAge: Int
    public let maxAge: Int
    public let category: GameCategory
    public let isLocked: Bool
    public let bundleSize: Int // in MB
    public let requiredCVEvents: [String] // Simplified for codable
    
    public init(gameId: String,
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
public struct GameProgress: Codable {
    public let gameId: String
    public var levelsCompleted: Set<String>
    public var totalPlayTime: TimeInterval
    public var lastPlayed: Date
    
    public init(gameId: String) {
        self.gameId = gameId
        self.levelsCompleted = []
        self.totalPlayTime = 0
        self.lastPlayed = Date()
    }
}
