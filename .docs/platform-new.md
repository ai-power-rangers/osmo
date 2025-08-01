# Osmo Platform Architecture (Enhanced)

## Overview

Osmo is a modular iOS gaming platform that combines computer vision (CV) with interactive gameplay. Built on modern iOS technologies (SwiftUI, SpriteKit, ARKit, Vision), the platform provides a flexible foundation for creating games that respond to real-world visual input through the device camera. The platform now includes a comprehensive Visual Grid Editor system for content creation and puzzle design.

## Design Philosophy & Architectural Decisions

### Key Design Choices

1. **Direct Integration Over Abstraction**
   - Games are integrated via switch statements for explicit control and compile-time safety
   - Direct AsyncStream connections provide predictable, low-latency event flow
   - Trade-off: Less dynamic but more performant and debuggable

2. **Service-Oriented Architecture**
   - Centralized ServiceLocator manages dependencies
   - Protocol-based services enable testing and future implementations
   - Clear separation between platform services and game logic

3. **Stream-Based CV Events**
   - Point-to-point AsyncStreams for real-time processing
   - Each game gets a dedicated CV processor instance
   - Avoids overhead of event bus routing and filtering

4. **Modular Game Structure**
   - Self-contained game modules with standard interfaces
   - Three-layer architecture: Module (metadata), Scene (UI), ViewModel (logic)
   - Games share services but maintain independent state

5. **Modern Swift Patterns**
   - Observable ViewModels for reactive UI updates
   - Async/await for concurrent operations
   - SwiftData for type-safe persistence

6. **Constraint-Based Content Creation** (New)
   - Visual Grid Editor for authoring puzzles and game content
   - Relation graph approach with geometric constraints
   - CV-ready abstractions for future computer vision integration

These choices prioritize performance, type safety, and developer clarity over dynamic flexibility - appropriate for a platform where games are known at compile time and real-time CV processing is critical.

## Core Architecture Principles

### 1. Service-Oriented Architecture (SOA)
The platform is built around core services that provide cross-cutting functionality:
- **Computer Vision Service**: Camera access and visual processing
- **Audio Service**: Sound effects, music, and haptic feedback
- **Analytics Service**: Event tracking and telemetry
- **Persistence Service**: Game progress and user settings
- **Grid Editor Service** (New): Visual content creation and arrangement management

### 2. Modular Game Architecture
Games are self-contained modules that:
- Implement a standard protocol interface
- Receive services through dependency injection
- Process CV events through reactive streams
- Maintain independent state and logic
- Provide adapters for grid editor integration (New)

### 3. Event-Driven Communication
The platform uses async streams for real-time event delivery:
- CV events flow from processors to games
- Games subscribe to specific event types
- Non-blocking reactive processing
- Constraint validation events from grid editor (New)

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        App Layer                             │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   osmoApp   │  │AppCoordinator│  │   LobbyView     │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                     Game Host Layer                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    GameHost                          │   │
│  │  ┌─────────┐  ┌────────────┐  ┌────────────────┐  │   │
│  │  │ Camera  │  │   Scene    │  │  CV Event      │  │   │
│  │  │ Preview │  │ Container  │  │  Processing    │  │   │
│  │  └─────────┘  └────────────┘  └────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                   Grid Editor Layer (New)                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │               Grid Editor Framework                   │  │
│  │  ┌──────────┐  ┌─────────────┐  ┌───────────────┐  │  │
│  │  │PoseSource│  │AnchorManager│  │ConstraintValid│  │  │
│  │  └──────────┘  └─────────────┘  └───────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                      Game Layer                              │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │ Game Module    │  │  Game Scene    │  │  ViewModel   │ │
│  │ (Factory)      │  │  (SpriteKit)   │  │ (Business)   │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
│  ┌────────────────┐                                         │
│  │ Editor Adapter │ (New - Game-specific editor bridge)    │
│  └────────────────┘                                         │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌────────────┐  ┌──────────┐  ┌───────────┐  ┌────────┐ │
│  │ CV Service │  │  Audio   │  │ Analytics │  │Persist │ │
│  │  (Vision)  │  │ Service  │  │  Service  │  │Service │ │
│  └────────────┘  └──────────┘  └───────────┘  └────────┘ │
│  ┌─────────────────┐                                        │
│  │Grid Editor Svc  │ (New - Content creation service)      │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                 Infrastructure Layer                         │
│  ┌──────────────────┐  ┌─────────────────────────────────┐│
│  │ Service Locator  │  │    SwiftData Models            ││
│  └──────────────────┘  └─────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Service Layer Architecture

### Service Locator Pattern
The `ServiceLocator` acts as a dependency injection container:

```swift
// Service Registration (App Initialization)
ServiceLocator.shared.register(CVServiceProtocol.self, service: cameraService)
ServiceLocator.shared.register(AudioServiceProtocol.self, service: audioService)
ServiceLocator.shared.register(GridEditorServiceProtocol.self, service: gridEditorService) // New

// Service Resolution (Runtime)
let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
let gridEditor = ServiceLocator.shared.resolve(GridEditorServiceProtocol.self) // New
```

### Core Service Interfaces

#### Computer Vision Service
```swift
protocol CVServiceProtocol {
    func startSession(gameId: String, configuration: CVSessionConfiguration) async throws
    func stopSession()
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent>
}
```

Key Features:
- Dual implementation support (AVFoundation and ARKit)
- Game-specific CV processors
- 30-60 FPS processing with throttling
- Event-based detection delivery

#### Grid Editor Service (New)
```swift
protocol GridEditorServiceProtocol: AnyObject {
    func createEditor(for gameType: GameType, configuration: GridConfiguration) -> GridEditor
    func saveArrangement(_ arrangement: GridArrangement) async throws
    func loadArrangements(for gameType: GameType) async -> [GridArrangement]
}
```

Features:
- Visual puzzle/content creation
- Constraint-based validation
- Game-specific adapters
- CV-ready abstractions

#### Audio Service
```swift
protocol AudioServiceProtocol {
    func playSound(_ sound: GameSound)
    func playHaptic(_ haptic: HapticType)
    func setBackgroundMusicEnabled(_ enabled: Bool)
}
```

Features:
- Preloaded sound effects
- CoreHaptics integration
- Background music with mixing
- Volume and mute controls

#### Analytics Service
```swift
protocol AnalyticsServiceProtocol {
    func logEvent(_ event: AnalyticsEvent)
    func startGameSession(gameId: String) -> UUID
    func endGameSession(sessionId: UUID)
}
```

Features:
- Event queuing and batching
- Session tracking
- Error logging with context
- SwiftData persistence

#### Persistence Service
```swift
protocol PersistenceServiceProtocol {
    func saveGameProgress(_ progress: GameProgress) async throws
    func loadGameProgress(gameId: String) async throws -> GameProgress?
    func saveUserSettings(_ settings: UserSettings) async throws
    func saveArrangement(_ arrangement: GridArrangement) async throws // New
    func loadArrangements(type: GameType) async -> [GridArrangement] // New
}
```

Features:
- Game state persistence
- User preferences
- High score tracking
- Grid arrangements storage (New)
- SwiftData backend

## Grid Editor Architecture (New)

### Overview
The Visual Grid Editor is a reusable framework that enables visual creation and editing of puzzle arrangements, game boards, and success conditions. It provides an intuitive drag-and-drop interface using a relation graph approach with geometric constraints.

### Core Components

#### 1. PoseSource Abstraction
```swift
public protocol PoseSource: AnyObject {
    func currentPoses() -> [String: SE2Pose]  // pieceId → pose in world/table space
    func currentAnchorPieceId() -> String?    // optional hint; may be nil
}
```

This abstraction allows the same validation logic to work with:
- Touch-based editing (TouchPoseSource)
- Future CV-based detection (CVPoseSource)

#### 2. AnchorManager
```swift
public protocol AnchorManagerProtocol: AnyObject {
    func anchorRelativePoses(from worldPoses: [String: SE2Pose]) -> (anchorId: String, relPoses: [String: SE2Pose])
}
```

Centralizes anchoring policy:
- Touch mode: First placed piece or user-selected
- CV mode (future): Longest-stable, highest-confidence piece

#### 3. ConstraintValidator
```swift
public protocol ConstraintValidatorProtocol {
    func validate(arrangement: GridArrangement, relPoses: [String: SE2Pose]) -> ValidationResult
}
```

Central validation engine for:
- Constraint satisfaction checking
- Overlap detection
- Win condition evaluation

### Module Organization

```
osmo/
├── Core/
│   ├── GridEditor/                    # Framework layer
│   │   ├── Abstractions/              # Core protocols & models
│   │   ├── Models/                    # Shared data structures
│   │   ├── Geometry/                  # Shape & feature definitions
│   │   ├── Services/                  # Core services
│   │   ├── UI/                        # Reusable UI components
│   │   └── Utils/                     # Utilities
│   │
│   └── Services/                      # Existing platform services
│
└── Games/
    ├── Tangram/
    │   ├── GridEditor/                # Game-specific editor
    │   │   ├── TangramEditorAdapter.swift
    │   │   ├── TangramShapeLibrary.swift
    │   │   └── TangramConstraintBuilder.swift
    │   └── ...
    │
    └── Sudoku/
        ├── GridEditor/                # Game-specific editor
        │   ├── SudokuEditorAdapter.swift
        │   └── SudokuValidationRules.swift
        └── ...
```

### Game Integration Pattern

Each game provides an adapter:

```swift
protocol GridEditorAdapter {
    associatedtype ElementType
    associatedtype ConfigType: GridConfiguration
    
    func toGridElement(_ element: ElementType) -> PlacedElement
    func fromGridElement(_ element: PlacedElement) -> ElementType?
    func shapeLibrary() -> [String: ShapeGeometry]
    func additionalValidators() -> [ConstraintValidatorProtocol]
    func customizePalette(_ palette: ComponentPaletteView)
}
```

### Data Flow

```
User Input → TouchPoseSource → AnchorManager → ConstraintValidator
     ↓                              ↓                    ↓
GridCanvasView ←──────── GridEditorViewController ←─ ValidationResult
     ↓                              ↓
ComponentPalette         PropertyInspector
```

## Computer Vision Architecture

### CV Processing Pipeline

```
Camera → Sample Buffer → CV Processor → Vision Framework → CV Events → Game
```

### Two-Tier Processing Architecture

1. **Base CV Service** (Platform Level)
   - Camera session management
   - Frame capture and routing
   - Event stream multiplexing
   - Performance throttling

2. **Game CV Processors** (Game Level)
   - Game-specific detection logic
   - Event generation and filtering
   - Temporal smoothing
   - Confidence scoring

### CV-Grid Editor Integration (Future)

The PoseSource abstraction enables seamless CV integration:

```swift
// Touch mode (current)
let poseSource = TouchPoseSource(canvas: editorCanvas)

// CV mode (future)
let poseSource = CVPoseSource(session: cvSession)

// Same validation logic works with both
let result = validator.validate(arrangement: arrangement, relPoses: relPoses)
```

### CV Event System

Events are strongly typed with rich metadata:

```swift
enum CVEventType {
    case objectDetected(type: String, objectId: UUID)
    case gestureRecognized(type: GestureType)
    case handDetected(handId: UUID, chirality: HandChirality)
    case rectangleDetected(rectangles: [CVRectangle])
    case textDetected(text: String, boundingBox: CGRect)
    case pieceDetected(pieceId: String, pose: SE2Pose) // New for Grid Editor CV
}
```

## Game Module Architecture

### Module Structure

Each game follows a consistent structure:

```
Games/
├── GameName/
│   ├── GameNameGameModule.swift      # Module implementation & metadata
│   ├── GameNameGameScene.swift       # SpriteKit UI
│   ├── GameNameViewModel.swift       # Business logic
│   ├── Models/
│   │   └── GameNameModels.swift      # Data structures
│   ├── CV/
│   │   └── GameNameProcessor.swift   # CV processing
│   └── GridEditor/                   # Grid editor integration (New)
│       ├── GameNameEditorAdapter.swift
│       ├── GameNameShapeLibrary.swift
│       └── GameNameConstraints.swift
```

### Enhanced Game Module Protocol

```swift
protocol GameModule: AnyObject {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func createEditorAdapter() -> any GridEditorAdapter? // New
    func cleanup()
}
```

### Game Lifecycle (Enhanced)

1. **Selection**: User selects game from lobby
2. **Instantiation**: GameHost uses switch statement to create specific module
3. **Context Creation**: GameHost creates context with service references
4. **Scene Creation**: Module creates SpriteKit scene with context
5. **CV Setup**: GameHost starts CV session (if needed by game)
6. **Event Stream**: Game connects to CV processor's AsyncStream
7. **Content Loading**: Game loads custom arrangements from Grid Editor (New)
8. **Gameplay**: Game processes events from stream and validates constraints (New)
9. **Cleanup**: Module cleanup and CV session stop

### ViewModel Pattern (Enhanced)

ViewModels now handle both CV events and constraint validation:
- `@Observable` for SwiftUI integration
- Process CV events into game state
- Validate arrangements using ConstraintValidator (New)
- Manage timers and async operations
- Coordinate service interactions
- Maintain game rules and scoring

## Data Flow Patterns

### CV Event Flow
```
1. Camera captures frame (AVFoundation/ARKit)
2. CV Service delegates to game-specific processor
3. Processor analyzes frame and yields events to stream continuation
4. Events flow through AsyncStream (direct point-to-point)
5. Game scene iterates stream with 'for await' loop
6. Scene delegates event handling to ViewModel
7. UI updates reflect state changes
```

### Grid Editor Flow (New)
```
1. User opens Grid Editor for specific game
2. GridEditorService creates editor with game adapter
3. User places pieces with constraint snapping
4. TouchPoseSource provides real-time poses
5. AnchorManager computes relative positions
6. ConstraintValidator checks satisfaction
7. Arrangement saved to PersistenceService
8. Game loads custom arrangements on startup
```

### Unified Validation Flow (New)
```
Touch Mode:                          CV Mode (Future):
User drags piece                     CV detects piece
     ↓                                    ↓
TouchPoseSource                      CVPoseSource
     ↓                                    ↓
     └──────────→ AnchorManager ←─────────┘
                        ↓
                 ConstraintValidator
                        ↓
                  ValidationResult
                        ↓
                   Game Logic
```

## Modularity and Extensibility

### Adding New Games (Enhanced)

1. Create game directory structure under `Games/`
2. Implement GameModule protocol with metadata
3. Create CV processor extending BaseGameCVProcessor (if CV needed)
4. Build SpriteKit scene and Observable ViewModel
5. Create GridEditorAdapter for content creation (New)
6. Define shape library and constraints (New)
7. Add case to GameHost.swift switch statement
8. Register adapter with GridEditorService (New)
9. Add GameInfo to LobbyView.swift mockGames array

### Adding Grid Editor Support to Existing Games (New)

1. Create `GridEditor/` subdirectory in game folder
2. Implement game-specific adapter conforming to `GridEditorAdapter`
3. Define shape geometry with semantic features
4. Create constraint builders for game rules
5. Register adapter in app initialization
6. Update game to load custom arrangements

### Current Implementation Notes

Games are registered in three places:
- `GameHost.swift`: Switch statement for module instantiation
- `LobbyView.swift`: Game catalog for UI display
- `GridEditorService`: Adapter registration for content creation (New)

This approach ensures compile-time safety and explicit control over available games.

## Performance Considerations

### CV Processing
- Frame throttling (30-60 FPS)
- Background queue processing
- Efficient memory management
- Object pooling for detections

### Grid Editor Performance (New)
- Efficient constraint graph traversal
- Spatial indexing for snap detection
- Lazy evaluation of constraints
- Cached transformation matrices

### Rendering
- SpriteKit hardware acceleration
- Transparent scene overlay
- Minimal UI updates
- Batch sprite operations

### Memory Management
- Weak service references
- Event stream cleanup
- Texture caching
- Constraint graph pruning (New)
- Automatic resource deallocation

## Security and Privacy

### Camera Access
- Explicit permission requests
- Graceful degradation without camera
- No image storage or transmission
- Local processing only

### Data Protection
- Local persistence only
- No network communication
- User settings encryption
- Analytics anonymization
- Custom arrangements stored locally (New)

## Testing Architecture

### Unit Testing
- Protocol-based mocking
- Service injection for testing
- Isolated game logic testing
- CV event simulation
- Constraint validation testing (New)
- Adapter testing per game (New)

### Integration Testing
- Mock CV service for predictable events
- Mock PoseSource for editor testing (New)
- Service interaction verification
- Game lifecycle testing
- Arrangement persistence testing (New)
- Performance profiling

### Grid Editor Testing (New)
```
Tests/
├── GridEditorTests/
│   ├── AnchorManagerTests.swift
│   ├── ConstraintValidatorTests.swift
│   ├── PoseSourceTests.swift
│   └── TransformationTests.swift
├── GameEditorTests/
│   ├── TangramAdapterTests.swift
│   └── SudokuAdapterTests.swift
└── IntegrationTests/
    └── EditorGameIntegrationTests.swift
```

## Future Extensibility

### Planned Enhancements
1. Dynamic game discovery
2. Game marketplace/downloads
3. Multiplayer support
4. Cloud synchronization
5. Additional CV capabilities
6. Real-time CV validation in editor (New)
7. Community puzzle sharing (New)
8. Advanced constraint types (New)

### Architecture Evolution
The platform is designed to support:
- New game types and genres
- Advanced CV algorithms
- Cross-platform expansion
- External hardware integration
- Machine learning models
- Augmented reality editing (New)
- Collaborative content creation (New)

## Best Practices

### For Game Developers
1. Keep games self-contained
2. Use services through protocols
3. Handle CV events reactively
4. Implement proper cleanup
5. Follow existing patterns
6. Create comprehensive shape libraries (New)
7. Design intuitive constraints (New)
8. Test with various arrangements (New)

### For Platform Developers
1. Maintain service contracts
2. Ensure backward compatibility
3. Document breaking changes
4. Optimize shared resources
5. Monitor performance impacts
6. Keep abstractions CV-ready (New)
7. Maintain adapter consistency (New)

### For Content Creators (New)
1. Use semantic feature names
2. Design clear constraint relationships
3. Test arrangements thoroughly
4. Consider CV detection limits
5. Document puzzle solutions

## Migration Strategy

### Phase 1: Core Implementation
- Implement Grid Editor framework
- Create core abstractions (PoseSource, AnchorManager, ConstraintValidator)
- Build reusable UI components
- Integrate with existing services

### Phase 2: Game Integration
- Create Tangram adapter as reference
- Migrate Tangram to constraint-based validation
- Update BlueprintStore to load custom arrangements
- Add editor access from settings

### Phase 3: Platform Enhancement
- Add Grid Editor Service to ServiceLocator
- Update GameModule protocol
- Enhance persistence for arrangements
- Add analytics for editor usage

### Phase 4: CV Preparation
- Implement CVPoseSource prototype
- Test dual-mode validation
- Optimize for real-time performance
- Document CV requirements

## Conclusion

The enhanced Osmo platform with the Visual Grid Editor system demonstrates a sophisticated architecture that seamlessly integrates content creation with gameplay. The constraint-based approach with CV-ready abstractions ensures the platform can evolve from touch-based editing to computer vision validation without architectural changes. The service-oriented design maintains clean separation of concerns while the adapter pattern enables game-specific customization within a reusable framework.

This architecture balances immediate functionality with future extensibility, providing a solid foundation for creating engaging, vision-enabled games with user-generated content capabilities.