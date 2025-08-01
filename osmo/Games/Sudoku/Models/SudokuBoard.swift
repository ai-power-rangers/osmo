//
//  SudokuBoard.swift
//  osmo
//
//  Sudoku board logic and validation
//

import Foundation

struct SudokuBoard {
    let size: GridSize
    private(set) var grid: [[Int?]]
    private(set) var isLocked: [[Bool]]  // Original tiles that can't be moved
    
    // MARK: - Initialization
    
    init(size: GridSize) {
        self.size = size
        let dimension = size.rawValue
        self.grid = Array(repeating: Array(repeating: nil, count: dimension), count: dimension)
        self.isLocked = Array(repeating: Array(repeating: false, count: dimension), count: dimension)
    }
    
    // MARK: - Public Methods
    
    mutating func place(number: Int?, at position: Position) -> PlacementResult {
        guard position.row >= 0 && position.row < size.rawValue &&
              position.col >= 0 && position.col < size.rawValue else {
            return .invalid(reason: "Position out of bounds")
        }
        
        // Check if it's an original tile
        if isLocked[position.row][position.col] {
            return .originalTile
        }
        
        // Check if already filled
        if let existing = grid[position.row][position.col], existing != nil && number != nil {
            return .alreadyFilled
        }
        
        // Validate number range
        if let num = number {
            if num < 1 || num > size.maxNumber {
                return .invalid(reason: "Number must be between 1 and \(size.maxNumber)")
            }
            
            // Check validity
            let validation = validate(number: num, at: position)
            if !validation.isValid {
                return .invalid(reason: validation.errorMessage)
            }
        }
        
        // Place the number
        grid[position.row][position.col] = number
        return .valid
    }
    
    mutating func remove(at position: Position) -> PlacementResult {
        guard !isLocked[position.row][position.col] else {
            return .originalTile
        }
        
        grid[position.row][position.col] = nil
        return .valid
    }
    
    mutating func lockCurrentState() {
        // Lock all non-empty cells as original tiles
        for row in 0..<size.rawValue {
            for col in 0..<size.rawValue {
                isLocked[row][col] = (grid[row][col] != nil)
            }
        }
    }
    
    func validate(number: Int, at position: Position) -> ValidationResult {
        // Check row
        for col in 0..<size.rawValue {
            if col != position.col && grid[position.row][col] == number {
                return .duplicateInRow(position: Position(row: position.row, col: col), number: number)
            }
        }
        
        // Check column
        for row in 0..<size.rawValue {
            if row != position.row && grid[row][position.col] == number {
                return .duplicateInColumn(position: Position(row: row, col: position.col), number: number)
            }
        }
        
        // Check box
        let boxSize = size.boxSize
        let boxStartRow = (position.row / boxSize) * boxSize
        let boxStartCol = (position.col / boxSize) * boxSize
        
        for row in boxStartRow..<(boxStartRow + boxSize) {
            for col in boxStartCol..<(boxStartCol + boxSize) {
                if row != position.row || col != position.col {
                    if grid[row][col] == number {
                        return .duplicateInBox(position: Position(row: row, col: col), number: number)
                    }
                }
            }
        }
        
        return .valid
    }
    
    func isSolved() -> Bool {
        // Check if all cells are filled
        for row in 0..<size.rawValue {
            for col in 0..<size.rawValue {
                if grid[row][col] == nil {
                    return false
                }
            }
        }
        
        // Validate all positions
        for row in 0..<size.rawValue {
            for col in 0..<size.rawValue {
                if let number = grid[row][col] {
                    let tempGrid = grid
                    var tempBoard = self
                    tempBoard.grid[row][col] = nil  // Temporarily remove to validate
                    let validation = tempBoard.validate(number: number, at: Position(row: row, col: col))
                    tempBoard.grid = tempGrid  // Restore
                    
                    if !validation.isValid {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    func getNumber(at position: Position) -> Int? {
        guard position.row >= 0 && position.row < size.rawValue &&
              position.col >= 0 && position.col < size.rawValue else {
            return nil
        }
        return grid[position.row][position.col]
    }
    
    func isOriginalTile(at position: Position) -> Bool {
        guard position.row >= 0 && position.row < size.rawValue &&
              position.col >= 0 && position.col < size.rawValue else {
            return false
        }
        return isLocked[position.row][position.col]
    }
    
    // MARK: - Puzzle Generation (for testing)
    
    static func generatePuzzle(size: GridSize, difficulty: Int = 3) -> SudokuBoard {
        var board = SudokuBoard(size: size)
        
        // Simple puzzle generation - just place a few numbers
        // In production, use proper Sudoku generation algorithm
        switch size {
        case .fourByFour:
            // Place some initial numbers for 4x4
            _ = board.place(number: 1, at: Position(row: 0, col: 0))
            _ = board.place(number: 3, at: Position(row: 0, col: 2))
            _ = board.place(number: 2, at: Position(row: 1, col: 1))
            _ = board.place(number: 4, at: Position(row: 2, col: 3))
            _ = board.place(number: 3, at: Position(row: 3, col: 0))
            
        case .nineByNine:
            // Place some initial numbers for 9x9
            _ = board.place(number: 5, at: Position(row: 0, col: 0))
            _ = board.place(number: 3, at: Position(row: 0, col: 1))
            _ = board.place(number: 7, at: Position(row: 1, col: 0))
            _ = board.place(number: 6, at: Position(row: 1, col: 3))
            _ = board.place(number: 1, at: Position(row: 1, col: 4))
            _ = board.place(number: 9, at: Position(row: 1, col: 5))
            _ = board.place(number: 5, at: Position(row: 1, col: 8))
            // Add more as needed...
        }
        
        board.lockCurrentState()
        return board
    }
}