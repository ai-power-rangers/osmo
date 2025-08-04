//
//  TangramScene.swift
//  osmo
//
//  Refactored Tangram scene using BaseGameScene for consistent interactions
//

import SpriteKit
import CoreGraphics

class TangramScene: BaseGameScene {
    
    // MARK: - Properties
    
    var tangramViewModel: TangramViewModel? {
        return viewModel as? TangramViewModel
    }
    
    // Scene containers
    private var gridNode: SKNode!
    private var piecesContainer: SKNode!
    private var targetOverlay: SKNode!
    
    // Piece tracking
    private var pieceNodes: [UUID: SKNode] = [:]
    
    // Visual settings (using inherited unitSize from BaseGameScene)
    private let gridLineWidth: CGFloat = 0.5
    
    // Edit mode tracking
    private var isEditMode: Bool = false
    
    // MARK: - Scene Setup
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Configure base settings from inherited BaseGameScene
        unitSize = 30.0  // Override default unit size for Tangram
        
        setupScene()
        
        // Create view model if not set via gameContext
        if tangramViewModel == nil {
            let tangramVM = TangramViewModel()
            viewModel = tangramVM
        }
        
        // Initial update from view model if available
        if let vm = tangramViewModel {
            updateFromViewModel(vm)
        }
    }
    
    override func willMove(from view: SKView) {
        // No more cancellables - we use explicit updates now
        super.willMove(from: view)
    }
    
    private func setupScene() {
        backgroundColor = SKColor(white: 0.95, alpha: 1.0)
        
        // Grid layer
        gridNode = SKNode()
        gridNode.position = CGPoint(x: frame.midX, y: frame.midY)
        gridNode.zPosition = 0
        addChild(gridNode)
        drawGrid()
        
        // Target overlay (for showing target state in editor)
        targetOverlay = SKNode()
        targetOverlay.position = CGPoint(x: frame.midX, y: frame.midY)
        targetOverlay.zPosition = 5
        targetOverlay.alpha = 0.3
        targetOverlay.isHidden = true
        addChild(targetOverlay)
        
        // Pieces container
        piecesContainer = SKNode()
        piecesContainer.position = CGPoint(x: frame.midX, y: frame.midY)
        piecesContainer.zPosition = 10
        addChild(piecesContainer)
    }
    
    private func drawGrid() {
        gridNode.removeAllChildren()
        
        let gridCount = 12  // 12x12 grid
        let totalSize = CGFloat(gridCount) * unitSize
        
        for i in 0...gridCount {
            let offset = CGFloat(i) * unitSize - totalSize/2
            let isMainLine = i % 2 == 0
            
            // Vertical line
            let vLine = SKShapeNode()
            vLine.path = CGPath(rect: CGRect(
                x: offset - gridLineWidth/2,
                y: -totalSize/2,
                width: gridLineWidth,
                height: totalSize
            ), transform: nil)
            vLine.fillColor = isMainLine ? .systemGray3 : .systemGray5
            vLine.strokeColor = .clear
            gridNode.addChild(vLine)
            
            // Horizontal line
            let hLine = SKShapeNode()
            hLine.path = CGPath(rect: CGRect(
                x: -totalSize/2,
                y: offset - gridLineWidth/2,
                width: totalSize,
                height: gridLineWidth
            ), transform: nil)
            hLine.fillColor = isMainLine ? .systemGray3 : .systemGray5
            hLine.strokeColor = .clear
            gridNode.addChild(hLine)
        }
        
        // Add subdivision lines (quarter units)
        for i in 0...(gridCount * 4) {
            guard i % 4 != 0 else { continue }
            let offset = CGFloat(i) * unitSize/4 - totalSize/2
            
            // Vertical subdivision
            let vLine = SKShapeNode()
            vLine.path = CGPath(rect: CGRect(
                x: offset - gridLineWidth/4,
                y: -totalSize/2,
                width: gridLineWidth/2,
                height: totalSize
            ), transform: nil)
            vLine.fillColor = .systemGray6
            vLine.strokeColor = .clear
            vLine.alpha = 0.3
            gridNode.addChild(vLine)
            
            // Horizontal subdivision
            let hLine = SKShapeNode()
            hLine.path = CGPath(rect: CGRect(
                x: -totalSize/2,
                y: offset - gridLineWidth/4,
                width: totalSize,
                height: gridLineWidth/2
            ), transform: nil)
            hLine.fillColor = .systemGray6
            hLine.strokeColor = .clear
            hLine.alpha = 0.3
            gridNode.addChild(hLine)
        }
    }
    
    // MARK: - SceneUpdateReceiver Override
    
    override func updateGameDisplay(_ state: GameStateSnapshot) {
        // Update display based on state snapshot
        guard let vm = tangramViewModel else { return }
        
        // Extract Tangram-specific data from metadata if available
        if let pieces = state.pieces as? [TangramPiece] {
            updatePieces(pieces)
        } else {
            let currentState = vm.currentState
            updatePieces(currentState.pieces)
        }
        
        // Update based on current view model state
        updateFromViewModel(vm)
    }
    
    override func performAnimation(_ animation: GameAnimation) {
        switch animation {
        case .pieceSnap(let position):
            animatePieceSnap(at: position)
        case .pieceRelease:
            animatePieceRelease()
        case .puzzleComplete:
            animatePuzzleComplete()
        case .invalidMove:
            animateInvalidMove()
        default:
            break
        }
    }
    
    private func updateFromViewModel(_ vm: TangramViewModel) {
        // Update pieces
        let currentState = vm.currentState
        updatePieces(currentState.pieces)
        
        // Update selection
        updateSelection(vm.selectedPieceId)
        
        // Update grid visibility
        gridNode.isHidden = !vm.showGrid
        
        // Update editor mode
        isEditMode = (vm.editorMode != nil)
        updateTargetOverlay()
        
        // Update target overlay visibility
        targetOverlay.isHidden = !vm.showTargetOverlay
    }
    
    // MARK: - Piece Management
    
    private func updatePieces(_ pieces: [TangramPiece]) {
        // Remove nodes for deleted pieces
        let currentIds = Set(pieces.map { $0.id })
        let nodeIds = Set(pieceNodes.keys)
        
        for id in nodeIds.subtracting(currentIds) {
            pieceNodes[id]?.removeFromParent()
            pieceNodes.removeValue(forKey: id)
        }
        
        // Update or create nodes
        for piece in pieces {
            if let node = pieceNodes[piece.id] {
                updatePieceNode(node, with: piece)
            } else {
                let node = createPieceNode(for: piece)
                piecesContainer.addChild(node)
                pieceNodes[piece.id] = node
            }
        }
    }
    
    private func createPieceNode(for piece: TangramPiece) -> SKNode {
        let container = SKNode()
        container.name = piece.id.uuidString
        
        // Create shape
        let shape = createShape(for: piece.shape)
        shape.fillColor = colorForShape(piece.shape)
        shape.strokeColor = .black
        shape.lineWidth = 1
        
        container.addChild(shape)
        updatePieceNode(container, with: piece)
        
        return container
    }
    
    private func createShape(for shape: TangramShape) -> SKShapeNode {
        let path = CGMutablePath()
        
        // Get vertices from TangramShapeData
        guard let vertices = TangramShapeData.shapes[shape] else {
            print("[TangramScene] Warning: No vertices found for shape: \(shape)")
            // Fallback to a simple square
            let fallbackPath = CGMutablePath()
            fallbackPath.addRect(CGRect(x: 0, y: 0, width: unitSize, height: unitSize))
            return SKShapeNode(path: fallbackPath)
        }
        
        // Scale vertices by unit size
        let scaledVertices = vertices.map { CGPoint(x: $0.x * unitSize, y: $0.y * unitSize) }
        
        // Create path
        if let first = scaledVertices.first {
            path.move(to: first)
            for vertex in scaledVertices.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        let shapeNode = SKShapeNode(path: path)
        print("[TangramScene] Created shape \(shape) with \(vertices.count) vertices")
        return shapeNode
    }
    
    private func updatePieceNode(_ node: SKNode, with piece: TangramPiece) {
        // Position
        node.position = CGPoint(
            x: piece.position.x * unitSize,
            y: piece.position.y * unitSize
        )
        
        // Rotation
        node.zRotation = CGFloat(piece.rotation)
        
        // Flip
        node.xScale = piece.isFlipped ? -1 : 1
    }
    
    private func colorForShape(_ shape: TangramShape) -> SKColor {
        // Use colors from TangramShapeData or defaults
        if let skColor = TangramShapeData.colors[shape] {
            return skColor
        }
        
        // Fallback colors
        switch shape {
        case .largeTriangle1: return .red
        case .largeTriangle2: return .blue
        case .mediumTriangle: return .green
        case .smallTriangle1: return .yellow
        case .smallTriangle2: return .orange
        case .square: return .purple
        case .parallelogram: return .cyan
        }
    }
    
    private func updateSelection(_ pieceId: UUID?) {
        // Don't show visual selection in Tangram - pieces are obvious when selected
        // The selection is tracked internally for rotation/flip operations
    }
    
    private func updateTargetOverlay() {
        targetOverlay.removeAllChildren()
        
        guard let vm = tangramViewModel,
              let puzzle = vm.currentPuzzle,
              vm.showTargetOverlay else {
            return
        }
        
        // Draw target pieces as outlines
        for piece in puzzle.targetState.pieces {
            let shape = createShape(for: piece.shape)
            shape.fillColor = .clear
            shape.strokeColor = .systemBlue
            shape.lineWidth = 2
            shape.lineCap = .round
            shape.position = CGPoint(
                x: piece.position.x * unitSize,
                y: piece.position.y * unitSize
            )
            shape.zRotation = CGFloat(piece.rotation)
            shape.xScale = piece.isFlipped ? -1 : 1
            
            targetOverlay.addChild(shape)
        }
    }
    
    // MARK: - Touch Handling Overrides
    
    override func handleTouchBegan(at location: CGPoint) {
        super.handleTouchBegan(at: location)
        
        // Find piece at location
        let localPoint = piecesContainer.convert(location, from: self)
        
        for (id, node) in pieceNodes {
            if node.contains(localPoint) {
                tangramViewModel?.selectPiece(id)
                node.zPosition = 100  // Bring to front
                break
            }
        }
    }
    
    override func handleTouchMoved(to location: CGPoint, translation: CGPoint) {
        super.handleTouchMoved(to: location, translation: translation)
        
        // Move selected piece if any
        if let selectedId = tangramViewModel?.selectedPieceId,
           let node = pieceNodes[selectedId] {
            // Convert to Tangram units
            let tangramPosition = CGPoint(
                x: location.x / unitSize,
                y: location.y / unitSize
            )
            tangramViewModel?.movePiece(selectedId, to: tangramPosition)
        }
    }
    
    override func handleTouchEnded(at location: CGPoint, velocity: CGPoint) {
        super.handleTouchEnded(at: location, velocity: velocity)
        
        // Reset z-position and check solution
        if let selectedId = tangramViewModel?.selectedPieceId,
           let node = pieceNodes[selectedId] {
            node.zPosition = 0
        }
        
        // Check solution if in play mode
        if tangramViewModel?.editorMode == nil {
            tangramViewModel?.checkSolution()
        }
    }
    
    override func handleTap(at location: CGPoint) {
        super.handleTap(at: location)
        
        // Find and select piece at location
        let localPoint = piecesContainer.convert(location, from: self)
        
        for (id, node) in pieceNodes {
            if node.contains(localPoint) {
                tangramViewModel?.selectPiece(id)
                break
            }
        }
    }
    
    // MARK: - Animation Helpers
    
    private func animatePieceSnap(at position: CGPoint) {
        // Find piece at position and animate snap
        let localPoint = piecesContainer.convert(position, from: self)
        
        for (_, node) in pieceNodes {
            if node.contains(localPoint) {
                let snapAction = SKAction.sequence([
                    SKAction.scale(to: 1.1, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                node.run(snapAction)
                break
            }
        }
    }
    
    private func animatePieceRelease() {
        // Animate piece drop
        if let selectedId = tangramViewModel?.selectedPieceId,
           let node = pieceNodes[selectedId] {
            let dropAction = SKAction.sequence([
                SKAction.moveBy(x: 0, y: -5, duration: 0.1),
                SKAction.moveBy(x: 0, y: 5, duration: 0.1)
            ])
            node.run(dropAction)
        }
    }
    
    private func animatePuzzleComplete() {
        // Celebrate completion
        for (_, node) in pieceNodes {
            let rotateAction = SKAction.rotate(byAngle: .pi * 2, duration: 1.0)
            let scaleAction = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            let group = SKAction.group([rotateAction, scaleAction])
            node.run(group)
        }
    }
    
    private func animateInvalidMove() {
        // Shake to indicate invalid
        if let selectedId = tangramViewModel?.selectedPieceId,
           let node = pieceNodes[selectedId] {
            let shakeAction = SKAction.sequence([
                SKAction.moveBy(x: -10, y: 0, duration: 0.1),
                SKAction.moveBy(x: 20, y: 0, duration: 0.1),
                SKAction.moveBy(x: -20, y: 0, duration: 0.1),
                SKAction.moveBy(x: 10, y: 0, duration: 0.1)
            ])
            node.run(shakeAction)
        }
    }
}