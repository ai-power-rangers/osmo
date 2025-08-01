//
//  SudokuGameScene.swift
//  osmo
//
//  SpriteKit scene for Sudoku game with AR overlay
//

import SpriteKit
import SwiftUI

final class SudokuGameScene: SKScene, GameSceneProtocol {
    
    // MARK: - Initializers
    
    override init(size: CGSize) {
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Properties
    
    weak var gameContext: GameContext?
    private var viewModel: SudokuViewModel!
    
    // MARK: - Visual Nodes
    
    // Status bar (minimal top overlay)
    private var statusContainer: SKNode!
    private var boardStatusIndicator: SKShapeNode!
    private var timerLabel: SKLabelNode!
    private var modeLabel: SKLabelNode!
    private var detectionStateLabel: SKLabelNode!
    
    // AR overlay elements
    private var boardOutlineNode: SKShapeNode!
    private var gridOverlay: SKNode!
    private var detectedNumbersOverlay: SKNode!
    private var feedbackContainer: SKNode!
    
    // Controls
    private var confirmButton: SKShapeNode!
    private var stopButton: SKShapeNode!
    
    // Grid size selector
    private var gridSizeSelector: SKNode!
    private var fourByFourButton: SKShapeNode!
    private var nineByNineButton: SKShapeNode!
    
    // MARK: - Configuration
    
    private var gridSize: GridSize = .fourByFour
    private var boardCorners: [CGPoint] = []
    
    // MARK: - CV Integration
    
    private var cvEventStream: AsyncStream<CVEvent>?
    private var cvTask: Task<Void, Never>?
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Setup scene
        setupScene()
        setupNodes()
        layoutNodes()
        
        // Show grid size selection
        showGridSizeSelection()
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        backgroundColor = .clear  // Transparent to show camera
        scaleMode = .resizeFill
    }
    
    private func setupNodes() {
        // Create main containers
        statusContainer = SKNode()
        gridOverlay = SKNode()
        detectedNumbersOverlay = SKNode()
        feedbackContainer = SKNode()
        
        // Status elements
        boardStatusIndicator = SKShapeNode(circleOfRadius: 6)
        boardStatusIndicator.fillColor = .systemRed
        boardStatusIndicator.strokeColor = .white.withAlphaComponent(0.8)
        boardStatusIndicator.lineWidth = 1.5
        
        timerLabel = createLabel(text: "00:00", fontSize: 20, weight: .semibold)
        modeLabel = createLabel(text: "Select Grid Size", fontSize: 18, weight: .medium)
        detectionStateLabel = createLabel(text: "", fontSize: 16, weight: .regular)
        
        // Board outline - will show detected quadrilateral
        boardOutlineNode = SKShapeNode()
        boardOutlineNode.strokeColor = .systemGreen.withAlphaComponent(0.8)
        boardOutlineNode.lineWidth = 4
        boardOutlineNode.fillColor = .clear
        boardOutlineNode.isHidden = true
        boardOutlineNode.zPosition = 100  // Ensure it's on top
        
        // Control buttons
        confirmButton = createButton(text: "Confirm & Start", size: CGSize(width: 160, height: 44))
        confirmButton.fillColor = .systemBlue
        confirmButton.alpha = 0.5  // Start disabled
        
        stopButton = SKShapeNode(circleOfRadius: 18)
        stopButton.fillColor = .systemRed
        stopButton.strokeColor = .white
        stopButton.lineWidth = 2
        
        // X for stop button
        let xLabel = createLabel(text: "✕", fontSize: 20, weight: .bold)
        stopButton.addChild(xLabel)
        
        // Grid size selector
        setupGridSizeSelector()
        
        // Add to scene
        statusContainer.addChild(boardStatusIndicator)
        statusContainer.addChild(timerLabel)
        statusContainer.addChild(modeLabel)
        statusContainer.addChild(detectionStateLabel)
        
        addChild(statusContainer)
        addChild(boardOutlineNode)
        addChild(gridOverlay)
        addChild(detectedNumbersOverlay)
        addChild(feedbackContainer)
        addChild(confirmButton)
        addChild(stopButton)
        addChild(gridSizeSelector)
    }
    
    private func layoutNodes() {
        let screenWidth = size.width
        let screenHeight = size.height
        let safeTop = screenHeight - 80  // More space from top
        
        // Single row status bar
        boardStatusIndicator.position = CGPoint(x: 30, y: safeTop)
        timerLabel.position = CGPoint(x: screenWidth / 2, y: safeTop)
        stopButton.position = CGPoint(x: screenWidth - 30, y: safeTop)
        stopButton.isHidden = true
        
        // Instructions below status bar
        detectionStateLabel.position = CGPoint(x: screenWidth / 2, y: safeTop - 35)
        
        // Confirm button (centered, lower)
        confirmButton.position = CGPoint(x: screenWidth / 2, y: 120)
        confirmButton.isHidden = true  // Hidden until board detected
        
        // Grid selector (centered)
        gridSizeSelector.position = CGPoint(x: screenWidth / 2, y: screenHeight / 2)
        
        // Remove mode label - not needed
        modeLabel.isHidden = true
    }
    
    // MARK: - Grid Size Selection
    
    private func setupGridSizeSelector() {
        gridSizeSelector = SKNode()
        
        let background = SKShapeNode(rectOf: CGSize(width: 300, height: 160), cornerRadius: 20)
        background.fillColor = .black.withAlphaComponent(0.8)
        background.strokeColor = .white
        background.lineWidth = 2
        
        let titleLabel = createLabel(text: "Select Grid Size", fontSize: 22, weight: .bold)
        titleLabel.position = CGPoint(x: 0, y: 50)
        
        // 4x4 button
        fourByFourButton = createButton(text: "4×4 Mini", size: CGSize(width: 120, height: 50))
        fourByFourButton.position = CGPoint(x: -70, y: -10)
        fourByFourButton.name = "fourByFour"
        
        // 9x9 button
        nineByNineButton = createButton(text: "9×9 Classic", size: CGSize(width: 120, height: 50))
        nineByNineButton.position = CGPoint(x: 70, y: -10)
        nineByNineButton.name = "nineByNine"
        
        gridSizeSelector.addChild(background)
        gridSizeSelector.addChild(titleLabel)
        gridSizeSelector.addChild(fourByFourButton)
        gridSizeSelector.addChild(nineByNineButton)
    }
    
    private func showGridSizeSelection() {
        gridSizeSelector.isHidden = false
        confirmButton.isHidden = true
        boardOutlineNode.isHidden = true
    }
    
    private func selectGridSize(_ size: GridSize) {
        gridSize = size
        
        // Initialize ViewModel
        viewModel = SudokuViewModel(gridSize: size, context: gameContext)
        
        // Hide selector
        gridSizeSelector.isHidden = true
        
        // Update instructions
        detectionStateLabel.text = "Place board in view"
        
        // Subscribe to CV events
        subscribeToCV()
        
        // Start detection
        viewModel.startSetupMode()
        updateDisplay()
    }
    
    // MARK: - CV Integration
    
    private func subscribeToCV() {
        guard let cvService = gameContext?.cvService else { return }
        
        // Create configuration with grid size
        let configuration: [String: Any] = [
            "gridSize": gridSize.rawValue
        ]
        
        cvEventStream = cvService.eventStream(
            gameId: SudokuGameModule.gameId,
            events: [],
            configuration: configuration
        )
        
        cvTask = Task { [weak self] in
            guard let stream = self?.cvEventStream else { return }
            for await event in stream {
                await MainActor.run {
                    self?.handleCVEvent(event)
                }
            }
        }
        
        print("[Sudoku] Subscribed to CV events with grid size: \(gridSize.displayName)")
    }
    
    func handleCVEvent(_ event: CVEvent) {
        switch event.type {
        case .rectangleDetected(let rectangles):
            if let rect = rectangles.first {
                processBoardDetection(rect)
            }
            
        case .textDetected(let text, let boundingBox):
            processTextDetection(text, boundingBox: boundingBox, event: event)
            
        case .rectangleLost:
            viewModel.handleBoardLost()
            updateBoardStatus()
            
        default:
            break
        }
    }
    
    private func processBoardDetection(_ rectangle: CVRectangle) {
        // Update board corners
        boardCorners = [
            convertToSceneCoordinates(rectangle.topLeft),
            convertToSceneCoordinates(rectangle.topRight),
            convertToSceneCoordinates(rectangle.bottomRight),
            convertToSceneCoordinates(rectangle.bottomLeft)
        ]
        
        // Create board detection
        let detection = BoardDetection(
            corners: boardCorners,
            confidence: rectangle.confidence,
            timestamp: Date(),
            transform: .identity  // Simplified for now
        )
        
        viewModel.processBoardDetection(detection)
        updateBoardOutline()
        updateBoardStatus()  // Update status first
        updateGridOverlay()  // Then overlay
        
        print("[Sudoku] Board detected at corners: \(boardCorners)")
    }
    
    private func processTextDetection(_ text: String, boundingBox: CGRect, event: CVEvent) {
        guard let number = Int(text) else { return }
        
        // Try to get position from metadata first
        let position: Position
        if let row = event.metadata?.additionalProperties["position_row"] as? Int,
           let col = event.metadata?.additionalProperties["position_col"] as? Int {
            position = Position(row: row, col: col)
        } else {
            // Fallback to mapping from bounding box
            guard let mappedPosition = mapBoundingBoxToGridPosition(boundingBox) else {
                return
            }
            position = mappedPosition
        }
        
        let detection = TileDetection(
            position: position,
            number: number,
            confidence: event.confidence,
            timestamp: Date(),
            boundingBox: boundingBox
        )
        
        viewModel.processTileDetection(detection)
        updateDetectedNumbers()
    }
    
    // MARK: - Display Updates
    
    private func updateDisplay() {
        updateBoardStatus()
        updateTimer()
        updateDetectedNumbers()
    }
    
    private func updateBoardStatus() {
        // Update status indicator color based on state
        switch viewModel.detectionState {
        case .searching:
            boardStatusIndicator.fillColor = .systemRed
            boardOutlineNode.isHidden = true
            gridOverlay.isHidden = true
            detectionStateLabel.text = "Place board in view"
            confirmButton.isHidden = true
            
        case .detecting:
            boardStatusIndicator.fillColor = .systemYellow
            boardOutlineNode.strokeColor = .systemYellow.withAlphaComponent(0.8)
            boardOutlineNode.isHidden = false
            detectionStateLabel.text = "Board found, analyzing..."
            
        case .stabilizing:
            boardStatusIndicator.fillColor = .systemGreen.withAlphaComponent(0.7)
            boardOutlineNode.strokeColor = .systemGreen.withAlphaComponent(0.7)
            detectionStateLabel.text = "Hold steady..."
            
            // Pulse effect for stabilizing
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                SKAction.fadeAlpha(to: 1.0, duration: 0.5)
            ])
            boardOutlineNode.run(SKAction.repeatForever(pulse), withKey: "pulse")
            
        case .confirmed:
            boardStatusIndicator.fillColor = .systemGreen
            boardOutlineNode.strokeColor = .systemGreen
            boardOutlineNode.removeAction(forKey: "pulse")
            boardOutlineNode.alpha = 1.0
            gridOverlay.isHidden = false
            
            // Show detected numbers and enable confirm button
            detectionStateLabel.text = "Board locked! Check numbers and confirm"
            
            // Only show confirm button when we're in setup mode and have detected tiles
            if viewModel.gameState.mode == .setup && countFilledCells() > 0 {
                confirmButton.isHidden = false
                confirmButton.alpha = 1.0  // Enable button
            }
        }
    }
    
    private func updateBoardOutline() {
        guard boardCorners.count == 4 else { return }
        
        // Draw quadrilateral outline
        let path = CGMutablePath()
        path.move(to: boardCorners[0])
        for i in 1..<4 {
            path.addLine(to: boardCorners[i])
        }
        path.closeSubpath()
        
        boardOutlineNode.path = path
        boardOutlineNode.isHidden = false
    }
    
    private func updateGridOverlay() {
        // Clear existing grid
        gridOverlay.removeAllChildren()
        
        guard boardCorners.count == 4 else { return }
        
        let dimension = gridSize.rawValue
        let boxSize = gridSize.boxSize
        
        // Draw grid lines
        for i in 0...dimension {
            let t = CGFloat(i) / CGFloat(dimension)
            
            // Vertical lines
            let topPoint = interpolate(from: boardCorners[0], to: boardCorners[1], t: t)
            let bottomPoint = interpolate(from: boardCorners[3], to: boardCorners[2], t: t)
            
            let vLine = SKShapeNode()
            let vPath = CGMutablePath()
            vPath.move(to: topPoint)
            vPath.addLine(to: bottomPoint)
            vLine.path = vPath
            vLine.strokeColor = (i % boxSize == 0) ? .white.withAlphaComponent(0.6) : .white.withAlphaComponent(0.3)
            vLine.lineWidth = (i % boxSize == 0) ? 2 : 1
            gridOverlay.addChild(vLine)
            
            // Horizontal lines
            let leftPoint = interpolate(from: boardCorners[0], to: boardCorners[3], t: t)
            let rightPoint = interpolate(from: boardCorners[1], to: boardCorners[2], t: t)
            
            let hLine = SKShapeNode()
            let hPath = CGMutablePath()
            hPath.move(to: leftPoint)
            hPath.addLine(to: rightPoint)
            hLine.path = hPath
            hLine.strokeColor = (i % boxSize == 0) ? .white.withAlphaComponent(0.6) : .white.withAlphaComponent(0.3)
            hLine.lineWidth = (i % boxSize == 0) ? 2 : 1
            gridOverlay.addChild(hLine)
        }
        
        gridOverlay.isHidden = false
        gridOverlay.zPosition = 50  // Above camera but below board outline
    }
    
    private func updateDetectedNumbers() {
        // Clear existing numbers
        detectedNumbersOverlay.removeAllChildren()
        
        guard boardCorners.count == 4 else { return }
        
        let dimension = gridSize.rawValue
        
        for row in 0..<dimension {
            for col in 0..<dimension {
                let position = Position(row: row, col: col)
                if let number = viewModel.virtualBoard[row][col] {
                    let cellCenter = getCellCenter(for: position)
                    let isOriginal = viewModel.board.isOriginalTile(at: position)
                    
                    // Create number label
                    let label = createLabel(
                        text: "\(number)",
                        fontSize: 28,
                        weight: isOriginal ? .bold : .medium
                    )
                    label.fontColor = isOriginal ? .systemBlue : .white
                    label.position = cellCenter
                    
                    // Add background for better visibility
                    let background = SKShapeNode(circleOfRadius: 20)
                    background.fillColor = .black.withAlphaComponent(0.6)
                    background.strokeColor = .clear
                    background.position = cellCenter
                    
                    detectedNumbersOverlay.addChild(background)
                    detectedNumbersOverlay.addChild(label)
                }
            }
        }
        
        // Show feedback if any
        if let animation = viewModel.feedbackAnimation {
            showFeedbackAnimation(animation)
        }
    }
    
    private func updateTimer() {
        if viewModel.gameState.mode == .solving || viewModel.gameState.mode == .completed {
            timerLabel.text = viewModel.gameState.formattedTime
        } else {
            timerLabel.text = "00:00"
        }
    }
    
    // MARK: - Feedback Animations
    
    private func showFeedbackAnimation(_ animation: FeedbackAnimation) {
        feedbackContainer.removeAllChildren()
        
        let centerY = size.height * 0.6
        let emoji = SKLabelNode(text: animation.emoji)
        emoji.fontSize = 80
        emoji.position = CGPoint(x: size.width / 2, y: centerY)
        
        feedbackContainer.addChild(emoji)
        
        // Animate
        let fadeOut = SKAction.fadeOut(withDuration: 1.5)
        let moveUp = SKAction.moveBy(x: 0, y: 100, duration: 1.5)
        let remove = SKAction.removeFromParent()
        
        emoji.run(SKAction.sequence([SKAction.group([fadeOut, moveUp]), remove]))
        
        // Clear feedback after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.viewModel.feedbackAnimation = nil
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        
        // Grid size selection
        if node.name == "fourByFour" || node.parent?.name == "fourByFour" {
            selectGridSize(.fourByFour)
        } else if node.name == "nineByNine" || node.parent?.name == "nineByNine" {
            selectGridSize(.nineByNine)
        }
        
        // Control buttons
        else if node == confirmButton || node.parent == confirmButton {
            handleConfirmButton()
        } else if node == stopButton || node.parent == stopButton {
            handleStopButton()
        }
    }
    
    private func handleConfirmButton() {
        if viewModel.gameState.mode == .setup {
            viewModel.confirmSetup()
            confirmButton.isHidden = true
            stopButton.isHidden = false
            detectionStateLabel.text = "Game started! Place tiles to solve"
            
            // Hide board outline during solving
            boardOutlineNode.isHidden = true
        }
    }
    
    private func handleStopButton() {
        viewModel.stopGame()
        // Would typically return to lobby
    }
    
    // MARK: - Helper Methods
    
    private func countFilledCells() -> Int {
        var count = 0
        let dimension = gridSize.rawValue
        for row in 0..<dimension {
            for col in 0..<dimension {
                if viewModel.virtualBoard[row][col] != nil {
                    count += 1
                }
            }
        }
        return count
    }
    
    private func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight) -> SKLabelNode {
        let label = SKLabelNode()
        label.text = text
        label.fontSize = fontSize
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight).fontDescriptor.withDesign(.rounded)
        if let roundedFont = font {
            label.fontName = UIFont(descriptor: roundedFont, size: fontSize).fontName
        }
        
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }
    
    private func createButton(text: String, size: CGSize) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        button.fillColor = .systemBlue
        button.strokeColor = .white
        button.lineWidth = 2
        
        let label = createLabel(text: text, fontSize: 16, weight: .semibold)
        button.addChild(label)
        
        return button
    }
    
    private func convertToSceneCoordinates(_ point: CGPoint) -> CGPoint {
        // Convert from normalized (0-1) to scene coordinates
        return CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
    }
    
    private func interpolate(from: CGPoint, to: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(
            x: from.x + (to.x - from.x) * t,
            y: from.y + (to.y - from.y) * t
        )
    }
    
    private func getCellCenter(for position: Position) -> CGPoint {
        guard boardCorners.count == 4 else { return .zero }
        
        let dimension = CGFloat(gridSize.rawValue)
        let row = CGFloat(position.row)
        let col = CGFloat(position.col)
        
        // Calculate normalized position (0-1)
        let u = (col + 0.5) / dimension
        let v = (row + 0.5) / dimension
        
        // Bilinear interpolation
        let top = interpolate(from: boardCorners[0], to: boardCorners[1], t: u)
        let bottom = interpolate(from: boardCorners[3], to: boardCorners[2], t: u)
        
        return interpolate(from: top, to: bottom, t: v)
    }
    
    private func mapBoundingBoxToGridPosition(_ boundingBox: CGRect) -> Position? {
        // Simplified mapping - in production would use inverse perspective transform
        let dimension = gridSize.rawValue
        let col = Int(boundingBox.midX / size.width * CGFloat(dimension))
        let row = Int(boundingBox.midY / size.height * CGFloat(dimension))
        
        if row >= 0 && row < dimension && col >= 0 && col < dimension {
            return Position(row: row, col: col)
        }
        return nil
    }
    
    // MARK: - GameSceneProtocol
    
    func pauseGame() {
        isPaused = true
    }
    
    func resumeGame() {
        isPaused = false
    }
    
    // MARK: - Cleanup
    
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        cvTask?.cancel()
        viewModel?.stopGame()
    }
}