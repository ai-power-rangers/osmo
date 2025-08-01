//
//  ServiceModels.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation

// MARK: - Audio Models
enum AudioCategory: String {
    case sfx
    case music
    case voice
    case ambient
}

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
}

// MARK: - Game Session
class GameSession {
    let sessionId: UUID
    let gameId: String
    let startTime: Date
    var endTime: Date?
    var events: [AnalyticsEvent]
    var cvEventCount: Int
    var errorCount: Int
    
    init(sessionId: UUID, gameId: String, startTime: Date, events: [AnalyticsEvent], cvEventCount: Int, errorCount: Int) {
        self.sessionId = sessionId
        self.gameId = gameId
        self.startTime = startTime
        self.events = events
        self.cvEventCount = cvEventCount
        self.errorCount = errorCount
    }
}

// MARK: - Analytics Event
struct AnalyticsEvent {
    let eventId = UUID()
    let eventType: EventType
    let gameId: String
    let timestamp = Date()
    let parameters: [String: Any]
}

enum EventType {
    case gameStarted
    case levelCompleted
    case achievementUnlocked
    case errorOccurred
    case cvEventProcessed
    case customEvent(name: String)
    
    var description: String {
        switch self {
        case .gameStarted: return "gameStarted"
        case .levelCompleted: return "levelCompleted"
        case .achievementUnlocked: return "achievementUnlocked"
        case .errorOccurred: return "errorOccurred"
        case .cvEventProcessed: return "cvEventProcessed"
        case .customEvent(let name): return name
        }
    }
}

// MARK: - User Settings
struct UserSettings: Codable {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var hapticEnabled: Bool = true
    var cvDebugMode: Bool = false
    var parentalControlsEnabled: Bool = false
}

// MARK: - Persistence Keys
enum PersistenceKey {
    case gameProgress(gameId: String)
    case userSettings
    case currentSession
    
    var stringValue: String {
        switch self {
        case .gameProgress(let gameId):
            return "game.\(gameId).progress"
        case .userSettings:
            return "settings.user"
        case .currentSession:
            return "session.current"
        }
    }
}
