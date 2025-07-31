# Game Integration Architecture

## Overview
This document defines the standard architecture pattern for integrating games into the Osmo platform. All games follow a consistent structure leveraging the existing service-oriented architecture.

## Core Architecture Principles

### 1. Protocol-Driven Design
Every game implements the `GameModule` protocol, ensuring consistent integration:
```swift
protocol GameModule: AnyObject {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func cleanup()
}
```

### 2. Service Integration via GameContext
Games receive dependencies through the GameContext protocol:
```swift
protocol GameContext {
    var cvService: CVServiceProtocol { get }
    var audioService: AudioServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var persistenceService: PersistenceServiceProtocol { get }
}
```

### 3. Modern Swift Patterns
- **@Observable**: All ViewModels use iOS 17+ Observable
- **AsyncStream**: CV events delivered via async streams
- **Structured Concurrency**: async/await for all async operations
- **Pure SwiftUI**: No UIKit dependencies

## Standard Game Structure

### Directory Layout
```
Games/
├── [GameName]/
│   ├── [GameName]GameModule.swift      // GameModule implementation
│   ├── [GameName]GameScene.swift       // SpriteKit scene
│   ├── [GameName]ViewModel.swift       // @Observable game logic
│   ├── Models/
│   │   └── [GameName]Models.swift      // Game-specific data models
│   └── Components/                     // Optional: reusable UI components
│       └── [GameName]Components.swift
```

### Required Components

#### 1. GameModule Implementation
```swift
final class [GameName]GameModule: GameModule {
    static let gameId = "game-identifier"
    static let gameInfo = GameInfo(
        title: "Game Title",
        description: "Game description",
        iconName: "system.icon.name",
        category: .puzzle, // or .strategy, .action, etc.
        minPlayers: 1,
        maxPlayers: 1
    )
    
    init() {
        // Lightweight initialization only
    }
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        return [GameName]GameScene(size: size, gameContext: context)
    }
    
    func cleanup() {
        // Release any resources
    }
}
```

#### 2. ViewModel Pattern
```swift
@Observable
final class [GameName]ViewModel {
    // MARK: - Game State
    private(set) var gamePhase: GamePhase = .setup
    private(set) var score: Int = 0
    
    // MARK: - CV State
    private(set) var cvDetectionActive = false
    
    // MARK: - Dependencies
    private let cvService: CVServiceProtocol?
    private let audioService: AudioServiceProtocol?
    
    init(context: GameContext?) {
        self.cvService = context?.cvService
        self.audioService = context?.audioService
    }
    
    // MARK: - Game Logic
    func startGame() { }
    func processMove() { }
    func endGame() { }
}
```

#### 3. GameScene Integration
```swift
final class [GameName]GameScene: SKScene, GameSceneProtocol {
    // MARK: - Properties
    weak var gameContext: GameContext?
    weak var viewModel: [GameName]ViewModel?
    
    private var cvEventStream: AsyncStream<CVEvent>?
    private var cvTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupScene()
        subscribeToCV()
    }
    
    // MARK: - CV Integration
    private func subscribeToCV() {
        guard let cvService = gameContext?.cvService else { return }
        
        cvEventStream = cvService.eventStream(
            gameId: [GameName]GameModule.gameId,
            events: [/* game-specific events */]
        )
        
        cvTask = Task { [weak self] in
            guard let stream = self?.cvEventStream else { return }
            for await event in stream {
                await self?.handleCVEvent(event)
            }
        }
    }
    
    @MainActor
    private func handleCVEvent(_ event: CVEvent) {
        switch event.type {
        // Handle game-specific CV events
        }
    }
    
    // MARK: - Cleanup
    deinit {
        cvTask?.cancel()
    }
}
```

## CV Integration Patterns

### Event Subscription
Games subscribe to specific CV events they need:
```swift
let events: Set<CVEventType> = [
    .fingerCountDetected(count: 0),
    .handPoseChanged(pose: .unknown),
    .objectDetected(type: "custom")
]

cvService.eventStream(gameId: gameId, events: events)
```

### Custom CV Processing
For game-specific CV needs:
```swift
extension CVServiceProtocol {
    func detectGameObject(
        in buffer: CVImageBuffer,
        gameId: String
    ) async -> GameObjectDetection? {
        // Custom detection logic
    }
}
```

### Performance Guidelines
- Subscribe only to needed events
- Process CV events asynchronously
- Implement frame skipping for performance
- Use confidence thresholds for validation

## Audio Integration

### Sound Effects
```swift
// In ViewModel or GameScene
audioService?.playSound(
    named: "move_sound",
    category: .gameEffect
)
```

### Haptic Feedback
```swift
audioService?.playHaptic(
    type: .impact,
    intensity: 0.7
)
```

## Analytics Integration

### Standard Events
Every game should track:
```swift
struct GameAnalytics {
    static let gameStarted = "\(gameId)_started"
    static let gameCompleted = "\(gameId)_completed"
    static let gamePaused = "\(gameId)_paused"
    static let gameError = "\(gameId)_error"
}
```

### Custom Metrics
```swift
analyticsService?.track(
    event: GameAnalytics.gameCompleted,
    properties: [
        "score": score,
        "duration": duration,
        "difficulty": difficulty.rawValue
    ]
)
```

## Persistence Integration

### Game Progress
```swift
@Model
final class GameProgress {
    let gameId: String
    let lastPlayed: Date
    let highScore: Int
    let completionPercentage: Double
    
    init(gameId: String) {
        self.gameId = gameId
        self.lastPlayed = .now
        self.highScore = 0
        self.completionPercentage = 0
    }
}
```

### Saving State
```swift
func saveProgress() async {
    let progress = GameProgress(gameId: gameId)
    await persistenceService?.save(progress)
}
```

## Error Handling

### CV Errors
```swift
enum GameCVError: Error {
    case detectionFailed
    case multipleObjectsDetected
    case trackingLost
    case insufficientLight
}
```

### Recovery Strategies
1. **Graceful Degradation**: Continue without CV if possible
2. **User Guidance**: Show helpful overlay messages
3. **Automatic Retry**: Attempt reconnection with backoff
4. **Fallback Input**: Provide alternative input methods

## Performance Optimization

### Memory Management
- Release resources in `cleanup()`
- Use weak references for delegates
- Cancel async tasks on deinit
- Limit texture atlas size

### Frame Rate
- Target 60 FPS for smooth gameplay
- Implement dynamic quality adjustment
- Use LOD for complex scenes
- Profile with Instruments

## Testing Strategy

### Unit Tests
```swift
final class [GameName]Tests: XCTestCase {
    func testGameLogic() { }
    func testScoring() { }
    func testWinCondition() { }
}
```

### Integration Tests
```swift
final class [GameName]IntegrationTests: XCTestCase {
    func testCVIntegration() { }
    func testServiceCommunication() { }
    func testPersistence() { }
}
```

## Accessibility

### Required Support
- VoiceOver labels for all UI elements
- Haptic feedback for important events
- High contrast mode support
- Alternative input methods

### Implementation
```swift
node.accessibilityLabel = "Game piece at row \(row), column \(col)"
node.accessibilityTraits = [.button, .updatesFrequently]
```

## Game Registration

### In App Initialization
```swift
// In OsmoApp.swift
private func registerGames() {
    GameRegistry.shared.register(TicTacToeGameModule.self)
    GameRegistry.shared.register(SudokuGameModule.self)
    GameRegistry.shared.register(RockPaperScissorsGameModule.self)
}
```

### In Lobby View
Games automatically appear in the lobby once registered.

## Best Practices

### DO
- Follow existing patterns consistently
- Use dependency injection via GameContext
- Implement proper cleanup
- Track analytics events
- Handle errors gracefully
- Test CV integration thoroughly
- Optimize for performance
- Support accessibility

### DON'T
- Access services directly (use GameContext)
- Create singletons
- Use completion handlers (use async/await)
- Ignore memory management
- Skip error handling
- Assume CV will always work
- Block the main thread

## Migration Guide

### Adding a New Game
1. Create game directory under `Games/`
2. Implement GameModule protocol
3. Create ViewModel with @Observable
4. Build GameScene extending SKScene
5. Define game-specific models
6. Register in GameRegistry
7. Test all integrations
8. Add analytics tracking
9. Implement accessibility
10. Document CV requirements

### Updating Existing Games
1. Ensure protocol compliance
2. Migrate to @Observable
3. Use AsyncStream for events
4. Remove singleton usage
5. Add proper cleanup
6. Implement analytics
7. Test thoroughly

## Conclusion

This architecture ensures all games integrate consistently with the Osmo platform while maintaining flexibility for game-specific requirements. Following these patterns results in maintainable, testable, and performant games that leverage the full power of the platform's services.