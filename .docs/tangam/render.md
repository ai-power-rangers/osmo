import SpriteKit
import SwiftUI

// MARK: - Shape Definitions
extension CGFloat {
    static let sqrt2: CGFloat = 1.4142135623730951
    
    // Snap rotation to nearest 45°
    func snappedRotation() -> CGFloat {
        let increment: CGFloat = .pi / 4
        return round(self / increment) * increment
    }
}

extension CGPoint {
    // Check if within tolerance of target (no default - must specify tolerance)
    func isNear(_ target: CGPoint, tolerance: CGFloat) -> Bool {
        let distance = hypot(x - target.x, y - target.y)
        return distance < tolerance
    }
}

struct TangramShapeData {
    let vertices: [CGPoint]
    let color: UIColor
    
    // IMPORTANT: All shapes use (0,0) as bottom-left anchor.
    // All targetPositions in JSON blueprints are measured from this anchor.
    // Define all tangram shapes with unit coordinates
    static let shapes: [String: TangramShapeData] = [
        "smallTriangle1": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 0, y: 1)
            ],
            color: .systemCyan
        ),
        "smallTriangle2": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 0, y: 1)
            ],
            color: .systemPink
        ),
        "square": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 1, y: 1),
                CGPoint(x: 0, y: 1)
            ],
            color: .systemYellow
        ),
        "mediumTriangle": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: .sqrt2, y: 0),    // Always use .sqrt2, never hardcode
                CGPoint(x: 0, y: .sqrt2)
            ],
            color: .systemGreen
        ),
        "largeTriangle1": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 2, y: 0),
                CGPoint(x: 0, y: 2)
            ],
            color: .systemBlue
        ),
        "largeTriangle2": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 2, y: 0),
                CGPoint(x: 0, y: 2)
            ],
            color: .systemRed
        ),
        "parallelogram": TangramShapeData(
            vertices: [
                CGPoint(x: 0, y: 0),     // Bottom-left anchor (ALL positions measured from here)
                CGPoint(x: 2, y: 0),
                CGPoint(x: 3, y: 1),
                CGPoint(x: 1, y: 1)
            ],
            color: .systemOrange
        )
    ]
}

// MARK: - Tangram Piece Node
class TangramPiece: SKNode {
    let pieceId: String
    let shapeNode: SKShapeNode
    let outlineNode: SKShapeNode
    private var originalPath: CGPath
    var isMirrored: Bool = false
    var isPlaced: Bool = false
    
    init(pieceId: String, screenUnit: CGFloat) {
        self.pieceId = pieceId
        
        guard let shapeData = TangramShapeData.shapes[pieceId] else {
            fatalError("Unknown piece: \(pieceId)")
        }
        
        // Create the path from vertices
        self.originalPath = TangramPiece.createPath(from: shapeData.vertices, scale: screenUnit)
        
        // Create filled shape
        self.shapeNode = SKShapeNode(path: originalPath)
        shapeNode.fillColor = shapeData.color
        shapeNode.strokeColor = .black
        shapeNode.lineWidth = 2.0
        
        // Create outline (for target position)
        self.outlineNode = SKShapeNode(path: originalPath)
        outlineNode.fillColor = .clear
        outlineNode.strokeColor = .white.withAlphaComponent(0.3)
        outlineNode.lineWidth = 3.0
        outlineNode.lineCap = .round
        outlineNode.lineJoin = .round
        
        super.init()
        
        // Add shape as child
        addChild(shapeNode)
        
        // Enable user interaction
        isUserInteractionEnabled = true
        
        // Create physics body for accurate touch detection
        let physicsBody = SKPhysicsBody(polygonFrom: originalPath)
        physicsBody.isDynamic = false
        physicsBody.categoryBitMask = 0
        // Enable usesPreciseCollisionDetection if adding fast drag gestures
        self.physicsBody = physicsBody
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Create CGPath from vertices
    static func createPath(from vertices: [CGPoint], scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        guard !vertices.isEmpty else { return path }
        
        // Scale vertices and create path
        let scaledVertices = vertices.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        
        path.move(to: scaledVertices[0])
        for vertex in scaledVertices.dropFirst() {
            path.addLine(to: vertex)
        }
        path.closeSubpath()
        
        // IMPORTANT: Keep (0,0) as bottom-left anchor - do NOT recenter on centroid
        // This ensures pieces align with their targetPosition values
        return path
    }
    
    // Mirror the parallelogram
    func setMirrored(_ mirrored: Bool) {
        guard pieceId == "parallelogram", mirrored != isMirrored else { return }
        
        isMirrored = mirrored
        xScale = mirrored ? -1 : 1
        // For future: If adding y-mirroring, store scaleX/scaleY in JSON instead of boolean
    }
}

// MARK: - Game Scene
class TangramGameScene: SKScene {
    // COORDINATE SYSTEM:
    // - Unit space: 8×8 grid with (4,4) at center
    // - Shape anchors: (0,0) at bottom-left corner of each shape
    // - Screen space: SpriteKit coordinates with (0,0) at scene center
    // - Grid: 0.1 unit resolution = 81×81 possible positions
    
    var screenUnit: CGFloat = 50
    var pieces: [TangramPiece] = []
    var targetOutlines: [SKShapeNode] = []
    var selectedPiece: TangramPiece?
    var puzzle: Puzzle!
    
    // Grid constants
    let gridResolution: CGFloat = 0.1  // Could halve to 0.05 for tiny screens
    let rotationSnapAngle: CGFloat = .pi / 4  // 45° final snap
    
    // Cached auto-scaling snap tolerance
    lazy var snapTolerance: CGFloat = max(0.2, 0.0375 * screenUnit)
    
    override func didMove(to view: SKView) {
        backgroundColor = .systemBackground
        
        // Calculate screen unit
        let margin: CGFloat = 40
        let availableSize = min(size.width, size.height) - margin * 2
        screenUnit = availableSize / 8.0
        
        setupPuzzle()
        setupPieces()
    }
    
    func setupPuzzle() {
        // Create target outlines for each piece
        for pieceDef in puzzle.pieces {
            guard let shapeData = TangramShapeData.shapes[pieceDef.pieceId] else { continue }
            
            // Create outline at target position
            let path = TangramPiece.createPath(from: shapeData.vertices, scale: screenUnit)
            let outline = SKShapeNode(path: path)
            outline.fillColor = .clear
            outline.strokeColor = .white.withAlphaComponent(0.2)
            outline.lineWidth = 2.0
            outline.lineCap = .round
            outline.lineJoin = .round
            
            // Position and rotate
            outline.position = unitToScreen(CGPoint(x: pieceDef.targetPosition.x, 
                                                   y: pieceDef.targetPosition.y))
            outline.zRotation = CGFloat(pieceDef.targetRotation)
            
            // Note: Shape paths are NOT centered - they use bottom-left anchor
            // This ensures targetPosition values align correctly
            
            // Mirror if needed
            if pieceDef.isMirrored == true {
                outline.xScale = -1
            }
            
            addChild(outline)
            targetOutlines.append(outline)
        }
    }
    
    func setupPieces() {
        // Create draggable pieces
        let startY = -size.height / 2 + screenUnit
        var currentX = -size.width / 2 + screenUnit
        
        for pieceDef in puzzle.pieces {
            let piece = TangramPiece(pieceId: pieceDef.pieceId, screenUnit: screenUnit)
            
            // Random starting position at bottom
            piece.position = CGPoint(x: currentX, y: startY)
            piece.zRotation = 0
            piece.zPosition = 1
            
            // Apply initial mirroring state to match target (optional)
            piece.setMirrored(pieceDef.isMirrored ?? false)
            
            pieces.append(piece)
            addChild(piece)
            
            currentX += screenUnit * 1.5
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Find piece at touch location
        let nodes = self.nodes(at: location)
        for node in nodes {
            if let piece = node.parent as? TangramPiece, !piece.isPlaced {
                selectedPiece = piece
                piece.zPosition = 10
                
                // Visual feedback
                piece.run(SKAction.scale(to: 1.1, duration: 0.1))
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let piece = selectedPiece else { return }
        
        // Move piece with finger
        piece.position = touch.location(in: self)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let piece = selectedPiece else { return }
        
        // Reset scale
        piece.run(SKAction.scale(to: 1.0, duration: 0.1))
        piece.zPosition = 1
        
        // Snap to grid
        let unitPos = screenToUnit(piece.position)
        let snappedPos = snapToGrid(unitPos)
        piece.position = unitToScreen(snappedPos)
        
        // Check if placement is correct
        checkPlacement(piece)
        
        selectedPiece = nil
    }
    
    // MARK: - Rotation
    func rotatePiece(_ piece: TangramPiece) {
        let newRotation = (piece.zRotation + rotationSnapAngle).snappedRotation()
        piece.run(SKAction.rotate(toAngle: newRotation, duration: 0.15))
        
        // Check placement after rotation
        checkPlacement(piece)
    }
    
    // MARK: - Placement Validation
    func checkPlacement(_ piece: TangramPiece) {
        guard let targetPiece = puzzle.pieces.first(where: { $0.pieceId == piece.pieceId }) else {
            return
        }
        
        let targetPos = CGPoint(x: targetPiece.targetPosition.x, y: targetPiece.targetPosition.y)
        let currentPos = screenToUnit(piece.position)
        
        // Check position (using auto-scaled tolerance)
        let positionCorrect = currentPos.isNear(targetPos, tolerance: snapTolerance)
        
        // Check rotation (both values are snapped to π/4, so direct equality works)
        let targetRot = CGFloat(targetPiece.targetRotation)
        let snappedRot = piece.zRotation.snappedRotation()
        let rotationCorrect = snappedRot == targetRot
        
        // Check mirroring (for parallelogram)
        let mirrorCorrect = piece.isMirrored == (targetPiece.isMirrored ?? false)
        
        if positionCorrect && rotationCorrect && mirrorCorrect {
            // Snap to exact position
            piece.position = unitToScreen(targetPos)
            piece.zRotation = targetRot
            piece.isPlaced = true
            piece.isUserInteractionEnabled = false
            
            // Success feedback
            let scaleAction = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            piece.run(scaleAction)
            
            // Play sound
            run(SKAction.playSoundFileNamed("snap.wav", waitForCompletion: false))
            
            // Check if puzzle is complete
            checkCompletion()
        }
    }
    
    // MARK: - Helper Functions
    func unitToScreen(_ point: CGPoint) -> CGPoint {
        // Convert from unit coordinates (0-8) to screen coordinates
        // Origin (4,4) in unit space maps to (0,0) in screen space
        return CGPoint(x: (point.x - 4) * screenUnit, y: (point.y - 4) * screenUnit)
    }
    
    func screenToUnit(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x / screenUnit + 4, y: point.y / screenUnit + 4)
    }
    
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: round(point.x / gridResolution) * gridResolution,
            y: round(point.y / gridResolution) * gridResolution
        )
    }
    
    func checkCompletion() {
        if pieces.allSatisfy({ $0.isPlaced }) {
            // Puzzle complete!
            isUserInteractionEnabled = false  // Pause touches during celebration
            
            let confetti = SKEmitterNode(fileNamed: "Confetti")
            confetti?.position = CGPoint(x: 0, y: size.height / 2)
            addChild(confetti!)
            
            run(SKAction.playSoundFileNamed("win.wav", waitForCompletion: false))
            
            // Re-enable touches after celebration (optional)
            run(SKAction.wait(forDuration: 3.0)) {
                self.isUserInteractionEnabled = true
            }
        }
    }
}