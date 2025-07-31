# Sudoku Game Design Document

## Overview
Paper-based Sudoku game with computer vision assistance. Players solve Sudoku puzzles on paper while the app provides real-time validation, hints, and error detection through camera-based digit recognition and constraint checking.

## Game Flow

### 1. Setup Phase
- User selects difficulty level (Easy/Medium/Hard/Expert)
- App generates puzzle or user shows existing paper puzzle
- For app-generated: Display puzzle grid, user copies to paper
- For existing puzzle: User shows puzzle to camera for scanning
- Game captures baseline empty cells

### 2. Gameplay Phase
**Solving Process:**
- User writes digits in cells on paper
- Holds paper up to camera periodically
- CV detects new digits and positions
- Real-time validation of moves
- Visual feedback for errors/conflicts

**Assistance Features:**
- Hint system (shows possible values)
- Error highlighting (conflicting cells)
- Progress tracking (% complete)
- Note mode (small pencil marks)

### 3. Completion Phase
- Automatic detection of completed puzzle
- Validation of solution
- Time and score calculation
- Statistics update
- Option for new puzzle

## Technical Integration

### CV Events Required
```swift
enum SudokuCVEvent {
    case gridDetected(gridId: UUID, corners: [CGPoint])
    case cellWritten(gridId: UUID, row: Int, col: Int, digit: Int)
    case cellErased(gridId: UUID, row: Int, col: Int)
    case pencilMarkDetected(gridId: UUID, row: Int, col: Int, marks: Set<Int>)
    case gridLost
    case multipleGridsDetected
    case ocrConfidence(row: Int, col: Int, confidence: Float)
}
```

### CV Detection Strategy

#### Grid Detection
1. **Rectangle Detection**: Find largest rectangle in frame
2. **Grid Validation**: 
   - Detect internal lines (8 horizontal, 8 vertical)
   - Verify 9x9 structure
   - Account for thick box borders (3x3 sections)
3. **Perspective Correction**: Transform to square grid
4. **Cell Extraction**: Divide into 81 cells

#### Digit Recognition
```swift
struct DigitRecognition {
    func recognizeDigit(in cellImage: CVImageBuffer) -> (digit: Int?, confidence: Float) {
        // 1. Preprocess: Threshold, denoise, center
        let processed = preprocessCell(cellImage)
        
        // 2. Feature extraction
        let features = extractFeatures(processed)
        
        // 3. Classification (CoreML or Vision)
        let prediction = digitClassifier.predict(features)
        
        // 4. Confidence threshold
        return prediction.confidence > 0.85 ? 
            (prediction.digit, prediction.confidence) : (nil, 0.0)
    }
}
```

#### Advanced Detection Features
1. **Pencil Mark Recognition**: Detect small digits in corners
2. **Handwriting Adaptation**: Learn user's digit style
3. **Incremental Updates**: Track only changed cells
4. **Error Recovery**: Handle partial occlusion

### Game Architecture

#### SudokuGameModule
```swift
final class SudokuGameModule: GameModule {
    static let gameId = "sudoku"
    static let gameInfo = GameInfo(
        title: "Sudoku",
        description: "Classic number puzzle with CV assistance",
        iconName: "square.grid.3x3",
        category: .puzzle,
        minPlayers: 1,
        maxPlayers: 1
    )
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        return SudokuGameScene(size: size, gameContext: context)
    }
}
```

#### SudokuViewModel
```swift
@Observable
final class SudokuViewModel {
    // Game state
    private(set) var puzzle: SudokuPuzzle
    private(set) var solution: [[Int]]
    private(set) var userGrid: [[Int?]]
    private(set) var pencilMarks: [[[Bool]]] // 9x9x9 array
    
    // Game settings
    var difficulty: Difficulty = .medium
    var showErrors = true
    var showHints = true
    var noteMode = false
    
    // CV state
    private(set) var isGridDetected = false
    private(set) var gridCorners: [CGPoint]?
    private(set) var lastScanTime: Date?
    private(set) var detectionConfidence: Float = 0.0
    
    // Progress tracking
    private(set) var startTime: Date
    private(set) var moveCount = 0
    private(set) var hintCount = 0
    private(set) var errorCount = 0
    
    // Validation
    private(set) var conflicts: Set<CellPosition> = []
    private(set) var availableNumbers: [[Set<Int>]] = []
    
    // Core methods
    func generatePuzzle(difficulty: Difficulty) { }
    func validateMove(row: Int, col: Int, digit: Int) -> Bool { }
    func checkConflicts() -> Set<CellPosition> { }
    func getHint() -> CellHint? { }
    func calculateScore() -> Int { }
}
```

#### SudokuGameScene
```swift
final class SudokuGameScene: SKScene, GameSceneProtocol {
    // Visual components
    private var gridOverlay: SKShapeNode!
    private var conflictHighlights: [SKShapeNode] = []
    private var hintLabels: [SKLabelNode] = []
    private var progressBar: SKShapeNode!
    
    // Grid visualization
    private func createGridOverlay() {
        gridOverlay = SKShapeNode()
        
        // Main grid lines
        for i in 0...9 {
            let width: CGFloat = i % 3 == 0 ? 3.0 : 1.0
            // Draw horizontal and vertical lines
        }
        
        // Cell highlights for errors
        for conflict in viewModel.conflicts {
            let highlight = createCellHighlight(
                row: conflict.row,
                col: conflict.col,
                color: .systemRed
            )
            conflictHighlights.append(highlight)
        }
    }
    
    // AR overlay for hints
    private func showHintOverlay(for cell: CellPosition) {
        let possibleValues = viewModel.availableNumbers[cell.row][cell.col]
        let hintNode = createHintNode(values: possibleValues)
        positionHintNode(hintNode, at: cell)
    }
}
```

### Puzzle Generation

#### Difficulty Levels
```swift
enum Difficulty {
    case easy    // 45-50 given numbers
    case medium  // 35-40 given numbers
    case hard    // 28-32 given numbers
    case expert  // 22-27 given numbers
    
    var givenCells: ClosedRange<Int> {
        switch self {
        case .easy:   return 45...50
        case .medium: return 35...40
        case .hard:   return 28...32
        case .expert: return 22...27
        }
    }
}
```

#### Generation Algorithm
```swift
class SudokuGenerator {
    func generate(difficulty: Difficulty) -> SudokuPuzzle {
        // 1. Generate complete valid grid
        let solution = generateCompleteSolution()
        
        // 2. Remove cells based on difficulty
        let puzzle = removeClues(
            from: solution,
            targetCount: difficulty.givenCells.randomElement()!
        )
        
        // 3. Ensure unique solution
        guard hasUniqueSolution(puzzle) else {
            return generate(difficulty: difficulty) // Retry
        }
        
        return SudokuPuzzle(
            given: puzzle,
            solution: solution,
            difficulty: difficulty
        )
    }
}
```

### Solving Assistance

#### Hint System
```swift
enum HintType {
    case single(row: Int, col: Int, digit: Int)
    case elimination(row: Int, col: Int, impossible: Set<Int>)
    case pattern(technique: SolvingTechnique, cells: [CellPosition])
}

struct SolvingTechnique {
    enum Technique {
        case nakedSingle
        case hiddenSingle
        case nakedPair
        case pointingPair
        case boxLineReduction
        case xWing
        case swordfish
    }
    
    let name: String
    let difficulty: Int  // 1-10 scale
    let description: String
}
```

#### Smart Hints Implementation
```swift
class HintEngine {
    func getNextHint(for puzzle: SudokuState) -> HintType? {
        // Try techniques in order of difficulty
        if let single = findNakedSingle(puzzle) {
            return .single(single.row, single.col, single.digit)
        }
        
        if let hidden = findHiddenSingle(puzzle) {
            return .single(hidden.row, hidden.col, hidden.digit)
        }
        
        if let pair = findNakedPair(puzzle) {
            return .pattern(
                technique: .nakedPair,
                cells: pair.cells
            )
        }
        
        // Continue with advanced techniques...
        return nil
    }
}
```

### Visual Design

#### Camera Overlay
```
┌─────────────────────────────┐
│ Difficulty: Medium  ⏱ 05:42 │
├─────────────────────────────┤
│                             │
│    [Camera Preview with     │
│     Grid Detection          │
│     Overlay and Digit       │
│     Recognition]            │
│                             │
├─────────────────────────────┤
│ Progress: ████████░░ 78%    │
│ Errors: 2  Hints: 1         │
└─────────────────────────────┘
```

#### Grid Overlay Features
- Green borders: Valid cells
- Red highlights: Conflicting cells
- Blue numbers: Given clues
- Black numbers: User entries
- Gray numbers: Pencil marks
- Yellow pulse: Recent changes

### Performance Optimization

#### CV Processing Pipeline
```swift
class SudokuCVPipeline {
    private let processQueue = DispatchQueue(
        label: "sudoku.cv",
        qos: .userInitiated
    )
    
    private var lastProcessedGrid: [[Int?]]?
    private var frameSkipCounter = 0
    
    func processFrame(_ buffer: CVImageBuffer) {
        // Skip frames for performance
        frameSkipCounter += 1
        guard frameSkipCounter % 3 == 0 else { return }
        
        processQueue.async { [weak self] in
            // 1. Quick grid detection check
            guard let corners = self?.detectGrid(buffer) else { return }
            
            // 2. Extract and process only changed cells
            let changes = self?.detectChangedCells(buffer, corners: corners)
            
            // 3. Run OCR on changed cells only
            for change in changes ?? [] {
                self?.recognizeDigit(at: change)
            }
        }
    }
}
```

#### Memory Management
- Cache detected grid for 5 seconds
- Store only cell differences
- Limit OCR history to 10 frames
- Release resources on background

### Error Handling

#### CV Challenges
1. **Poor Handwriting**
   - Show confidence indicator
   - Request clearer writing
   - Provide digit examples

2. **Grid Distortion**
   - Guide for better angle
   - Support rotated grids
   - Handle partial visibility

3. **Lighting Issues**
   - Auto-adjust exposure
   - Shadow compensation
   - Glare detection

4. **Multiple Digits in Cell**
   - Detect erasure attempts
   - Prefer darker/larger digit
   - Show ambiguity warning

### Analytics Events

```swift
struct SudokuAnalytics {
    static let puzzleStarted = "sudoku_puzzle_started"
    static let digitEntered = "sudoku_digit_entered"
    static let hintRequested = "sudoku_hint_requested"
    static let errorMade = "sudoku_error_made"
    static let puzzleCompleted = "sudoku_puzzle_completed"
    static let puzzleAbandoned = "sudoku_puzzle_abandoned"
    
    struct Properties {
        static let difficulty = "difficulty"
        static let cellPosition = "cell_position"
        static let digit = "digit"
        static let timeElapsed = "time_elapsed"
        static let completionTime = "completion_time"
        static let errorCount = "error_count"
        static let hintCount = "hint_count"
        static let technique = "solving_technique"
    }
}
```

### Accessibility

#### Features
- VoiceOver grid navigation
- Audio feedback for moves
- High contrast mode
- Digit announcement
- Conflict description

#### Implementation
```swift
extension SudokuGameScene {
    func setupAccessibility() {
        // Grid navigation
        gridOverlay.isAccessibilityElement = true
        gridOverlay.accessibilityTraits = .allowsDirectInteraction
        gridOverlay.accessibilityLabel = "Sudoku grid, 9 by 9"
        
        // Custom rotor for navigation
        let rowRotor = UIAccessibilityCustomRotor(name: "Rows") { predicate in
            // Navigate by row
        }
        
        let boxRotor = UIAccessibilityCustomRotor(name: "3x3 Boxes") { predicate in
            // Navigate by box
        }
    }
}
```

### Testing Strategy

#### Unit Tests
- Puzzle generation validity
- Solution uniqueness
- Hint accuracy
- Conflict detection

#### CV Tests
- Grid detection accuracy
- Digit recognition rates
- Performance benchmarks
- Edge case handling

#### Integration Tests
- End-to-end solving flow
- Hint system integration
- Analytics tracking
- Error recovery

### Future Enhancements

1. **Puzzle Sharing**: QR codes for puzzle exchange
2. **Daily Challenges**: New puzzle every day
3. **Speed Mode**: Timed competitions
4. **Tutorial Mode**: Interactive solving lessons
5. **Custom Puzzles**: User-created challenges
6. **Variant Support**: Killer, Samurai Sudoku
7. **Cloud Sync**: Progress across devices
8. **Social Features**: Compete with friends

### Success Metrics

- Grid detection rate > 95%
- Digit recognition accuracy > 90%
- Average completion rate > 70%
- Hint usage < 3 per puzzle
- User session length > 10 minutes