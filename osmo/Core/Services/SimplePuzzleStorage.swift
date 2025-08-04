//
//  SimplePuzzleStorage.swift
//  osmo
//
//  Simple, direct storage using PuzzleType enum to eliminate generic casting
//

import Foundation

@MainActor
public final class SimplePuzzleStorage {
    private let documentsDirectory: URL
    
    public init() {
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                          in: .userDomainMask).first!
    }
    
    // MARK: - Core Storage Methods
    
    public func save(_ puzzle: TangramPuzzle) async throws {
        try await saveTangram(puzzle)
    }
    
    public func load(id: String) async throws -> TangramPuzzle? {
        return try await loadTangram(id: id)
    }
    
    public func loadAll() async throws -> [TangramPuzzle] {
        return try await loadAllTangrams()
    }
    
    public func loadPuzzles(
        difficulty: TangramPuzzle.Difficulty? = nil,
        tags: Set<String>? = nil,
        completed: Bool? = nil
    ) async throws -> [TangramPuzzle] {
        // Load all puzzles - filtering not implemented for simplicity
        return try await loadAll()
    }
    
    public func delete(id: String) async throws {
        let tangramURL = documentsDirectory.appendingPathComponent("tangram_\(id).json")
        try? FileManager.default.removeItem(at: tangramURL)
    }
    
    public func exists(id: String) async -> Bool {
        let tangramURL = documentsDirectory.appendingPathComponent("tangram_\(id).json")
        return FileManager.default.fileExists(atPath: tangramURL.path)
    }
    
    // MARK: - Batch Operations
    
    public func saveBatch(_ puzzles: [TangramPuzzle]) async throws {
        for puzzle in puzzles {
            try await save(puzzle)
        }
    }
    
    public func deleteBatch(_ ids: [String]) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
    
    // MARK: - Direct, Simple Methods (Legacy, kept for compatibility)
    
    func saveTangram(_ puzzle: TangramPuzzle) async throws {
        let url = documentsDirectory.appendingPathComponent("tangram_\(puzzle.id).json")
        let data = try JSONEncoder().encode(puzzle)
        try data.write(to: url)
    }
    
    func loadTangram(id: String) async throws -> TangramPuzzle? {
        let url = documentsDirectory.appendingPathComponent("tangram_\(id).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TangramPuzzle.self, from: data)
    }
    
    func loadAllTangrams() async throws -> [TangramPuzzle] {
        let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory,
                                                                includingPropertiesForKeys: nil)
        let tangramFiles = files.filter { $0.lastPathComponent.hasPrefix("tangram_") &&
                                          $0.pathExtension == "json" }
        
        var puzzles: [TangramPuzzle] = []
        for url in tangramFiles {
            if let data = try? Data(contentsOf: url),
               let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: data) {
                puzzles.append(puzzle)
            }
        }
        return puzzles
    }
    
    // MARK: - Storage Info
    
    public func getPuzzleCount(difficulty: TangramPuzzle.Difficulty? = nil, completed: Bool? = nil) async throws -> Int {
        let tangrams = try await loadAllTangrams()
        // Simple filter if needed
        return tangrams.count
    }
    
    public struct StorageInfo {
        let totalPuzzles: Int
        let storageSizeBytes: Int
        let lastCleanup: Date?
        let version: String
    }
    
    public func getStorageInfo() async throws -> StorageInfo {
        let tangramCount = try await loadAllTangrams().count
        
        // Calculate approximate size (rough estimate)
        let estimatedSize = Int64(tangramCount * 1024) // ~1KB per puzzle
        
        return StorageInfo(
            totalPuzzles: tangramCount,
            storageSizeBytes: Int(estimatedSize),
            lastCleanup: nil,
            version: "1.0"
        )
    }
    
    public func cleanup() async throws {
        // No cleanup needed for file-based storage
    }
    
    // MARK: - Import/Export
    
    public func exportPuzzles(_ puzzles: [TangramPuzzle]) async throws -> Data {
        return try JSONEncoder().encode(puzzles)
    }
    
    public func importPuzzles(from data: Data) async throws -> [TangramPuzzle] {
        let puzzles = try JSONDecoder().decode([TangramPuzzle].self, from: data)
        for puzzle in puzzles {
            try await save(puzzle)
        }
        return puzzles
    }
}

enum StorageError: LocalizedError {
    case unsupportedType
    
    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported puzzle type"
        }
    }
}

