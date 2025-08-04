//
//  SimpleTangramScene.swift
//  osmo
//
//  Simplified Tangram scene with no dependencies
//

import SpriteKit

class TangramScene: SKScene {
    // Data passed in, not injected
    private let puzzle: TangramPuzzle
    private let onPieceMove: () -> Void
    private let onComplete: () -> Void
    
    // Local state management
    private var pieces: [TangramPieceNode] = []
    private var targetShape: SKShapeNode?
    private var selectedPiece: TangramPieceNode?
    private var initialTouch: CGPoint = .zero
    
    // Grid for alignment
    private let gridSize: CGFloat = 30
    
    init(size: CGSize, puzzle: TangramPuzzle,
         onPieceMove: @escaping () -> Void,
         onComplete: @escaping () -> Void) {
        self.puzzle = puzzle
        self.onPieceMove = onPieceMove
        self.onComplete = onComplete
        super.init(size: size)
        
        scaleMode = .aspectFill
        backgroundColor = .systemBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented - use init(size:puzzle:)")
    }
    
    override func didMove(to view: SKView) {
        setupPuzzle()
    }
    
    private func setupPuzzle() {
        // Add grid background
        addGrid()
        
        // Create target shape
        if let target = createTargetShape() {
            targetShape = target
            target.position = CGPoint(x: size.width * 0.5, y: size.height * 0.6)
            addChild(target)
        }
        
        // Create draggable pieces
        for (index, pieceData) in puzzle.pieces.enumerated() {
            let piece = TangramPieceNode(pieceData: pieceData, index: index)
            piece.position = randomStartPosition(index: index)
            pieces.append(piece)
            addChild(piece)
        }
    }
    
    private func addGrid() {
        let gridNode = SKShapeNode()
        let path = CGMutablePath()
        
        // Vertical lines
        for x in stride(from: 0, through: size.width, by: gridSize) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: size.height, by: gridSize) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        
        gridNode.path = path
        gridNode.strokeColor = .systemGray5
        gridNode.lineWidth = 0.5
        gridNode.zPosition = -10
        addChild(gridNode)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Find piece at touch location
        for piece in pieces.reversed() {
            if piece.contains(location) {
                selectedPiece = piece
                initialTouch = location
                piece.zPosition = 100 // Bring to front
                
                // Visual feedback
                piece.run(SKAction.scale(to: 1.1, duration: 0.1))
                
                // Haptic feedback via GameKit
                GameKit.haptics.selection()
                break
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let piece = selectedPiece else { return }
        
        let location = touch.location(in: self)
        piece.position = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let piece = selectedPiece else { return }
        
        // Snap to grid
        snapToGrid(piece)
        
        // Visual feedback
        piece.run(SKAction.scale(to: 1.0, duration: 0.1))
        
        // Check if puzzle is complete
        if checkSolution() {
            celebrateCompletion()
            onComplete()
        } else {
            onPieceMove()
        }
        
        selectedPiece = nil
    }
    
    // MARK: - Gestures
    
    func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let piece = selectedPiece else { return }
        
        if gesture.state == .changed {
            piece.zRotation = -gesture.rotation
        } else if gesture.state == .ended {
            // Snap to 45-degree angles
            snapRotation(piece)
            GameKit.audio.play(.pieceRotate)
        }
    }
    
    func handleDoubleTap(at location: CGPoint) {
        for piece in pieces {
            if piece.contains(location) {
                // Rotate by 45 degrees
                let rotation = piece.zRotation + (.pi / 4)
                piece.run(SKAction.rotate(toAngle: rotation, duration: 0.2))
                GameKit.audio.play(.pieceRotate)
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func snapToGrid(_ piece: TangramPieceNode) {
        let x = round(piece.position.x / gridSize) * gridSize
        let y = round(piece.position.y / gridSize) * gridSize
        piece.position = CGPoint(x: x, y: y)
    }
    
    private func snapRotation(_ piece: TangramPieceNode) {
        let angleInDegrees = piece.zRotation * 180 / .pi
        let snappedAngle = round(angleInDegrees / 45) * 45
        piece.zRotation = snappedAngle * .pi / 180
    }
    
    private func randomStartPosition(index: Int) -> CGPoint {
        // Position pieces at bottom of screen
        let columns = 5
        let row = index / columns
        let col = index % columns
        
        let x = CGFloat(col) * 80 + 100
        let y = CGFloat(row) * 80 + 100
        
        return CGPoint(x: x, y: y)
    }
    
    private func createTargetShape() -> SKShapeNode? {
        // Create outline of target shape
        let shape = SKShapeNode()
        
        // For now, create a simple square target
        let path = CGMutablePath()
        let size: CGFloat = 200
        path.addRect(CGRect(x: -size/2, y: -size/2, width: size, height: size))
        
        shape.path = path
        shape.strokeColor = .systemGray3
        shape.lineWidth = 2
        shape.fillColor = .clear
        shape.zPosition = 1
        
        return shape
    }
    
    private func checkSolution() -> Bool {
        // Simplified solution checking
        // In a real app, would check if pieces match target positions
        
        // For demo: check if all pieces are near center
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.6)
        let threshold: CGFloat = 250
        
        for piece in pieces {
            let distance = hypot(piece.position.x - center.x, piece.position.y - center.y)
            if distance > threshold {
                return false
            }
        }
        
        return true
    }
    
    private func celebrateCompletion() {
        // Visual celebration
        for piece in pieces {
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.2)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
            let sequence = SKAction.sequence([scaleUp, scaleDown])
            piece.run(sequence)
        }
        
        // Particle effect
        if let stars = SKEmitterNode(fileNamed: "Stars") {
            stars.position = CGPoint(x: size.width * 0.5, y: size.height * 0.6)
            stars.zPosition = 1000
            addChild(stars)
            
            stars.run(SKAction.sequence([
                SKAction.wait(forDuration: 2),
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
    }
}

// MARK: - Tangram Piece Node

class TangramPieceNode: SKShapeNode {
    let pieceData: TangramPiece
    let index: Int
    
    init(pieceData: TangramPiece, index: Int) {
        self.pieceData = pieceData
        self.index = index
        super.init()
        
        // Create shape from piece data
        self.path = createPath(for: pieceData.shape)
        self.fillColor = pieceData.color.uiColor
        self.strokeColor = .black
        self.lineWidth = 1
        self.zPosition = CGFloat(10 + index)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private func createPath(for shape: TangramPiece.Shape) -> CGPath {
        let path = CGMutablePath()
        
        switch shape {
        case .largeTriangle:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 60, y: 0))
            path.addLine(to: CGPoint(x: 30, y: 60))
            path.closeSubpath()
            
        case .mediumTriangle:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 45, y: 0))
            path.addLine(to: CGPoint(x: 22.5, y: 45))
            path.closeSubpath()
            
        case .smallTriangle:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 30, y: 0))
            path.addLine(to: CGPoint(x: 15, y: 30))
            path.closeSubpath()
            
        case .square:
            path.addRect(CGRect(x: 0, y: 0, width: 30, height: 30))
            
        case .parallelogram:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 30, y: 0))
            path.addLine(to: CGPoint(x: 45, y: 30))
            path.addLine(to: CGPoint(x: 15, y: 30))
            path.closeSubpath()
        }
        
        return path
    }
}