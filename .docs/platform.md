# Osmo Platform Architecture

## Overview

Osmo is a modular iOS gaming platform that combines computer vision (CV) with interactive gameplay. Built on modern iOS technologies (SwiftUI, SpriteKit, ARKit, Vision), the platform provides a flexible foundation for creating games that respond to real-world visual input through the device camera.

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

These choices prioritize performance, type safety, and developer clarity over dynamic flexibility - appropriate for a platform where games are known at compile time and real-time CV processing is critical.

## Core Architecture Principles

### 1. Service-Oriented Architecture (SOA)
The platform is built around four core services that provide cross-cutting functionality:
- **Computer Vision Service**: Camera access and visual processing
- **Audio Service**: Sound effects, music, and haptic feedback
- **Analytics Service**: Event tracking and telemetry
- **Persistence Service**: Game progress and user settings

### 2. Modular Game Architecture
Games are self-contained modules that:
- Implement a standard protocol interface
- Receive services through dependency injection
- Process CV events through reactive streams
- Maintain independent state and logic

### 3. Event-Driven Communication
The platform uses async streams for real-time event delivery:
- CV events flow from processors to games
- Games subscribe to specific event types
- Non-blocking reactive processing

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
│                      Game Layer                              │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │ Game Module    │  │  Game Scene    │  │  ViewModel   │ │
│  │ (Factory)      │  │  (SpriteKit)   │  │ (Business)   │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                             │
│  ┌────────────┐  ┌──────────┐  ┌───────────┐  ┌────────┐ │
│  │ CV Service │  │  Audio   │  │ Analytics │  │Persist │ │
│  │  (Vision)  │  │ Service  │  │  Service  │  │Service │ │
│  └────────────┘  └──────────┘  └───────────┘  └────────┘ │
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

// Service Resolution (Runtime)
let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
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
}
```

Features:
- Game state persistence
- User preferences
- High score tracking
- SwiftData backend

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

### CV Event System

Events are strongly typed with rich metadata:

```swift
enum CVEventType {
    case objectDetected(type: String, objectId: UUID)
    case gestureRecognized(type: GestureType)
    case handDetected(handId: UUID, chirality: HandChirality)
    case rectangleDetected(rectangles: [CVRectangle])
    case textDetected(text: String, boundingBox: CGRect)
    // Game-specific events...
}
```

### Event Streaming Architecture

The system uses direct AsyncStream connections for CV event delivery:

```swift
// In GameCVProcessor base class
var eventStream: AsyncStream<CVEvent> {
    AsyncStream { continuation in
        self.eventContinuation = continuation
    }
}

// CV processor emits events
func emit(event: CVEvent) {
    eventContinuation?.yield(event)
}

// Game subscribes to its processor's stream
for await event in cvService.eventStream(gameId: gameId, events: []) {
    handleCVEvent(event)
}
```

This architecture provides:
- Dedicated CV processor per game for isolation
- Direct stream connection for minimal latency
- Type-safe event delivery with backpressure handling
- Simple debugging with clear event flow

### Game-Specific CV Processing

#### Rock Paper Scissors
- Hand pose detection with 21 landmarks
- Gesture recognition with temporal smoothing
- Transition validation for logical sequences
- Multi-metric confidence scoring

#### Sudoku
- Board detection with perspective correction
- Grid cell extraction and mapping
- OCR for digit recognition
- Temporal consistency buffering

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
│   └── CV/
│       └── GameNameProcessor.swift   # CV processing
```

### Game Module Protocol

```swift
protocol GameModule: AnyObject {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func cleanup()
}
```

### Game Lifecycle

1. **Selection**: User selects game from lobby
2. **Instantiation**: GameHost uses switch statement to create specific module
3. **Context Creation**: GameHost creates context with service references
4. **Scene Creation**: Module creates SpriteKit scene with context
5. **CV Setup**: GameHost starts CV session (if needed by game)
6. **Event Stream**: Game connects to CV processor's AsyncStream
7. **Gameplay**: Game processes events from stream
8. **Cleanup**: Module cleanup and CV session stop

### ViewModel Pattern

ViewModels serve as the business logic layer:
- `@Observable` for SwiftUI integration
- Process CV events into game state
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

### Game Instantiation Flow
```
1. User selects game in LobbyView
2. AppCoordinator navigates to GameHost with gameId
3. GameHost switches on gameId to instantiate specific module
4. Module creates scene with injected GameContext
5. CV session starts if game requires it
```

### Service Communication Flow
```
Game Action → ViewModel → Service Call → Response
     ↓                         ↓
Analytics Event          Persistence Update
```

### State Management
- ViewModels own game state
- Scenes handle presentation
- Services manage system state
- No shared mutable state between games

## Modularity and Extensibility

### Adding New Games

1. Create game directory structure under `Games/`
2. Implement GameModule protocol with metadata
3. Create CV processor extending BaseGameCVProcessor (if CV needed)
4. Build SpriteKit scene and Observable ViewModel
5. Add case to GameHost.swift switch statement
6. Add GameInfo to LobbyView.swift mockGames array

### Current Implementation Notes

Games are registered in two places:
- `GameHost.swift`: Switch statement for module instantiation
- `LobbyView.swift`: Game catalog for UI display

This approach ensures compile-time safety and explicit control over available games.

### Adding New CV Detections

1. Extend CVEventType enum
2. Implement detection in CV processor
3. Add event handling in games
4. Update debug overlays

### Adding New Services

1. Define service protocol
2. Implement service class
3. Register with ServiceLocator
4. Add to GameContext
5. Use in games as needed

## Performance Considerations

### CV Processing
- Frame throttling (30-60 FPS)
- Background queue processing
- Efficient memory management
- Object pooling for detections

### Rendering
- SpriteKit hardware acceleration
- Transparent scene overlay
- Minimal UI updates
- Batch sprite operations

### Memory Management
- Weak service references
- Event stream cleanup
- Texture caching
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

## Testing Architecture

### Unit Testing
- Protocol-based mocking
- Service injection for testing
- Isolated game logic testing
- CV event simulation

### Integration Testing
- Mock CV service for predictable events
- Service interaction verification
- Game lifecycle testing
- Performance profiling

## Future Extensibility

### Planned Enhancements
1. Dynamic game discovery
2. Game marketplace/downloads
3. Multiplayer support
4. Cloud synchronization
5. Additional CV capabilities

### Architecture Evolution
The platform is designed to support:
- New game types and genres
- Advanced CV algorithms
- Cross-platform expansion
- External hardware integration
- Machine learning models

## Best Practices

### For Game Developers
1. Keep games self-contained
2. Use services through protocols
3. Handle CV events reactively
4. Implement proper cleanup
5. Follow existing patterns

### For Platform Developers
1. Maintain service contracts
2. Ensure backward compatibility
3. Document breaking changes
4. Optimize shared resources
5. Monitor performance impacts

## Conclusion

The Osmo platform demonstrates a well-architected system that balances modularity, performance, and extensibility. The service-oriented design with dependency injection enables clean separation of concerns, while the event-driven CV integration provides responsive real-time gameplay. The modular game architecture ensures new games can be added without affecting existing functionality, making the platform suitable for continuous growth and evolution.