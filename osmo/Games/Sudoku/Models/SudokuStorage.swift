//
//  SudokuStorage.swift
//  osmo
//
//  Storage management for Sudoku puzzles using consistent patterns
//

import Foundation

/// Storage manager for Sudoku puzzles
final class SudokuStorage: BasePuzzleStorage {
    
    static let shared = SudokuStorage()
    
    private init() {
        do {
            try super.init(configuration: PuzzleStorageConfiguration())
        } catch {
            fatalError("Failed to initialize SudokuStorage: \(error)")
        }
        // Ensure default puzzles exist
        ensureBuiltInPuzzles()
    }
    
    private func ensureBuiltInPuzzles() {
        Task {
            do {
                let puzzles: [SudokuPuzzle] = try await loadAll()
                
                // If no puzzles exist, create built-in ones
                if puzzles.isEmpty {
                    for puzzle in SudokuPuzzle.createBuiltInPuzzles() {
                        try await save(puzzle)
                    }
                }
            } catch {
                print("Failed to ensure built-in puzzles: \(error)")
            }
        }
    }
    
    // Additional Sudoku-specific methods if needed
    
    // Synchronous wrapper for SwiftUI views that need immediate data
    func loadAll() -> [SudokuPuzzle] {
        // This is a synchronous wrapper that returns cached puzzles
        // In production, you'd want to handle this with async/await properly
        var puzzles: [SudokuPuzzle] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                let loadedPuzzles: [SudokuPuzzle] = try await super.loadAll()
                puzzles = loadedPuzzles
            } catch {
                print("Failed to load puzzles synchronously: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return puzzles
    }
    
    func getPuzzlesByDifficulty(_ difficulty: PuzzleDifficulty) async throws -> [SudokuPuzzle] {
        let puzzles: [SudokuPuzzle] = try await loadAll()
        return puzzles.filter { $0.difficulty == difficulty }
    }
    
    func getPuzzlesByGridSize(_ gridSize: GridSize) async throws -> [SudokuPuzzle] {
        let puzzles: [SudokuPuzzle] = try await loadAll()
        return puzzles.filter { $0.gridSize == gridSize }
    }
}

// Removed old GamePuzzle extension - SudokuPuzzle now properly implements GamePuzzleProtocol

// Cleaned up - SudokuPuzzle now has proper state properties defined in the main struct