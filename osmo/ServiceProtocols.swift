//
//  ServiceProtocols.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation
import CoreGraphics

// MARK: - CV Service Protocol
protocol CVServiceProtocol: AnyObject {
    var isSessionActive: Bool { get }
    var debugMode: Bool { get set }
    
    func startSession() async throws
    func stopSession()
    func subscribe(gameId: String, 
                  events: [CVEventType], 
                  handler: @escaping (CVEvent) -> Void) -> CVSubscription
    func unsubscribe(_ subscription: CVSubscription)
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
    func saveGameProgress(_ progress: GameProgress)
    func loadGameProgress(for gameId: String) -> GameProgress?
    
    // Level Completion
    func saveLevel(gameId: String, level: String, completed: Bool)
    func isLevelCompleted(gameId: String, level: String) -> Bool
    func getCompletedLevels(gameId: String) -> [String]
    
    // High Scores
    func saveHighScore(gameId: String, level: String, score: Int)
    func getHighScore(gameId: String, level: String) -> Int?
    
    // Settings
    func saveUserSettings(_ settings: UserSettings)
    func loadUserSettings() -> UserSettings
}