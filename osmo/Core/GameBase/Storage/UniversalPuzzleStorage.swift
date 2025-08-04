//
//  UniversalPuzzleStorage.swift
//  osmo
//
//  Universal storage service that can handle all puzzle types
//

import Foundation

/// Universal puzzle storage that delegates to specific storage implementations
final class UniversalPuzzleStorage: PuzzleStorageProtocol {
    static let shared = UniversalPuzzleStorage()
    
    private init() {}
    
    // MARK: - PuzzleStorageProtocol Implementation
    
    func save<T: GamePuzzleProtocol>(_ puzzle: T) async throws {
        // Delegate to specific storage based on puzzle type
        if let tangramPuzzle = puzzle as? TangramPuzzle {
            try await TangramPuzzleStorage.shared.save(tangramPuzzle)
        } else if let sudokuPuzzle = puzzle as? SudokuPuzzle {
            try await SudokuStorage.shared.save(sudokuPuzzle)
        } else {
            throw PuzzleStorageError.unsupportedVersion("Unknown puzzle type")
        }
    }
    
    func load<T: GamePuzzleProtocol>(id: String) async throws -> T? {
        // Try each storage type
        if T.self == TangramPuzzle.self {
            if let puzzle: TangramPuzzle = try await TangramPuzzleStorage.shared.load(id: id) {
                return puzzle as? T
            }
        } else if T.self == SudokuPuzzle.self {
            if let puzzle: SudokuPuzzle = try await SudokuStorage.shared.load(id: id) {
                return puzzle as? T
            }
        }
        return nil
    }
    
    func loadAll<T: GamePuzzleProtocol>() async throws -> [T] {
        if T.self == TangramPuzzle.self {
            let puzzles = try await TangramPuzzleStorage.shared.loadAll()
            return puzzles as? [T] ?? []
        } else if T.self == SudokuPuzzle.self {
            let puzzles = try await SudokuStorage.shared.loadAll()
            return puzzles as? [T] ?? []
        }
        return []
    }
    
    func delete(id: String) async throws {
        // Try to delete from all storages
        try? await TangramPuzzleStorage.shared.delete(id: id)
        try? await SudokuStorage.shared.delete(id: id)
    }
    
    func exists(id: String) async -> Bool {
        let tangramExists = await TangramPuzzleStorage.shared.exists(id: id)
        let sudokuExists = await SudokuStorage.shared.exists(id: id)
        return tangramExists || sudokuExists
    }
    
    func saveBatch<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws {
        for puzzle in puzzles {
            try await save(puzzle)
        }
    }
    
    func deleteBatch(_ ids: [String]) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
    
    func loadPuzzles<T: GamePuzzleProtocol>(
        difficulty: PuzzleDifficulty?,
        tags: Set<String>?,
        completed: Bool?
    ) async throws -> [T] {
        let allPuzzles: [T] = try await loadAll()
        
        return allPuzzles.filter { puzzle in
            if let difficulty = difficulty, puzzle.difficulty != difficulty {
                return false
            }
            if let tags = tags, puzzle.tags.isDisjoint(with: tags) {
                return false
            }
            if let completed = completed, puzzle.hasBeenCompleted != completed {
                return false
            }
            return true
        }
    }
    
    func getPuzzleCount(difficulty: PuzzleDifficulty?, completed: Bool?) async throws -> Int {
        let tangramCount = try await TangramPuzzleStorage.shared.getPuzzleCount(difficulty: difficulty, completed: completed)
        let sudokuCount = try await SudokuStorage.shared.getPuzzleCount(difficulty: difficulty, completed: completed)
        return tangramCount + sudokuCount
    }
    
    func getStorageInfo() async throws -> StorageInfo {
        // Combine info from all storages
        let tangramInfo = try await TangramPuzzleStorage.shared.getStorageInfo()
        let sudokuInfo = try await SudokuStorage.shared.getStorageInfo()
        
        return StorageInfo(
            totalPuzzles: tangramInfo.totalPuzzles + sudokuInfo.totalPuzzles,
            storageSizeBytes: tangramInfo.storageSizeBytes + sudokuInfo.storageSizeBytes,
            lastCleanup: max(tangramInfo.lastCleanup ?? Date.distantPast, sudokuInfo.lastCleanup ?? Date.distantPast),
            version: "1.0",
            availableSpaceBytes: tangramInfo.availableSpaceBytes,
            puzzleTypeBreakdown: [
                "tangram": tangramInfo.totalPuzzles,
                "sudoku": sudokuInfo.totalPuzzles
            ]
        )
    }
    
    func cleanup() async throws {
        try await TangramPuzzleStorage.shared.cleanup()
        try await SudokuStorage.shared.cleanup()
    }
    
    func exportPuzzles<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws -> Data {
        return try JSONEncoder().encode(puzzles)
    }
    
    func importPuzzles<T: GamePuzzleProtocol>(from data: Data) async throws -> [T] {
        return try JSONDecoder().decode([T].self, from: data)
    }
}