# Sudoku Implementation Tracker

## Overview
This document tracks the implementation of the Sudoku game for the Osmo platform. The game will support both 4x4 and 9x9 grids with computer vision detection of physical tiles placed on a tabletop surface.

## Game Requirements

### Core Features
- **Grid Sizes**: 4x4 (Mini) and 9x9 (Classic)
- **Setup Mode**: User places initial tiles to create puzzle
- **Play Mode**: User solves puzzle by placing numbered tiles
- **CV Detection**: Detect board, tile positions, and numbers (upside down from camera view)
- **Validation**: Real-time checking of placed tiles
- **Visual Feedback**: 
  - ✅ Thumbs up animation for correct placement
  - ❌ Thumbs down for incorrect placement
  - ⚠️ Warning for moving original tiles
  - 🎉 Celebration animation on completion
- **Timer**: Shows solving duration
- **Board Tracking**: Resume game if camera loses/regains board view
- **Status Indicator**: Green circle when board is detected and tracked

### UI/UX Requirements
- Smooth, flicker-free interface
- Portrait mode camera orientation
- Board viewed at angle (numbers appear upside down)
- Minimal UI overlay on camera view
- Non-intrusive feedback animations

## Technical Architecture

### Game Module Structure
```
Games/
└── Sudoku/
    ├── SudokuGameModule.swift
    ├── SudokuGameScene.swift
    ├── SudokuViewModel.swift
    ├── Models/
    │   ├── SudokuModels.swift
    │   ├── SudokuBoard.swift
    │   └── SudokuValidator.swift
    └── CV/
        ├── SudokuBoardDetector.swift
        └── SudokuNumberRecognizer.swift
```

### Key Components

#### 1. SudokuGameModule
- Game registration and initialization
- CV event requirements: rectangleDetected, textDetected
- Game configuration for 4x4 and 9x9 modes

#### 2. SudokuViewModel
```swift
@Observable
final class SudokuViewModel {
    // Game State
    var gameMode: GameMode = .setup
    var gridSize: GridSize = .fourByFour
    var board: SudokuBoard
    var initialBoard: SudokuBoard // Locked positions
    var timer: TimeInterval = 0
    var isGameComplete = false
    
    // CV State
    var isBoardDetected = false
    var boardConfidence: Float = 0.0
    var detectedTiles: [TileDetection] = []
    var boardTransform: CGAffineTransform?
    
    // Validation
    var lastPlacedTile: TilePosition?
    var validationResult: ValidationResult?
}
```

#### 3. SudokuBoard Model
```swift
struct SudokuBoard {
    let size: GridSize
    private(set) var grid: [[Int?]]
    private(set) var isLocked: [[Bool]]
    
    mutating func place(number: Int, at position: Position) -> PlacementResult
    func isValid(number: Int, at position: Position) -> Bool
    func isSolved() -> Bool
}
```

#### 4. CV Integration

##### Board Detection
- Use `rectangleDetected` events to find board outline
- Apply perspective correction for angled view
- Track board position across frames
- Handle board loss/recovery gracefully

##### Number Recognition
- Process detected rectangles as potential tiles
- Use Vision framework's text recognition
- Handle upside-down numbers (rotate 180°)
- Filter noise and validate detected numbers

##### Detection Pipeline
```swift
1. Detect large rectangle (board)
2. Divide into grid cells (4x4 or 9x9)
3. For each cell:
   - Detect if tile present
   - If tile, recognize number
   - Track position stability
4. Update game state with confident detections
```

### Visual Design

#### Game Scene Layout
```
┌─────────────────────────┐
│  🟢 Board Detected      │ <- Status indicator
│                         │
│    Timer: 02:34        │ <- Solving timer
│                         │
│  ┌─────────────────┐   │
│  │                 │   │ <- Camera view with
│  │  Board Overlay  │   │    grid overlay
│  │                 │   │
│  └─────────────────┘   │
│                         │
│  [Stop Game]           │ <- Control button
└─────────────────────────┘
```

#### Feedback Animations
- **Correct Placement**: Green thumbs up floats up and fades
- **Incorrect Placement**: Red thumbs down with shake animation
- **Original Tile Warning**: Yellow warning icon with "Please return tile"
- **Completion**: Confetti burst with "Puzzle Solved!" message

### Game Flow

#### Setup Phase
1. User selects grid size (4x4 or 9x9)
2. "Setup your puzzle" instruction shown
3. User places numbered tiles on physical board
4. CV detects and tracks tile positions
5. User taps "Start Solving" when ready
6. Initial positions locked as puzzle constraints

#### Solving Phase
1. Timer starts
2. Board state continuously monitored
3. Each tile placement triggers validation
4. Visual feedback for placement results
5. Warning if original tiles moved
6. Game completes when all cells correctly filled

#### Board Tracking
- Continuous board detection with smoothing
- Position/rotation interpolation to reduce flicker
- Grace period for temporary occlusion
- Clear indicators when board lost/found

### CV Event Handling

```swift
func handleCVEvent(_ event: CVEvent) {
    switch event.type {
    case .rectangleDetected(let rectangles):
        processBoardDetection(rectangles)
        
    case .textDetected(let text, let boundingBox):
        processNumberDetection(text, at: boundingBox)
        
    case .rectangleLost:
        handleBoardLost()
    }
}
```

### Validation Logic

#### 4x4 Rules
- Numbers 1-4 in each row
- Numbers 1-4 in each column
- Numbers 1-4 in each 2x2 box

#### 9x9 Rules
- Numbers 1-9 in each row
- Numbers 1-9 in each column
- Numbers 1-9 in each 3x3 box

### Performance Optimizations

1. **Board Detection Caching**: Only recompute when significant change
2. **Tile Detection Throttling**: Process at 15 FPS for efficiency
3. **Number Recognition Queue**: Prioritize cells near recent activity
4. **Smooth UI Updates**: Interpolate positions, batch animations

### Error Handling

1. **No Board Detected**: Show setup guide overlay
2. **Poor Lighting**: Suggest better lighting conditions
3. **Ambiguous Numbers**: Require higher confidence threshold
4. **Multiple Boards**: Focus on largest/most centered

## Implementation Plan

### Phase 1: Core Game Logic
- [ ] Create game module structure
- [ ] Implement SudokuBoard model with validation
- [ ] Create 4x4 and 9x9 puzzle generators
- [ ] Implement game state management

### Phase 2: CV Integration
- [ ] Create board detection algorithm
- [ ] Implement grid cell mapping
- [ ] Add number recognition with rotation handling
- [ ] Create tile tracking system

### Phase 3: Visual Layer
- [ ] Design game scene with SpriteKit
- [ ] Implement board overlay visualization
- [ ] Create feedback animations
- [ ] Add timer and status displays

### Phase 4: Game Flow
- [ ] Implement setup mode
- [ ] Create solving mode with validation
- [ ] Add completion detection and celebration
- [ ] Handle board tracking edge cases

### Phase 5: Polish
- [ ] Optimize CV performance
- [ ] Smooth all animations
- [ ] Add sound effects
- [ ] Implement difficulty presets

## Technical Decisions

### Why Rectangle Detection?
- More reliable than individual tile detection
- Provides stable reference frame
- Enables perspective correction
- Allows grid inference

### Number Recognition Strategy
1. Use Vision framework's VNRecognizeTextRequest
2. Apply 180° rotation for upside-down view
3. Confidence threshold: 0.8 for acceptance
4. Validate numbers are in valid range (1-4 or 1-9)

### Board Tracking Approach
- Kalman filter for position smoothing
- Homography tracking between frames
- Recovery strategy with template matching
- Visual indicator for tracking quality

## Risk Mitigation

### CV Challenges
1. **Upside-down numbers**: Pre-rotate image regions
2. **Variable lighting**: Adaptive thresholding
3. **Tile occlusion**: Temporal consistency checks
4. **Board warping**: Perspective transformation

### UX Considerations
1. **Clear feedback**: Immediate visual responses
2. **Error recovery**: Graceful handling of CV failures
3. **Performance**: Maintain 30+ FPS during play
4. **Accessibility**: Alternative input methods

## Testing Strategy

### Unit Tests
- Board validation logic
- Puzzle generation algorithms
- Game state transitions

### Integration Tests
- CV detection accuracy
- Frame-to-frame tracking
- Number recognition rates

### Performance Tests
- CV processing latency
- UI responsiveness
- Memory usage patterns

## Next Steps

1. Create Sudoku game directory structure
2. Implement core board model and validation
3. Design CV detection pipeline
4. Create initial game scene
5. Integrate with existing CV service

## Notes

### Advantages of Our Approach
- Leverages existing rectangle detection
- Builds on proven game architecture
- Natural progression from RPS complexity
- Engaging tabletop interaction

### Key Differentiators
- Physical tile manipulation
- Real-time validation feedback
- Smooth board tracking
- Multiple grid sizes

### Success Metrics
- Board detection accuracy > 95%
- Number recognition accuracy > 90%
- Game completion rate > 80%
- Average FPS > 30