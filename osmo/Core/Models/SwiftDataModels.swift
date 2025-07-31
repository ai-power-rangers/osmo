//
//  SwiftDataModels.swift
//  osmo
//
//  Created by Phase 2 Implementation
//

import Foundation
import SwiftData

// MARK: - Game Progress Model
@Model
final class SDGameProgress {
    @Attribute(.unique) var gameId: String
    var levelsCompleted: [String]
    var totalPlayTime: TimeInterval
    var lastPlayed: Date
    var highScores: [String: Int] // level: score
    
    init(gameId: String) {
        self.gameId = gameId
        self.levelsCompleted = []
        self.totalPlayTime = 0
        self.lastPlayed = Date()
        self.highScores = [:]
    }
    
    func toGameProgress() -> GameProgress {
        var progress = GameProgress(gameId: gameId)
        progress.levelsCompleted = Set(levelsCompleted)
        progress.totalPlayTime = totalPlayTime
        progress.lastPlayed = lastPlayed
        return progress
    }
    
    func update(from progress: GameProgress) {
        self.levelsCompleted = Array(progress.levelsCompleted)
        self.totalPlayTime = progress.totalPlayTime
        self.lastPlayed = progress.lastPlayed
    }
}

// MARK: - User Settings Model
@Model
final class SDUserSettings {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var hapticEnabled: Bool = true
    var cvDebugMode: Bool = false
    var parentalControlsEnabled: Bool = false
    var lastUpdated: Date = Date()
    
    init() {}
    
    func toUserSettings() -> UserSettings {
        var settings = UserSettings()
        settings.soundEnabled = soundEnabled
        settings.musicEnabled = musicEnabled
        settings.hapticEnabled = hapticEnabled
        settings.cvDebugMode = cvDebugMode
        settings.parentalControlsEnabled = parentalControlsEnabled
        return settings
    }
    
    func update(from settings: UserSettings) {
        self.soundEnabled = settings.soundEnabled
        self.musicEnabled = settings.musicEnabled
        self.hapticEnabled = settings.hapticEnabled
        self.cvDebugMode = settings.cvDebugMode
        self.parentalControlsEnabled = settings.parentalControlsEnabled
        self.lastUpdated = Date()
    }
}

// MARK: - Analytics Event Model
@Model
final class SDAnalyticsEvent {
    var eventId: UUID
    var eventType: String
    var gameId: String
    var timestamp: Date
    var parameters: Data? // JSON encoded
    
    init(event: AnalyticsEvent) {
        self.eventId = event.eventId
        self.eventType = event.eventType.description
        self.gameId = event.gameId
        self.timestamp = event.timestamp
        self.parameters = try? JSONSerialization.data(withJSONObject: event.parameters)
    }
}

// MARK: - Game Session Model
@Model
final class SDGameSession {
    var sessionId: UUID
    var gameId: String
    var startTime: Date
    var endTime: Date?
    var eventCount: Int
    var errorCount: Int
    
    init(gameId: String) {
        self.sessionId = UUID()
        self.gameId = gameId
        self.startTime = Date()
        self.eventCount = 0
        self.errorCount = 0
    }
}
