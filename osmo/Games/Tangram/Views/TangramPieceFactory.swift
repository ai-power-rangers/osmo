import SpriteKit
import CoreGraphics

/// Factory for creating Tangram pieces as SKShapeNodes
final class TangramPieceFactory {
    
    // MARK: - Path Creation
    
    /// Convert shape vertices to CGPath
    static func createPath(for shape: TangramShape) -> CGPath {
        let path = CGMutablePath()
        guard let vertices = TangramShapeData.shapes[shape] else { return path }
        
        if vertices.isEmpty { return path }
        
        path.move(to: vertices[0])
        for index in 1..<vertices.count {
            path.addLine(to: vertices[index])
        }
        path.closeSubpath()
        
        return path
    }
    
    /// Create path from pieceId string
    static func createPath(for pieceId: String) -> CGPath? {
        guard let shape = TangramShape(rawValue: pieceId) else { return nil }
        return createPath(for: shape)
    }
    
    // MARK: - Piece Creation
    
    /// Create a game piece as SKShapeNode
    static func createPiece(shape: TangramShape, scale: CGFloat) -> SKShapeNode {
        let path = createPath(for: shape)
        
        // Scale path to screen units
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledPath = path.copy(using: &transform) ?? path
        
        let piece = SKShapeNode(path: scaledPath)
        piece.name = shape.rawValue
        
        // Visual properties
        piece.fillColor = TangramShapeData.colors[shape] ?? .gray
        piece.strokeColor = .black
        piece.lineWidth = 2.0
        piece.lineCap = .round
        piece.lineJoin = .round
        
        // Physics properties (for touch detection)
        piece.isUserInteractionEnabled = false  // Handle at scene level
        
        // Add subtle shadow for depth
        // Note: SKShapeNode doesn't support shadow masks
        
        return piece
    }
    
    /// Create a target outline for placement
    static func createTargetOutline(for pieceDef: PieceDefinition, screenUnit: CGFloat) -> SKShapeNode? {
        guard let path = createPath(for: pieceDef.pieceId) else { return nil }
        
        // Scale path to screen units
        var transform = CGAffineTransform(scaleX: screenUnit, y: screenUnit)
        let scaledPath = path.copy(using: &transform) ?? path
        
        let outline = SKShapeNode(path: scaledPath)
        outline.fillColor = .clear
        outline.strokeColor = SKColor.white.withAlphaComponent(0.2)
        outline.lineWidth = 2.0
        outline.lineCap = .round
        outline.lineJoin = .round
        outline.isUserInteractionEnabled = false
        outline.zPosition = -1  // Behind pieces
        
        return outline
    }
}

// MARK: - Tangram Piece Node

/// Custom SKNode for Tangram pieces with drag support
class TangramPiece: SKNode {
    let pieceId: String
    let shapeNode: SKShapeNode
    var originalPosition: CGPoint = .zero
    var isLocked: Bool = false
    var isMirrored: Bool = false
    
    init(pieceId: String, scale: CGFloat) {
        self.pieceId = pieceId
        
        // Find corresponding enum case for factory
        guard let shape = TangramShape(rawValue: pieceId) else {
            fatalError("Unknown piece: \(pieceId)")
        }
        
        // Create shape node
        self.shapeNode = TangramPieceFactory.createPiece(shape: shape, scale: scale)
        
        super.init()
        
        // Add shape as child
        addChild(shapeNode)
        self.name = pieceId
        
        // Enable user interaction will be handled at scene level
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Mirror the parallelogram
    func setMirrored(_ mirrored: Bool) {
        guard pieceId == "parallelogram", mirrored != isMirrored else { return }
        
        isMirrored = mirrored
        xScale = mirrored ? -1 : 1
    }
    
    /// Lock piece in place when correctly positioned
    func lock() {
        isLocked = true
        isUserInteractionEnabled = false
        
        // Visual feedback
        run(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ]))
    }
}

// MARK: - Coordinate System Helper

class CoordinateSystem {
    let screenSize: CGSize
    let margin: CGFloat = 20
    
    init(screenSize: CGSize) {
        self.screenSize = screenSize
    }
    
    /// Points per unit (computed to fit screen)
    var screenUnit: CGFloat {
        let availableSize = min(screenSize.width, screenSize.height) - (margin * 2)
        return availableSize / GridConstants.playAreaSize
    }
    
    /// Convert unit coordinates (0-8) to screen coordinates
    /// Origin (4,4) in unit space maps to (0,0) in screen space
    func toScreen(_ unitPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: (unitPoint.x - 4) * screenUnit,
            y: (unitPoint.y - 4) * screenUnit
        )
    }
    
    /// Convert SIMD2 unit coordinates to screen coordinates
    func toScreen(_ unitPoint: SIMD2<Double>) -> CGPoint {
        return toScreen(CGPoint(x: CGFloat(unitPoint.x), y: CGFloat(unitPoint.y)))
    }
    
    /// Convert screen coordinates to unit coordinates
    func toUnit(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: screenPoint.x / screenUnit + 4,
            y: screenPoint.y / screenUnit + 4
        )
    }
}

// MARK: - Grid Extensions

extension CGPoint {
    /// Snap to nearest grid point (0.1 resolution)
    func snappedToGrid() -> CGPoint {
        CGPoint(
            x: round(x / GridConstants.resolution) * GridConstants.resolution,
            y: round(y / GridConstants.resolution) * GridConstants.resolution
        )
    }
    
    /// Check if within snap tolerance of target
    func isNear(_ target: CGPoint, tolerance: CGFloat) -> Bool {
        let distance = hypot(x - target.x, y - target.y)
        return distance < tolerance
    }
}

extension CGFloat {
    /// Snap rotation to nearest 45°
    func snappedRotation() -> CGFloat {
        let increment = GridConstants.rotationIncrement
        return Darwin.round(self / increment) * increment
    }
}