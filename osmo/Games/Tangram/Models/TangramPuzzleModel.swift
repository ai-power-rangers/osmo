//
//  TangramPuzzleModel.swift
//  osmo
//
//  Tangram puzzle model following consistent game architecture
//

import Foundation
import CoreGraphics

// MARK: - Tangram Piece

public struct TangramPiece: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let shape: TangramShape
    public var position: CGPoint
    public var rotation: Double  // Radians
    public var isFlipped: Bool
    
    public init(id: UUID = UUID(), 
         shape: TangramShape, 
         position: CGPoint = .zero, 
         rotation: Double = 0, 
         isFlipped: Bool = false) {
        self.id = id
        self.shape = shape
        self.position = position
        self.rotation = rotation
        self.isFlipped = isFlipped
    }
    
    /// Create a copy with new position
    public func moved(to position: CGPoint) -> TangramPiece {
        var copy = self
        copy.position = position
        return copy
    }
    
    /// Create a copy with new rotation
    public func rotated(to rotation: Double) -> TangramPiece {
        var copy = self
        copy.rotation = rotation
        return copy
    }
    
    /// Create a flipped copy
    public func flipped() -> TangramPiece {
        var copy = self
        copy.isFlipped.toggle()
        return copy
    }
}

// MARK: - Tangram State

public struct TangramState: Codable, Equatable, Hashable {
    public var pieces: [TangramPiece]
    
    public init(pieces: [TangramPiece] = []) {
        self.pieces = pieces
    }
    
    /// Check if state contains all standard Tangram pieces
    public var isComplete: Bool {
        let shapes = Set(pieces.map { $0.shape })
        return shapes.count == 7 && shapes.isSubset(of: Set(TangramShape.allCases))
    }
    
    /// Get piece by ID
    public func piece(withId id: UUID) -> TangramPiece? {
        pieces.first { $0.id == id }
    }
    
    /// Update or add a piece
    public mutating func updatePiece(_ piece: TangramPiece) {
        if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
            pieces[index] = piece
        } else {
            pieces.append(piece)
        }
    }
    
    /// Remove a piece
    public mutating func removePiece(withId id: UUID) {
        pieces.removeAll { $0.id == id }
    }
}

// MARK: - Tangram Puzzle

public struct TangramPuzzle: GamePuzzleProtocol, Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var difficulty: PuzzleDifficulty
    public let createdAt: Date
    public var updatedAt: Date
    
    // MARK: - GamePuzzleProtocol Implementation
    
    public typealias PieceType = TangramPiece
    public typealias StateType = TangramState
    
    public var initialState: TangramState
    public var targetState: TangramState
    public var currentState: TangramState
    
    public var pieces: [TangramPiece] {
        get { currentState.pieces }
        set { currentState.pieces = newValue }
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
    
    /// Optional hint image name
    var hintImageName: String?
    
    public init(name: String, difficulty: PuzzleDifficulty) {
        self.id = UUID().uuidString
        self.name = name
        self.difficulty = difficulty
        self.createdAt = Date()
        self.updatedAt = Date()
        self.initialState = TangramState()
        self.targetState = TangramState()
        self.currentState = TangramState()
        self.tags = Set<String>()
        self.author = nil
        self.puzzleDescription = nil
        self.previewImageData = nil
    }
    
    // Custom initializer for creating puzzles with full configuration
    public init(id: String = UUID().uuidString,
         name: String,
         difficulty: PuzzleDifficulty = .medium,
         author: String? = nil,
         tags: Set<String> = [],
         initialState: TangramState = TangramState(),
         targetState: TangramState,
         puzzleDescription: String? = nil) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.author = author
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.initialState = initialState
        self.targetState = targetState
        self.currentState = initialState
        self.puzzleDescription = puzzleDescription
        self.previewImageData = nil
    }
    
    public func validate() -> [String] {
        var errors: [String] = []
        
        // Check target state has all pieces
        if !targetState.isComplete {
            errors.append("Target state must contain all 7 Tangram pieces")
        }
        
        // Check initial state pieces are valid
        for piece in initialState.pieces {
            if !targetState.pieces.contains(where: { $0.shape == piece.shape }) {
                errors.append("Initial piece \(piece.shape) not found in target state")
            }
        }
        
        // Check name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Puzzle name cannot be empty")
        }
        
        return errors
    }
    
    // MARK: - GamePuzzleProtocol Methods
    
    public func isValid() -> Bool {
        return validate().isEmpty
    }
    
    public func isCompleted() -> Bool {
        return checkSolution(currentState)
    }
    
    public mutating func reset() {
        currentState = initialState
        touch()
    }
    
    public func copy() -> TangramPuzzle {
        return self // Struct copy semantics
    }
    
    /// Check if current state matches target (with tolerance)
    public func checkSolution(_ currentState: TangramState, tolerance: CGFloat = 0.2) -> Bool {
        // Must have same number of pieces
        guard currentState.pieces.count == targetState.pieces.count else {
            return false
        }
        
        // Check each target piece has a matching current piece
        for targetPiece in targetState.pieces {
            let hasMatch = currentState.pieces.contains { currentPiece in
                currentPiece.shape == targetPiece.shape &&
                abs(currentPiece.position.x - targetPiece.position.x) < tolerance &&
                abs(currentPiece.position.y - targetPiece.position.y) < tolerance &&
                abs(currentPiece.rotation - targetPiece.rotation) < 0.1 &&
                currentPiece.isFlipped == targetPiece.isFlipped
            }
            
            if !hasMatch {
                return false
            }
        }
        
        return true
    }
    
    // Hashable conformance
    public static func == (lhs: TangramPuzzle, rhs: TangramPuzzle) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Create an empty puzzle for editing
    public static func empty() -> TangramPuzzle {
        TangramPuzzle(
            name: "New Puzzle",
            initialState: TangramState(),
            targetState: TangramState()
        )
    }
}

// MARK: - Tangram Storage

class TangramPuzzleStorage: BasePuzzleStorage {
    static let shared = TangramPuzzleStorage()
    
    private init() {
        do {
            try super.init(
                configuration: PuzzleStorageConfiguration()
            )
            // Create Documents/TangramPuzzles directory structure
            createGameDirectoryIfNeeded()
            createDefaultPuzzlesIfNeeded()
        } catch {
            fatalError("Failed to initialize TangramPuzzleStorage: \(error)")
        }
    }
    
    private func createGameDirectoryIfNeeded() {
        // BasePuzzleStorage will handle directory creation
    }
    
    // Synchronous wrapper for SwiftUI views that need immediate data
    func loadAll() -> [TangramPuzzle] {
        // This is a synchronous wrapper that returns cached puzzles
        // In production, you'd want to handle this with async/await properly
        var puzzles: [TangramPuzzle] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                let loadedPuzzles: [TangramPuzzle] = try await super.loadAll()
                puzzles = loadedPuzzles
            } catch {
                print("Failed to load puzzles synchronously: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return puzzles
    }
    
    private func createDefaultPuzzlesIfNeeded() {
        // Check if we have any puzzles
        Task {
            do {
                let puzzles: [TangramPuzzle] = try await loadAll()
                if puzzles.isEmpty {
                    await createDefaultPuzzles()
                }
            } catch {
                print("Failed to check existing puzzles: \(error)")
            }
        }
    }
    
    private func createDefaultPuzzles() async {
        // Simple square puzzle
        let squarePuzzle = TangramPuzzle(
            id: "default_square",
            name: "Perfect Square",
            difficulty: .easy,
            author: "System",
            tags: Set(["shapes", "beginner"]),
            initialState: TangramState(pieces: [
                // Start with one piece placed as a hint
                TangramPiece(shape: .square, position: CGPoint(x: 0, y: 0), rotation: 0)
            ]),
            targetState: TangramState(pieces: [
                TangramPiece(shape: .largeTriangle1, position: CGPoint(x: -1, y: 1), rotation: 0),
                TangramPiece(shape: .largeTriangle2, position: CGPoint(x: 1, y: 1), rotation: .pi/2),
                TangramPiece(shape: .mediumTriangle, position: CGPoint(x: 0, y: -1), rotation: .pi),
                TangramPiece(shape: .smallTriangle1, position: CGPoint(x: -1, y: -1), rotation: -.pi/2),
                TangramPiece(shape: .smallTriangle2, position: CGPoint(x: 1, y: -1), rotation: .pi/2),
                TangramPiece(shape: .square, position: CGPoint(x: 0, y: 0), rotation: 0),
                TangramPiece(shape: .parallelogram, position: CGPoint(x: 0, y: 1), rotation: 0)
            ])
        )
        
        // House puzzle
        let housePuzzle = TangramPuzzle(
            id: "default_house",
            name: "Little House",
            difficulty: .medium,
            author: "System",
            tags: Set(["objects", "buildings"]),
            initialState: TangramState(), // No initial pieces
            targetState: TangramState(pieces: [
                TangramPiece(shape: .largeTriangle1, position: CGPoint(x: -1, y: 2), rotation: 0),
                TangramPiece(shape: .largeTriangle2, position: CGPoint(x: 1, y: 2), rotation: 0),
                TangramPiece(shape: .square, position: CGPoint(x: 0, y: 0), rotation: 0),
                TangramPiece(shape: .mediumTriangle, position: CGPoint(x: 0, y: -2), rotation: .pi),
                TangramPiece(shape: .smallTriangle1, position: CGPoint(x: -2, y: 0), rotation: -.pi/2),
                TangramPiece(shape: .smallTriangle2, position: CGPoint(x: 2, y: 0), rotation: .pi/2),
                TangramPiece(shape: .parallelogram, position: CGPoint(x: 0, y: 3), rotation: 0)
            ])
        )
        
        // Save default puzzles
        do {
            try await save(squarePuzzle)
            try await save(housePuzzle)
        } catch {
            print("Failed to save default puzzles: \(error)")
        }
    }
}