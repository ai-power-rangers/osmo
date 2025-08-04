//
//  GameSettingsProtocol.swift
//  osmo
//
//  Protocol for game-specific settings integration
//

import SwiftUI

/// Protocol that games implement to provide settings UI
public protocol GameSettingsProtocol {
    /// Unique identifier for the game
    var gameId: String { get }
    
    /// Display name shown in settings
    var displayName: String { get }
    
    /// SF Symbol name for the game icon
    var iconName: String { get }
    
    /// Create the settings view for this game
    func createSettingsView() -> AnyView
    
    /// Whether this game has settings to display
    func hasSettings() -> Bool
}

/// Default implementation
public extension GameSettingsProtocol {
    func hasSettings() -> Bool {
        return true
    }
}

/// Container for passing game settings to views
struct GameSettingsContext {
    let gameId: String
    
    init(gameId: String) {
        self.gameId = gameId
    }
}