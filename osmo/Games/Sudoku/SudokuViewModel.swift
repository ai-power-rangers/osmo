//
//  SudokuViewModel.swift
//  osmo
//
//  Refactored ViewModel with initial/target state management
//

import Foundation
import SwiftUI
import CoreGraphics

@MainActor
final class SudokuViewModel: BaseGameViewModel<SudokuPuzzle> {
    
    // MARK: - Sudoku-Specific Properties
    
    var gridSize: GridSize = .nineByNine
    var selectedCell: Position?
    
    // Computed access to board states for convenience
    var currentBoard: [[Int?]] { currentPuzzle?.currentState.grid ?? [] }
    var initialBoard: [[Int?]] { currentPuzzle?.initialState.grid ?? [] }
    var targetBoard: [[Int?]] { currentPuzzle?.targetState.grid ?? [] }
    
    // MARK: - Editor Mode
    
    var editorMode: EditorMode?
    var showTargetOverlay: Bool = false
    
    // MARK: - Game State (inherited from BaseGameViewModel: timer, moveCount, startTime, isPaused)
    
    // MARK: - Validation State
    
    var conflicts: Set<Position> = []
    var availableNumbers: [Position: Set<Int>] = [:]
    // isComplete inherited from BaseGameViewModel
    var isSolved: Bool = false
    
    // MARK: - UI State
    
    var showingNumberPicker: Bool = false
    var showingHints: Bool = false
    var highlightedNumber: Int?
    var showingCandidates: Bool = false
    
    // MARK: - History for Undo/Redo
    
    private var moveHistory: [Move] = []
    private var redoStack: [Move] = []
    
    struct Move {
        let position: Position
        let oldValue: Int?
        let newValue: Int?
        let timestamp: Date
    }
    
    // MARK: - Services
    
    private let storage = SudokuStorage.shared
    
    // MARK: - Initialization
    
    override convenience init(services: ServiceContainer) {
        self.init(puzzle: nil, editorMode: nil, services: services)
    }
    
    init(puzzle: SudokuPuzzle? = nil, editorMode: EditorMode? = nil, services: ServiceContainer) {
        // Initialize gridSize first
        let gridSizeValue = puzzle?.gridSize ?? .nineByNine
        self.gridSize = gridSizeValue
        self.editorMode = editorMode
        
        super.init(services: services)
        
        if let puzzle = puzzle {
            loadPuzzle(puzzle)
        } else if editorMode != nil {
            // Start with empty puzzle in editor
            currentPuzzle = SudokuPuzzle.empty(gridSize: gridSize)
        } else {
            // Load first available puzzle for play mode
            loadFirstPuzzle()
        }
    }
    
    // MARK: - Computed Properties
    
    var isEditMode: Bool {
        editorMode != nil
    }
    
    func isInitialCell(row: Int, col: Int) -> Bool {
        return initialBoard[row][col] != nil
    }
    
    // MARK: - Puzzle Management
    
    func loadPuzzle(_ puzzle: SudokuPuzzle) {
        var mutablePuzzle = puzzle
        gridSize = puzzle.gridSize
        
        switch editorMode {
        case .initial:
            mutablePuzzle.currentState = puzzle.initialState
        case .target:
            mutablePuzzle.currentState = SudokuBoard(grid: puzzle.solution, size: puzzle.gridSize)
        case .testing, nil:
            mutablePuzzle.currentState = puzzle.initialState
        }
        
        // Use inherited startGame method
        startGame(with: mutablePuzzle)
        
        selectedCell = nil
        moveHistory.removeAll()
        redoStack.removeAll()
        isSolved = false
        
        validateBoard()
        updateAvailableNumbers()
    }
    
    func loadFirstPuzzle() {
        Task {
            do {
                let puzzles: [SudokuPuzzle] = try await storage.loadAll()
                if let first = puzzles.first {
                    await MainActor.run {
                        loadPuzzle(first)
                    }
                } else {
                    // Load a built-in puzzle if no saved puzzles
                    let builtIn = SudokuPuzzle.createBuiltInPuzzles().first!
                    await MainActor.run {
                        loadPuzzle(builtIn)
                    }
                }
            } catch {
                print("Failed to load first Sudoku puzzle: \(error)")
            }
        }
    }
    
    func savePuzzle(name: String) {
        guard var puzzle = currentPuzzle else { return }
        
        puzzle.name = name
        puzzle.updatedAt = Date()
        
        // Update the appropriate state based on editor mode
        switch editorMode {
        case .initial:
            puzzle.initialState.grid = currentBoard
        case .target:
            puzzle.targetState.grid = currentBoard
        case .testing, nil:
            break
        }
        
        // Validate before saving
        let errors = puzzle.validate()
        if !errors.isEmpty {
            print("[SudokuViewModel] Validation errors: \(errors)")
            return
        }
        
        Task {
            do {
                try await storage.save(puzzle)
                currentPuzzle = puzzle
                services.audioService.playSound("save_success")
            } catch {
                print("[SudokuViewModel] Failed to save puzzle: \(error)")
            }
        }
    }
    
    func deletePuzzle(_ puzzle: SudokuPuzzle) {
        Task {
            do {
                try await storage.delete(id: puzzle.id)
                if currentPuzzle?.id == puzzle.id {
                    loadFirstPuzzle()
                }
            } catch {
                print("[SudokuViewModel] Failed to delete puzzle: \(error)")
            }
        }
    }
    
    func getAllPuzzles() -> [SudokuPuzzle] {
        return storage.loadAll()
    }
    
    // MARK: - Number Placement
    
    func placeNumber(_ number: Int?, at position: Position) {
        guard position.row >= 0 && position.row < gridSize.rawValue,
              position.col >= 0 && position.col < gridSize.rawValue else { return }
        
        // Don't modify initial cells in game mode
        if !isEditMode && initialBoard[position.row][position.col] != nil {
            return
        }
        
        // Record move for undo
        if !isEditMode {
            let move = Move(
                position: position,
                oldValue: currentBoard[position.row][position.col],
                newValue: number,
                timestamp: Date()
            )
            moveHistory.append(move)
            redoStack.removeAll()
            moveCount += 1
        }
        
        // Update board
        currentPuzzle?.currentState.grid[position.row][position.col] = number
        
        // Update initial board if in initial editor mode
        if editorMode == .initial && number != nil {
            currentPuzzle?.initialState.grid[position.row][position.col] = number
        }
        
        // Validate and check completion
        validateBoard()
        updateAvailableNumbers()
        checkCompletion()
        
        services.audioService.playSound("piece_place")
        notifySceneUpdate()
    }
    
    func clearCell(at position: Position) {
        placeNumber(nil, at: position)
    }
    
    func selectCell(_ position: Position) {
        selectedCell = position
        highlightedNumber = currentBoard[position.row][position.col]
        services.audioService.playSound("cell_select")
        notifySceneUpdate()
    }
    
    func toggleInitialCell(at position: Position) {
        guard editorMode == .initial else { return }
        
        if currentPuzzle?.initialState.grid[position.row][position.col] != nil {
            currentPuzzle?.initialState.grid[position.row][position.col] = nil
        } else if let value = currentPuzzle?.currentState.grid[position.row][position.col] {
            currentPuzzle?.initialState.grid[position.row][position.col] = value
        }
    }
    
    // MARK: - Validation
    
    func validateBoard() {
        conflicts.removeAll()
        
        for row in 0..<gridSize.rawValue {
            for col in 0..<gridSize.rawValue {
                let position = Position(row: row, col: col)
                
                guard let value = currentBoard[row][col] else {
                    continue
                }
                
                // Check for conflicts in row
                for c in 0..<gridSize.rawValue {
                    if c != col && currentBoard[row][c] == value {
                        conflicts.insert(position)
                        conflicts.insert(Position(row: row, col: c))
                    }
                }
                
                // Check for conflicts in column
                for r in 0..<gridSize.rawValue {
                    if r != row && currentBoard[r][col] == value {
                        conflicts.insert(position)
                        conflicts.insert(Position(row: r, col: col))
                    }
                }
                
                // Check for conflicts in box
                let boxSize = gridSize == .fourByFour ? 2 : 3
                let boxStartRow = (row / boxSize) * boxSize
                let boxStartCol = (col / boxSize) * boxSize
                
                for r in boxStartRow..<(boxStartRow + boxSize) {
                    for c in boxStartCol..<(boxStartCol + boxSize) {
                        if (r != row || c != col) && currentBoard[r][c] == value {
                            conflicts.insert(position)
                            conflicts.insert(Position(row: r, col: c))
                        }
                    }
                }
            }
        }
    }
    
    func getAvailableNumbers(for position: Position) -> Set<Int> {
        // If cell is filled or initial in game mode, no numbers available
        if currentBoard[position.row][position.col] != nil || 
           (!isEditMode && initialBoard[position.row][position.col] != nil) {
            return []
        }
        
        // Start with all possible numbers
        var available = Set(1...gridSize.rawValue)
        
        // Remove numbers in same row
        for col in 0..<gridSize.rawValue {
            if let value = currentBoard[position.row][col] {
                available.remove(value)
            }
        }
        
        // Remove numbers in same column
        for row in 0..<gridSize.rawValue {
            if let value = currentBoard[row][position.col] {
                available.remove(value)
            }
        }
        
        // Remove numbers in same box
        let boxSize = gridSize == .fourByFour ? 2 : 3
        let boxStartRow = (position.row / boxSize) * boxSize
        let boxStartCol = (position.col / boxSize) * boxSize
        
        for r in boxStartRow..<(boxStartRow + boxSize) {
            for c in boxStartCol..<(boxStartCol + boxSize) {
                if let value = currentBoard[r][c] {
                    available.remove(value)
                }
            }
        }
        
        return available
    }
    
    func checkSolution() {
        guard currentPuzzle != nil,
              editorMode == nil else { return }
        
        // Check if current board matches target
        var matchesTarget = true
        for row in 0..<gridSize.rawValue {
            for col in 0..<gridSize.rawValue {
                if currentBoard[row][col] != targetBoard[row][col] {
                    matchesTarget = false
                    break
                }
            }
            if !matchesTarget { break }
        }
        
        if matchesTarget && !isSolved {
            isSolved = true
            isComplete = true
            // Timer is managed by BaseGameViewModel
            services.audioService.playSound("puzzle_complete")
        }
    }
    
    func resetToInitial() {
        guard let puzzle = currentPuzzle else { return }
        currentPuzzle?.currentState.grid = puzzle.initialBoard
        isComplete = false
        isSolved = false
        selectedCell = nil
        moveHistory.removeAll()
        redoStack.removeAll()
        moveCount = 0
        validateBoard()
        updateAvailableNumbers()
    }
    
    // MARK: - Editor Mode Management
    
    func switchEditorMode(_ mode: EditorMode?) {
        editorMode = mode
        
        guard let puzzle = currentPuzzle else { return }
        
        switch mode {
        case .initial:
            currentPuzzle?.currentState.grid = puzzle.initialBoard
            showTargetOverlay = true
        case .target:
            currentPuzzle?.currentState.grid = puzzle.solution
            showTargetOverlay = false
        case .testing:
            currentPuzzle?.currentState.grid = puzzle.initialBoard
            showTargetOverlay = false
        case nil:
            currentPuzzle?.currentState.grid = puzzle.initialBoard
            showTargetOverlay = false
        }
        
        // Timer management is handled by BaseGameViewModel
        notifySceneUpdate()
    }
    
    func clearBoard() {
        let dimension = gridSize.rawValue
        currentPuzzle?.currentState.grid = Array(repeating: Array(repeating: nil, count: dimension), count: dimension)
        
        if editorMode == .initial {
            if let grid = currentPuzzle?.currentState.grid {
                currentPuzzle?.initialState.grid = grid
            }
        } else if editorMode == .target {
            if let grid = currentPuzzle?.currentState.grid {
                currentPuzzle?.targetState.grid = grid
            }
        }
        
        validateBoard()
    }
    
    func fillAllCells() {
        // In editor mode, fill with a valid solution pattern
        // This is a simple pattern - in production would use proper solver
        guard editorMode == .target else { return }
        
        // Simple valid 9x9 pattern
        if gridSize == .nineByNine {
            currentPuzzle?.targetState.grid = [
                [5, 3, 4, 6, 7, 8, 9, 1, 2],
                [6, 7, 2, 1, 9, 5, 3, 4, 8],
                [1, 9, 8, 3, 4, 2, 5, 6, 7],
                [8, 5, 9, 7, 6, 1, 4, 2, 3],
                [4, 2, 6, 8, 5, 3, 7, 9, 1],
                [7, 1, 3, 9, 2, 4, 8, 5, 6],
                [9, 6, 1, 5, 3, 7, 2, 8, 4],
                [2, 8, 7, 4, 1, 9, 6, 3, 5],
                [3, 4, 5, 2, 8, 6, 1, 7, 9]
            ]
            if let grid = currentPuzzle?.targetState.grid {
                currentPuzzle?.currentState.grid = grid
            }
        }
    }
    
    // MARK: - Game Methods
    
    func provideHint() {
        guard editorMode == nil else { return }
        
        // Find an empty cell and fill it with the solution value
        for row in 0..<gridSize.rawValue {
            for col in 0..<gridSize.rawValue {
                if currentBoard[row][col] == nil {
                    if let solutionValue = targetBoard[row][col] {
                        placeNumber(solutionValue, at: Position(row: row, col: col))
                        services.audioService.playSound("hint")
                        return
                    }
                }
            }
        }
    }
    
    override func undo() {
        guard let lastMove = moveHistory.popLast() else { return }
        
        // Restore previous value
        currentPuzzle?.currentState.grid[lastMove.position.row][lastMove.position.col] = lastMove.oldValue
        
        // Add to redo stack
        redoStack.append(lastMove)
        
        // Revalidate
        validateBoard()
        updateAvailableNumbers()
        checkSolution()
        services.audioService.playSound("undo")
        notifySceneUpdate()
    }
    
    override func redo() {
        guard let redoMove = redoStack.popLast() else { return }
        
        // Restore the move
        currentPuzzle?.currentState.grid[redoMove.position.row][redoMove.position.col] = redoMove.newValue
        
        // Add back to history
        moveHistory.append(redoMove)
        
        // Revalidate
        validateBoard()
        updateAvailableNumbers()
        checkSolution()
        services.audioService.playSound("redo")
        notifySceneUpdate()
    }
    
    
    // MARK: - Private Methods
    
    private func updateAvailableNumbers() {
        availableNumbers.removeAll()
        
        for row in 0..<gridSize.rawValue {
            for col in 0..<gridSize.rawValue {
                let position = Position(row: row, col: col)
                availableNumbers[position] = getAvailableNumbers(for: position)
            }
        }
    }
    
    private func checkCompletion() {
        // Check if all cells are filled
        var allFilled = true
        for row in currentBoard {
            for cell in row {
                if cell == nil {
                    allFilled = false
                    break
                }
            }
            if !allFilled { break }
        }
        
        isComplete = allFilled
        
        // Check if solved correctly
        if isComplete && conflicts.isEmpty {
            checkSolution()
        }
    }
    
    // Timer management is handled by BaseGameViewModel
    
    // MARK: - Computed Properties
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // canUndo and canRedo are inherited from BaseGameViewModel
    
    // MARK: - Cleanup
    
    deinit {
        // Cleanup handled by BaseGameViewModel
    }
}