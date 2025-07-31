//
//  SwiftDataService.swift
//  osmo
//
//  Created by Phase 2 Implementation
//

import Foundation
import SwiftData
import Observation
import os.log

// MARK: - SwiftData Persistence Service
@Observable
final class SwiftDataService: PersistenceServiceProtocol {
    private let logger = Logger(subsystem: "com.osmoapp", category: "persistence")
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    // Cache for performance
    private var settingsCache: UserSettings?
    
    init() throws {
        let schema = Schema([
            SDGameProgress.self,
            SDUserSettings.self,
            SDAnalyticsEvent.self,
            SDGameSession.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Can enable for sync later
        )
        
        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true
        
        logger.info("[SwiftData] Service initialized")
    }
    
    // MARK: - Game Progress
    func saveGameProgress(_ progress: GameProgress) async throws {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == progress.gameId }
        )
        
        let existingProgress = try modelContext.fetch(fetchDescriptor).first
        
        if let existing = existingProgress {
            existing.update(from: progress)
        } else {
            let sdProgress = SDGameProgress(gameId: progress.gameId)
            sdProgress.update(from: progress)
            modelContext.insert(sdProgress)
        }
        
        try modelContext.save()
        logger.debug("[SwiftData] Saved progress for game: \(progress.gameId)")
    }
    
    func loadGameProgress(for gameId: String) async -> GameProgress? {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        do {
            if let sdProgress = try modelContext.fetch(fetchDescriptor).first {
                return sdProgress.toGameProgress()
            }
        } catch {
            logger.error("[SwiftData] Failed to load progress: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) async throws {
        var progress = await loadGameProgress(for: gameId) ?? GameProgress(gameId: gameId)
        
        if completed {
            progress.levelsCompleted.insert(level)
        } else {
            progress.levelsCompleted.remove(level)
        }
        
        progress.lastPlayed = Date()
        try await saveGameProgress(progress)
    }
    
    func isLevelCompleted(gameId: String, level: String) async -> Bool {
        let progress = await loadGameProgress(for: gameId)
        return progress?.levelsCompleted.contains(level) ?? false
    }
    
    func getCompletedLevels(gameId: String) async -> [String] {
        let progress = await loadGameProgress(for: gameId)
        return Array(progress?.levelsCompleted ?? [])
    }
    
    // MARK: - High Scores
    func saveHighScore(gameId: String, level: String, score: Int) async throws {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        let progress = try modelContext.fetch(fetchDescriptor).first ?? {
            let new = SDGameProgress(gameId: gameId)
            modelContext.insert(new)
            return new
        }()
        
        let currentHigh = progress.highScores[level] ?? 0
        if score > currentHigh {
            progress.highScores[level] = score
            try modelContext.save()
            logger.info("[SwiftData] New high score for \(gameId).\(level): \(score)")
        }
    }
    
    func getHighScore(gameId: String, level: String) async -> Int? {
        let fetchDescriptor = FetchDescriptor<SDGameProgress>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        do {
            if let progress = try modelContext.fetch(fetchDescriptor).first {
                return progress.highScores[level]
            }
        } catch {
            logger.error("[SwiftData] Failed to get high score: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Settings
    func saveUserSettings(_ settings: UserSettings) async throws {
        let fetchDescriptor = FetchDescriptor<SDUserSettings>()
        
        let existingSettings = try modelContext.fetch(fetchDescriptor).first ?? {
            let new = SDUserSettings()
            modelContext.insert(new)
            return new
        }()
        
        existingSettings.update(from: settings)
        try modelContext.save()
        
        settingsCache = settings
        logger.debug("[SwiftData] Saved user settings")
    }
    
    func loadUserSettings() async -> UserSettings {
        // Check cache first
        if let cached = settingsCache {
            return cached
        }
        
        let fetchDescriptor = FetchDescriptor<SDUserSettings>()
        
        do {
            if let sdSettings = try modelContext.fetch(fetchDescriptor).first {
                let settings = sdSettings.toUserSettings()
                settingsCache = settings
                return settings
            }
        } catch {
            logger.error("[SwiftData] Failed to load settings: \(error)")
        }
        
        let defaultSettings = UserSettings()
        settingsCache = defaultSettings
        return defaultSettings
    }
    
    // MARK: - Session Management
    func saveCurrentSession(gameId: String, sessionStart: Date) async throws {
        let session = SDGameSession(gameId: gameId)
        modelContext.insert(session)
        try modelContext.save()
    }
    
    func loadCurrentSession() async -> (gameId: String, startTime: Date)? {
        let fetchDescriptor = FetchDescriptor<SDGameSession>(
            predicate: #Predicate { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            if let session = try modelContext.fetch(fetchDescriptor).first {
                return (session.gameId, session.startTime)
            }
        } catch {
            logger.error("[SwiftData] Failed to load session: \(error)")
        }
        
        return nil
    }
    
    func clearCurrentSession() async throws {
        let fetchDescriptor = FetchDescriptor<SDGameSession>(
            predicate: #Predicate { $0.endTime == nil }
        )
        
        do {
            let sessions = try modelContext.fetch(fetchDescriptor)
            sessions.forEach { $0.endTime = Date() }
            try modelContext.save()
        } catch {
            logger.error("[SwiftData] Failed to clear session: \(error)")
        }
    }
    
    // MARK: - Analytics Support
    func saveAnalyticsEvent(_ event: AnalyticsEvent) async throws {
        let sdEvent = SDAnalyticsEvent(event: event)
        modelContext.insert(sdEvent)
        
        // Save in batches for performance
        if Int.random(in: 0..<10) == 0 { // 10% chance to save
            try modelContext.save()
        }
    }
    
    func getAnalyticsEvents(since date: Date) async -> [SDAnalyticsEvent] {
        let fetchDescriptor = FetchDescriptor<SDAnalyticsEvent>(
            predicate: #Predicate { $0.timestamp > date },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            return try modelContext.fetch(fetchDescriptor)
        } catch {
            logger.error("[SwiftData] Failed to fetch analytics: \(error)")
            return []
        }
    }
}
