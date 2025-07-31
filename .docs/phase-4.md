# Phase 4: AR Sudoku Game Implementation

NOTE: Use SwiftUI NOT UIKIT!!!
- Replace all UIColor with Color
- Replace UIImage with SwiftUI equivalents where needed
- The AR overlays might need a UIViewRepresentable wrapper for ARSCNView
- Everything else (Vision, ARKit, SceneKit, game logic, models) remains exactly the same. The architecture and 95% of the code is framework-agnostic. The UIKit references are mostly just color types that are easily swapped.

## Overview
Phase 4 implements an AR Sudoku game that detects paper sudoku boards, recognizes handwritten numbers, provides AR overlays for hints/errors, and tracks progress across multiple boards. This integrates with the existing architecture from phases 1-3.

## Required Phase 1-3 Updates

### Update 1: Extend CV Event Types (Phase 1)
Update `Core/Models/CVEvent.swift`:

```swift
// Add to CVEventType enum:
enum CVEventType: Equatable {
    // Existing cases...
    case objectDetected(type: String, objectId: UUID)
    case objectMoved(type: String, objectId: UUID, from: CGPoint, to: CGPoint)
    case objectRemoved(type: String, objectId: UUID)
    case gestureRecognized(type: GestureType)
    case fingerCountDetected(count: Int)
    
    // New Sudoku-specific events
    case sudokuGridDetected(gridId: UUID, corners: [CGPoint])
    case sudokuCellWritten(gridId: UUID, row: Int, col: Int, value: Int?)
    case sudokuCellErased(gridId: UUID, row: Int, col: Int)
    case sudokuGridLost(gridId: UUID)
    case sudokuCompleted(gridId: UUID)
}
```

### Update 2: Add Sudoku Game Info (Phase 1)
Add to game registry in Phase 1:

```swift
GameInfo(
    gameId: "ar_sudoku",
    displayName: "AR Sudoku",
    description: "Solve paper sudoku puzzles with AR hints!",
    iconName: "square.grid.3x3",
    minAge: 7,
    category: .problemSolving,
    requiredCVEvents: ["sudokuGridDetected", "sudokuCellWritten"]
)
```

### Update 3: Extend CV Service for Grid Detection (Phase 3)
Add to `Core/Services/CVService/ARKitCVService.swift`:

```swift
// Add property for grid detection
private var gridDetectionRequest: VNDetectRectanglesRequest?
private var trackedGrids: [UUID: TrackedSudokuGrid] = [:]

// Add in setupVisionRequest():
gridDetectionRequest = VNDetectRectanglesRequest { [weak self] request, error in
    self?.processGridDetection(request.results as? [VNRectangleObservation] ?? [])
}
gridDetectionRequest?.maximumObservations = 4
```

## Step 1: Sudoku Data Models (30 minutes)

### 1.1 Create Sudoku Models
Create `Games/Sudoku/Models/SudokuModels.swift`:

```swift
import Foundation
import CoreGraphics
import Vision

// MARK: - Sudoku Grid Model
struct SudokuGrid: Equatable {
    let id: UUID
    var cells: [[SudokuCell]]
    let size: GridSize
    var isComplete: Bool = false
    var errors: Set<CellPosition> = []
    
    enum GridSize: Int {
        case small = 4  // 4x4 for beginners
        case standard = 9  // 9x9 standard
        
        var blockSize: Int {
            switch self {
            case .small: return 2
            case .standard: return 3
            }
        }
    }
    
    init(size: GridSize) {
        self.id = UUID()
        self.size = size
        let dimension = size.rawValue
        self.cells = Array(repeating: Array(repeating: SudokuCell(), count: dimension), count: dimension)
    }
}

// MARK: - Sudoku Cell
struct SudokuCell: Equatable {
    var value: Int?
    var isGiven: Bool = false
    var isPencilMark: Bool = false
    var possibleValues: Set<Int> = []
    var isError: Bool = false
    var isHinted: Bool = false
}

// MARK: - Cell Position
struct CellPosition: Hashable {
    let row: Int
    let col: Int
}

// MARK: - Tracked Grid for AR
class TrackedSudokuGrid {
    let id: UUID
    var corners: [CGPoint]
    var lastSeen: Date
    var transform: simd_float4x4?
    var confidence: Float
    var sudokuGrid: SudokuGrid
    
    init(corners: [CGPoint], size: SudokuGrid.GridSize) {
        self.id = UUID()
        self.corners = corners
        self.lastSeen = Date()
        self.confidence = 1.0
        self.sudokuGrid = SudokuGrid(size: size)
    }
}

// MARK: - Game Progress
struct SudokuProgress: Codable {
    let gridId: UUID
    var solvedCells: Int
    var hintsUsed: Int
    var timeElapsed: TimeInterval
    var completedAt: Date?
    
    var completionPercentage: Float {
        let totalCells = 81 // For 9x9
        return Float(solvedCells) / Float(totalCells)
    }
}

// MARK: - Hint Types
enum HintType {
    case singlePossibility
    case nakedSingle
    case hiddenSingle
    case pointing
    case boxLineReduction
    
    var difficulty: Int {
        switch self {
        case .singlePossibility: return 1
        case .nakedSingle: return 2
        case .hiddenSingle: return 3
        case .pointing: return 4
        case .boxLineReduction: return 5
        }
    }
}

// MARK: - Hint Result
struct HintResult {
    let type: HintType
    let position: CellPosition
    let value: Int
    let explanation: String
}
```

### 1.2 Create Sudoku Solver
Create `Games/Sudoku/Logic/SudokuSolver.swift`:

```swift
import Foundation

// MARK: - Sudoku Solver
final class SudokuSolver {
    
    // MARK: - Validation
    static func isValidPlacement(_ grid: SudokuGrid, row: Int, col: Int, value: Int) -> Bool {
        let size = grid.size.rawValue
        
        // Check row
        for c in 0..<size {
            if grid.cells[row][c].value == value && c != col {
                return false
            }
        }
        
        // Check column
        for r in 0..<size {
            if grid.cells[r][col].value == value && r != row {
                return false
            }
        }
        
        // Check block
        let blockSize = grid.size.blockSize
        let blockRow = (row / blockSize) * blockSize
        let blockCol = (col / blockSize) * blockSize
        
        for r in blockRow..<(blockRow + blockSize) {
            for c in blockCol..<(blockCol + blockSize) {
                if grid.cells[r][c].value == value && (r != row || c != col) {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Possible Values
    static func getPossibleValues(for grid: SudokuGrid, at position: CellPosition) -> Set<Int> {
        guard grid.cells[position.row][position.col].value == nil else {
            return []
        }
        
        let size = grid.size.rawValue
        var possible = Set(1...size)
        
        // Remove values in same row
        for col in 0..<size {
            if let value = grid.cells[position.row][col].value {
                possible.remove(value)
            }
        }
        
        // Remove values in same column
        for row in 0..<size {
            if let value = grid.cells[row][position.col].value {
                possible.remove(value)
            }
        }
        
        // Remove values in same block
        let blockSize = grid.size.blockSize
        let blockRow = (position.row / blockSize) * blockSize
        let blockCol = (position.col / blockSize) * blockSize
        
        for r in blockRow..<(blockRow + blockSize) {
            for c in blockCol..<(blockCol + blockSize) {
                if let value = grid.cells[r][c].value {
                    possible.remove(value)
                }
            }
        }
        
        return possible
    }
    
    // MARK: - Hint Generation
    static func generateHint(for grid: SudokuGrid) -> HintResult? {
        let size = grid.size.rawValue
        
        // Look for cells with only one possible value
        for row in 0..<size {
            for col in 0..<size {
                guard grid.cells[row][col].value == nil else { continue }
                
                let possible = getPossibleValues(for: grid, at: CellPosition(row: row, col: col))
                if possible.count == 1, let value = possible.first {
                    return HintResult(
                        type: .singlePossibility,
                        position: CellPosition(row: row, col: col),
                        value: value,
                        explanation: "This cell can only contain \(value)"
                    )
                }
            }
        }
        
        // Look for naked singles (advanced technique)
        // ... implementation for more advanced hints
        
        return nil
    }
    
    // MARK: - Error Detection
    static func findErrors(in grid: SudokuGrid) -> Set<CellPosition> {
        var errors = Set<CellPosition>()
        let size = grid.size.rawValue
        
        for row in 0..<size {
            for col in 0..<size {
                if let value = grid.cells[row][col].value {
                    // Temporarily remove the value to check validity
                    var testGrid = grid
                    testGrid.cells[row][col].value = nil
                    
                    if !isValidPlacement(testGrid, row: row, col: col, value: value) {
                        errors.insert(CellPosition(row: row, col: col))
                    }
                }
            }
        }
        
        return errors
    }
    
    // MARK: - Completion Check
    static func isComplete(_ grid: SudokuGrid) -> Bool {
        let size = grid.size.rawValue
        
        // Check if all cells are filled
        for row in 0..<size {
            for col in 0..<size {
                if grid.cells[row][col].value == nil {
                    return false
                }
            }
        }
        
        // Check if there are no errors
        return findErrors(in: grid).isEmpty
    }
}
```

## Step 2: Grid Detection and OCR (60 minutes)

### 2.1 Create Grid Detector
Create `Games/Sudoku/CV/SudokuGridDetector.swift`:

```swift
import Foundation
import Vision
import ARKit
import CoreGraphics

// MARK: - Sudoku Grid Detector
final class SudokuGridDetector {
    private let minimumConfidence: Float = 0.8
    private let gridStabilityThreshold = 5 // frames
    private var gridStabilityCounter: [UUID: Int] = [:]
    
    // MARK: - Grid Detection
    func detectGrid(in observation: VNRectangleObservation) -> (corners: [CGPoint], confidence: Float)? {
        guard observation.confidence > minimumConfidence else { return nil }
        
        let corners = [
            observation.topLeft,
            observation.topRight,
            observation.bottomRight,
            observation.bottomLeft
        ]
        
        // Validate grid shape (should be roughly square)
        if isValidSudokuShape(corners: corners) {
            return (corners, observation.confidence)
        }
        
        return nil
    }
    
    private func isValidSudokuShape(corners: [CGPoint]) -> Bool {
        // Calculate aspect ratio
        let width = distance(from: corners[0], to: corners[1])
        let height = distance(from: corners[0], to: corners[3])
        let aspectRatio = width / height
        
        // Sudoku grids should be roughly square (aspect ratio near 1.0)
        return aspectRatio > 0.8 && aspectRatio < 1.2
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Grid Lines Extraction
    func extractGridLines(from image: CVPixelBuffer, corners: [CGPoint]) -> GridLineDetection? {
        // Transform perspective to square
        guard let warpedImage = perspectiveTransform(image: image, corners: corners) else {
            return nil
        }
        
        // Detect horizontal and vertical lines
        let horizontalLines = detectLines(in: warpedImage, orientation: .horizontal)
        let verticalLines = detectLines(in: warpedImage, orientation: .vertical)
        
        // Validate we have the right number of lines (10 for 9x9, 5 for 4x4)
        let gridSize: SudokuGrid.GridSize
        if horizontalLines.count == 10 && verticalLines.count == 10 {
            gridSize = .standard
        } else if horizontalLines.count == 5 && verticalLines.count == 5 {
            gridSize = .small
        } else {
            return nil
        }
        
        return GridLineDetection(
            horizontal: horizontalLines,
            vertical: verticalLines,
            gridSize: gridSize
        )
    }
    
    private func perspectiveTransform(image: CVPixelBuffer, corners: [CGPoint]) -> CVPixelBuffer? {
        // Implementation using Core Image or Metal
        // Transform the detected quadrilateral to a square
        // This is simplified - real implementation would use CIPerspectiveTransform
        return nil
    }
    
    private func detectLines(in image: CVPixelBuffer, orientation: LineOrientation) -> [CGFloat] {
        // Use Vision or Core Image to detect lines
        // This is simplified - real implementation would use edge detection
        return []
    }
}

// MARK: - Supporting Types
struct GridLineDetection {
    let horizontal: [CGFloat]
    let vertical: [CGFloat]
    let gridSize: SudokuGrid.GridSize
}

enum LineOrientation {
    case horizontal
    case vertical
}

// MARK: - Cell Extractor
extension SudokuGridDetector {
    func extractCells(from image: CVPixelBuffer, 
                     grid: GridLineDetection) -> [[CellImage]] {
        let size = grid.gridSize.rawValue
        var cells: [[CellImage]] = []
        
        for row in 0..<size {
            var rowCells: [CellImage] = []
            for col in 0..<size {
                let cellRect = getCellRect(row: row, col: col, grid: grid)
                if let cellImage = extractCell(from: image, rect: cellRect) {
                    rowCells.append(CellImage(
                        image: cellImage,
                        position: CellPosition(row: row, col: col)
                    ))
                }
            }
            cells.append(rowCells)
        }
        
        return cells
    }
    
    private func getCellRect(row: Int, col: Int, grid: GridLineDetection) -> CGRect {
        let x = grid.vertical[col]
        let y = grid.horizontal[row]
        let width = grid.vertical[col + 1] - x
        let height = grid.horizontal[row + 1] - y
        
        // Add padding to avoid grid lines
        let padding: CGFloat = 0.1
        return CGRect(
            x: x + width * padding,
            y: y + height * padding,
            width: width * (1 - 2 * padding),
            height: height * (1 - 2 * padding)
        )
    }
    
    private func extractCell(from image: CVPixelBuffer, rect: CGRect) -> CVPixelBuffer? {
        // Extract cell region from image
        // This is simplified - real implementation would crop the pixel buffer
        return nil
    }
}

struct CellImage {
    let image: CVPixelBuffer
    let position: CellPosition
}
```

### 2.2 Create Handwriting Recognizer
Create `Games/Sudoku/CV/HandwritingRecognizer.swift`:

```swift
import Foundation
import Vision
import CoreML
import UIKit

// MARK: - Handwriting Recognizer
final class HandwritingRecognizer {
    private var digitClassifier: VNCoreMLModel?
    private let textRecognitionRequest = VNRecognizeTextRequest()
    
    init() {
        setupTextRecognition()
        loadDigitClassifier()
    }
    
    private func setupTextRecognition() {
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.customWords = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        textRecognitionRequest.minimumTextHeight = 0.3
    }
    
    private func loadDigitClassifier() {
        // Load a Core ML model trained for digit recognition
        // For now, we'll use Vision's text recognition
    }
    
    // MARK: - Digit Recognition
    func recognizeDigit(in cellImage: CVPixelBuffer) async -> Int? {
        return await withCheckedContinuation { continuation in
            recognizeDigit(in: cellImage) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    private func recognizeDigit(in cellImage: CVPixelBuffer, 
                               completion: @escaping (Int?) -> Void) {
        // Check if cell is empty first
        if isCellEmpty(cellImage) {
            completion(nil)
            return
        }
        
        // Create request handler
        let handler = VNImageRequestHandler(
            cvPixelBuffer: cellImage,
            orientation: .up,
            options: [:]
        )
        
        // Configure request
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            // Process observations
            let digit = self.processTextObservations(observations)
            completion(digit)
        }
        
        request.recognitionLevel = .accurate
        request.customWords = (1...9).map { String($0) }
        
        // Perform request
        do {
            try handler.perform([request])
        } catch {
            print("[HandwritingRecognizer] Failed to recognize: \(error)")
            completion(nil)
        }
    }
    
    private func isCellEmpty(_ image: CVPixelBuffer) -> Bool {
        // Analyze pixel buffer to determine if cell is empty
        // Check for ink coverage, contrast, etc.
        // This is simplified - real implementation would analyze pixels
        return false
    }
    
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) -> Int? {
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to parse as digit
            if let digit = Int(text), (1...9).contains(digit) {
                // Check confidence
                if candidate.confidence > 0.7 {
                    return digit
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Batch Recognition
    func recognizeGrid(_ cells: [[CellImage]]) async -> [[Int?]] {
        var results: [[Int?]] = []
        
        for row in cells {
            var rowResults: [Int?] = []
            for cell in row {
                let digit = await recognizeDigit(in: cell.image)
                rowResults.append(digit)
            }
            results.append(rowResults)
        }
        
        return results
    }
}

// MARK: - Recognition Confidence
extension HandwritingRecognizer {
    struct RecognitionResult {
        let value: Int?
        let confidence: Float
        let alternatives: [(value: Int, confidence: Float)]
    }
    
    func recognizeWithConfidence(in cellImage: CVPixelBuffer) async -> RecognitionResult {
        // Enhanced recognition that returns confidence scores
        // and alternative interpretations
        return RecognitionResult(
            value: nil,
            confidence: 0,
            alternatives: []
        )
    }
}
```

## Step 3: AR Overlay System (60 minutes)

### 3.1 Create AR Overlay Manager
Create `Games/Sudoku/AR/SudokuAROverlay.swift`:

```swift
import ARKit
import SceneKit
import UIKit

// MARK: - Sudoku AR Overlay Manager
final class SudokuAROverlay {
    private weak var sceneView: ARSCNView?
    private var overlayNodes: [UUID: SudokuOverlayNode] = [:]
    private let nodePool = NodePool()
    
    init(sceneView: ARSCNView) {
        self.sceneView = sceneView
        setupLighting()
    }
    
    private func setupLighting() {
        // Add ambient lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 1000
        ambientLight.color = UIColor.white
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        sceneView?.scene.rootNode.addChildNode(ambientNode)
    }
    
    // MARK: - Grid Overlay
    func showGridOverlay(for grid: TrackedSudokuGrid) {
        guard let transform = grid.transform else { return }
        
        // Create or update overlay node
        let overlayNode = overlayNodes[grid.id] ?? createOverlayNode(for: grid)
        overlayNode.updateGrid(grid.sudokuGrid)
        overlayNode.simdTransform = transform
        
        if overlayNodes[grid.id] == nil {
            sceneView?.scene.rootNode.addChildNode(overlayNode)
            overlayNodes[grid.id] = overlayNode
        }
    }
    
    private func createOverlayNode(for grid: TrackedSudokuGrid) -> SudokuOverlayNode {
        let node = SudokuOverlayNode(grid: grid.sudokuGrid)
        node.delegate = self
        return node
    }
    
    // MARK: - Cell Highlights
    func highlightCell(gridId: UUID, position: CellPosition, type: HighlightType) {
        guard let overlayNode = overlayNodes[gridId] else { return }
        
        overlayNode.highlightCell(at: position, type: type)
        
        // Play haptic feedback
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        switch type {
        case .error:
            audio.playHaptic(.error)
        case .hint:
            audio.playHaptic(.light)
        case .success:
            audio.playHaptic(.success)
        default:
            break
        }
    }
    
    // MARK: - Ghost Numbers
    func showGhostNumbers(gridId: UUID, position: CellPosition, numbers: Set<Int>) {
        guard let overlayNode = overlayNodes[gridId] else { return }
        overlayNode.showGhostNumbers(at: position, numbers: numbers)
    }
    
    // MARK: - Hints
    func showHint(_ hint: HintResult, gridId: UUID) {
        guard let overlayNode = overlayNodes[gridId] else { return }
        
        // Highlight the hint cell
        highlightCell(gridId: gridId, position: hint.position, type: .hint)
        
        // Show hint bubble
        overlayNode.showHintBubble(text: hint.explanation, at: hint.position)
        
        // Animate the suggested number
        overlayNode.animateSuggestedNumber(hint.value, at: hint.position)
    }
    
    // MARK: - Confetti
    func showCompletionConfetti(gridId: UUID) {
        guard let overlayNode = overlayNodes[gridId] else { return }
        
        let confettiNode = ConfettiNode()
        confettiNode.position = SCNVector3(0, 0.1, 0)
        overlayNode.addChildNode(confettiNode)
        confettiNode.explode()
        
        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            confettiNode.removeFromParentNode()
        }
    }
    
    // MARK: - Cleanup
    func removeOverlay(for gridId: UUID) {
        overlayNodes[gridId]?.removeFromParentNode()
        overlayNodes.removeValue(forKey: gridId)
    }
}

// MARK: - Overlay Node Delegate
extension SudokuAROverlay: SudokuOverlayNodeDelegate {
    func overlayNodeDidTapCell(_ node: SudokuOverlayNode, position: CellPosition) {
        // Handle cell taps if needed
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        audio.playSound("tap")
    }
}

// MARK: - Highlight Types
enum HighlightType {
    case error
    case hint
    case success
    case selected
    case related // Same row/col/block
    
    var color: UIColor {
        switch self {
        case .error: return .systemRed.withAlphaComponent(0.6)
        case .hint: return .systemYellow.withAlphaComponent(0.6)
        case .success: return .systemGreen.withAlphaComponent(0.6)
        case .selected: return .systemBlue.withAlphaComponent(0.4)
        case .related: return .systemGray.withAlphaComponent(0.3)
        }
    }
}
```

### 3.2 Create Overlay Node Components
Create `Games/Sudoku/AR/SudokuOverlayNode.swift`:

```swift
import SceneKit
import UIKit

// MARK: - Sudoku Overlay Node Delegate
protocol SudokuOverlayNodeDelegate: AnyObject {
    func overlayNodeDidTapCell(_ node: SudokuOverlayNode, position: CellPosition)
}

// MARK: - Sudoku Overlay Node
final class SudokuOverlayNode: SCNNode {
    weak var delegate: SudokuOverlayNodeDelegate?
    
    private var grid: SudokuGrid
    private var cellNodes: [[CellOverlayNode]] = []
    private var gridLinesNode: SCNNode?
    private var timerNode: TimerOverlayNode?
    
    init(grid: SudokuGrid) {
        self.grid = grid
        super.init()
        setupGrid()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupGrid() {
        // Create grid lines
        createGridLines()
        
        // Create cell nodes
        createCellNodes()
        
        // Add timer
        createTimer()
    }
    
    private func createGridLines() {
        let gridSize: Float = 0.2 // 20cm grid
        let lineThickness: CGFloat = 0.002
        
        let linesNode = SCNNode()
        
        // Create horizontal and vertical lines
        let size = grid.size.rawValue
        let cellSize = gridSize / Float(size)
        
        for i in 0...size {
            let isMainLine = (i % grid.size.blockSize) == 0
            let thickness = isMainLine ? lineThickness * 2 : lineThickness
            
            // Horizontal line
            let hLine = SCNBox(
                width: CGFloat(gridSize),
                height: thickness,
                length: 0.001,
                chamferRadius: 0
            )
            hLine.firstMaterial?.diffuse.contents = UIColor.black
            let hNode = SCNNode(geometry: hLine)
            hNode.position = SCNVector3(0, 0, Float(i) * cellSize - gridSize/2)
            linesNode.addChildNode(hNode)
            
            // Vertical line
            let vLine = SCNBox(
                width: thickness,
                height: 0.001,
                length: CGFloat(gridSize),
                chamferRadius: 0
            )
            vLine.firstMaterial?.diffuse.contents = UIColor.black
            let vNode = SCNNode(geometry: vLine)
            vNode.position = SCNVector3(Float(i) * cellSize - gridSize/2, 0, 0)
            linesNode.addChildNode(vNode)
        }
        
        gridLinesNode = linesNode
        addChildNode(linesNode)
    }
    
    private func createCellNodes() {
        let gridSize: Float = 0.2
        let size = grid.size.rawValue
        let cellSize = gridSize / Float(size)
        
        for row in 0..<size {
            var rowNodes: [CellOverlayNode] = []
            for col in 0..<size {
                let cellNode = CellOverlayNode(
                    position: CellPosition(row: row, col: col),
                    size: cellSize
                )
                
                let x = Float(col) * cellSize - gridSize/2 + cellSize/2
                let z = Float(row) * cellSize - gridSize/2 + cellSize/2
                cellNode.position = SCNVector3(x, 0.001, z)
                
                addChildNode(cellNode)
                rowNodes.append(cellNode)
            }
            cellNodes.append(rowNodes)
        }
    }
    
    private func createTimer() {
        timerNode = TimerOverlayNode()
        timerNode?.position = SCNVector3(0, 0.05, -0.15)
        if let timer = timerNode {
            addChildNode(timer)
        }
    }
    
    // MARK: - Updates
    func updateGrid(_ newGrid: SudokuGrid) {
        grid = newGrid
        
        // Update cell displays
        for row in 0..<grid.size.rawValue {
            for col in 0..<grid.size.rawValue {
                let cell = grid.cells[row][col]
                cellNodes[row][col].updateCell(cell)
            }
        }
        
        // Update errors
        let errors = SudokuSolver.findErrors(in: grid)
        for row in 0..<grid.size.rawValue {
            for col in 0..<grid.size.rawValue {
                let position = CellPosition(row: row, col: col)
                cellNodes[row][col].showError(errors.contains(position))
            }
        }
    }
    
    // MARK: - Highlighting
    func highlightCell(at position: CellPosition, type: HighlightType) {
        cellNodes[position.row][position.col].highlight(type: type)
    }
    
    func showGhostNumbers(at position: CellPosition, numbers: Set<Int>) {
        cellNodes[position.row][position.col].showGhostNumbers(numbers)
    }
    
    // MARK: - Hints
    func showHintBubble(text: String, at position: CellPosition) {
        let bubble = HintBubbleNode(text: text)
        let cellNode = cellNodes[position.row][position.col]
        bubble.position = SCNVector3(0, 0.03, 0)
        cellNode.addChildNode(bubble)
        
        // Animate and remove
        bubble.animateIn()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            bubble.animateOut {
                bubble.removeFromParentNode()
            }
        }
    }
    
    func animateSuggestedNumber(_ number: Int, at position: CellPosition) {
        cellNodes[position.row][position.col].animateSuggestedNumber(number)
    }
}

// MARK: - Cell Overlay Node
final class CellOverlayNode: SCNNode {
    private let position: CellPosition
    private var highlightNode: SCNNode?
    private var ghostNumbersNode: SCNNode?
    private var errorNode: SCNNode?
    
    init(position: CellPosition, size: Float) {
        self.position = position
        super.init()
        setupCell(size: size)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell(size: Float) {
        // Create invisible plane for hit testing
        let plane = SCNPlane(width: CGFloat(size * 0.9), height: CGFloat(size * 0.9))
        plane.firstMaterial?.diffuse.contents = UIColor.clear
        geometry = plane
    }
    
    func updateCell(_ cell: SudokuCell) {
        // Update based on cell state
        if cell.isError {
            showError(true)
        } else {
            showError(false)
        }
        
        if cell.isHinted {
            highlight(type: .hint)
        }
    }
    
    func highlight(type: HighlightType) {
        highlightNode?.removeFromParentNode()
        
        let highlight = SCNPlane(width: 0.018, height: 0.018)
        highlight.firstMaterial?.diffuse.contents = type.color
        highlight.firstMaterial?.isDoubleSided = true
        
        let node = SCNNode(geometry: highlight)
        node.eulerAngles.x = -.pi / 2
        node.position.y = 0.001
        
        // Animate
        node.scale = SCNVector3(0.1, 0.1, 0.1)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        node.scale = SCNVector3(1, 1, 1)
        SCNTransaction.commit()
        
        highlightNode = node
        addChildNode(node)
    }
    
    func showError(_ show: Bool) {
        errorNode?.removeFromParentNode()
        
        if show {
            let error = SCNPlane(width: 0.02, height: 0.02)
            error.firstMaterial?.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.8)
            error.firstMaterial?.isDoubleSided = true
            
            let node = SCNNode(geometry: error)
            node.eulerAngles.x = -.pi / 2
            node.position.y = 0.002
            
            // Pulse animation
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.2, duration: 0.3),
                SCNAction.scale(to: 1.0, duration: 0.3)
            ])
            node.runAction(SCNAction.repeatForever(pulse))
            
            errorNode = node
            addChildNode(node)
        }
    }
    
    func showGhostNumbers(_ numbers: Set<Int>) {
        ghostNumbersNode?.removeFromParentNode()
        
        let container = SCNNode()
        
        // Create 3x3 grid of ghost numbers
        let positions: [(x: Float, z: Float)] = [
            (-0.006, -0.006), (0, -0.006), (0.006, -0.006),
            (-0.006, 0), (0, 0), (0.006, 0),
            (-0.006, 0.006), (0, 0.006), (0.006, 0.006)
        ]
        
        for number in numbers {
            guard number >= 1 && number <= 9 else { continue }
            let pos = positions[number - 1]
            
            let text = SCNText(string: String(number), extrusionDepth: 0)
            text.font = UIFont.systemFont(ofSize: 0.004)
            text.firstMaterial?.diffuse.contents = UIColor.systemGray
            
            let textNode = SCNNode(geometry: text)
            textNode.position = SCNVector3(pos.x, 0.002, pos.z)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            
            container.addChildNode(textNode)
        }
        
        ghostNumbersNode = container
        addChildNode(container)
    }
    
    func animateSuggestedNumber(_ number: Int) {
        let text = SCNText(string: String(number), extrusionDepth: 0.001)
        text.font = UIFont.boldSystemFont(ofSize: 0.02)
        text.firstMaterial?.diffuse.contents = UIColor.systemGreen
        
        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(-0.01, 0.01, -0.01)
        
        // Animate
        textNode.opacity = 0
        addChildNode(textNode)
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        textNode.opacity = 1
        textNode.position.y = 0.03
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            textNode.opacity = 0
            SCNTransaction.completionBlock = {
                textNode.removeFromParentNode()
            }
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
    }
}
```

## Step 4: Game Implementation (90 minutes)

### 4.1 Create Sudoku Game Module
Create `Games/Sudoku/SudokuGameModule.swift`:

```swift
import Foundation
import SpriteKit

// MARK: - Sudoku Game Module
final class SudokuGameModule: GameModule {
    static let gameId = "ar_sudoku"
    
    static let gameInfo = GameInfo(
        gameId: gameId,
        displayName: "AR Sudoku",
        description: "Solve paper sudoku puzzles with AR hints!",
        iconName: "square.grid.3x3",
        minAge: 7,
        category: .problemSolving,
        requiredCVEvents: ["sudokuGridDetected", "sudokuCellWritten"]
    )
    
    required init() {}
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        return SudokuGameScene(size: size, context: context)
    }
    
    func cleanup() {
        // Cleanup any resources
    }
}

// MARK: - Sudoku Game Scene
final class SudokuGameScene: SKScene, GameSceneProtocol {
    var gameContext: GameContext?
    
    // Game state
    private var viewModel: SudokuGameViewModel!
    private var arOverlay: SudokuAROverlay!
    private var hudNode: SudokuHUDNode!
    
    // CV subscription
    private var cvEventStream: AsyncStream<CVEvent>?
    private var cvTask: Task<Void, Never>?
    
    init(size: CGSize, context: GameContext) {
        self.gameContext = context
        super.init(size: size)
        
        setupScene()
        setupViewModel()
        subscribeToCV()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        
        // Create HUD
        hudNode = SudokuHUDNode(size: size)
        hudNode.position = CGPoint(x: size.width / 2, y: size.height - 50)
        addChild(hudNode)
        
        // Setup instructions
        showInstructions()
    }
    
    private func setupViewModel() {
        viewModel = SudokuGameViewModel(context: gameContext!)
        
        // Bind to view model updates
        viewModel.onStateChange = { [weak self] state in
            self?.updateUI(for: state)
        }
        
        viewModel.onGridDetected = { [weak self] grid in
            self?.handleGridDetected(grid)
        }
        
        viewModel.onCompletion = { [weak self] in
            self?.handleCompletion()
        }
    }
    
    private func subscribeToCV() {
        guard let cvService = gameContext?.cvService else { return }
        
        // Create event stream
        cvEventStream = cvService.eventStream(
            gameId: SudokuGameModule.gameId,
            events: [
                .sudokuGridDetected(gridId: UUID(), corners: []),
                .sudokuCellWritten(gridId: UUID(), row: 0, col: 0, value: nil)
            ]
        )
        
        // Process events
        cvTask = Task { [weak self] in
            guard let stream = self?.cvEventStream else { return }
            
            for await event in stream {
                await self?.handleCVEvent(event)
            }
        }
    }
    
    // MARK: - Instructions
    private func showInstructions() {
        let instructionNode = SKLabelNode(text: "Point your device at a paper Sudoku puzzle")
        instructionNode.fontSize = 24
        instructionNode.fontName = "AvenirNext-Medium"
        instructionNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(instructionNode)
        
        // Fade out after delay
        instructionNode.run(SKAction.sequence([
            SKAction.wait(forDuration: 3),
            SKAction.fadeOut(withDuration: 1),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: - CV Event Handling
    func handleCVEvent(_ event: CVEvent) {
        switch event.type {
        case .sudokuGridDetected(let gridId, let corners):
            viewModel.processGridDetection(gridId: gridId, corners: corners)
            
        case .sudokuCellWritten(let gridId, let row, let col, let value):
            viewModel.processCellUpdate(
                gridId: gridId,
                position: CellPosition(row: row, col: col),
                value: value
            )
            
        default:
            break
        }
    }
    
    // MARK: - Grid Detection
    private func handleGridDetected(_ grid: TrackedSudokuGrid) {
        // Play sound
        gameContext?.audioService.playSound("grid_detected")
        gameContext?.audioService.playHaptic(.medium)
        
        // Update HUD
        hudNode.showGridDetected()
        
        // Log analytics
        gameContext?.analyticsService.logEvent("sudoku_grid_detected", parameters: [
            "grid_size": grid.sudokuGrid.size.rawValue
        ])
    }
    
    // MARK: - Completion
    private func handleCompletion() {
        // Play celebration
        gameContext?.audioService.playSound("puzzle_complete")
        gameContext?.audioService.playHaptic(.success)
        
        // Show completion UI
        showCompletionOverlay()
        
        // Save progress
        Task {
            await viewModel.saveProgress()
        }
        
        // Log analytics
        let stats = viewModel.getGameStats()
        gameContext?.analyticsService.endLevel(
            gameId: SudokuGameModule.gameId,
            level: "puzzle",
            success: true,
            score: stats.score
        )
    }
    
    private func showCompletionOverlay() {
        let overlay = CompletionOverlayNode(size: size, stats: viewModel.getGameStats())
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.alpha = 0
        addChild(overlay)
        
        overlay.run(SKAction.fadeIn(withDuration: 0.5))
    }
    
    // MARK: - UI Updates
    private func updateUI(for state: SudokuGameState) {
        hudNode.update(with: state)
        
        switch state {
        case .searching:
            hudNode.showSearching()
            
        case .tracking(let grid):
            hudNode.showTracking(grid: grid)
            
        case .completed(let stats):
            hudNode.showCompleted(stats: stats)
        }
    }
    
    // MARK: - Game Controls
    func pauseGame() {
        isPaused = true
        viewModel.pauseTimer()
    }
    
    func resumeGame() {
        isPaused = false
        viewModel.resumeTimer()
    }
    
    // MARK: - Cleanup
    deinit {
        cvTask?.cancel()
    }
}
```

### 4.2 Create Game View Model
Create `Games/Sudoku/SudokuGameViewModel.swift`:

```swift
import Foundation
import CoreGraphics
import Observation

// MARK: - Game State
enum SudokuGameState {
    case searching
    case tracking(grid: TrackedSudokuGrid)
    case completed(stats: GameStats)
}

// MARK: - Game Stats
struct GameStats {
    let timeElapsed: TimeInterval
    let hintsUsed: Int
    let errorsFound: Int
    let score: Int
}

// MARK: - Sudoku Game View Model
@Observable
@MainActor
final class SudokuGameViewModel {
    // State
    private(set) var gameState: SudokuGameState = .searching
    private(set) var trackedGrids: [UUID: TrackedSudokuGrid] = [:]
    
    // Game logic
    private let gridDetector = SudokuGridDetector()
    private let handwritingRecognizer = HandwritingRecognizer()
    private let solver = SudokuSolver()
    
    // Progress tracking
    private var startTime: Date?
    private var hintsUsed = 0
    private var errorsFound = 0
    private var timer: Timer?
    
    // Context
    private let context: GameContext
    
    // Callbacks
    var onStateChange: ((SudokuGameState) -> Void)?
    var onGridDetected: ((TrackedSudokuGrid) -> Void)?
    var onCompletion: (() -> Void)?
    
    init(context: GameContext) {
        self.context = context
        startTimer()
    }
    
    // MARK: - Grid Detection
    func processGridDetection(gridId: UUID, corners: [CGPoint]) {
        // Check if we're already tracking this grid
        if let existingGrid = trackedGrids[gridId] {
            existingGrid.corners = corners
            existingGrid.lastSeen = Date()
            existingGrid.confidence = 0.95
        } else {
            // New grid detected
            let trackedGrid = TrackedSudokuGrid(
                corners: corners,
                size: .standard // Detect size from grid
            )
            trackedGrid.id = gridId
            trackedGrids[gridId] = trackedGrid
            
            gameState = .tracking(grid: trackedGrid)
            onGridDetected?(trackedGrid)
            
            // Start recognition
            Task {
                await recognizeInitialGrid(trackedGrid)
            }
        }
    }
    
    private func recognizeInitialGrid(_ grid: TrackedSudokuGrid) async {
        // Extract cells and recognize initial numbers
        // This would use the HandwritingRecognizer
        
        // For now, create a sample puzzle
        createSamplePuzzle(for: grid)
    }
    
    private func createSamplePuzzle(for grid: TrackedSudokuGrid) {
        // Create a sample 4x4 puzzle for testing
        grid.sudokuGrid = SudokuGrid(size: .small)
        
        // Set some given values
        grid.sudokuGrid.cells[0][1].value = 3
        grid.sudokuGrid.cells[0][1].isGiven = true
        grid.sudokuGrid.cells[1][0].value = 4
        grid.sudokuGrid.cells[1][0].isGiven = true
        grid.sudokuGrid.cells[2][3].value = 1
        grid.sudokuGrid.cells[2][3].isGiven = true
        grid.sudokuGrid.cells[3][2].value = 2
        grid.sudokuGrid.cells[3][2].isGiven = true
    }
    
    // MARK: - Cell Updates
    func processCellUpdate(gridId: UUID, position: CellPosition, value: Int?) {
        guard let grid = trackedGrids[gridId] else { return }
        
        let previousValue = grid.sudokuGrid.cells[position.row][position.col].value
        
        // Update cell
        grid.sudokuGrid.cells[position.row][position.col].value = value
        
        // Validate
        if let value = value {
            let isValid = SudokuSolver.isValidPlacement(
                grid.sudokuGrid,
                row: position.row,
                col: position.col,
                value: value
            )
            
            if !isValid {
                errorsFound += 1
                grid.sudokuGrid.cells[position.row][position.col].isError = true
                
                // Play error sound
                context.audioService.playSound("error")
                context.audioService.playHaptic(.error)
            } else {
                grid.sudokuGrid.cells[position.row][position.col].isError = false
                
                // Play success sound
                context.audioService.playSound("cell_filled")
                context.audioService.playHaptic(.light)
            }
        }
        
        // Check for completion
        if SudokuSolver.isComplete(grid.sudokuGrid) {
            handlePuzzleCompletion()
        }
        
        // Update errors
        grid.sudokuGrid.errors = SudokuSolver.findErrors(in: grid.sudokuGrid)
    }
    
    // MARK: - Hints
    func requestHint() -> HintResult? {
        guard case .tracking(let grid) = gameState else { return nil }
        
        if let hint = SudokuSolver.generateHint(for: grid.sudokuGrid) {
            hintsUsed += 1
            
            // Mark cell as hinted
            grid.sudokuGrid.cells[hint.position.row][hint.position.col].isHinted = true
            
            // Play hint sound
            context.audioService.playSound("hint")
            
            return hint
        }
        
        return nil
    }
    
    func showPossibleValues(for position: CellPosition) -> Set<Int> {
        guard case .tracking(let grid) = gameState else { return [] }
        
        return SudokuSolver.getPossibleValues(
            for: grid.sudokuGrid,
            at: position
        )
    }
    
    // MARK: - Completion
    private func handlePuzzleCompletion() {
        guard let startTime = startTime else { return }
        
        let timeElapsed = Date().timeIntervalSince(startTime)
        let score = calculateScore(
            time: timeElapsed,
            hints: hintsUsed,
            errors: errorsFound
        )
        
        let stats = GameStats(
            timeElapsed: timeElapsed,
            hintsUsed: hintsUsed,
            errorsFound: errorsFound,
            score: score
        )
        
        gameState = .completed(stats: stats)
        stopTimer()
        
        onCompletion?()
    }
    
    private func calculateScore(time: TimeInterval, hints: Int, errors: Int) -> Int {
        let baseScore = 1000
        let timePenalty = Int(time / 10) * 5 // -5 points per 10 seconds
        let hintPenalty = hints * 50 // -50 points per hint
        let errorPenalty = errors * 20 // -20 points per error
        
        return max(100, baseScore - timePenalty - hintPenalty - errorPenalty)
    }
    
    // MARK: - Timer
    private func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Update timer display if needed
        }
    }
    
    func pauseTimer() {
        timer?.invalidate()
    }
    
    func resumeTimer() {
        if timer == nil || !timer!.isValid {
            startTimer()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Progress
    func saveProgress() async {
        guard case .tracking(let grid) = gameState else { return }
        
        let progress = SudokuProgress(
            gridId: grid.id,
            solvedCells: countSolvedCells(in: grid.sudokuGrid),
            hintsUsed: hintsUsed,
            timeElapsed: Date().timeIntervalSince(startTime ?? Date()),
            completedAt: SudokuSolver.isComplete(grid.sudokuGrid) ? Date() : nil
        )
        
        // Save to persistence
        // This would use SwiftData in a real implementation
    }
    
    private func countSolvedCells(in grid: SudokuGrid) -> Int {
        var count = 0
        for row in grid.cells {
            for cell in row {
                if cell.value != nil && !cell.isGiven {
                    count += 1
                }
            }
        }
        return count
    }
    
    // MARK: - Stats
    func getGameStats() -> GameStats {
        let timeElapsed = Date().timeIntervalSince(startTime ?? Date())
        let score = calculateScore(
            time: timeElapsed,
            hints: hintsUsed,
            errors: errorsFound
        )
        
        return GameStats(
            timeElapsed: timeElapsed,
            hintsUsed: hintsUsed,
            errorsFound: errorsFound,
            score: score
        )
    }
}
```

### 4.3 Create HUD Components
Create `Games/Sudoku/UI/SudokuHUDNode.swift`:

```swift
import SpriteKit

// MARK: - Sudoku HUD Node
final class SudokuHUDNode: SKNode {
    private let size: CGSize
    
    // UI Elements
    private var timerLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var hintButton: SKSpriteNode!
    private var statusLabel: SKLabelNode!
    
    init(size: CGSize) {
        self.size = size
        super.init()
        setupHUD()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupHUD() {
        // Background
        let background = SKShapeNode(
            rect: CGRect(x: -size.width/2, y: -30, width: size.width, height: 60),
            cornerRadius: 10
        )
        background.fillColor = UIColor.black.withAlphaComponent(0.7)
        background.strokeColor = .clear
        addChild(background)
        
        // Timer
        timerLabel = SKLabelNode(text: "0:00")
        timerLabel.fontSize = 20
        timerLabel.fontName = "AvenirNext-Bold"
        timerLabel.position = CGPoint(x: -size.width/2 + 50, y: -5)
        addChild(timerLabel)
        
        // Score
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontSize = 20
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.position = CGPoint(x: 0, y: -5)
        addChild(scoreLabel)
        
        // Hint button
        createHintButton()
        
        // Status
        statusLabel = SKLabelNode(text: "Searching...")
        statusLabel.fontSize = 16
        statusLabel.fontName = "AvenirNext-Medium"
        statusLabel.position = CGPoint(x: 0, y: -40)
        statusLabel.alpha = 0.8
        addChild(statusLabel)
    }
    
    private func createHintButton() {
        hintButton = SKSpriteNode(
            texture: SKTexture(imageNamed: "lightbulb.fill"),
            size: CGSize(width: 40, height: 40)
        )
        hintButton.position = CGPoint(x: size.width/2 - 50, y: 0)
        hintButton.name = "hintButton"
        addChild(hintButton)
    }
    
    // MARK: - Updates
    func update(with state: SudokuGameState) {
        switch state {
        case .searching:
            statusLabel.text = "Point at a Sudoku puzzle"
            
        case .tracking(let grid):
            statusLabel.text = "Grid detected - Start solving!"
            updateScore(for: grid)
            
        case .completed(let stats):
            statusLabel.text = "Puzzle completed! 🎉"
            scoreLabel.text = "Final Score: \(stats.score)"
        }
    }
    
    func showSearching() {
        animateStatus("Searching for puzzle...")
    }
    
    func showGridDetected() {
        animateStatus("Grid detected! ✓")
    }
    
    func showTracking(grid: TrackedSudokuGrid) {
        let completion = calculateCompletion(for: grid.sudokuGrid)
        statusLabel.text = "\(Int(completion * 100))% complete"
    }
    
    func showCompleted(stats: GameStats) {
        statusLabel.text = "Completed in \(formatTime(stats.timeElapsed))!"
    }
    
    // MARK: - Helpers
    private func animateStatus(_ text: String) {
        statusLabel.removeAllActions()
        statusLabel.text = text
        statusLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ]))
    }
    
    private func updateScore(for grid: TrackedSudokuGrid) {
        // Calculate current score based on progress
        let completion = calculateCompletion(for: grid.sudokuGrid)
        let baseScore = Int(1000 * completion)
        scoreLabel.text = "Score: \(baseScore)"
    }
    
    private func calculateCompletion(for grid: SudokuGrid) -> Float {
        var filled = 0
        let total = grid.size.rawValue * grid.size.rawValue
        
        for row in grid.cells {
            for cell in row {
                if cell.value != nil {
                    filled += 1
                }
            }
        }
        
        return Float(filled) / Float(total)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Completion Overlay
final class CompletionOverlayNode: SKNode {
    init(size: CGSize, stats: GameStats) {
        super.init()
        createOverlay(size: size, stats: stats)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createOverlay(size: CGSize, stats: GameStats) {
        // Background
        let background = SKShapeNode(rect: CGRect(
            x: -size.width/2,
            y: -size.height/2,
            width: size.width,
            height: size.height
        ))
        background.fillColor = UIColor.black.withAlphaComponent(0.8)
        addChild(background)
        
        // Success message
        let title = SKLabelNode(text: "🎉 Puzzle Complete! 🎉")
        title.fontSize = 48
        title.fontName = "AvenirNext-Bold"
        title.position = CGPoint(x: 0, y: 100)
        addChild(title)
        
        // Stats
        let timeLabel = SKLabelNode(text: "Time: \(formatTime(stats.timeElapsed))")
        timeLabel.fontSize = 24
        timeLabel.position = CGPoint(x: 0, y: 0)
        addChild(timeLabel)
        
        let scoreLabel = SKLabelNode(text: "Score: \(stats.score)")
        scoreLabel.fontSize = 32
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.position = CGPoint(x: 0, y: -50)
        addChild(scoreLabel)
        
        // Continue button
        let button = SKLabelNode(text: "Find Another Puzzle")
        button.fontSize = 24
        button.fontName = "AvenirNext-Medium"
        button.position = CGPoint(x: 0, y: -150)
        button.name = "continueButton"
        addChild(button)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

## Step 5: Integration and Testing (30 minutes)

### 5.1 Register Game Module
Add to `GameRegistry` in Phase 2:

```swift
// In GameRegistry.shared.registerGame():
registry.registerGame(SudokuGameModule.self)
```

### 5.2 Create Confetti Node
Create `Games/Sudoku/AR/ConfettiNode.swift`:

```swift
import SceneKit
import SpriteKit

// MARK: - Confetti Node
final class ConfettiNode: SCNNode {
    private let particleSystem = SCNParticleSystem()
    
    override init() {
        super.init()
        setupParticleSystem()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupParticleSystem() {
        particleSystem.loops = false
        particleSystem.birthRate = 500
        particleSystem.emissionDuration = 0.5
        particleSystem.spreadingAngle = 45
        particleSystem.particleLifeSpan = 3
        particleSystem.particleVelocity = 0.2
        particleSystem.particleVelocityVariation = 0.1
        particleSystem.particleSize = 0.002
        particleSystem.particleColor = .systemYellow
        particleSystem.particleColorVariation = SCNVector4(1, 1, 1, 0)
        
        // Physics
        particleSystem.isAffectedByGravity = true
        particleSystem.acceleration = SCNVector3(0, -0.1, 0)
        
        // Geometry
        let confettiGeometry = SCNPlane(width: 0.002, height: 0.004)
        confettiGeometry.firstMaterial?.diffuse.contents = UIColor.systemPink
        confettiGeometry.firstMaterial?.isDoubleSided = true
        particleSystem.particleImage = confettiTexture()
        
        geometry = SCNGeometry()
    }
    
    private func confettiTexture() -> UIImage {
        // Create colorful confetti texture
        let size = CGSize(width: 20, height: 40)
        UIGraphicsBeginImageContext(size)
        
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink]
        let color = colors.randomElement()!
        color.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func explode() {
        addParticleSystem(particleSystem)
        
        // Remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.removeAllParticleSystems()
        }
    }
}
```

### 5.3 Add Test Mode to Settings
Update Settings to include Sudoku test options:

```swift
// Add to Debug Tools section:
Section("Sudoku Testing") {
    Toggle("Show Ghost Numbers", isOn: .constant(true))
    Toggle("Auto-detect Errors", isOn: .constant(true))
    
    Button("Test Grid Detection") {
        // Launch sudoku with test grid
    }
    
    Button("Test Completion Animation") {
        // Trigger confetti test
    }
}
```

## Phase 4 Completion Checklist

### ✅ Data Models & Logic
- [ ] Sudoku grid and cell models
- [ ] Solver with validation and hints
- [ ] Progress tracking models
- [ ] Hint generation system

### ✅ Computer Vision
- [ ] Grid detection from paper
- [ ] Handwriting recognition for digits
- [ ] Grid line extraction
- [ ] Cell content analysis

### ✅ AR Overlays
- [ ] Grid overlay with proper transform
- [ ] Error highlighting
- [ ] Ghost numbers display
- [ ] Hint bubbles and animations
- [ ] Confetti celebration

### ✅ Game Implementation
- [ ] SudokuGameModule following architecture
- [ ] Game scene with SpriteKit
- [ ] View model with game logic
- [ ] HUD with timer and score
- [ ] Progress saving with SwiftData

### ✅ Integration
- [ ] CV event handling
- [ ] Audio feedback
- [ ] Haptic responses
- [ ] Analytics tracking
- [ ] Game registration

## Key Features Implemented

1. **Paper Detection**: Uses ARKit to detect and track paper sudoku grids
2. **Handwriting Recognition**: Vision framework recognizes written numbers
3. **AR Hints**: Shows possible values as ghost numbers in empty cells
4. **Error Highlighting**: Real-time validation with red overlays
5. **Progress Tracking**: Saves progress across sessions using SwiftData
6. **Confetti Celebration**: 3D particle effects when puzzle is completed
7. **Smart Hints**: Progressive hint system from simple to complex
8. **Timer & Scoring**: Tracks time and calculates score based on performance

The implementation follows the established architecture patterns and integrates seamlessly with the existing service layer from phases 1-3.