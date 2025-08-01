import SpriteKit
import UIKit
import Observation

final class TangramGameScene: SKScene {
    // MARK: - Properties
    
    weak var gameContext: GameContext?
    var deviceType: UIUserInterfaceIdiom = .phone
    var puzzle: Puzzle!
    private var viewModel: TangramViewModel!
    private var layoutConfig: TangramLayoutConfig!
    private var coordinateSystem: CoordinateSystem!
    private var dragHandler: DragHandler!
    private var placementValidator: PlacementValidator!
    
    // MARK: - Visual Nodes
    
    private var backgroundNode: SKSpriteNode!
    private var gameBoard: SKNode!
    private var pieceTray: SKNode!
    private var targetOutlines: [String: SKShapeNode] = [:]
    private var pieces: [String: TangramPiece] = [:]
    
    // UI Elements
    private var timerLabel: SKLabelNode!
    private var progressLabel: SKLabelNode!
    private var hintLabel: SKLabelNode!
    private var exitButton: SKShapeNode!
    private var resetButton: SKShapeNode!
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Initialize components
        viewModel = TangramViewModel(context: gameContext)
        dragHandler = DragHandler()
        
        // Setup drag handler callbacks
        setupDragHandlerCallbacks()
        
        // Setup scene
        setupScene()
        setupLayout()
        setupNodes()
        
        // Load puzzle
        if puzzle != nil {
            loadPuzzle(puzzle)
        }
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        backgroundColor = .clear  // Transparent for camera view
        scaleMode = .resizeFill
        
        // Light overlay like RockPaperScissors
        backgroundNode = SKSpriteNode(color: .black.withAlphaComponent(0.3), size: size)
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.zPosition = -10
        addChild(backgroundNode)
    }
    
    private func setupLayout() {
        // Initialize layout configuration
        let deviceType = UIDevice.current.userInterfaceIdiom
        layoutConfig = TangramLayoutConfig(
            screenSize: size,
            deviceType: deviceType,
            orientation: currentOrientation()
        )
        
        coordinateSystem = CoordinateSystem(screenSize: size)
    }
    
    private func setupNodes() {
        // Game board container
        gameBoard = SKNode()
        gameBoard.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        addChild(gameBoard)
        
        // Piece tray
        pieceTray = SKNode()
        pieceTray.position = CGPoint(x: size.width / 2, y: layoutConfig.trayHeight / 2 + 20)
        addChild(pieceTray)
        
        // UI Elements
        setupUIElements()
    }
    
    private func setupUIElements() {
        // Timer label
        timerLabel = createLabel(
            text: "00:00",
            fontSize: layoutConfig.fontSize.large,
            fontWeight: .semibold
        )
        timerLabel.position = CGPoint(x: size.width / 2, y: size.height - 50)
        addChild(timerLabel)
        
        // Progress label
        progressLabel = createLabel(
            text: "0/7 Pieces",
            fontSize: layoutConfig.fontSize.medium,
            fontWeight: .medium
        )
        progressLabel.position = CGPoint(x: size.width / 2, y: size.height - 80)
        addChild(progressLabel)
        
        // Exit button (top left)
        exitButton = createCircleButton(radius: 20)
        exitButton.position = CGPoint(x: 40, y: size.height - 40)
        exitButton.name = "exitButton"
        let exitIcon = createLabel(text: "✕", fontSize: 20, fontWeight: .bold)
        exitIcon.verticalAlignmentMode = .center
        exitButton.addChild(exitIcon)
        addChild(exitButton)
        
        // Reset button (top right)
        resetButton = createCircleButton(radius: 20)
        resetButton.position = CGPoint(x: size.width - 40, y: size.height - 40)
        resetButton.name = "resetButton"
        let resetIcon = createLabel(text: "↻", fontSize: 20, fontWeight: .bold)
        resetIcon.verticalAlignmentMode = .center
        resetButton.addChild(resetIcon)
        addChild(resetButton)
        
        // Hint label (hidden by default)
        hintLabel = createLabel(
            text: "",
            fontSize: layoutConfig.fontSize.medium,
            fontWeight: .medium
        )
        hintLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 100)
        hintLabel.alpha = 0
        addChild(hintLabel)
    }
    
    // MARK: - Puzzle Loading
    
    private func loadPuzzle(_ puzzle: Puzzle) {
        viewModel.loadPuzzle(puzzle)
        placementValidator = PlacementValidator(
            puzzle: puzzle,
            coordinateSystem: coordinateSystem,
            screenUnit: coordinateSystem.screenUnit
        )
        
        // Create target outlines
        createTargetOutlines(for: puzzle)
        
        // Create puzzle pieces
        createPuzzlePieces(for: puzzle)
        
        // Update UI
        updateProgressDisplay()
    }
    
    private func createTargetOutlines(for puzzle: Puzzle) {
        // Clear existing outlines
        targetOutlines.values.forEach { $0.removeFromParent() }
        targetOutlines.removeAll()
        
        // Create new outlines
        for pieceDef in puzzle.pieces {
            if let outline = createTargetOutline(for: pieceDef) {
                gameBoard.addChild(outline)
                targetOutlines[pieceDef.pieceId] = outline
            }
        }
    }
    
    private func createTargetOutline(for definition: PieceDefinition) -> SKShapeNode? {
        guard let outline = TangramPieceFactory.createTargetOutline(
            for: definition,
            screenUnit: coordinateSystem.screenUnit
        ) else { return nil }
        
        // Position and rotate
        let screenPos = coordinateSystem.toScreen(definition.targetPosition)
        outline.position = screenPos
        outline.zRotation = CGFloat(definition.targetRotation)
        
        // Handle parallelogram mirroring
        if definition.isMirrored == true {
            outline.xScale = -1
        }
        
        return outline
    }
    
    private func createPuzzlePieces(for puzzle: Puzzle) {
        // Clear existing pieces
        pieces.values.forEach { $0.removeFromParent() }
        pieces.removeAll()
        
        // Create pieces in tray
        let trayWidth = size.width - 100
        let pieceSpacing = trayWidth / CGFloat(puzzle.pieces.count + 1)
        
        for (index, pieceDef) in puzzle.pieces.enumerated() {
            let piece = TangramPiece(
                pieceId: pieceDef.pieceId,
                scale: coordinateSystem.screenUnit * 0.5 // Half size in tray
            )
            
            // Position in tray
            piece.position = CGPoint(
                x: -trayWidth / 2 + pieceSpacing * CGFloat(index + 1),
                y: 0
            )
            piece.originalPosition = piece.position
            
            pieceTray.addChild(piece)
            pieces[pieceDef.pieceId] = piece
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        
        // Handle UI buttons
        if node.name == "exitButton" || node.parent?.name == "exitButton" {
            handleExitButton()
            return
        }
        
        if node.name == "resetButton" || node.parent?.name == "resetButton" {
            handleResetButton()
            return
        }
        
        // Handle piece selection
        if let piece = findPiece(at: location), !piece.isLocked {
            dragHandler.beginDrag(piece: piece, at: location)
            viewModel.startGame() // Start timer on first interaction
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        dragHandler.updateDrag(to: touch.location(in: self))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.first != nil else { return }
        dragHandler.endDrag(coordinateSystem: coordinateSystem, validator: placementValidator)
    }
    
    // MARK: - Drag Handler Callbacks
    
    private func setupDragHandlerCallbacks() {
        dragHandler.onPieceSnapped = { [weak self] pieceId in
            self?.handleSuccessfulPlacement(pieceId: pieceId)
        }
        
        dragHandler.onPieceMissed = { [weak self] pieceId, error in
            self?.handleFailedPlacement(pieceId: pieceId, error: error)
        }
    }
    
    private func handleSuccessfulPlacement(pieceId: String) {
        // Update view model
        viewModel.recordSuccessfulPlacement(pieceId: pieceId)
        
        // Audio feedback
        gameContext?.audioService.playSound("snap")
        gameContext?.audioService.playHaptic(.success)
        
        // Visual celebration
        if let piece = pieces[pieceId] {
            createSnapEffect(at: piece.position)
        }
        
        // Update UI
        updateProgressDisplay()
        
        // Check for completion
        if viewModel.isComplete {
            celebrateCompletion()
        }
    }
    
    private func handleFailedPlacement(pieceId: String, error: PlacementValidator.PlacementError) {
        // Audio feedback
        gameContext?.audioService.playSound("error")
        gameContext?.audioService.playHaptic(.warning)
        
        // Show appropriate hint
        switch error {
        case .needsRotation:
            showHint("Try rotating this piece! 🔄")
            
        case .wrongPiece:
            showHint("This piece goes somewhere else 🤔")
            
        case .tooFar:
            // No hint for too far - piece just returns
            break
        }
    }
    
    // MARK: - UI Updates
    
    private func updateProgressDisplay() {
        progressLabel.text = "\(viewModel.piecesPlaced)/\(viewModel.totalPieces) Pieces"
        
        // Update timer
        let minutes = Int(viewModel.elapsedTime) / 60
        let seconds = Int(viewModel.elapsedTime) % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func showHint(_ text: String) {
        hintLabel.text = text
        hintLabel.removeAllActions()
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        
        hintLabel.run(SKAction.sequence([fadeIn, wait, fadeOut]))
    }
    
    private func createSnapEffect(at position: CGPoint) {
        // Simple pulse effect
        let circle = SKShapeNode(circleOfRadius: 30)
        circle.position = position
        circle.strokeColor = .systemGreen
        circle.lineWidth = 3
        circle.fillColor = .clear
        circle.zPosition = 150
        addChild(circle)
        
        let expand = SKAction.scale(to: 2, duration: 0.3)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        circle.run(SKAction.sequence([
            SKAction.group([expand, fade]),
            remove
        ]))
    }
    
    // MARK: - Completion
    
    private func celebrateCompletion() {
        // Stop timer
        viewModel.stopTimer()
        
        // Victory sound
        gameContext?.audioService.playSound("win")
        
        // Create celebration overlay
        // (Simplified for now - full implementation in Phase 4)
        let overlayLabel = createLabel(
            text: "Puzzle Complete! 🎉",
            fontSize: layoutConfig.fontSize.large * 1.5,
            fontWeight: .heavy
        )
        overlayLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlayLabel.zPosition = 200
        addChild(overlayLabel)
    }
    
    // MARK: - Button Handlers
    
    private func handleExitButton() {
        // Exit the game by notifying the game context
        NotificationCenter.default.post(name: Notification.Name("ExitGame"), object: nil)
    }
    
    private func handleResetButton() {
        viewModel.resetPuzzle()
        
        // Reset all pieces to original positions
        for piece in pieces.values {
            piece.isLocked = false
            piece.run(SKAction.move(to: piece.originalPosition, duration: 0.3))
            piece.zRotation = 0
        }
        
        updateProgressDisplay()
    }
    
    // MARK: - Helpers
    
    private func findPiece(at location: CGPoint) -> TangramPiece? {
        let nodes = self.nodes(at: location)
        
        for node in nodes {
            // Check if it's a piece or child of a piece
            if let piece = node as? TangramPiece {
                return piece
            }
            if let piece = node.parent as? TangramPiece {
                return piece
            }
        }
        
        return nil
    }
    
    private func createLabel(text: String, fontSize: CGFloat, fontWeight: UIFont.Weight) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = UIFont.systemFont(ofSize: fontSize, weight: fontWeight).fontName
        label.fontSize = fontSize
        label.fontColor = .white
        return label
    }
    
    private func createCircleButton(radius: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: radius)
        button.fillColor = UIColor.black.withAlphaComponent(0.5)
        button.strokeColor = UIColor.white.withAlphaComponent(0.8)
        button.lineWidth = 2
        return button
    }
    
    private func currentOrientation() -> UIInterfaceOrientation {
        if let windowScene = view?.window?.windowScene {
            return windowScene.interfaceOrientation
        }
        return .portrait
    }
}

// MARK: - GameSceneProtocol Conformance
extension TangramGameScene: GameSceneProtocol {
    func handleCVEvent(_ event: CVEvent) {
        // Future CV implementation
    }
    
    func pauseGame() {
        viewModel.pauseGame()
        isPaused = true
    }
    
    func resumeGame() {
        viewModel.resumeGame()
        isPaused = false
    }
}