# Osmo-like Educational App Architecture PRD (MVP)

## Executive Summary

This document outlines the MVP architecture for a modular iOS educational game platform combining computer vision with SpriteKit-based 2D games. The architecture prioritizes parallel development, clear separation of concerns, and a foundation that can scale from 2 games to 50-100 games without major refactoring.

## Architectural Decisions & Rationale

### 1. **Rendering Engine Split**
**Decision**: UIKit for navigation/menus, SpriteKit for all gameplay
**Rationale**: Educational games for 3-6 year olds need consistent 60 FPS for smooth animations and physics. SpriteKit provides this out-of-the-box with minimal setup. UIKit remains familiar for non-game screens.

### 2. **Plugin Architecture**
**Decision**: Each game is a self-contained module with minimal dependencies
**Rationale**: Enables true parallel development. Adding game #50 should be as simple as game #2.

### 3. **Event-Driven CV Communication**
**Decision**: CV publishes events, games subscribe only to what they need
**Rationale**: Keeps CV expert isolated from game logic. Games can work with mock events during development.

### 4. **Lean Service Layer**
**Decision**: Start with only essential services (CV, Audio, Basic Analytics)
**Rationale**: Avoid over-engineering. Add services as needed, not preemptively.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    App Coordinator                       │
│                 (Navigation & Flow)                      │
└─────────────┬───────────────────────────┬───────────────┘
              │                           │
┌─────────────▼─────────────┐ ┌──────────▼──────────────┐
│      Lobby (UIKit)        │ │   Game Host (UIKit)     │
│   (Game Selection)        │ │  (SpriteKit Container)  │
└───────────────────────────┘ └─────────────────────────┘
              │                           │
┌─────────────▼─────────────────────────▼─────────────────┐
│                   Service Layer                          │
│  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌────────────┐  │
│  │   CV    │ │  Audio   │ │Analytics│ │Persistence │  │
│  │ Service │ │ Service  │ │ Service │ │  Service   │  │
│  └─────────┘ └──────────┘ └─────────┘ └────────────┘  │
└──────────────────────────────────────────────────────────┘
              │                           │
┌─────────────▼─────────────┐ ┌──────────▼──────────────┐
│    Game Module 1          │ │    Game Module 2        │
│   (SpriteKit Scene)       │ │   (SpriteKit Scene)     │
└───────────────────────────┘ └─────────────────────────┘
```

## Core Protocols (MVP)

### 1. Game Module Protocol
```swift
protocol GameModule {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func cleanup()
}

struct GameInfo {
    let displayName: String
    let description: String
    let iconName: String
    let requiredCVEvents: [CVEventType]
    let minAge: Int
}

protocol GameContext {
    var cvService: CVServiceProtocol { get }
    var audioService: AudioServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var persistenceService: PersistenceServiceProtocol { get }
}
```

### 2. CV Service Protocol (Simplified)
```swift
protocol CVServiceProtocol {
    func startSession()
    func stopSession()
    func subscribe(gameId: String, events: [CVEventType], handler: @escaping (CVEvent) -> Void) -> CVSubscription
}

struct CVEvent {
    let type: CVEventType
    let position: CGPoint  // Normalized 0-1
    let timestamp: TimeInterval
    let confidence: Float
}

enum CVEventType {
    case objectDetected(type: String)
    case objectMoved(type: String, from: CGPoint, to: CGPoint)
    case objectRemoved(type: String)
}
```

### 3. Basic Service Protocols
```swift
protocol AudioServiceProtocol {
    func playSound(_ soundName: String)
    func playHaptic(_ type: HapticType)
}

protocol AnalyticsServiceProtocol {
    func logEvent(_ event: String, parameters: [String: Any])
    func startLevel(gameId: String, level: String)
    func endLevel(gameId: String, level: String, success: Bool)
}

protocol PersistenceServiceProtocol {
    func saveLevel(gameId: String, level: String, completed: Bool)
    func isLevelCompleted(gameId: String, level: String) -> Bool
    func getCompletedLevels(gameId: String) -> [String]
    func saveHighScore(gameId: String, level: String, score: Int)
    func getHighScore(gameId: String, level: String) -> Int?
}
```

## Error Handling Strategy (MVP)

### Critical Errors to Handle

1. **Camera Permission Denied**
```swift
enum CVError: Error {
    case cameraPermissionDenied
    case cameraUnavailable
    case initializationFailed
}

// In Game Host
func handleCVError(_ error: CVError) {
    switch error {
    case .cameraPermissionDenied:
        showPermissionAlert(
            title: "Camera Needed",
            message: "This game needs the camera to see your toys! Ask a grown-up to help turn it on.",
            settingsAction: true
        )
    case .cameraUnavailable:
        coordinator.showError("Camera not working. Try another game!")
        coordinator.returnToLobby()
    }
}
```

2. **Game Loading Failures**
```swift
// In Game Host
guard let gameModule = try? GameLoader.loadGame(gameId) else {
    showAlert("Oops! This game is taking a nap. Try another one!")
    coordinator.returnToLobby()
    return
}
```

3. **Service Failures (Graceful Degradation)**
```swift
// Games continue without audio if audio fails
class AudioService: AudioServiceProtocol {
    func playSound(_ soundName: String) {
        do {
            try audioPlayer?.play()
        } catch {
            // Log error but don't crash
            print("Audio failed, continuing silently")
        }
    }
}
```

### Parent-Friendly Error Messages
- Use simple, non-technical language
- Suggest actions kids can take
- Provide settings shortcuts where appropriate
- Never show technical error codes to users

## Development Phases & Responsibilities

### CV Developer (4 weeks)

**Goal**: Build a working CV service that publishes events games can use.

#### Week 1-2: Foundation
- Set up OpenCV in iOS project
- Create basic camera capture pipeline
- Implement CVService with protocol
- Build simple object detection (shapes/colors)

#### Week 3: Event System
- Define core event types
- Implement publish/subscribe pattern
- Add debug visualization overlay
- Create mock mode for testing

#### Week 4: Integration & Testing
- Performance optimization (target 30+ FPS)
- Create integration examples
- Document event types with videos
- Coordinate with game developers on events

**Deliverables**:
- CVService implementation
- Event type documentation with examples
- Mock mode for game testing
- Performance benchmarks

---

### Game Developers 1 & 2 (4 weeks)

**Goal**: Build complete educational games using SpriteKit and CV events.

#### Week 1: Setup & Planning
- Create game module structure
- Design game concept for 3-6 year olds
- Set up SpriteKit scene
- List required CV events

#### Week 2-3: Core Implementation
- Build game mechanics in SpriteKit
- Integrate with mock CV events
- Add basic animations and physics
- Implement sound effects

#### Week 4: Polish & Integration
- Test with real CV service
- Add particle effects for rewards
- Tune difficulty for age group
- Memory optimization

**Deliverables**:
- Complete game module
- Required CV events specification
- Game assets (sprites, sounds)
- Basic gameplay video

---

### Platform Developer (5 weeks)

**Goal**: Build the app shell that hosts games and provides core services.

#### Week 1: Foundation
- Set up project structure
- Implement basic navigation (UIKit)
- Create game module loading system
- Build service locator pattern

#### Week 2: Core Services
- Implement AudioService (using AVFoundation)
- Implement basic AnalyticsService
- Implement PersistenceService (UserDefaults)
- Create SpriteKit hosting view controller
- Build lobby screen

#### Week 3: Game Integration
- Create game loading/unloading system
- Implement scene transitions
- Add memory management basics
- Build settings screen

#### Week 4: CV Integration
- Integrate CV service
- Wire up permissions handling
- Create debug menu
- Test with game modules

#### Week 5: Polish
- App lifecycle handling
- Error handling & recovery flows
- Camera permission flow
- Performance monitoring
- Create integration documentation

**Deliverables**:
- Main app with navigation
- Service implementations (Audio, Analytics, Persistence)
- Game hosting system
- Error handling flows
- Integration guide

## Repository Structure (MVP)

```
OsmoApp/
├── Core/
│   ├── Protocols/
│   │   ├── GameModule.swift
│   │   ├── CVService.swift
│   │   └── Services.swift
│   └── Models/
│       ├── CVEvent.swift
│       └── GameInfo.swift
│
├── Services/
│   ├── CVService/          # CV Developer owns this
│   ├── AudioService/       # Platform Developer
│   ├── AnalyticsService/   # Platform Developer
│   └── PersistenceService/ # Platform Developer
│
├── Games/
│   ├── ExampleGame/        # Template
│   ├── Game1/              # Game Dev 1
│   └── Game2/              # Game Dev 2
│
├── App/
│   ├── Coordinators/
│   ├── Lobby/
│   ├── GameHost/           # SpriteKit container
│   └── Settings/
│
└── Resources/
    └── Sounds/             # Shared sounds
```

## Key Technical Decisions

### Memory Management (Simple)
- Each game gets ~100MB budget
- Unload game assets when returning to lobby
- Shared sounds stay in memory
- No complex caching in MVP

### CV Integration Pattern
- Games work with normalized coordinates (0-1)
- CV runs on background queue
- Events delivered on main queue
- 50ms max latency for events

### SpriteKit Standards
- Standard scene size: 1024x768 (scales to device)
- 60 FPS target
- Use built-in physics for simple collisions
- Particle effects for celebrations

### Persistence (Minimal)
- UserDefaults for level completion
- No user profiles or cloud sync
- Simple key-value storage
- ~1KB per game maximum

### Error Handling
- Camera permissions required on first launch
- Graceful degradation if services fail
- Kid-friendly error messages
- No crashes from common errors

### Testing Approach (MVP)
- Manual testing with real devices
- CV mock mode for development
- Basic memory profiling
- No automated tests initially

## What We're NOT Building (Yet)

To avoid over-engineering the MVP:

1. **Not Building**: Complex progress tracking
   **Instead**: Simple level completion

2. **Not Building**: Difficulty adjustment system
   **Instead**: Fixed difficulty per game

3. **Not Building**: Parent dashboard
   **Instead**: Basic playtime analytics

4. **Not Building**: Asset downloading
   **Instead**: All assets in app bundle

5. **Not Building**: Multiple game templates
   **Instead**: One example template

6. **Not Building**: Sophisticated memory management
   **Instead**: Simple load/unload

7. **Not Building**: IAP in phase 1
   **Instead**: All games unlocked

## Success Criteria (MVP)

1. **Integration**: All 4 developers can work without blocking each other
2. **Performance**: 60 FPS games with CV running at 30 FPS
3. **Stability**: No crashes during normal gameplay
4. **Simplicity**: Adding game #3 takes <1 week
5. **Foundation**: Architecture supports future features without major refactoring
6. **Persistence**: Kids don't lose progress when app restarts
7. **Error Handling**: Graceful handling of camera permissions and common failures

## Future Expansion Hooks

The architecture includes these extension points for post-MVP features:

- **GameProgress** protocol: Ready for progress tracking
- **DifficultyLevel** enum: Ready for adaptive difficulty
- **IAPService** protocol: Ready for subscriptions
- **AssetLoader** protocol: Ready for dynamic content
- **ParentDashboard** module: Ready to add

## Integration Timeline

```
Week 1: All teams start in parallel
Week 2: First service integration tests
Week 3: CV + Game integration tests  
Week 4: Full integration testing
Week 5: Polish and ship MVP
```

## Example Integration Code

### Game Module Implementation
```swift
class ShapeMatchGame: GameModule {
    static let gameId = "shape_match"
    static let gameInfo = GameInfo(
        displayName: "Shape Matcher",
        description: "Match shapes with objects",
        iconName: "shape_match_icon",
        requiredCVEvents: [.objectDetected(type: "shape")],
        minAge: 3
    )
    
    private var cvSubscription: CVSubscription?
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = ShapeMatchScene(size: size)
        
        // Subscribe to CV events
        cvSubscription = context.cvService.subscribe(
            gameId: Self.gameId,
            events: Self.gameInfo.requiredCVEvents
        ) { [weak scene] event in
            scene?.handleCVEvent(event)
        }
        
        // Use services
        scene.audioPlayer = context.audioService
        scene.analytics = context.analyticsService
        scene.persistence = context.persistenceService
        
        // Load saved progress
        let completedLevels = context.persistenceService.getCompletedLevels(gameId: Self.gameId)
        scene.unlockedLevels = completedLevels
        
        return scene
    }
    
    func cleanup() {
        cvSubscription?.cancel()
    }
}
```

### Simple Persistence Implementation
```swift
class UserDefaultsPersistence: PersistenceServiceProtocol {
    private let defaults = UserDefaults.standard
    
    func saveLevel(gameId: String, level: String, completed: Bool) {
        let key = "\(gameId).level.\(level)"
        defaults.set(completed, forKey: key)
    }
    
    func isLevelCompleted(gameId: String, level: String) -> Bool {
        let key = "\(gameId).level.\(level)"
        return defaults.bool(forKey: key)
    }
    
    func getCompletedLevels(gameId: String) -> [String] {
        // Get all keys for this game
        let gamePrefix = "\(gameId).level."
        return defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix(gamePrefix) && $0.value as? Bool == true }
            .map { $0.key.replacingOccurrences(of: gamePrefix, with: "") }
    }
}
```

### CV Mock Mode
```swift
// For game development without CV
class MockCVService: CVServiceProtocol {
    func startSession() {
        // Simulate CV events every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let event = CVEvent(
                type: .objectDetected(type: "circle"),
                position: CGPoint(x: 0.5, y: 0.5),
                timestamp: Date().timeIntervalSince1970,
                confidence: 0.95
            )
            // Publish to subscribers
        }
    }
}
```

## Conclusion

This MVP architecture provides a solid foundation for an educational game platform that can grow from 2 to 100 games. By focusing on clean interfaces and modular design, we enable parallel development while avoiding premature optimization. The architecture is simple enough to build in 5 weeks but robust enough to support years of expansion.