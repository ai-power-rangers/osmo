//
//  SudokuPuzzle.swift
//  osmo
//
//  Puzzle definition model for Sudoku
//

import Foundation

/// Represents a complete Sudoku puzzle with initial state and solution
public struct SudokuPuzzle: GamePuzzleProtocol, Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var difficulty: PuzzleDifficulty
    public let createdAt: Date
    public var updatedAt: Date
    
    // MARK: - GamePuzzleProtocol Implementation
    
    public typealias PieceType = Int // Sudoku numbers 1-9
    public typealias StateType = SudokuBoard
    
    public var initialState: SudokuBoard
    public var targetState: SudokuBoard  // The complete solution
    public var currentState: SudokuBoard
    
    public var pieces: [Int] {
        get { Array(1...gridSize.rawValue) } // Available numbers for this grid size
        set { /* Sudoku pieces are fixed, no-op */ }
    }
    public var previewImageData: Data?
    public var tags: Set<String>
    public var author: String?
    public var puzzleDescription: String?
    public let version: Int = 1
    public var playCount: Int = 0
    public var bestTime: TimeInterval?
    public var averageTime: TimeInterval?
    public var completionCount: Int = 0
    
    // MARK: - Sudoku-Specific Properties
    
    var gridSize: GridSize
    
    // Backward compatibility - computed from states
    var initialBoard: [[Int?]] { initialState.grid }
    var solution: [[Int?]] { targetState.grid }
    
    // MARK: - Required GamePuzzleProtocol Initializer
    
    public init(name: String, difficulty: PuzzleDifficulty) {
        self.id = UUID().uuidString
        self.name = name
        self.difficulty = difficulty
        self.createdAt = Date()
        self.updatedAt = Date()
        self.gridSize = .nineByNine // Default grid size
        self.initialState = SudokuBoard(size: .nineByNine)
        self.targetState = SudokuBoard(size: .nineByNine)
        self.currentState = SudokuBoard(size: .nineByNine)
        self.tags = Set<String>()
        self.author = nil
        self.puzzleDescription = nil
        self.previewImageData = nil
    }
    
    // Custom initializer for creating puzzles with full configuration
    public init(id: String = UUID().uuidString,
         name: String,
         gridSize: GridSize,
         initialBoard: [[Int?]],
         solution: [[Int?]],
         difficulty: PuzzleDifficulty = .medium,
         author: String? = nil,
         tags: Set<String> = [],
         puzzleDescription: String? = nil) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.author = author
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.gridSize = gridSize
        self.initialState = SudokuBoard(grid: initialBoard, size: gridSize)
        self.targetState = SudokuBoard(grid: solution, size: gridSize)
        self.currentState = SudokuBoard(grid: initialBoard, size: gridSize) // Start with initial board
        self.puzzleDescription = puzzleDescription
        self.previewImageData = nil
    }
    
    /// Create an empty puzzle for editing
    static func empty(gridSize: GridSize) -> SudokuPuzzle {
        let dimension = gridSize.rawValue
        let emptyBoard = Array(repeating: Array(repeating: nil as Int?, count: dimension), count: dimension)
        
        return SudokuPuzzle(
            name: "New Puzzle",
            gridSize: gridSize,
            initialBoard: emptyBoard,
            solution: emptyBoard,
            difficulty: .medium
        )
    }
    
    // MARK: - GamePuzzleProtocol Methods
    
    public func isValid() -> Bool {
        // Check that both initial and target states are valid Sudoku boards
        return initialState.grid.count == gridSize.rawValue &&
               targetState.grid.count == gridSize.rawValue &&
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func isCompleted() -> Bool {
        // Check if current state matches the target solution
        return currentState.grid == targetState.grid && 
               currentState.isComplete
    }
    
    public mutating func reset() {
        currentState = initialState
        touch()
    }
    
    public func copy() -> SudokuPuzzle {
        return self // Struct copy semantics
    }
    
    /// Validate that the puzzle is properly formed
    public func validate() -> [String] {
        var errors: [String] = []
        let dimension = gridSize.rawValue
        
        // Check board dimensions
        if initialBoard.count != dimension {
            errors.append("Initial board has incorrect number of rows")
        }
        if solution.count != dimension {
            errors.append("Solution has incorrect number of rows")
        }
        
        for (index, row) in initialBoard.enumerated() {
            if row.count != dimension {
                errors.append("Initial board row \(index) has incorrect number of columns")
            }
        }
        
        for (index, row) in solution.enumerated() {
            if row.count != dimension {
                errors.append("Solution row \(index) has incorrect number of columns")
            }
        }
        
        // Check that initial values match solution
        for row in 0..<min(initialBoard.count, dimension) {
            for col in 0..<min(initialBoard[row].count, dimension) {
                if let initialValue = initialBoard[row][col],
                   let solutionValue = solution[row][col],
                   initialValue != solutionValue {
                    errors.append("Initial value at (\(row),\(col)) doesn't match solution")
                }
            }
        }
        
        // Check solution is complete
        var hasEmptyCells = false
        for row in solution {
            for cell in row {
                if cell == nil {
                    hasEmptyCells = true
                    break
                }
            }
        }
        if hasEmptyCells {
            errors.append("Solution has empty cells")
        }
        
        // Check solution is valid
        if !isSolutionValid() {
            errors.append("Solution violates Sudoku rules")
        }
        
        return errors
    }
    
    /// Check if the solution follows Sudoku rules
    func isSolutionValid() -> Bool {
        let dimension = gridSize.rawValue
        let boxSize = gridSize == .fourByFour ? 2 : 3
        
        // Check rows
        for row in solution {
            if !isGroupValid(row, dimension: dimension) {
                return false
            }
        }
        
        // Check columns
        for col in 0..<dimension {
            let column = solution.map { $0[col] }
            if !isGroupValid(column, dimension: dimension) {
                return false
            }
        }
        
        // Check boxes
        for boxRow in 0..<boxSize {
            for boxCol in 0..<boxSize {
                var box: [Int?] = []
                for r in (boxRow * boxSize)..<((boxRow + 1) * boxSize) {
                    for c in (boxCol * boxSize)..<((boxCol + 1) * boxSize) {
                        box.append(solution[r][c])
                    }
                }
                if !isGroupValid(box, dimension: dimension) {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func isGroupValid(_ group: [Int?], dimension: Int) -> Bool {
        let values = group.compactMap { $0 }
        
        // Check all values are in valid range
        for value in values {
            if value < 1 || value > dimension {
                return false
            }
        }
        
        // Check no duplicates
        return Set(values).count == values.count
    }
    
    /// Count how many cells are filled in the initial board
    var filledCellCount: Int {
        initialBoard.flatMap { $0 }.compactMap { $0 }.count
    }
    
    /// Calculate fill percentage
    var fillPercentage: Double {
        let total = Double(gridSize.rawValue * gridSize.rawValue)
        return Double(filledCellCount) / total * 100
    }
}

// MARK: - Built-in Puzzles

extension SudokuPuzzle {
    /// Create some default puzzles for testing
    static func createBuiltInPuzzles() -> [SudokuPuzzle] {
        var puzzles: [SudokuPuzzle] = []
        
        // 4x4 Easy Puzzle
        puzzles.append(SudokuPuzzle(
            id: "builtin_4x4_easy",
            name: "Easy 4x4",
            gridSize: .fourByFour,
            initialBoard: [
                [1, nil, 3, nil],
                [nil, 3, nil, 1],
                [3, nil, 1, nil],
                [nil, 1, nil, 3]
            ],
            solution: [
                [1, 2, 3, 4],
                [4, 3, 2, 1],
                [3, 4, 1, 2],
                [2, 1, 4, 3]
            ],
            difficulty: .easy,
            author: "System",
            tags: ["4x4", "beginner"]
        ))
        
        // 9x9 Easy Puzzle
        puzzles.append(SudokuPuzzle(
            id: "builtin_9x9_easy",
            name: "Easy 9x9",
            gridSize: .nineByNine,
            initialBoard: [
                [5, 3, nil, nil, 7, nil, nil, nil, nil],
                [6, nil, nil, 1, 9, 5, nil, nil, nil],
                [nil, 9, 8, nil, nil, nil, nil, 6, nil],
                [8, nil, nil, nil, 6, nil, nil, nil, 3],
                [4, nil, nil, 8, nil, 3, nil, nil, 1],
                [7, nil, nil, nil, 2, nil, nil, nil, 6],
                [nil, 6, nil, nil, nil, nil, 2, 8, nil],
                [nil, nil, nil, 4, 1, 9, nil, nil, 5],
                [nil, nil, nil, nil, 8, nil, nil, 7, 9]
            ],
            solution: [
                [5, 3, 4, 6, 7, 8, 9, 1, 2],
                [6, 7, 2, 1, 9, 5, 3, 4, 8],
                [1, 9, 8, 3, 4, 2, 5, 6, 7],
                [8, 5, 9, 7, 6, 1, 4, 2, 3],
                [4, 2, 6, 8, 5, 3, 7, 9, 1],
                [7, 1, 3, 9, 2, 4, 8, 5, 6],
                [9, 6, 1, 5, 3, 7, 2, 8, 4],
                [2, 8, 7, 4, 1, 9, 6, 3, 5],
                [3, 4, 5, 2, 8, 6, 1, 7, 9]
            ],
            difficulty: .easy,
            author: "System",
            tags: ["9x9", "classic"]
        ))
        
        return puzzles
    }
}