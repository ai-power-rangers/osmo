//
//  SudokuScene.swift
//  osmo
//
//  Refactored Sudoku scene using BaseGameScene for consistent interactions
//

import SpriteKit

class SudokuScene: BaseGameScene {
    
    // MARK: - Properties
    
    var sudokuViewModel: SudokuViewModel? {
        return viewModel as? SudokuViewModel
    }
    
    // Scene containers
    private var boardNode: SKNode!
    private var gridNode: SKNode!
    private var cellsContainer: SKNode!
    private var numbersContainer: SKNode!
    private var highlightLayer: SKNode!
    
    // Visual settings - using inherited unitSize from BaseGameScene
    private let cellSize: CGFloat // Will be calculated based on grid size
    private let gridLineWidth: CGFloat = 1.0
    private let boxLineWidth: CGFloat = 2.0
    
    // Grid configuration
    private var gridDimension: Int = 9
    private var boxSize: Int = 3
    
    // Cell tracking
    private var cellNodes: [[SKNode]] = []
    private var selectedCell: Position?
    
    // Number palette for input
    private var numberPalette: SKNode!
    
    // Edit mode tracking
    private var isEditMode: Bool = false
    
    // No subscriptions needed - direct property access with @Observable
    
    // MARK: - Initialization
    
    override init(size: CGSize) {
        // Calculate cell size based on 8 unit play area divided by grid dimension
        self.cellSize = (8.0 * 100.0) / 9.0  // Will be recalculated based on actual grid
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.cellSize = (8.0 * 50.0) / 9.0
        super.init(coder: aDecoder)
    }
    
    // MARK: - Scene Setup
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Configure base settings from inherited BaseGameScene
        unitSize = 50.0  // Override default unit size for Sudoku
        // Fine grid snapping for precise cell selection would be 0.1 * unitSize
        // No visual grid needed for Sudoku (we have our own)
        
        setupScene()
        
        // Create view model if not set via gameContext
        if sudokuViewModel == nil {
            let sudokuVM = SudokuViewModel()
            viewModel = sudokuVM
        }
        
        // Initial update from view model if available
        if let vm = sudokuViewModel {
            updateGameDisplay(GameStateSnapshot.empty)
        }
        
        // Scene is ready to play
    }
    
    override func willMove(from view: SKView) {
        super.willMove(from: view)
    }
    
    private func setupScene() {
        backgroundColor = SKColor.white
        
        // Main board container
        boardNode = SKNode()
        boardNode.position = CGPoint(x: frame.midX, y: frame.midY + 50)
        boardNode.zPosition = 0
        addChild(boardNode)
        
        // Grid lines layer
        gridNode = SKNode()
        gridNode.zPosition = 1
        boardNode.addChild(gridNode)
        
        // Highlight layer (for selected cells, conflicts, etc.)
        highlightLayer = SKNode()
        highlightLayer.zPosition = 5
        boardNode.addChild(highlightLayer)
        
        // Cells container
        cellsContainer = SKNode()
        cellsContainer.zPosition = 10
        boardNode.addChild(cellsContainer)
        
        // Numbers container (for placed numbers)
        numbersContainer = SKNode()
        numbersContainer.zPosition = 15
        boardNode.addChild(numbersContainer)
        
        // Number palette for input
        setupNumberPalette()
        
        // Draw the board
        drawSudokuGrid()
        setupCells()
    }
    
    private func drawSudokuGrid() {
        gridNode.removeAllChildren()
        
        let boardSize = cellSize * CGFloat(gridDimension)
        let halfSize = boardSize / 2
        
        // Draw thin lines for cells
        for i in 0...gridDimension {
            let offset = CGFloat(i) * cellSize - halfSize
            let isBoxLine = i % boxSize == 0
            
            // Vertical line
            let vLine = SKShapeNode()
            vLine.path = CGPath(rect: CGRect(
                x: offset - (isBoxLine ? boxLineWidth : gridLineWidth) / 2,
                y: -halfSize,
                width: isBoxLine ? boxLineWidth : gridLineWidth,
                height: boardSize
            ), transform: nil)
            vLine.fillColor = isBoxLine ? .label : .systemGray3
            vLine.strokeColor = .clear
            gridNode.addChild(vLine)
            
            // Horizontal line
            let hLine = SKShapeNode()
            hLine.path = CGPath(rect: CGRect(
                x: -halfSize,
                y: offset - (isBoxLine ? boxLineWidth : gridLineWidth) / 2,
                width: boardSize,
                height: isBoxLine ? boxLineWidth : gridLineWidth
            ), transform: nil)
            hLine.fillColor = isBoxLine ? .label : .systemGray3
            hLine.strokeColor = .clear
            gridNode.addChild(hLine)
        }
    }
    
    private func setupCells() {
        cellsContainer.removeAllChildren()
        cellNodes = []
        
        let boardSize = cellSize * CGFloat(gridDimension)
        let halfSize = boardSize / 2
        
        for row in 0..<gridDimension {
            var rowNodes: [SKNode] = []
            
            for col in 0..<gridDimension {
                let cellNode = SKNode()
                cellNode.name = "\(row),\(col)"
                cellNode.position = CGPoint(
                    x: CGFloat(col) * cellSize - halfSize + cellSize/2,
                    y: CGFloat(gridDimension - 1 - row) * cellSize - halfSize + cellSize/2
                )
                
                cellsContainer.addChild(cellNode)
                rowNodes.append(cellNode)
            }
            
            cellNodes.append(rowNodes)
        }
    }
    
    private func setupNumberPalette() {
        numberPalette = SKNode()
        numberPalette.position = CGPoint(x: frame.midX, y: frame.midY - 250)
        numberPalette.zPosition = 20
        addChild(numberPalette)
        
        let paletteSize: CGFloat = 40
        let spacing: CGFloat = 10
        let totalWidth = CGFloat(gridDimension) * paletteSize + CGFloat(gridDimension - 1) * spacing
        
        for i in 1...gridDimension {
            let button = createNumberButton(number: i, size: paletteSize)
            button.position = CGPoint(
                x: CGFloat(i - 1) * (paletteSize + spacing) - totalWidth/2 + paletteSize/2,
                y: 0
            )
            button.name = "palette_\(i)"
            numberPalette.addChild(button)
        }
        
        // Add clear button
        let clearButton = createClearButton(size: paletteSize)
        clearButton.position = CGPoint(x: 0, y: -paletteSize - spacing)
        clearButton.name = "palette_clear"
        numberPalette.addChild(clearButton)
    }
    
    private func createNumberButton(number: Int, size: CGFloat) -> SKNode {
        let container = SKNode()
        
        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 5)
        bg.fillColor = .systemBlue
        bg.strokeColor = .clear
        container.addChild(bg)
        
        // Number label
        let label = SKLabelNode(text: "\(number)")
        label.fontName = "Helvetica-Bold"
        label.fontSize = size * 0.6
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)
        
        return container
    }
    
    private func createClearButton(size: CGFloat) -> SKNode {
        let container = SKNode()
        
        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: size * 2, height: size), cornerRadius: 5)
        bg.fillColor = .systemRed
        bg.strokeColor = .clear
        container.addChild(bg)
        
        // Label
        let label = SKLabelNode(text: "Clear")
        label.fontName = "Helvetica-Bold"
        label.fontSize = size * 0.5
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)
        
        return container
    }
    
    // MARK: - SceneUpdateReceiver Override
    
    override func updateGameDisplay(_ state: GameStateSnapshot) {
        guard let vm = sudokuViewModel else { return }
        
        // Update UI based on current state
        updatePuzzle(vm.currentPuzzle)
        updateBoard(vm.currentBoard)
        updateSelection(vm.selectedCell)
        updateConflicts(vm.conflicts)
        if vm.isComplete {
            showCompletionAnimation()
        }
        isEditMode = (vm.editorMode != nil)
    }
    
    override func performAnimation(_ animation: GameAnimation) {
        switch animation {
        case .pieceSnap:
            // Snap animation for number placement
            if let selected = selectedCell {
                let cell = cellNodes[selected.row][selected.col]
                let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                cell.run(SKAction.sequence([scaleUp, scaleDown]))
            }
        case .puzzleComplete:
            showCompletionAnimation()
        case .invalidMove:
            // Shake animation for invalid move
            if let selected = selectedCell {
                let cell = cellNodes[selected.row][selected.col]
                let shake = SKAction.sequence([
                    SKAction.moveBy(x: -5, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 10, y: 0, duration: 0.05),
                    SKAction.moveBy(x: -10, y: 0, duration: 0.05),
                    SKAction.moveBy(x: 5, y: 0, duration: 0.05)
                ])
                cell.run(shake)
            }
        default:
            break
        }
    }
    
    // Call this whenever we make changes to sync the UI
    private func syncWithViewModel() {
        guard let vm = sudokuViewModel else { return }
        updateBoard(vm.currentBoard)
        updateSelection(vm.selectedCell)
        updateConflicts(vm.conflicts)
        if vm.isComplete {
            showCompletionAnimation()
        }
    }
    
    // MARK: - Board Updates
    
    private func updatePuzzle(_ puzzle: SudokuPuzzle?) {
        guard let puzzle = puzzle else { return }
        
        // Update grid dimensions if needed
        if gridDimension != puzzle.gridSize.rawValue {
            gridDimension = puzzle.gridSize.rawValue
            boxSize = puzzle.gridSize == .fourByFour ? 2 : 3
            drawSudokuGrid()
            setupCells()
        }
    }
    
    private func updateBoard(_ board: [[Int?]]) {
        numbersContainer.removeAllChildren()
        
        for row in 0..<board.count {
            for col in 0..<board[row].count {
                if let value = board[row][col] {
                    let cellNode = cellNodes[row][col]
                    addNumber(value, to: cellNode, isInitial: sudokuViewModel?.initialBoard[row][col] != nil)
                }
            }
        }
    }
    
    private func addNumber(_ number: Int, to cellNode: SKNode, isInitial: Bool) {
        let label = SKLabelNode(text: "\(number)")
        label.fontName = isInitial ? "Helvetica-Bold" : "Helvetica"
        label.fontSize = cellSize * 0.6
        label.fontColor = isInitial ? .label : .systemBlue
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = cellNode.position
        numbersContainer.addChild(label)
    }
    
    private func updateSelection(_ position: Position?) {
        highlightLayer.removeAllChildren()
        selectedCell = position
        
        guard let position = position else { return }
        
        // Highlight selected cell
        let cellNode = cellNodes[position.row][position.col]
        let highlight = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4), cornerRadius: 3)
        highlight.fillColor = SKColor.blue.withAlphaComponent(0.2)
        highlight.strokeColor = .systemBlue
        highlight.lineWidth = 2
        highlight.position = cellNode.position
        highlightLayer.addChild(highlight)
        
        // Highlight same row and column
        for i in 0..<gridDimension {
            // Row
            if i != position.col {
                let rowHighlight = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4))
                rowHighlight.fillColor = SKColor.blue.withAlphaComponent(0.05)
                rowHighlight.strokeColor = .clear
                rowHighlight.position = cellNodes[position.row][i].position
                highlightLayer.addChild(rowHighlight)
            }
            
            // Column
            if i != position.row {
                let colHighlight = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4))
                colHighlight.fillColor = SKColor.blue.withAlphaComponent(0.05)
                colHighlight.strokeColor = .clear
                colHighlight.position = cellNodes[i][position.col].position
                highlightLayer.addChild(colHighlight)
            }
        }
        
        // Highlight same box
        let boxStartRow = (position.row / boxSize) * boxSize
        let boxStartCol = (position.col / boxSize) * boxSize
        
        for r in boxStartRow..<(boxStartRow + boxSize) {
            for c in boxStartCol..<(boxStartCol + boxSize) {
                if r != position.row || c != position.col {
                    let boxHighlight = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4))
                    boxHighlight.fillColor = SKColor.blue.withAlphaComponent(0.05)
                    boxHighlight.strokeColor = .clear
                    boxHighlight.position = cellNodes[r][c].position
                    highlightLayer.addChild(boxHighlight)
                }
            }
        }
    }
    
    private func updateConflicts(_ conflicts: Set<Position>) {
        // Remove existing conflict highlights
        highlightLayer.children.filter { $0.name == "conflict" }.forEach { $0.removeFromParent() }
        
        for position in conflicts {
            let cellNode = cellNodes[position.row][position.col]
            let conflict = SKShapeNode(rectOf: CGSize(width: cellSize - 4, height: cellSize - 4))
            conflict.name = "conflict"
            conflict.fillColor = SKColor.red.withAlphaComponent(0.2)
            conflict.strokeColor = .systemRed
            conflict.lineWidth = 2
            conflict.position = cellNode.position
            conflict.zPosition = 2  // Above normal highlights
            highlightLayer.addChild(conflict)
        }
    }
    
    private func showCompletionAnimation() {
        // Celebration animation
        let particles = SKEmitterNode(fileNamed: "Confetti")
        particles?.position = CGPoint(x: frame.midX, y: frame.midY)
        particles?.zPosition = 100
        if let particles = particles {
            addChild(particles)
            
            let wait = SKAction.wait(forDuration: 3.0)
            let remove = SKAction.removeFromParent()
            particles.run(SKAction.sequence([wait, remove]))
        }
        
        // Pulse the board
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        boardNode.run(SKAction.sequence([scaleUp, scaleDown]))
        
        // Animation complete
    }
    
    // MARK: - BaseGameScene Overrides
    
    func selectableNode(at location: CGPoint) -> SKNode? {
        // Check if we hit a cell
        let boardLocation = boardNode.convert(location, from: self)
        let cellLocation = cellsContainer.convert(boardLocation, from: boardNode)
        
        for row in 0..<gridDimension {
            for col in 0..<gridDimension {
                let cellNode = cellNodes[row][col]
                let cellFrame = CGRect(
                    x: cellNode.position.x - cellSize/2,
                    y: cellNode.position.y - cellSize/2,
                    width: cellSize,
                    height: cellSize
                )
                
                if cellFrame.contains(cellLocation) {
                    return cellNode
                }
            }
        }
        
        // Check number palette
        if let paletteNode = nodes(at: location).first(where: { $0.name?.starts(with: "palette_") ?? false }) {
            return paletteNode
        }
        
        return nil
    }
    
    func shouldSnapToGrid(node: SKNode) -> Bool {
        return false  // Sudoku doesn't use drag and drop
    }
    
    func isValidPlacement(node: SKNode, at position: CGPoint) -> Bool {
        return true  // Not applicable for Sudoku
    }
    
    // MARK: - Gesture Callbacks
    
    func onNodeSelected(node: SKNode) {
        if let name = node.name {
            if name.starts(with: "palette_") {
                handlePaletteSelection(name)
            } else if name.contains(",") {
                // Cell selection
                let components = name.split(separator: ",")
                if components.count == 2,
                   let row = Int(components[0]),
                   let col = Int(components[1]) {
                    sudokuViewModel?.selectCell(Position(row: row, col: col))
                }
            }
        }
    }
    
    private func handlePaletteSelection(_ name: String) {
        guard let selectedCell = selectedCell else { return }
        
        if name == "palette_clear" {
            sudokuViewModel?.clearCell(at: selectedCell)
        } else if let numberStr = name.split(separator: "_").last,
                  let number = Int(numberStr) {
            sudokuViewModel?.placeNumber(number, at: selectedCell)
        }
    }
    
    func onDoubleTap(node: SKNode) {
        // Clear cell on double tap
        if let name = node.name, name.contains(",") {
            let components = name.split(separator: ",")
            if components.count == 2,
               let row = Int(components[0]),
               let col = Int(components[1]) {
                sudokuViewModel?.clearCell(at: Position(row: row, col: col))
            }
        }
    }
    
    func onLongPress(node: SKNode) {
        guard isEditMode else { return }
        
        // In edit mode, long press toggles initial state
        if let name = node.name, name.contains(",") {
            let components = name.split(separator: ",")
            if components.count == 2,
               let row = Int(components[0]),
               let col = Int(components[1]) {
                // Toggle initial cell in edit mode
                let position = Position(row: row, col: col)
                if let vm = sudokuViewModel {
                    let currentValue = vm.initialBoard[row][col]
                    if currentValue != nil {
                        vm.clearCell(at: position)
                    } else if let value = vm.currentBoard[row][col] {
                        vm.placeNumber(value, at: position)
                    }
                }
            }
        }
    }
    
    // Disable drag for Sudoku
    func onDragBegan(node: SKNode, at location: CGPoint) {
        // Not used in Sudoku
    }
    
    func onDragMoved(node: SKNode, to position: CGPoint) {
        // Not used in Sudoku
    }
    
    func onDragEnded(node: SKNode, at position: CGPoint) {
        // Not used in Sudoku
    }
}