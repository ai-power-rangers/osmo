import Foundation
import CoreGraphics

/// Represents a placed element in the grid
public struct PlacedElement: Codable, Identifiable {
    public let id: String
    public let elementId: String           // Unique identifier for this instance
    public let elementType: String         // References canonical geometry (e.g., "largeTriangle1")
    public let rotationIndex: Int          // Discrete rotation (0-7 for 45° steps)
    public let mirrored: Bool              // Whether the shape is mirrored
    public let position: CGPoint           // Unit space (Tangram units), authoring/preview only
                                          // Runtime validation ignores absolute positions
    
    public init(id: String? = nil, elementId: String, elementType: String, rotationIndex: Int, mirrored: Bool, position: CGPoint) {
        self.id = id ?? UUID().uuidString
        self.elementId = elementId
        self.elementType = elementType
        self.rotationIndex = rotationIndex
        self.mirrored = mirrored
        self.position = position
    }
}

/// Edge orientation for edge-to-edge constraints
public enum EdgeOrientation: String, Codable {
    case sameDirection
    case oppositeDirection
}

/// Types of geometric constraints
public enum ConstraintKind: String, Codable {
    case cornerToCorner
    case edgeToEdge
}

/// Represents a geometric constraint between two pieces
public struct RelationConstraint: Codable, Identifiable {
    public let id: String
    public let pieceA: String              // elementId of first piece
    public let pieceB: String              // elementId of second piece
    public let kind: ConstraintKind
    public let featureA: String            // Feature ID on piece A (corner or edge)
    public let featureB: String            // Feature ID on piece B
    public let edgeOrientation: EdgeOrientation?  // For edge constraints
    public let gap: Double?                // >= 0 for spacing; nil for coincidence
    public let mirrorAware: Bool           // Whether constraint handles mirroring (default true)
    public let rotationIndexDelta: Int?    // Optional relative discrete rotation
    public let overlapRatioMin: Double?    // For edge-to-edge (1.0=full, 0.5=half); nil=endpoints
    
    public init(id: String = UUID().uuidString,
                pieceA: String,
                pieceB: String,
                kind: ConstraintKind,
                featureA: String,
                featureB: String,
                edgeOrientation: EdgeOrientation? = nil,
                gap: Double? = nil,
                mirrorAware: Bool = true,
                rotationIndexDelta: Int? = nil,
                overlapRatioMin: Double? = nil) {
        self.id = id
        self.pieceA = pieceA
        self.pieceB = pieceB
        self.kind = kind
        self.featureA = featureA
        self.featureB = featureB
        self.edgeOrientation = edgeOrientation
        self.gap = gap
        self.mirrorAware = mirrorAware
        self.rotationIndexDelta = rotationIndexDelta
        self.overlapRatioMin = overlapRatioMin
    }
}

/// Tolerance settings for validation
public struct Tolerances: Codable {
    public let positionTolerance: Double   // Unit-space distance
    public let angleTolerance: Double      // Degrees
    public let edgeAlignment: Double       // Max deviation for collinearity
    
    public init(positionTolerance: Double = 0.1,
                angleTolerance: Double = 0.5,
                edgeAlignment: Double = 0.1) {
        self.positionTolerance = positionTolerance
        self.angleTolerance = angleTolerance
        self.edgeAlignment = edgeAlignment
    }
}

/// Puzzle mode determines validation approach
public enum PuzzleMode: String, Codable {
    case freeform   // SE(2) invariant (e.g., Tangram)
    case lattice    // Grid-indexed (e.g., Sudoku)
}

/// Metadata about the arrangement
public struct ArrangementMetadata: Codable {
    public let mode: PuzzleMode
    public let rotationStep: Int?          // 8 for 45°, 4 for 90°, nil for continuous
    public let allowedGlobalRotations: [Int]  // Which rotations validate as correct
    public let allowGlobalMirror: Bool
    public let tolerances: Tolerances
    public let difficulty: String?
    public let author: String?
    public let tags: [String]
    
    public init(mode: PuzzleMode = .freeform,
                rotationStep: Int? = 8,
                allowedGlobalRotations: [Int] = Array(0..<8),
                allowGlobalMirror: Bool = false,
                tolerances: Tolerances = Tolerances(),
                difficulty: String? = nil,
                author: String? = nil,
                tags: [String] = []) {
        self.mode = mode
        self.rotationStep = rotationStep
        self.allowedGlobalRotations = allowedGlobalRotations
        self.allowGlobalMirror = allowGlobalMirror
        self.tolerances = tolerances
        self.difficulty = difficulty
        self.author = author
        self.tags = tags
    }
}

/// Complete arrangement with pieces, constraints, and metadata
public struct GridArrangement: Codable, Identifiable {
    public let id: String
    public let gameType: GameType
    public let name: String
    public let elements: [PlacedElement]       // Authoring poses for preview
    public let constraints: [RelationConstraint]  // Graph of geometric relations
    public let metadata: ArrangementMetadata
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String = UUID().uuidString,
                gameType: GameType,
                name: String,
                elements: [PlacedElement],
                constraints: [RelationConstraint],
                metadata: ArrangementMetadata,
                createdAt: Date = Date(),
                updatedAt: Date = Date()) {
        self.id = id
        self.gameType = gameType
        self.name = name
        self.elements = elements
        self.constraints = constraints
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}