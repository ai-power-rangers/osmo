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
- Detect quadrilateral shapes (not perfect rectangles due to angle)
- Use corner detection to find board bounds
- Apply perspective transformation to normalize view
- Track board position with smoothing for stability
- Handle partial occlusion and recovery

##### Number Recognition
- Process each grid cell for tile presence
- Rotate image 180° before text recognition (upside down view)
- Use Vision framework's VNRecognizeTextRequest
- Confidence threshold adjustment for angled text
- Validate numbers are in valid range

##### Detection Pipeline
```swift
1. Detect quadrilateral board shape
   - Find 4 corners using edge detection
   - Validate aspect ratio for 4x4 or 9x9
2. Apply perspective transform
   - Warp quadrilateral to square
   - Create normalized grid coordinates
3. For each grid cell:
   - Check for tile presence (contrast detection)
   - If tile detected:
     - Extract cell region
     - Rotate 180° for text recognition
     - Apply OCR with confidence threshold
   - Track detection stability over frames
4. Update virtual board with smooth transitions
```

##### Visual Feedback System
```swift
// Split screen design
struct SudokuGameScene {
    // Top half: Camera feed with minimal overlay
    var cameraView: CameraPreviewLayer
    var boardOutlineOverlay: QuadrilateralShape // Shows detected corners
    
    // Bottom half: Virtual board representation
    var virtualBoard: SudokuBoardView {
        - Clean grid visualization
        - Smooth tile appearance animations
        - Number transitions with fade effects
        - Locked tiles shown with different style
    }
    
    // Debug overlay (bottom section)
    var debugInfo: DebugOverlay {
        - Board detection confidence
        - FPS counter
        - Current detections queue
    }
}
```

### Visual Design

#### Game Scene Layout
```
┌─────────────────────────┐
│  🟢 Board Detected      │ <- Status indicator
│    Timer: 02:34        │ <- Solving timer
│                         │
│  ┌─────────────────┐   │
│  │                 │   │ <- Camera view (top half)
│  │   Camera Feed   │   │    Shows physical board
│  │                 │   │
│  ├─────────────────┤   │
│  │  Virtual Board  │   │ <- Virtual board (bottom half)
│  │   [2][_][4][1]  │   │    Shows detected state
│  │   [_][3][_][_]  │   │    Smooth transitions
│  │   Debug: FPS 30 │   │    Debug info overlay
│  └─────────────────┘   │
│                         │
│  [Stop Game]           │ <- Control button
└─────────────────────────┘
```

#### Feedback Animations (Overlay on Camera View)
- **Correct Placement**: Green thumbs up floats up from tile position
- **Incorrect Placement**: Red thumbs down with subtle shake
- **Original Tile Warning**: Yellow ⚠️ pulses at tile location
- **Completion**: Confetti burst across full screen

#### Virtual Board Updates
- **Tile Detection**: Smooth scale-up animation (0.3s ease-out)
- **Number Recognition**: Fade transition between states
- **Tile Removal**: Scale-down with fade (0.2s)
- **Board State**: Continuous interpolation of detected values
- **Confidence Indication**: Opacity based on detection confidence

### Game Flow

#### Initial Board Setup (Pre-placed Tiles)
1. User selects grid size (4x4 or 9x9)
2. "Place your Sudoku board with initial tiles" instruction shown
3. User places physical board with numbered tiles already set up as the puzzle
4. CV system detects:
   - Board boundaries (quadrilateral detection)
   - Which cells contain tiles
   - Numbers on each tile (handling 180° rotation)
5. Visual confirmation shows:
   - Green border around detected board
   - Grid overlay showing detected structure
   - Numbers displayed in each detected cell
   - Confidence indicators for detection quality
6. User verifies detection is correct
7. User taps "Start Game" when satisfied with detection
8. Initial tile positions are locked as puzzle constraints

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
        // Board will appear as quadrilateral, not perfect rectangle
        processQuadrilateralDetection(rectangles)
        
    case .textDetected(let text, let boundingBox):
        // Numbers are upside down - rotate before recognition
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

## Comprehensive Board Detection Plan

### Phase 1: Fix Rectangle Detection (Immediate)

#### 1.1 Grid Size Communication
```swift
// Problem: Hardcoded gridSize in CameraVisionService
// Solution: Pass grid size through processor initialization
func setupProcessor(for gameId: String, configuration: [String: Any]) {
    switch gameId {
    case SudokuGameModule.gameId:
        let gridSize = configuration["gridSize"] as? GridSize ?? .nineByNine
        activeProcessor = SudokuBoardProcessor(gridSize: gridSize)
    }
}
```

#### 1.2 Relax Detection Parameters
```swift
// Current (too strict)
minimumSize: 0.3
minimumArea: 10000
angleRange: 60-120°

// New (more flexible)
minimumSize: 0.2  // 20% of frame
minimumArea: 5000
angleRange: 45-135°
confidenceThreshold: 0.5  // Lower from 0.6
```

#### 1.3 Debug Visualization
- Show ALL detected rectangles (not just validated ones)
- Color code: Green (valid), Yellow (detected but invalid), Red (no detection)
- Display rejection reasons on screen

### Phase 2: Progressive Detection States

#### 2.1 Detection State Machine
```
1. Searching → "Place board in view"
   - No rectangles detected
   - Show placement guide overlay
   
2. Detecting → "Board found, analyzing..."
   - Rectangle detected but not validated
   - Show yellow outline
   
3. Stabilizing → "Hold steady..."
   - Valid board, building confidence
   - Show pulsing green outline
   
4. Confirmed → "Board locked! Reading tiles..."
   - Stable detection for 10+ frames
   - Solid green outline
   - Begin tile detection
```

#### 2.2 Visual Feedback Layers
```
Layer 1: Board Detection
├── Rectangle outline (color-coded by state)
├── Corner markers
├── Confidence percentage
└── Detection state message

Layer 2: Grid Structure
├── Grid lines (once board confirmed)
├── Cell highlights (processing)
└── Cell numbers (1-16 or 1-81)

Layer 3: Tile Detection
├── Detected tile markers
├── Number overlays
├── Confidence indicators
└── Processing animation

Layer 4: Validation
├── Initial tile locks
├── Empty cell indicators
└── Ready state visualization
```

### Phase 3: Text Detection After Board Confirmation

#### 3.1 Cell-by-Cell Processing
```swift
// Only after board is stable for 10+ frames
func processTextInCells() {
    for row in 0..<gridSize {
        for col in 0..<gridSize {
            let cellRegion = extractCellRegion(row: row, col: col)
            let rotatedRegion = rotate180(cellRegion)
            let textResult = recognizeText(in: rotatedRegion)
            
            if textResult.confidence > 0.7 {
                updateCellDetection(row: row, col: col, number: textResult.value)
            }
        }
    }
}
```

#### 3.2 Temporal Smoothing
- Require 3 consistent detections before confirming a number
- Track detection history per cell
- Show confidence building animation

### Phase 4: Board Validation Flow

#### 4.1 Initial Detection
1. User places board with pre-set tiles
2. System detects board outline
3. Overlays grid structure
4. Begins cell scanning

#### 4.2 Tile Recognition
1. For each cell:
   - Check contrast (tile present?)
   - If tile: Extract, rotate, OCR
   - Build confidence over frames
2. Show live detection status per cell

#### 4.3 Confirmation UI
```
┌─────────────────────────┐
│ 🟢 Board Detected       │
│                         │
│  ╔═══╦═══╦═══╦═══╗    │
│  ║ 2 ║   ║ 4 ║ 1 ║    │ <- Detected numbers
│  ╠═══╬═══╬═══╬═══╣    │    with confidence
│  ║   ║ 3 ║   ║   ║    │    indicators
│  ╠═══╬═══╬═══╬═══╣    │
│  ║ 1 ║   ║   ║ 4 ║    │
│  ╠═══╬═══╬═══╬═══╣    │
│  ║   ║   ║ 2 ║   ║    │
│  ╚═══╩═══╩═══╩═══╝    │
│                         │
│ Detected: 7/16 tiles    │
│ [Start Game] (enabled)  │
└─────────────────────────┘
```

### Phase 5: Debug Mode Implementation

#### 5.1 Debug Overlay Information
- FPS counter
- Detection pipeline timing
- Raw Vision framework output
- Coordinate transformation visualization
- Confidence scores per detection
- Rejection reasons for invalid detections

#### 5.2 Debug Controls
- Toggle Vision output visualization
- Adjust detection thresholds in real-time
- Save/load detection snapshots
- Export detection logs

## Implementation Plan

### Phase 1: Fix Core Detection Issues
- [ ] Fix grid size propagation from UI to CV processor
- [ ] Relax board validation criteria
- [ ] Add debug visualization for all detected rectangles
- [ ] Implement proper event subscription

### Phase 2: Implement Detection States
- [ ] Create state machine for board detection
- [ ] Add visual feedback for each state
- [ ] Implement temporal smoothing
- [ ] Add confidence building animations

### Phase 3: Text Recognition Integration
- [ ] Implement cell extraction after board confirmation
- [ ] Add 180° rotation for upside-down text
- [ ] Create per-cell confidence tracking
- [ ] Build detection history system

### Phase 4: User Experience Polish
- [ ] Design confirmation UI
- [ ] Add progress indicators
- [ ] Create smooth transitions
- [ ] Implement error recovery

### Phase 5: Testing & Optimization
- [ ] Test with various lighting conditions
- [ ] Optimize for different board angles
- [ ] Fine-tune detection parameters
- [ ] Add performance monitoring

## Technical Decisions

### Why Rectangle Detection?
- More reliable than individual tile detection
- Provides stable reference frame
- Enables perspective correction
- Allows grid inference

### Quadrilateral Detection Strategy
1. Use VNDetectRectanglesRequest with low aspect ratio tolerance
2. Find largest quadrilateral in frame
3. Validate 4 corners are detected
4. Check angles are roughly 90° (with tolerance for perspective)
5. Apply perspective transform to normalize

### Number Recognition Strategy
1. Extract cell regions from normalized board
2. Pre-process: Rotate 180° for upside-down numbers
3. Use VNRecognizeTextRequest with custom configuration
4. Lower confidence threshold (0.6) due to angle/lighting
5. Validate numbers are in valid range (1-4 or 1-9)
6. Use temporal smoothing - require 3 consistent detections

### Board Tracking Approach
- Corner tracking with optical flow for smooth updates
- Exponential moving average for corner positions
- Perspective transform interpolation
- Recovery: If board lost, show last known state with fade
- Visual indicator: Green circle when tracking, yellow when recovering

### Virtual Board Design
- Clean, modern grid visualization
- Initial tiles: Bold with subtle background
- User tiles: Regular weight with animations
- Empty cells: Light gray placeholder
- Smooth transitions: 
  - Tile appearance: Scale up + fade in (0.3s)
  - Number changes: Cross-fade (0.2s)
  - Board updates: Synchronized with detection confidence

## Risk Mitigation

### CV Challenges
1. **Angled board detection**: Quadrilateral detection instead of rectangle
2. **Upside-down numbers**: 180° rotation before OCR
3. **Perspective distortion**: Real-time perspective correction
4. **Variable lighting**: Adaptive thresholding per cell
5. **Tile occlusion**: Temporal consistency (3-frame validation)
6. **Board movement**: Smooth corner tracking with prediction

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