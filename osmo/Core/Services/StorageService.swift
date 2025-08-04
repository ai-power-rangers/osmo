//
//  StorageService.swift
//  osmo
//
//  Simple storage service using SwiftData
//

import Foundation
import SwiftData

public actor StorageService {
    private let container: ModelContainer
    private let context: ModelContext
    private var cache: [String: Any] = [:]
    
    public init() {
        do {
            let schema = Schema([
                PuzzleData.self,
                GameProgressData.self,
                UserSettingsData.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
            
            context = ModelContext(container)
            context.autosaveEnabled = true
        } catch {
            print("[Storage] Failed to initialize: \(error)")
            // Create in-memory fallback
            let schema = Schema([
                PuzzleData.self,
                GameProgressData.self,
                UserSettingsData.self
            ])
            
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            container = try! ModelContainer(
                for: schema,
                configurations: [config]
            )
            
            context = ModelContext(container)
        }
    }
    
    // MARK: - Initialization
    
    public func initialize() async {
        // Warm up storage if needed
        print("[Storage] Initialized")
    }
    
    // MARK: - Puzzle Management
    
    public func savePuzzle<T: Codable>(_ puzzle: T, id: String) async throws {
        let data = try JSONEncoder().encode(puzzle)
        
        // Check if exists
        let descriptor = FetchDescriptor<PuzzleData>(
            predicate: #Predicate { $0.id == id }
        )
        
        if let existing = try context.fetch(descriptor).first {
            existing.data = data
            existing.type = String(describing: T.self)
            existing.updatedAt = Date()
        } else {
            let puzzleData = PuzzleData(
                id: id,
                type: String(describing: T.self),
                data: data
            )
            context.insert(puzzleData)
        }
        
        try context.save()
        cache[id] = puzzle
    }
    
    public func loadPuzzle<T: Codable>(_ id: String, type: T.Type) async throws -> T? {
        // Check cache
        if let cached = cache[id] as? T {
            return cached
        }
        
        // Load from storage
        let descriptor = FetchDescriptor<PuzzleData>(
            predicate: #Predicate { $0.id == id }
        )
        
        guard let puzzleData = try context.fetch(descriptor).first else {
            return nil
        }
        
        let puzzle = try JSONDecoder().decode(T.self, from: puzzleData.data)
        cache[id] = puzzle
        return puzzle
    }
    
    public func listPuzzles<T: Codable>(type: T.Type) async throws -> [T] {
        let typeName = String(describing: T.self)
        let descriptor = FetchDescriptor<PuzzleData>(
            predicate: #Predicate { $0.type == typeName }
        )
        
        let puzzleDataList = try context.fetch(descriptor)
        return puzzleDataList.compactMap { puzzleData in
            try? JSONDecoder().decode(T.self, from: puzzleData.data)
        }
    }
    
    public func deletePuzzle(_ id: String) async throws {
        let descriptor = FetchDescriptor<PuzzleData>(
            predicate: #Predicate { $0.id == id }
        )
        
        if let puzzleData = try context.fetch(descriptor).first {
            context.delete(puzzleData)
            try context.save()
            cache.removeValue(forKey: id)
        }
    }
    
    // MARK: - Progress Management
    
    public func saveProgress(gameId: String, level: String, completed: Bool) async throws {
        let progressId = "\(gameId)_progress"
        
        let descriptor = FetchDescriptor<GameProgressData>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        let progress: GameProgressData
        if let existing = try context.fetch(descriptor).first {
            progress = existing
        } else {
            progress = GameProgressData(gameId: gameId)
            context.insert(progress)
        }
        
        if completed {
            progress.completedLevels.insert(level)
        } else {
            progress.completedLevels.remove(level)
        }
        
        progress.lastPlayed = Date()
        try context.save()
    }
    
    public func loadProgress(gameId: String) async throws -> GameProgress? {
        let descriptor = FetchDescriptor<GameProgressData>(
            predicate: #Predicate { $0.gameId == gameId }
        )
        
        guard let data = try context.fetch(descriptor).first else {
            return nil
        }
        
        var progress = GameProgress(gameId: data.gameId)
        progress.levelsCompleted = data.completedLevels
        progress.totalPlayTime = data.totalPlayTime
        progress.lastPlayed = data.lastPlayed
        return progress
    }
    
    // MARK: - Settings
    
    public func saveSettings(_ settings: UserSettings) async throws {
        let descriptor = FetchDescriptor<UserSettingsData>()
        
        let settingsData: UserSettingsData
        if let existing = try context.fetch(descriptor).first {
            settingsData = existing
        } else {
            settingsData = UserSettingsData()
            context.insert(settingsData)
        }
        
        settingsData.soundEnabled = settings.soundEnabled
        settingsData.musicEnabled = settings.musicEnabled
        settingsData.hapticEnabled = settings.hapticEnabled
        settingsData.cvDebugMode = settings.cvDebugMode
        
        try context.save()
    }
    
    public func loadSettings() async throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettingsData>()
        
        if let data = try context.fetch(descriptor).first {
            var settings = UserSettings()
            settings.soundEnabled = data.soundEnabled
            settings.musicEnabled = data.musicEnabled
            settings.hapticEnabled = data.hapticEnabled
            settings.cvDebugMode = data.cvDebugMode
            return settings
        }
        
        return UserSettings()
    }
    
    // MARK: - Cache Management
    
    public func clearCache() async {
        cache.removeAll()
    }
}

// MARK: - SwiftData Models

@Model
final class PuzzleData {
    @Attribute(.unique) var id: String
    var type: String
    var data: Data
    var createdAt: Date
    var updatedAt: Date
    
    init(id: String, type: String, data: Data) {
        self.id = id
        self.type = type
        self.data = data
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class GameProgressData {
    @Attribute(.unique) var gameId: String
    var completedLevels: Set<String>
    var highScores: [String: Int]
    var totalPlayTime: TimeInterval
    var lastPlayed: Date
    
    init(gameId: String) {
        self.gameId = gameId
        self.completedLevels = []
        self.highScores = [:]
        self.totalPlayTime = 0
        self.lastPlayed = Date()
    }
}

@Model
final class UserSettingsData {
    var soundEnabled: Bool
    var musicEnabled: Bool
    var hapticEnabled: Bool
    var cvDebugMode: Bool
    
    init() {
        self.soundEnabled = true
        self.musicEnabled = true
        self.hapticEnabled = true
        self.cvDebugMode = false
    }
}