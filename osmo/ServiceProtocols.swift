//
//  ServiceProtocols.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation
import CoreGraphics

// MARK: - CV Subscription
protocol CVSubscription {
    func cancel()
}

// MARK: - CV Service Protocol
protocol CVServiceProtocol: AnyObject {
    var isSessionActive: Bool { get }
    var debugMode: Bool { get set }
    
    func startSession() async throws
    func stopSession()
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent>
    func eventStream(gameId: String, events: [CVEventType], configuration: [String: Any]) -> AsyncStream<CVEvent>
}

// MARK: - Audio Service Protocol
protocol AudioServiceProtocol: AnyObject {
    func preloadSound(_ soundName: String)
    func playSound(_ soundName: String)
    func playSound(_ soundName: String, volume: Float)
    func stopSound(_ soundName: String)
    func playHaptic(_ type: HapticType)
    func setBackgroundMusic(_ musicName: String?, volume: Float)
}

// MARK: - Analytics Service Protocol
protocol AnalyticsServiceProtocol: AnyObject {
    func logEvent(_ event: String, parameters: [String: Any])
    func startLevel(gameId: String, level: String)
    func endLevel(gameId: String, level: String, success: Bool, score: Int?)
    func logError(_ error: Error, context: String)
}

// MARK: - Persistence Service Protocol
protocol PersistenceServiceProtocol: AnyObject {
    // Game Progress
    func saveGameProgress(_ progress: GameProgress) async throws
    func loadGameProgress(for gameId: String) async -> GameProgress?
    
    // Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool) async throws
    func isLevelCompleted(gameId: String, level: String) async -> Bool
    func getCompletedLevels(gameId: String) async -> [String]
    
    // High Scores
    func saveHighScore(gameId: String, level: String, score: Int) async throws
    func getHighScore(gameId: String, level: String) async -> Int?
    
    // Settings
    func saveUserSettings(_ settings: UserSettings) async throws
    func loadUserSettings() async -> UserSettings
    
    // Session Management (for analytics)
    func saveCurrentSession(gameId: String, sessionStart: Date) async throws
    func loadCurrentSession() async -> (gameId: String, startTime: Date)?
    func clearCurrentSession() async throws
}
