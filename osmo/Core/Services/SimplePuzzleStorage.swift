//
//  SimplePuzzleStorage.swift
//  osmo
//
//  Simple, direct storage using PuzzleType enum to eliminate generic casting
//

import Foundation

@MainActor
public final class SimplePuzzleStorage: PuzzleStorageProtocol {
    private let documentsDirectory: URL
    
    public init() {
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                          in: .userDomainMask).first!
    }
    
    // MARK: - PuzzleStorageProtocol Implementation (Required for compatibility)
    
    public func save<T: GamePuzzleProtocol>(_ puzzle: T) async throws {
        guard let puzzleType = PuzzleType.from(puzzle) else {
            throw StorageError.unsupportedType
        }
        try await savePuzzleType(puzzleType)
    }
    
    public func load<T: GamePuzzleProtocol>(id: String) async throws -> T? {
        // Try to load the puzzle and cast to requested type
        if let puzzleType = try await loadPuzzleType(id: id) {
            switch puzzleType {
            case .tangram(let puzzle):
                return puzzle as? T
            case .sudoku(let puzzle):
                return puzzle as? T
            }
        }
        return nil
    }
    
    public func loadAll<T: GamePuzzleProtocol>() async throws -> [T] {
        let allPuzzles = try await loadAllPuzzleTypes()
        
        // Filter and cast to requested type
        if T.self == TangramPuzzle.self {
            return allPuzzles.compactMap { $0.asTangram() as? T }
        } else if T.self == SudokuPuzzle.self {
            return allPuzzles.compactMap { $0.asSudoku() as? T }
        }
        return []
    }
    
    public func loadPuzzles<T: GamePuzzleProtocol>(
        difficulty: PuzzleDifficulty? = nil,
        tags: Set<String>? = nil,
        completed: Bool? = nil
    ) async throws -> [T] {
        // Load all puzzles first
        let allPuzzles: [T] = try await loadAll()
        
        // Filter based on criteria
        return allPuzzles.filter { puzzle in
            // Filter by difficulty if specified
            if let difficulty = difficulty, puzzle.difficulty != difficulty {
                return false
            }
            
            // Filter by tags if specified (not implemented in current puzzles)
            // Would need to add tags property to puzzles
            
            // Filter by completion status if specified
            if let completed = completed {
                if completed != puzzle.isCompleted() {
                    return false
                }
            }
            
            return true
        }
    }
    
    public func delete(id: String) async throws {
        let tangramURL = documentsDirectory.appendingPathComponent("tangram_\(id).json")
        let sudokuURL = documentsDirectory.appendingPathComponent("sudoku_\(id).json")
        
        try? FileManager.default.removeItem(at: tangramURL)
        try? FileManager.default.removeItem(at: sudokuURL)
    }
    
    public func exists(id: String) async -> Bool {
        let tangramURL = documentsDirectory.appendingPathComponent("tangram_\(id).json")
        let sudokuURL = documentsDirectory.appendingPathComponent("sudoku_\(id).json")
        
        return FileManager.default.fileExists(atPath: tangramURL.path) ||
               FileManager.default.fileExists(atPath: sudokuURL.path)
    }
    
    // MARK: - Batch Operations
    
    public func saveBatch<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws {
        for puzzle in puzzles {
            try await save(puzzle)
        }
    }
    
    public func deleteBatch(_ ids: [String]) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
    
    // MARK: - PuzzleType-based Methods (New, cleaner approach)
    
    func savePuzzleType(_ puzzle: PuzzleType) async throws {
        let url = documentsDirectory.appendingPathComponent("\(puzzle.id).json")
        let data = try JSONEncoder().encode(puzzle)
        try data.write(to: url)
    }
    
    func loadPuzzleType(id: String) async throws -> PuzzleType? {
        // Try both tangram and sudoku prefixes
        let tangramURL = documentsDirectory.appendingPathComponent("tangram_\(id).json")
        let sudokuURL = documentsDirectory.appendingPathComponent("sudoku_\(id).json")
        let directURL = documentsDirectory.appendingPathComponent("\(id).json")
        
        // Try direct URL first (new format)
        if FileManager.default.fileExists(atPath: directURL.path) {
            let data = try Data(contentsOf: directURL)
            return try JSONDecoder().decode(PuzzleType.self, from: data)
        }
        
        // Fall back to legacy format
        if FileManager.default.fileExists(atPath: tangramURL.path) {
            let data = try Data(contentsOf: tangramURL)
            if let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: data) {
                return .tangram(puzzle)
            }
        }
        
        if FileManager.default.fileExists(atPath: sudokuURL.path) {
            let data = try Data(contentsOf: sudokuURL)
            if let puzzle = try? JSONDecoder().decode(SudokuPuzzle.self, from: data) {
                return .sudoku(puzzle)
            }
        }
        
        return nil
    }
    
    func loadAllPuzzleTypes() async throws -> [PuzzleType] {
        let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory,
                                                                includingPropertiesForKeys: nil)
        let jsonFiles = files.filter { $0.pathExtension == "json" }
        
        var puzzles: [PuzzleType] = []
        
        for url in jsonFiles {
            if let data = try? Data(contentsOf: url) {
                // Try to decode as PuzzleType first (new format)
                if let puzzle = try? JSONDecoder().decode(PuzzleType.self, from: data) {
                    puzzles.append(puzzle)
                }
                // Try legacy formats
                else if url.lastPathComponent.hasPrefix("tangram_"),
                        let puzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: data) {
                    puzzles.append(.tangram(puzzle))
                }
                else if url.lastPathComponent.hasPrefix("sudoku_"),
                        let puzzle = try? JSONDecoder().decode(SudokuPuzzle.self, from: data) {
                    puzzles.append(.sudoku(puzzle))
                }
            }
        }
        
        return puzzles
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
    
    func saveSudoku(_ puzzle: SudokuPuzzle) async throws {
        let url = documentsDirectory.appendingPathComponent("sudoku_\(puzzle.id).json")
        let data = try JSONEncoder().encode(puzzle)
        try data.write(to: url)
    }
    
    func loadSudoku(id: String) async throws -> SudokuPuzzle? {
        let url = documentsDirectory.appendingPathComponent("sudoku_\(id).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SudokuPuzzle.self, from: data)
    }
    
    func loadAllSudokus() async throws -> [SudokuPuzzle] {
        let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory,
                                                                includingPropertiesForKeys: nil)
        let sudokuFiles = files.filter { $0.lastPathComponent.hasPrefix("sudoku_") &&
                                         $0.pathExtension == "json" }
        
        var puzzles: [SudokuPuzzle] = []
        for url in sudokuFiles {
            if let data = try? Data(contentsOf: url),
               let puzzle = try? JSONDecoder().decode(SudokuPuzzle.self, from: data) {
                puzzles.append(puzzle)
            }
        }
        return puzzles
    }
    
    // MARK: - Storage Info
    
    public func getPuzzleCount(difficulty: PuzzleDifficulty? = nil, completed: Bool? = nil) async throws -> Int {
        let tangrams: [TangramPuzzle] = try await loadPuzzles(difficulty: difficulty, tags: nil, completed: completed)
        let sudokus: [SudokuPuzzle] = try await loadPuzzles(difficulty: difficulty, tags: nil, completed: completed)
        return tangrams.count + sudokus.count
    }
    
    public func getStorageInfo() async throws -> StorageInfo {
        let tangramCount = try await loadAllTangrams().count
        let sudokuCount = try await loadAllSudokus().count
        
        // Calculate approximate size (rough estimate)
        let estimatedSize = Int64((tangramCount + sudokuCount) * 1024) // ~1KB per puzzle
        
        return StorageInfo(
            totalPuzzles: tangramCount + sudokuCount,
            storageSizeBytes: Int(estimatedSize),
            lastCleanup: nil,
            version: "1.0"
        )
    }
    
    public func cleanup() async throws {
        // No cleanup needed for file-based storage
    }
    
    // MARK: - Import/Export
    
    public func exportPuzzles<T: GamePuzzleProtocol>(_ puzzles: [T]) async throws -> Data {
        return try JSONEncoder().encode(puzzles)
    }
    
    public func importPuzzles<T: GamePuzzleProtocol>(from data: Data) async throws -> [T] {
        let puzzles = try JSONDecoder().decode([T].self, from: data)
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

