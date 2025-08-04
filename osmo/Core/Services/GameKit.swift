//
//  GameKit.swift
//  osmo
//
//  The single source of truth for all game services
//  Simple, direct, game-appropriate architecture
//

import Foundation
import SwiftUI
import AVFoundation
import SpriteKit
import SwiftData

/// GameKit provides direct, static access to all game services
/// No dependency injection, no protocols, just direct access
public enum GameKit {
    
    // MARK: - Services (Static for simplicity, protocols for testability)
    
    /// Audio service for sound effects and music
    @MainActor public static let audio = AudioService()
    
    /// Haptics service for tactile feedback
    @MainActor public static var haptics: HapticsService = HapticsService()
    
    /// Analytics service for tracking events
    public static let analytics = SimpleAnalyticsService()
    
    /// Storage service for game data persistence
    public static let storage = StorageService()
    
    /// Computer vision service for camera-based interaction
    @MainActor public static let cv = CVService()
    
    // MARK: - Configuration
    
    /// Initialize all services at app launch
    @MainActor
    public static func configure() async {
        print("[GameKit] Configuring services...")
        
        // Preload common sounds
        await audio.preload([
            .buttonTap, .piecePickup, .pieceDrop,
            .success, .failure, .gameStart
        ])
        
        // Prepare haptics
        haptics.prepare()
        
        // Initialize storage
        await storage.initialize()
        
        print("[GameKit] All services configured")
    }
    
    // MARK: - Testing Support
    
    /// Reset all services for testing
    @MainActor
    public static func resetForTesting() {
        audio.stopAll()
        Task {
            await storage.clearCache()
        }
        analytics.clearEvents()
        print("[GameKit] Services reset for testing")
    }
    
    // MARK: - Convenience Methods
    
    /// Play a sound effect
    @MainActor
    public static func playSound(_ sound: Sound) {
        audio.play(sound)
    }
    
    /// Trigger haptic feedback
    @MainActor
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        haptics.playHaptic(style)
    }
    
    /// Log an analytics event
    public static func logEvent(_ event: String, parameters: [String: Any] = [:]) {
        analytics.logEvent(event, parameters: parameters)
    }
}

// MARK: - Haptics Service

@MainActor
public final class HapticsService {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    public init() {
        prepare()
    }
    
    public func prepare() {
        impactGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    public func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func selection() {
        selectionGenerator.selectionChanged()
    }
    
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
}

