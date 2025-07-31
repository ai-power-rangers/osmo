//
//  MockPersistenceService.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation

// MARK: - Mock Persistence Service
final class MockPersistenceService: PersistenceServiceProtocol {
    // In-memory storage for mock
    private var gameProgress: [String: GameProgress] = [:]
    private var levelCompletions: Set<String> = []
    private var highScores: [String: Int] = [:]
    private var userSettings = UserSettings()
    
    // MARK: - Game Progress
    func saveGameProgress(_ progress: GameProgress) {
        gameProgress[progress.gameId] = progress
        print("[MockPersistence] Saved progress for game: \(progress.gameId)")
    }
    
    func loadGameProgress(for gameId: String) -> GameProgress? {
        let progress = gameProgress[gameId]
        print("[MockPersistence] Loaded progress for game: \(gameId) - found: \(progress != nil)")
        return progress
    }
    
    // MARK: - Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) {
        let key = "\(gameId).\(level)"
        if completed {
            levelCompletions.insert(key)
        } else {
            levelCompletions.remove(key)
        }
        print("[MockPersistence] Level \(level) in game \(gameId): \(completed ? "completed" : "not completed")")
    }
    
    func isLevelCompleted(gameId: String, level: String) -> Bool {
        let key = "\(gameId).\(level)"
        return levelCompletions.contains(key)
    }
    
    func getCompletedLevels(gameId: String) -> [String] {
        let prefix = "\(gameId)."
        let completedLevels = levelCompletions
            .filter { $0.hasPrefix(prefix) }
            .map { $0.replacingOccurrences(of: prefix, with: "") }
        print("[MockPersistence] Found \(completedLevels.count) completed levels for game: \(gameId)")
        return Array(completedLevels)
    }
    
    // MARK: - High Scores
    func saveHighScore(gameId: String, level: String, score: Int) {
        let key = "\(gameId).\(level)"
        highScores[key] = score
        print("[MockPersistence] Saved high score \(score) for \(key)")
    }
    
    func getHighScore(gameId: String, level: String) -> Int? {
        let key = "\(gameId).\(level)"
        return highScores[key]
    }
    
    // MARK: - Settings
    func saveUserSettings(_ settings: UserSettings) {
        userSettings = settings
        print("[MockPersistence] Saved user settings")
    }
    
    func loadUserSettings() -> UserSettings {
        print("[MockPersistence] Loaded user settings")
        return userSettings
    }
}