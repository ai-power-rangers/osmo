# Technology Stack & Game Development Guide

## Overview

This guide provides practical implementation guidance for developing games on the Osmo platform. All games follow consistent patterns, inherit from base classes, and use native iOS technologies.

## Framework Choices

### SpriteKit - Game Scenes
**Use for:** All gameplay rendering and interaction
- Game boards and pieces
- Drag and drop interactions  
- Rotation and flip animations
- Visual feedback (highlights, hints)
- Particle effects for success/completion

**Standard Implementation:**
- All games **MUST** inherit from `BaseGameScene: SKScene`
- Pieces are `SKNode` subclasses
- Use **gesture recognizers ONLY** (no touchesBegan/Moved/Ended)
- Consistent grid/coordinate system provided by BaseGameScene

### SwiftUI - UI & Navigation
**Use for:** Everything outside actual gameplay
- Main navigation and lobbies
- Settings and configuration screens
- Puzzle/level selection lists
- Save/load dialogs
- Parent gate and parental controls
- Game setup editors (initial/target states)

**Standard Implementation:**
- `NavigationStack` for app flow (native iOS navigation)
- `AppRoute` enum for type-safe navigation
- Sheet presentations for editors
- Consistent `UIConstants` (Spacing, AppColors) design system
- Forms for metadata editing

### Native iOS Patterns Only
- **Navigation**: NavigationStack with value-based routing
- **State Management**: @Observable pattern
- **Async Operations**: async/await
- **Data Flow**: SwiftUI environment injection
- **NO custom coordinators or navigation abstractions**

## Foundation Layer (Required for ALL Games)

### BaseGameScene

Every game scene **MUST** inherit from `BaseGameScene`:

```swift
class YourGameScene: BaseGameScene {
    override func didMove(to view: SKView) {
        super.didMove(to: view)  // REQUIRED - sets up gestures and coordinate system
        
        // The base class provides:
        // - gameContext: GameContext? (access to services)
        // - viewModel: BaseGameViewModel? (state management)
        // - unitSize: CGFloat (screen points per unit)
        // - Gesture recognizers (pan, tap, rotation)
        // - Coordinate conversion methods
        // - Grid snapping functionality
        
        // Your game-specific setup here
        configureGameSpecificElements()
    }
    
    // Override gesture handlers as needed
    override func handleTap(at point: CGPoint) {
        let unitPos = screenToUnit(point)
        // Game-specific tap handling
    }
    
    override func handlePan(from: CGPoint, to: CGPoint, state: UIGestureRecognizer.State) {
        // Game-specific drag handling
    }
}
```

**IMPORTANT**: Never implement touchesBegan/touchesMoved/touchesEnded. Use the gesture recognizers provided by BaseGameScene.

### BaseGameViewModel

Every game view model **MUST** inherit from `BaseGameViewModel`:

```swift
@Observable
final class YourGameViewModel: BaseGameViewModel<YourGamePuzzle> {
    // BaseGameViewModel provides:
    // - currentPuzzle: PuzzleType?
    // - gameState: GameState
    // - isComplete: Bool
    // - Undo/redo functionality
    // - Save/load operations
    // - Timer management
    
    // Add ONLY game-specific logic
    override func validateCurrentState() -> Bool {
        // Your validation logic
        return super.validateCurrentState() && yourGameSpecificValidation()
    }
}
```

### GamePuzzleProtocol

All puzzle types **MUST** implement `GamePuzzleProtocol`:

```swift
struct YourGamePuzzle: GamePuzzleProtocol {
    // Required properties
    var id: String
    var name: String
    var difficulty: PuzzleDifficulty
    var createdAt: Date
    var updatedAt: Date
    
    // Required associated types
    typealias PieceType = YourPieceType
    typealias StateType = YourStateType
    
    // Required state properties
    var initialState: StateType
    var targetState: StateType
    var currentState: StateType
    
    // Required methods
    func isCompleted() -> Bool {
        return currentState == targetState
    }
    
    func isValid() -> Bool {
        // Your validation logic
    }
    
    func reset() {
        currentState = initialState
    }
}
```

## Implementing Game Mathematics

### Using the Unit System

All games use the unified coordinate system provided by `BaseGameScene`:

```swift
class YourGameScene: BaseGameScene {
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Configure grid for your game (inherited from BaseGameScene)
        gridStep = 0.25  // 1/4 unit snapping (standard)
        gridEnabled = true  // Show visual grid
    }
    
    // Use inherited coordinate conversion methods
    override func handlePan(from: CGPoint, to: CGPoint, state: UIGestureRecognizer.State) {
        // Convert screen coordinates to unit space
        let unitPos = screenToUnit(to)
        
        // Apply grid snapping (inherited method)
        let snappedPos = snapToGrid(unitPos)
        
        // Validate bounds (0-8 units)
        let validPos = CGPoint(
            x: max(0, min(8, snappedPos.x)),
            y: max(0, min(8, snappedPos.y))
        )
        
        // Convert back to screen space for rendering
        node.position = unitToScreen(validPos)
        
        // Update game model
        viewModel?.updatePiecePosition(nodeId: node.name, position: validPos)
    }
}
```

### Standard Grid Configuration

```swift
struct GameGridConfig {
    // Visual grid (what players see)
    static let majorGridLines: CGFloat = 1.0   // Every 1 unit
    static let minorGridLines: CGFloat = 0.25  // Every 1/4 unit
    
    // Interaction grid (where pieces snap)
    static let snapIncrement: CGFloat = 0.25   // 1/4 unit steps
    static let snapTolerance: CGFloat = 0.15   // Snap within 0.15 units
    
    // Storage precision
    static let storagePrecision: CGFloat = 0.1 // Save with 0.1 precision
}
```

## State Management

### Game States (Using GameState Enum)

All games use the `GameState` enum from Core/GameBase:

```swift
enum GameState {
    case initializing
    case ready
    case playing
    case paused
    case validating
    case completed
    case error(String)
}
```

**NO GKStateMachine** - Use the simple enum-based state management in BaseGameViewModel.

### State Transitions

```swift
class YourGameViewModel: BaseGameViewModel<YourGamePuzzle> {
    func handlePlayerAction() {
        guard gameState == .playing else { return }
        
        // Update game
        updateGameLogic()
        
        // Check completion
        if validateCurrentState() {
            gameState = .completed
            handleCompletion()
        }
    }
}
```

## Navigation Pattern

### Using Native NavigationStack

All navigation uses the native iOS NavigationStack with AppRoute:

```swift
// AppRoute.swift defines all navigation destinations
enum AppRoute: Hashable {
    case game(gameId: String, puzzleId: String?)
    case yourGameEditor(puzzleId: String? = nil)
    case yourGamePuzzleSelect
}

// Navigation in your game views
struct YourGameMenuView: View {
    var body: some View {
        NavigationLink(value: AppRoute.yourGameEditor()) {
            Text("Create Puzzle")
        }
        
        NavigationLink(value: AppRoute.game(gameId: "your-game", puzzleId: nil)) {
            Text("Play Game")
        }
    }
}
```

**NO custom navigation coordinators or abstractions - use NavigationStack directly.**

## Consistent Game Architecture

### Game Module Structure

Every game follows this exact structure:

```
Games/YourGame/
├── YourGameModule.swift         # Implements GameModule protocol
├── YourGameScene.swift          # Inherits from BaseGameScene
├── YourGameViewModel.swift      # Inherits from BaseGameViewModel
├── YourGameEditor.swift         # Puzzle editor (SwiftUI)
├── YourGamePlayView.swift       # Play interface (SwiftUI)
├── Models/
│   ├── YourGamePuzzle.swift    # Implements GamePuzzleProtocol
│   ├── YourGameModels.swift    # Game-specific models
│   └── YourGameStorage.swift   # Inherits from BasePuzzleStorage
└── Views/
    └── YourGameViews.swift      # Game-specific UI components
```

### Game Module Implementation

```swift
final class YourGameModule: GameModule {
    static let gameId = "your-game"
    static let gameInfo = GameInfo(
        gameId: gameId,
        displayName: "Your Game",
        description: "Game description",
        iconName: "gamecontroller",
        minAge: 5,
        maxAge: 99,
        category: .puzzle,
        isLocked: false,
        bundleSize: 10
    )
    
    required init() {
        // Initialize any required resources
    }
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = YourGameScene(size: size)
        scene.gameContext = context  // Pass services to scene
        scene.scaleMode = .aspectFill
        return scene
    }
    
    func cleanup() {
        // Release resources if needed
    }
}
```

### Interaction Standards

**Gesture Recognizers (provided by BaseGameScene):**
- `UIPanGestureRecognizer` → Drag & drop
- `UITapGestureRecognizer` → Selection
- `UIRotationGestureRecognizer` → Rotation (if needed)
- `UILongPressGestureRecognizer` → Context actions

**Visual Feedback:**
- Selection: Blue outline
- Valid placement: Green highlight
- Invalid placement: Red highlight
- Dragging: Scale to 1.1x with shadow

### Storage Pattern

All games use `BasePuzzleStorage` for consistent save/load:

```swift
final class YourGameStorage: BasePuzzleStorage {
    // If you need singleton for initialization guarantees (acceptable)
    static let shared = YourGameStorage()
    
    private init() {
        super.init(configuration: PuzzleStorageConfiguration())
        ensureBuiltInPuzzles()
    }
    
    private func ensureBuiltInPuzzles() {
        Task {
            let puzzles: [YourGamePuzzle] = try await loadAll()
            if puzzles.isEmpty {
                // Create default puzzles
            }
        }
    }
}
```

Storage location: `Documents/YourGamePuzzles/*.json`

## Using Shared Components

### PuzzleCardView

Use the unified `PuzzleCardView` for all puzzle selection:

```swift
import SwiftUI

struct YourPuzzleSelector: View {
    @State private var puzzles: [YourGamePuzzle] = []
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                ForEach(puzzles) { puzzle in
                    PuzzleCardView(
                        puzzle: puzzle,
                        onPlay: { p in launchGame(p) },
                        onEdit: { p in editPuzzle(p) },
                        onDelete: { p in deletePuzzle(p) }
                    )
                }
            }
        }
    }
}
```

### UIConstants

Always use the platform constants for consistent design:

```swift
import SwiftUI

struct YourGameView: View {
    var body: some View {
        VStack(spacing: Spacing.m) {  // Use Spacing constants
            Text("Your Game")
                .font(AppTypography.title)  // Use typography constants
                .foregroundColor(AppColors.gamePrimary)  // Use color constants
            
            // Content with consistent spacing
            YourGameContent()
                .padding(Spacing.l)
        }
        .background(AppColors.gameBackground)
    }
}
```

## Implementation Checklist

When creating a new game, ensure:

- [ ] Inherits from `BaseGameScene` (no touchesBegan/Moved/Ended)
- [ ] Inherits from `BaseGameViewModel<YourPuzzle>`
- [ ] Implements `GamePuzzleProtocol` for puzzle type
- [ ] Uses `BasePuzzleStorage` for save/load
- [ ] Implements `GameModule` protocol
- [ ] Registered in `GameHost.swift` switch statement
- [ ] Uses `AppRoute` for navigation (no custom coordinator)
- [ ] Uses `PuzzleCardView` for puzzle selection
- [ ] Uses `UIConstants` for styling
- [ ] Follows standard directory structure
- [ ] Uses gesture recognizers from BaseGameScene
- [ ] Implements unit coordinate system
- [ ] No manual touch handling
- [ ] No GKStateMachine (use GameState enum)

## Common Pitfalls to Avoid

### ❌ DON'T DO THIS:
```swift
// Don't implement manual touch handling
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    // WRONG - Use gesture recognizers from BaseGameScene
}

// Don't create custom navigation
class GameCoordinator {
    // WRONG - Use NavigationStack with AppRoute
}

// Don't duplicate base functionality
class YourGameScene: SKScene {  
    // WRONG - Must inherit from BaseGameScene
}

// Don't use GKStateMachine
let stateMachine = GKStateMachine(states: [...])
// WRONG - Use GameState enum from BaseGameViewModel
```

### ✅ DO THIS INSTEAD:
```swift
// Use inherited gesture handlers
override func handleTap(at point: CGPoint) {
    // Correct - Override base class methods
}

// Use native navigation
NavigationLink(value: AppRoute.yourGame) {
    Text("Play")
}

// Always inherit from base classes
class YourGameScene: BaseGameScene {
    // Correct - Inherit all base functionality
}

// Use simple state management
if gameState == .playing {
    // Correct - Simple enum-based states
}
```

## Testing Your Game

### Verification Script

Run the verification script to ensure compliance:
```bash
./Scripts/verify-refactor.sh
```

### Manual Testing Checklist

- [ ] Game launches without errors
- [ ] Gesture recognizers work (drag, tap, rotate)
- [ ] Grid snapping functions correctly
- [ ] Save/load works properly
- [ ] Navigation works (forward and back)
- [ ] Puzzle selection uses PuzzleCardView
- [ ] Consistent styling with UIConstants
- [ ] No console warnings about missing services

## Migration Guide for Existing Games

If updating an older game to the new architecture:

1. **Change inheritance**:
   - `SKScene` → `BaseGameScene`
   - Create new ViewModel inheriting from `BaseGameViewModel`

2. **Remove manual touch handling**:
   - Delete `touchesBegan/Moved/Ended`
   - Override `handleTap/handlePan` instead

3. **Update navigation**:
   - Remove any coordinator references
   - Use `NavigationLink` with `AppRoute`

4. **Use shared components**:
   - Replace custom puzzle cards with `PuzzleCardView`
   - Update styling to use `UIConstants`

5. **Update storage**:
   - Inherit from `BasePuzzleStorage`
   - Implement `GamePuzzleProtocol`

## Summary

The Osmo game development stack prioritizes:

- **Native iOS patterns** - NavigationStack, @Observable, gesture recognizers
- **Inheritance over duplication** - Use base classes for common functionality
- **Consistency** - All games follow the same patterns
- **Simplicity** - No complex abstractions or custom frameworks

Follow these patterns exactly. The base classes handle the complex parts - your game just needs to implement its specific logic.

---

*Last Updated: November 2024 - Post-Refactor*  
*All patterns reflect actual implementation in the codebase*