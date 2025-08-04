//
//  PuzzleType.swift
//  osmo
//
//  Unified puzzle type enum to eliminate generic casting and simplify storage
//

import Foundation

/// Unified puzzle type that wraps all game-specific puzzles
/// This eliminates the need for generic type casting in storage operations
public enum PuzzleType: Codable {
    case tangram(TangramPuzzle)
    case sudoku(SudokuPuzzle)
    // Note: RPS doesn't follow the puzzle pattern (it's real-time, not saved/loaded)
    
    /// Unique identifier for storage
    public var id: String {
        switch self {
        case .tangram(let puzzle):
            return "tangram_\(puzzle.id)"
        case .sudoku(let puzzle):
            return "sudoku_\(puzzle.id)"
        }
    }
    
    /// The game type this puzzle belongs to
    public var gameType: GameType {
        switch self {
        case .tangram:
            return .tangram
        case .sudoku:
            return .sudoku
        }
    }
    
    /// The difficulty level of the puzzle
    public var difficulty: PuzzleDifficulty? {
        switch self {
        case .tangram(let puzzle):
            return puzzle.difficulty
        case .sudoku(let puzzle):
            return puzzle.difficulty
        }
    }
    
    /// The name/title of the puzzle
    public var name: String {
        switch self {
        case .tangram(let puzzle):
            return puzzle.name
        case .sudoku(let puzzle):
            return puzzle.name
        }
    }
    
    /// When the puzzle was created
    public var createdAt: Date {
        switch self {
        case .tangram(let puzzle):
            return puzzle.createdAt
        case .sudoku(let puzzle):
            return puzzle.createdAt
        }
    }
    
    /// When the puzzle was last updated
    public var updatedAt: Date {
        switch self {
        case .tangram(let puzzle):
            return puzzle.updatedAt
        case .sudoku(let puzzle):
            return puzzle.updatedAt
        }
    }
    
    /// Check if the puzzle is completed
    public var isCompleted: Bool {
        switch self {
        case .tangram(let puzzle):
            return puzzle.isCompleted()
        case .sudoku(let puzzle):
            return puzzle.isCompleted()
        }
    }
    
    /// Extract specific puzzle type
    public func asTangram() -> TangramPuzzle? {
        if case .tangram(let puzzle) = self {
            return puzzle
        }
        return nil
    }
    
    public func asSudoku() -> SudokuPuzzle? {
        if case .sudoku(let puzzle) = self {
            return puzzle
        }
        return nil
    }
    
    // MARK: - Factory Methods
    
    /// Create a PuzzleType from any GamePuzzleProtocol
    public static func from(_ puzzle: any GamePuzzleProtocol) -> PuzzleType? {
        if let tangram = puzzle as? TangramPuzzle {
            return .tangram(tangram)
        } else if let sudoku = puzzle as? SudokuPuzzle {
            return .sudoku(sudoku)
        }
        return nil
    }
}

// MARK: - Storage Error

public enum StorageError: LocalizedError {
    case unsupportedType
    case encodingFailed
    case decodingFailed
    case fileNotFound
    case directoryNotFound
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Unsupported puzzle type"
        case .encodingFailed:
            return "Failed to encode puzzle data"
        case .decodingFailed:
            return "Failed to decode puzzle data"
        case .fileNotFound:
            return "Puzzle file not found"
        case .directoryNotFound:
            return "Storage directory not found"
        }
    }
}