# Tic-Tac-Toe Game Design Document

## Overview
Paper-based tic-tac-toe game using computer vision to detect the board and player moves. Players draw a tic-tac-toe grid on paper and play against the AI by physically marking X's and O's.

## Game Flow

### 1. Setup Phase
- User draws empty 3x3 tic-tac-toe grid on paper
- Holds paper up to camera
- Game detects grid using rectangle detection
- User presses "Start Game" button
- Random selection of who goes first (user or AI)

### 2. Gameplay Phase
**AI Turn:**
- AI calculates optimal move using minimax algorithm
- Displays move overlay on camera preview (X or O in chosen cell)
- User marks AI's move on physical paper
- User holds paper back up to camera

**User Turn:**
- User marks their move (X or O) on paper
- Holds paper up to camera
- CV detects new mark and its position
- Game validates move and updates state

### 3. End Phase
- Game detects win/draw condition
- Displays result with celebration animation
- Offers rematch or return to lobby

## Technical Integration

### CV Events Required
```swift
enum TicTacToeCVEvent {
    case gridDetected(corners: [CGPoint])
    case cellMarked(row: Int, col: Int, symbol: Symbol)
    case gridLost
    case multipleGridsDetected
}
```

### CV Detection Strategy

#### Grid Detection
- Use existing rectangle detection from ARKitCVService
- Validate 3x3 grid structure by detecting internal lines
- Track grid corners for perspective transformation
- Maintain grid ID for continuous tracking

#### Move Detection
1. **Baseline Capture**: Store empty grid image after detection
2. **Difference Analysis**: Compare current frame to baseline
3. **Symbol Recognition**: 
   - Use shape detection for X (two intersecting lines)
   - Use circle detection for O
   - Fallback to any significant mark in cell
4. **Cell Mapping**: Transform detected position to grid coordinates

### Game Architecture

#### TicTacToeGameModule
```swift
final class TicTacToeGameModule: GameModule {
    static let gameId = "tic-tac-toe"
    static let gameInfo = GameInfo(
        title: "Tic-Tac-Toe",
        description: "Classic paper tic-tac-toe with AI opponent",
        iconName: "grid.3x3",
        category: .strategy,
        minPlayers: 1,
        maxPlayers: 1
    )
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        return TicTacToeGameScene(size: size, gameContext: context)
    }
}
```

#### TicTacToeViewModel
```swift
@Observable
final class TicTacToeViewModel {
    // Game state
    var board: [[CellState]] = Array(repeating: Array(repeating: .empty, count: 3), count: 3)
    var currentPlayer: Player = .user
    var gamePhase: GamePhase = .setup
    var aiDifficulty: Difficulty = .medium
    
    // CV state
    var isGridDetected = false
    var gridCorners: [CGPoint]?
    var lastProcessedImage: CVImageBuffer?
    
    // Game logic
    func makeMove(row: Int, col: Int) { }
    func calculateAIMove() -> (row: Int, col: Int) { }
    func checkWinCondition() -> GameResult? { }
    func resetGame() { }
}
```

#### TicTacToeGameScene
- Extends SKScene with GameSceneProtocol
- Subscribes to CV events via AsyncStream
- Renders:
  - Grid overlay when detected
  - AI move suggestions
  - Win/draw animations
  - Score display

### AI Strategy

#### Difficulty Levels
1. **Easy**: Random valid moves
2. **Medium**: Block obvious wins, occasional smart moves
3. **Hard**: Minimax algorithm with full game tree search

#### Minimax Implementation
```swift
func minimax(board: [[CellState]], depth: Int, isMaximizing: Bool) -> Int {
    // Terminal state evaluation
    if let result = checkWinCondition() {
        return result == .aiWin ? 10 - depth : depth - 10
    }
    
    // Recursive minimax logic
    if isMaximizing {
        // AI's turn - maximize score
    } else {
        // User's turn - minimize score
    }
}
```

### Visual Design

#### Camera Preview Overlay
- Semi-transparent grid alignment guide during setup
- Glowing cell highlights for AI moves
- Success checkmarks for detected user moves
- Red X for invalid move attempts

#### Animations
- Particle effects for wins
- Smooth transitions between game phases
- Haptic feedback for moves and wins

### Error Handling

#### CV Errors
- **Grid not detected**: Show alignment guide
- **Multiple grids**: Prompt to show only one
- **Unclear marks**: Ask user to make marks clearer
- **Lost tracking**: Smoothly re-acquire grid

#### Game Errors  
- **Invalid moves**: Show error message
- **Ambiguous marks**: Highlight uncertain cell
- **Timeout**: Gentle reminder to continue

### Performance Optimization

#### CV Processing
- Process every 3rd frame (10 FPS) for move detection
- Cache baseline image for difference calculation
- Use region of interest for cell-specific detection
- Implement confidence thresholds for move validation

#### Memory Management
- Release baseline images when game ends
- Limit history to last 3 frames
- Use thumbnail resolution for difference detection

### Accessibility

- VoiceOver support for grid state
- Audio cues for moves and game events
- High contrast mode for better visibility
- Alternative input via tap gestures

### Analytics Events

```swift
struct TicTacToeAnalytics {
    static let gameStarted = "tictactoe_game_started"
    static let moveMade = "tictactoe_move_made"
    static let gameCompleted = "tictactoe_game_completed"
    static let cvDetectionFailed = "tictactoe_cv_detection_failed"
}
```

### Testing Strategy

#### Unit Tests
- Game logic (minimax, win detection)
- Board state management
- Move validation

#### Integration Tests
- CV event handling
- Service communication
- State persistence

#### UI Tests
- Game flow scenarios
- Error recovery
- Accessibility

### Future Enhancements

1. **Multiplayer Mode**: Two humans using different symbols
2. **Advanced CV**: Handwriting recognition for X/O style
3. **Tournament Mode**: Best of 3/5 matches
4. **Custom Boards**: 4x4 or 5x5 variants
5. **AR Mode**: Virtual board overlay on table

### Dependencies

- ARKitCVService for vision processing
- AudioEngineService for sound effects
- AnalyticsService for event tracking
- PersistenceService for statistics
- SpriteKit for game rendering

### Success Metrics

- Grid detection rate > 95%
- Move detection accuracy > 90%
- Average game completion time < 2 minutes
- User satisfaction rating > 4.5/5