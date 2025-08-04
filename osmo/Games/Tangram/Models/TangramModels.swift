import Foundation
import simd
import SpriteKit

// MARK: - Shape Types
public enum TangramShape: String, Codable, CaseIterable {
    case largeTriangle1, largeTriangle2
    case mediumTriangle  // No suffix - matches "mediumTriangle" in JSON
    case smallTriangle1, smallTriangle2
    case square         // No suffix - matches "square" in JSON
    case parallelogram  // No suffix - matches "parallelogram" in JSON
}

// MARK: - Piece Definition
public struct PieceDefinition: Codable {
    public let pieceId: String  // String to match JSON exactly
    public let targetPosition: SIMD2<Double>   // Unit grid 0-8, using SIMD for performance
    public let targetRotation: Double          // Radians, multiples of π/4
    public let isMirrored: Bool?               // Only for parallelogram
    
    // Custom decoding to handle x,y structure from JSON
    private enum CodingKeys: String, CodingKey {
        case pieceId, targetRotation, isMirrored
        case targetPosition
    }
    
    private struct Position: Codable {
        let x: Double
        let y: Double
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pieceId = try container.decode(String.self, forKey: .pieceId)
        let pos = try container.decode(Position.self, forKey: .targetPosition)
        targetPosition = SIMD2<Double>(pos.x, pos.y)
        targetRotation = try container.decode(Double.self, forKey: .targetRotation)
        isMirrored = try container.decodeIfPresent(Bool.self, forKey: .isMirrored)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pieceId, forKey: .pieceId)
        let pos = Position(x: targetPosition.x, y: targetPosition.y)
        try container.encode(pos, forKey: .targetPosition)
        try container.encode(targetRotation, forKey: .targetRotation)
        try container.encodeIfPresent(isMirrored, forKey: .isMirrored)
    }
}

// MARK: - Puzzle Model
public struct Puzzle: Codable, Identifiable {
    public let id: String
    public let name: String
    public let imageName: String
    public let pieces: [PieceDefinition]
    
    // Optional fields that might be in JSON
    public let difficulty: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, imageName, pieces, difficulty
    }
    
    public init(id: String, name: String, imageName: String, pieces: [PieceDefinition], difficulty: String? = nil) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.pieces = pieces
        self.difficulty = difficulty
    }
}

// MARK: - Game State
struct TangramGameState {
    var puzzle: Puzzle
    var placedPieces: Set<String> = []  // pieceIds that have been correctly placed
    var elapsedTime: TimeInterval = 0
    var isComplete: Bool {
        placedPieces.count == puzzle.pieces.count
    }
    
    mutating func placePiece(_ pieceId: String) {
        placedPieces.insert(pieceId)
    }
    
    mutating func reset() {
        placedPieces.removeAll()
        elapsedTime = 0
    }
}

// MARK: - Mathematical Constants
extension CGFloat {
    static let sqrt2: CGFloat = 1.4142135623730951
}

// MARK: - Grid System Constants
struct TangramGridConstants {
    static let resolution: CGFloat = 0.1
    static let playAreaSize: CGFloat = 8.0
    
    // Auto-scaling snap tolerance
    static func snapTolerance(for screenUnit: CGFloat) -> CGFloat {
        return max(0.2, 0.0375 * screenUnit)
    }
    
    static let rotationIncrement: CGFloat = .pi / 4  // 45°
    static let visualRotationIncrement: CGFloat = .pi / 16  // 11.25° for smooth feedback
}

// MARK: - Shape Vertices
public struct TangramShapeData {
    // All vertices start at origin (0,0) bottom-left
    public static let shapes: [TangramShape: [CGPoint]] = [
        // Small Triangles (1×1 right triangles)
        .smallTriangle1: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ],
        .smallTriangle2: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ],
        
        // Square (1×1)
        .square: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ],
        
        // Medium Triangle (√2×√2 right triangle)
        .mediumTriangle: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: .sqrt2, y: 0),
            CGPoint(x: 0, y: .sqrt2)
        ],
        
        // Large Triangles (2×2 right triangles)
        .largeTriangle1: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ],
        .largeTriangle2: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ],
        
        // Parallelogram (base 2, height 1)
        .parallelogram: [
            CGPoint(x: 0, y: 0),     // Bottom-left anchor
            CGPoint(x: 2, y: 0),
            CGPoint(x: 3, y: 1),
            CGPoint(x: 1, y: 1)
        ]
    ]
    
    // Piece colors from spec
    public static let colors: [TangramShape: SKColor] = [
        .largeTriangle1: .systemBlue,
        .largeTriangle2: .systemRed,
        .mediumTriangle: .systemGreen,
        .smallTriangle1: .systemCyan,
        .smallTriangle2: .systemPink,
        .square: .systemYellow,
        .parallelogram: .systemOrange
    ]
}