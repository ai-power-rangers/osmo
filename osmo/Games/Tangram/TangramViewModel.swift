//
//  TangramViewModel.swift
//  osmo
//
//  Refactored ViewModel with initial/target state management
//

import SwiftUI
import CoreGraphics

@MainActor
final class TangramViewModel: BaseGameViewModel<TangramPuzzle> {
    
    // MARK: - Tangram-Specific Properties
    
    var selectedPieceId: UUID?
    
    // Editor mode
    var editorMode: EditorMode?
    var showTargetOverlay: Bool = false
    
    // UI Settings
    var showGrid: Bool = true
    var snapToGrid: Bool = true
    
    // UI State
    var showingSaveDialog = false
    var showingLoadDialog = false
    var puzzleName = ""
    
    // MARK: - Services
    
    private let storage = TangramPuzzleStorage.shared
    
    // MARK: - Computed Properties
    
    var selectedPiece: TangramPiece? {
        guard let id = selectedPieceId else { return nil }
        return currentPuzzle?.currentState.piece(withId: id)
    }
    
    // Computed access to current state for convenience
    var currentState: TangramState {
        return currentPuzzle?.currentState ?? TangramState()
    }
    
    var availableShapes: [TangramShape] {
        let usedShapes = Set(currentState.pieces.map { $0.shape })
        return TangramShape.allCases.filter { !usedShapes.contains($0) }
    }
    
    var isEditMode: Bool {
        editorMode != nil
    }
    
    // MARK: - Initialization
    
    override convenience init(services: ServiceContainer) {
        self.init(puzzle: nil, editorMode: nil, services: services)
    }
    
    init(puzzle: TangramPuzzle? = nil, editorMode: EditorMode? = nil, services: ServiceContainer) {
        self.editorMode = editorMode
        super.init(services: services)
        
        if let puzzle = puzzle {
            loadPuzzle(puzzle)
        } else if editorMode != nil {
            // Start with empty puzzle in editor
            currentPuzzle = TangramPuzzle.empty()
        } else {
            // Load first available puzzle for play mode
            loadFirstPuzzle()
        }
        
        // Configure based on mode
        if editorMode != nil {
            showGrid = true
            snapToGrid = true
        } else {
            showGrid = false
            snapToGrid = true
        }
    }
    
    // MARK: - Puzzle Management
    
    func loadPuzzle(_ puzzle: TangramPuzzle) {
        var mutablePuzzle = puzzle
        
        switch editorMode {
        case .initial:
            mutablePuzzle.currentState = puzzle.initialState
        case .target:
            mutablePuzzle.currentState = puzzle.targetState
        case .testing, nil:
            mutablePuzzle.currentState = puzzle.initialState
        }
        
        // Use inherited startGame method
        startGame(with: mutablePuzzle)
        selectedPieceId = nil
    }
    
    func loadFirstPuzzle() {
        Task {
            do {
                let puzzles: [TangramPuzzle] = try await storage.loadAll()
                if let first = puzzles.first {
                    await MainActor.run {
                        loadPuzzle(first)
                    }
                }
            } catch {
                print("Failed to load puzzles: \(error)")
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
            puzzle.initialState = currentState
        case .target:
            puzzle.targetState = currentState
        case .testing, nil:
            break
        }
        
        // Validate before saving
        let errors = puzzle.validate()
        if !errors.isEmpty {
            print("[TangramViewModel] Validation errors: \(errors)")
            return
        }
        
        Task {
            do {
                try await storage.save(puzzle)
                await MainActor.run {
                    currentPuzzle = puzzle
                    showingSaveDialog = false
                    puzzleName = ""
                    services.audioService.playSound("save_success")
                }
            } catch {
                print("[TangramViewModel] Save failed: \(error)")
            }
        }
    }
    
    func deletePuzzle(_ puzzle: TangramPuzzle) {
        Task {
            do {
                try await storage.delete(id: puzzle.id)
                if currentPuzzle?.id == puzzle.id {
                    loadFirstPuzzle()
                }
            } catch {
                print("[TangramViewModel] Delete failed: \(error)")
            }
        }
    }
    
    func getAllPuzzles() -> [TangramPuzzle] {
        // Note: This is a synchronous wrapper - ideally should be async
        // For now, return cached puzzles or empty array
        var puzzles: [TangramPuzzle] = []
        Task {
            do {
                puzzles = try await storage.loadAll()
            } catch {
                print("[TangramViewModel] Failed to get puzzles: \(error)")
            }
        }
        return puzzles
    }
    
    // MARK: - Piece Management
    
    func addPiece(_ shape: TangramShape, at position: CGPoint = .zero) {
        let piece = TangramPiece(
            shape: shape,
            position: position
        )
        if var puzzle = currentPuzzle {
            puzzle.currentState.updatePiece(piece)
            currentPuzzle = puzzle
        }
        selectedPieceId = piece.id
        services.audioService.playSound("piece_add")
        notifySceneUpdate()
        print("[TangramViewModel] Added piece: \(shape) at \(position), total pieces: \(currentState.pieces.count)")
    }
    
    func movePiece(_ id: UUID, to position: CGPoint) {
        guard var piece = currentState.piece(withId: id) else { return }
        
        var finalPosition = position
        if snapToGrid {
            // Snap to 0.1 unit grid as per math spec (not 0.25)
            let gridSize: CGFloat = 0.1
            finalPosition.x = round(finalPosition.x / gridSize) * gridSize
            finalPosition.y = round(finalPosition.y / gridSize) * gridSize
        }
        
        piece.position = finalPosition
        if var puzzle = currentPuzzle {
            puzzle.currentState.updatePiece(piece)
            currentPuzzle = puzzle
        }
        notifySceneUpdate()
    }
    
    func rotatePiece(_ id: UUID) {
        guard var piece = currentState.piece(withId: id) else { return }
        
        // Rotate by 45 degrees
        let newRotation = piece.rotation + Double.pi / 4
        piece.rotation = newRotation.truncatingRemainder(dividingBy: 2 * Double.pi)
        
        if var puzzle = currentPuzzle {
            puzzle.currentState.updatePiece(piece)
            currentPuzzle = puzzle
        }
        services.audioService.playSound("piece_rotate")
        notifySceneUpdate()
    }
    
    func flipPiece(_ id: UUID) {
        guard var piece = currentState.piece(withId: id) else { return }
        
        piece.isFlipped.toggle()
        if var puzzle = currentPuzzle {
            puzzle.currentState.updatePiece(piece)
            currentPuzzle = puzzle
        }
        services.audioService.playSound("piece_flip")
        notifySceneUpdate()
    }
    
    func deletePiece(_ id: UUID) {
        if var puzzle = currentPuzzle {
            puzzle.currentState.removePiece(withId: id)
            currentPuzzle = puzzle
        }
        if selectedPieceId == id {
            selectedPieceId = nil
        }
        services.audioService.playSound("piece_delete")
        notifySceneUpdate()
    }
    
    func selectPiece(_ id: UUID?) {
        selectedPieceId = id
        if id != nil {
            services.audioService.playSound("piece_select")
        }
        notifySceneUpdate()
    }
    
    func clearAll() {
        if var puzzle = currentPuzzle {
            puzzle.currentState = TangramState()
            currentPuzzle = puzzle
        }
        selectedPieceId = nil
        isComplete = false
        notifySceneUpdate()
    }
    
    // MARK: - GameActionHandler Override
    
    override func handleMove(from: CGPoint, to: CGPoint, source: InputSource) {
        super.handleMove(from: from, to: to, source: source)
        
        // Move selected piece if any
        if let selectedId = selectedPieceId {
            movePiece(selectedId, to: to)
        }
    }
    
    override func handleSelection(at point: CGPoint, source: InputSource) {
        super.handleSelection(at: point, source: source)
        // Selection is handled by the scene finding the piece
    }
    
    // MARK: - Game Logic
    
    func checkSolution() {
        guard let puzzle = currentPuzzle,
              editorMode == nil else { return }
        
        if puzzle.checkSolution(currentState) {
            if !isComplete {
                isComplete = true
                services.audioService.playSound("puzzle_complete")
            }
        } else {
            isComplete = false
        }
    }
    
    func resetToInitial() {
        guard var puzzle = currentPuzzle else { return }
        puzzle.currentState = puzzle.initialState
        currentPuzzle = puzzle
        isComplete = false
        selectedPieceId = nil
    }
    
    // MARK: - Editor Mode Management
    
    func switchEditorMode(_ mode: EditorMode?) {
        editorMode = mode
        
        guard var puzzle = currentPuzzle else { return }
        
        switch mode {
        case .initial:
            puzzle.currentState = puzzle.initialState
            showGrid = true
            showTargetOverlay = true
        case .target:
            puzzle.currentState = puzzle.targetState
            showGrid = true
            showTargetOverlay = false
        case .testing:
            puzzle.currentState = puzzle.initialState
            showGrid = false
            showTargetOverlay = false
        case nil:
            puzzle.currentState = puzzle.initialState
            showGrid = false
            showTargetOverlay = false
        }
        
        currentPuzzle = puzzle
        notifySceneUpdate()
    }
    
    func toggleTargetOverlay() {
        showTargetOverlay.toggle()
        notifySceneUpdate()
    }
    
    // MARK: - Piece Palette (for editor)
    
    func addAllRemainingPieces() {
        print("[TangramViewModel] Adding all remaining pieces. Available: \(availableShapes)")
        
        let positions: [TangramShape: CGPoint] = [
            .largeTriangle1: CGPoint(x: -3, y: -3),
            .largeTriangle2: CGPoint(x: 0, y: -3),
            .mediumTriangle: CGPoint(x: 3, y: -3),
            .smallTriangle1: CGPoint(x: -3, y: 0),
            .smallTriangle2: CGPoint(x: -1, y: 0),
            .square: CGPoint(x: 1, y: 0),
            .parallelogram: CGPoint(x: 3, y: 0)
        ]
        
        for shape in TangramShape.allCases {
            if !currentState.pieces.contains(where: { $0.shape == shape }) {
                let position = positions[shape] ?? CGPoint(x: 0, y: -3)
                addPiece(shape, at: position)
            }
        }
        
        print("[TangramViewModel] After adding all, total pieces: \(currentState.pieces.count)")
    }
}