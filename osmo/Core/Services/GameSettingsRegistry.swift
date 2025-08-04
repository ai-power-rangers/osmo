//
//  GameSettingsRegistry.swift
//  osmo
//
//  Central registry for game-specific settings providers
//

import SwiftUI

/// Registry for managing game settings providers
/// Uses modern @Observable pattern (iOS 17+)
@MainActor
@Observable
public final class GameSettingsRegistry {
    /// Singleton instance
    public static let shared = GameSettingsRegistry()
    
    /// Registered game settings providers
    private var providers: [String: any GameSettingsProtocol] = [:]
    
    private init() {
        registerDefaultProviders()
    }
    
    /// Register a settings provider for a game
    public func register<T: GameSettingsProtocol>(_ provider: T) {
        providers[provider.gameId] = provider
    }
    
    /// Get settings provider for a game
    public func provider(for gameId: String) -> (any GameSettingsProtocol)? {
        return providers[gameId]
    }
    
    /// Get all registered providers that have settings
    public func allProviders() -> [any GameSettingsProtocol] {
        return providers.values
            .filter { $0.hasSettings() }
            .sorted { $0.displayName < $1.displayName }
    }
    
    /// Check if a game has settings
    public func hasSettings(for gameId: String) -> Bool {
        return provider(for: gameId)?.hasSettings() ?? false
    }
    
    /// Register default game settings
    private func registerDefaultProviders() {
        // Register Tangram settings
        if let tangramProvider = createTangramSettingsProvider() {
            register(tangramProvider)
        }
        
        // Register Sudoku settings
        if let sudokuProvider = createSudokuSettingsProvider() {
            register(sudokuProvider)
        }
        
        // Future games can be registered here
        // register(RockPaperScissorsSettingsProvider())
    }
    
    /// Create Tangram settings provider
    private func createTangramSettingsProvider() -> (any GameSettingsProtocol)? {
        return TangramSettingsProvider()
    }
    
    /// Create Sudoku settings provider
    private func createSudokuSettingsProvider() -> (any GameSettingsProtocol)? {
        return SudokuSettingsProvider()
    }
}