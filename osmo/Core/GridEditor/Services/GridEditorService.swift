import Foundation
import SwiftUI

/// Simple stub for GridEditor protocol
class StubGridEditor: GridEditor {
    var gameType: GameType { .tangram }
    
    var currentArrangement: GridArrangement { 
        GridArrangement(
            id: UUID().uuidString,
            gameType: .tangram,
            name: "Stub Arrangement",
            elements: [],
            constraints: [],
            metadata: ArrangementMetadata(
                author: "System",
                tags: []
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    var isValid: Bool { true }
    
    func createEditorView() -> AnyView {
        AnyView(Text("Stub Editor"))
    }
    
    func validate() -> [ValidationError] { [] }
}

/// Central service for managing grid editors across different games
@MainActor
final class GridEditorService: GridEditorServiceProtocol {
    private let persistenceService: any PersistenceServiceProtocol
    private let analyticsService: any AnalyticsServiceProtocol
    private var adapters: [GameType: any GridEditorAdapter] = [:]
    
    init(persistenceService: any PersistenceServiceProtocol,
         analyticsService: any AnalyticsServiceProtocol) {
        self.persistenceService = persistenceService
        self.analyticsService = analyticsService
    }
    
    /// Register a game-specific adapter
    func registerAdapter<T: GridEditorAdapter>(_ adapter: T, for gameType: GameType) {
        adapters[gameType] = adapter
    }
    
    /// Create an editor instance for a specific game
    func createEditor(for gameType: GameType, configuration: GridConfiguration) -> GridEditor {
        // Return a simple stub - grid editor removed in simplification
        return StubGridEditor()
    }
    
    /// Save an arrangement to persistent storage
    func saveArrangement(_ arrangement: GridArrangement) async throws {
        // Log analytics event
        analyticsService.logEvent("grid_editor_save", parameters: [
            "game_id": arrangement.gameType.rawValue,
            "element_count": String(arrangement.elements.count),
            "constraint_count": String(arrangement.constraints.count)
        ])
        
        // Save to persistence using UserDefaults for now
        let key = "grid_arrangement_\(arrangement.gameType.rawValue)_\(arrangement.id)"
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(arrangement) {
            UserDefaults.standard.set(data, forKey: key)
        }
        
        // Also update the arrangement index
        var index = loadArrangementIndex(for: arrangement.gameType)
        if !index.contains(arrangement.id) {
            index.append(arrangement.id)
            saveArrangementIndex(index, for: arrangement.gameType)
        }
    }
    
    /// Load all arrangements for a game type
    func loadArrangements(for gameType: GameType) async -> [GridArrangement] {
        let index = loadArrangementIndex(for: gameType)
        var arrangements: [GridArrangement] = []
        
        for arrangementId in index {
            let key = "grid_arrangement_\(gameType.rawValue)_\(arrangementId)"
            if let data = UserDefaults.standard.data(forKey: key) {
                let decoder = JSONDecoder()
                if let arrangement = try? decoder.decode(GridArrangement.self, from: data) {
                    arrangements.append(arrangement)
                }
            }
        }
        
        // Sort by updated date
        return arrangements.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Delete an arrangement by ID
    func deleteArrangement(_ arrangementId: String) async throws {
        // Find the arrangement to get its game type
        let allGameTypes = GameType.allCases
        
        for gameType in allGameTypes {
            let key = "grid_arrangement_\(gameType.rawValue)_\(arrangementId)"
            if UserDefaults.standard.data(forKey: key) != nil {
                // Delete the arrangement
                UserDefaults.standard.removeObject(forKey: key)
                
                // Update the index
                var index = loadArrangementIndex(for: gameType)
                index.removeAll { $0 == arrangementId }
                saveArrangementIndex(index, for: gameType)
                
                break
            }
        }
        
        // Log analytics
        analyticsService.logEvent("grid_editor_delete", parameters: [
            "arrangement_id": arrangementId
        ])
    }
    
    /// Delete an arrangement object
    func deleteArrangement(_ arrangement: GridArrangement) async throws {
        try await deleteArrangement(arrangement.id)
        
        // // Find the arrangement to get its game type
        // let allGameTypes = GameType.allCases
        // 
        // for gameType in allGameTypes {
        //     let key = "grid_arrangement_\(gameType.rawValue)_\(arrangementId)"
        //     if let _: Data = try? await persistenceService.loadData(forKey: key) {
        //         // Delete the arrangement
        //         try await persistenceService.deleteData(forKey: key)
        //         
        //         // Update the index
        //         var index = await loadArrangementIndex(for: gameType)
        //         index.removeAll { $0 == arrangementId }
        //         try await saveArrangementIndex(index, for: gameType)
        //         
        //         break
        //     }
        // }
    }
    
    // MARK: - Private Helpers
    
    private func loadArrangementIndex(for gameType: GameType) -> [String] {
        let key = "grid_arrangement_index_\(gameType.rawValue)"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode([String].self, from: data)) ?? []
    }
    
    private func saveArrangementIndex(_ index: [String], for gameType: GameType) {
        let key = "grid_arrangement_index_\(gameType.rawValue)"
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(index) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}