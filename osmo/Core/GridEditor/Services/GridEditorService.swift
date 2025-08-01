import Foundation
import SwiftUI

/// Central service for managing grid editors across different games
@MainActor
public final class GridEditorService: GridEditorServiceProtocol {
    private let persistenceService: any PersistenceServiceProtocol
    private let analyticsService: any AnalyticsServiceProtocol
    private var adapters: [GameType: any GridEditorAdapter] = [:]
    
    public init(persistenceService: any PersistenceServiceProtocol,
                analyticsService: any AnalyticsServiceProtocol) {
        self.persistenceService = persistenceService
        self.analyticsService = analyticsService
    }
    
    /// Register a game-specific adapter
    public func registerAdapter<T: GridEditorAdapter>(_ adapter: T, for gameType: GameType) {
        adapters[gameType] = adapter
    }
    
    /// Create an editor instance for a specific game
    public func createEditor(for gameType: GameType, configuration: GridConfiguration) -> GridEditor {
        // For now, return the existing TangramGridEditor
        // This will be refactored to use adapters
        switch gameType {
        case .tangram:
            return TangramGridEditor()
        default:
            fatalError("No editor available for game type: \(gameType)")
        }
    }
    
    /// Save an arrangement to persistent storage
    public func saveArrangement(_ arrangement: GridArrangement) async throws {
        // Log analytics event
        analyticsService.logEvent(AnalyticsEvent(
            eventType: .customEvent(name: "grid_editor_save"),
            gameId: arrangement.gameType.rawValue,
            parameters: [
                "element_count": String(arrangement.elements.count),
                "constraint_count": String(arrangement.constraints.count)
            ]
        ))
        
        // Save to persistence
        let key = "grid_arrangement_\(arrangement.gameType.rawValue)_\(arrangement.id)"
        let encoder = JSONEncoder()
        let data = try encoder.encode(arrangement)
        try await persistenceService.saveData(data, forKey: key)
        
        // Also update the arrangement index
        var index = await loadArrangementIndex(for: arrangement.gameType)
        if !index.contains(arrangement.id) {
            index.append(arrangement.id)
            try await saveArrangementIndex(index, for: arrangement.gameType)
        }
    }
    
    /// Load all arrangements for a game type
    public func loadArrangements(for gameType: GameType) async -> [GridArrangement] {
        let index = await loadArrangementIndex(for: gameType)
        var arrangements: [GridArrangement] = []
        
        for arrangementId in index {
            let key = "grid_arrangement_\(gameType.rawValue)_\(arrangementId)"
            if let data: Data = try? await persistenceService.loadData(forKey: key) {
                let decoder = JSONDecoder()
                if let arrangement = try? decoder.decode(GridArrangement.self, from: data) {
                    arrangements.append(arrangement)
                }
            }
        }
        
        // Sort by updated date
        return arrangements.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Delete an arrangement
    public func deleteArrangement(_ arrangementId: String) async throws {
        // Find the arrangement to get its game type
        let allGameTypes = GameType.allCases
        
        for gameType in allGameTypes {
            let key = "grid_arrangement_\(gameType.rawValue)_\(arrangementId)"
            if let _: Data = try? await persistenceService.loadData(forKey: key) {
                // Delete the arrangement
                try await persistenceService.deleteData(forKey: key)
                
                // Update the index
                var index = await loadArrangementIndex(for: gameType)
                index.removeAll { $0 == arrangementId }
                try await saveArrangementIndex(index, for: gameType)
                
                // Log analytics
                analyticsService.logEvent(AnalyticsEvent(
                    eventType: .customEvent(name: "grid_editor_delete"),
                    gameId: gameType.rawValue,
                    parameters: [:]
                ))
                
                break
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadArrangementIndex(for gameType: GameType) async -> [String] {
        let key = "grid_arrangement_index_\(gameType.rawValue)"
        guard let data: Data = try? await persistenceService.loadData(forKey: key) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([String].self, from: data)) ?? []
    }
    
    private func saveArrangementIndex(_ index: [String], for gameType: GameType) async throws {
        let key = "grid_arrangement_index_\(gameType.rawValue)"
        let encoder = JSONEncoder()
        let data = try encoder.encode(index)
        try await persistenceService.saveData(data, forKey: key)
    }
}