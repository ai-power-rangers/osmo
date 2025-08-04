# Osmo Platform Architecture

## Overview

Osmo is an iOS gaming platform that combines computer vision (CV) with interactive gameplay. Built using modern iOS technologies (SwiftUI, SpriteKit, Vision, ARKit), the platform provides a flexible, service-oriented architecture for creating educational games that respond to real-world visual input through the device camera.

## Table of Contents

1. [Architecture Philosophy](#architecture-philosophy)
2. [Repository Structure](#repository-structure)
3. [Core Architecture](#core-architecture)
4. [Foundation Layer](#foundation-layer)
5. [Service Layer](#service-layer)
6. [Game Module System](#game-module-system)
7. [Navigation System](#navigation-system)
8. [Unified Coordinate System](#unified-coordinate-system)
9. [Computer Vision Pipeline](#computer-vision-pipeline)
10. [Data Flow](#data-flow)
11. [Grid Editor System](#grid-editor-system)
12. [Adding New Games](#adding-new-games)
13. [Testing & Development](#testing--development)

## Architecture Philosophy

### Key Design Principles

1. **Native iOS Patterns**: Use standard iOS navigation (NavigationStack), state management (@Observable), and UI patterns
2. **Foundation-Based Architecture**: All games inherit from common base classes (BaseGameScene, BaseGameViewModel)
3. **Service-Oriented Architecture (SOA)**: Cross-cutting functionality provided through protocol-based services
4. **Modular Game Architecture**: Games are self-contained modules with standardized interfaces
5. **Event-Driven Communication**: AsyncStream-based CV event delivery for real-time processing
6. **SwiftUI + SpriteKit Hybrid**: SwiftUI for navigation/UI, SpriteKit for game rendering

### Technology Stack

- **UI Framework**: SwiftUI (navigation, settings, menus)
- **Navigation**: Native NavigationStack with value-based routing
- **Game Engine**: SpriteKit (game scenes, sprites, animations)
- **Computer Vision**: Vision Framework + ARKit
- **Persistence**: SwiftData + File-based storage
- **Audio**: AVFoundation + CoreHaptics
- **Concurrency**: Swift async/await + AsyncStream
- **State Management**: @Observable pattern

## Repository Structure

```
osmo/
├── .docs/                           # Documentation
│   ├── platform-architecture.md    # This document
│   ├── game-stack.md               # Game development guide
│   ├── refactor.md                 # Refactor plan
│   └── refactor-status.md          # Implementation status
│
├── osmo/                           # Main app source
│   ├── App/                        # App entry point & root views
│   │   ├── osmoApp.swift          # @main entry point
│   │   └── Views/                 # Root-level views
│   │       ├── RootView.swift     # Navigation root with NavigationStack
│   │       ├── LobbyView.swift    # Game selection
│   │       ├── SettingsView.swift # App settings
│   │       └── LaunchScreen.swift # Splash screen
│   │
│   ├── Core/                       # Platform infrastructure
│   │   ├── GameBase/              # Foundation layer (NEW)
│   │   │   ├── Scenes/
│   │   │   │   ├── BaseGameScene.swift       # Base scene all games inherit
│   │   │   │   └── GameSceneProtocol.swift   # Scene protocol
│   │   │   ├── ViewModels/
│   │   │   │   ├── BaseGameViewModel.swift   # Generic base view model
│   │   │   │   └── GameViewModelProtocol.swift
│   │   │   ├── Models/
│   │   │   │   ├── GamePuzzleProtocol.swift  # Puzzle contract
│   │   │   │   ├── GameState.swift           # Game state enum
│   │   │   │   └── PuzzleDifficulty.swift    # Difficulty levels
│   │   │   ├── Storage/
│   │   │   │   ├── PuzzleStorageProtocol.swift
│   │   │   │   └── BasePuzzleStorage.swift   # Base storage implementation
│   │   │   └── Views/
│   │   │       ├── PuzzleCardView.swift      # Unified puzzle card
│   │   │       └── CommonGameViews.swift     # Shared UI components
│   │   │
│   │   ├── Services/              # Core services
│   │   │   ├── ServiceContainer.swift        # DI container
│   │   │   ├── ServiceProtocols.swift        # Service interfaces
│   │   │   ├── EnvironmentServices.swift     # SwiftUI environment injection
│   │   │   ├── AnalyticsService.swift        # Analytics
│   │   │   ├── AudioEngineService.swift      # Audio/haptics
│   │   │   ├── SwiftDataService.swift        # Persistence
│   │   │   └── CV/                           # Computer vision
│   │   │       ├── CameraVisionService.swift # Camera management
│   │   │       ├── ARKitCVService.swift      # ARKit backend
│   │   │       └── GameCVProcessor.swift     # Base processor
│   │   │
│   │   ├── GameHost/              # Game hosting infrastructure
│   │   │   └── GameHost.swift     # Game container view
│   │   │
│   │   ├── Navigation/            # Navigation system
│   │   │   └── AppRoute.swift     # Native navigation routes (NEW)
│   │   │
│   │   ├── Protocols/             # Core protocols
│   │   │   ├── GameModule.swift   # Game module protocol
│   │   │   └── GameInfo.swift     # Game metadata
│   │   │
│   │   ├── GridEditor/            # Visual editor framework
│   │   │   ├── Abstractions/     # Core protocols
│   │   │   ├── Services/         # Editor services
│   │   │   └── Models/           # Data models
│   │   │
│   │   ├── UI/                    # UI constants and components
│   │   │   └── UIConstants.swift  # Spacing, colors, typography
│   │   │
│   │   └── CV/                    # CV infrastructure
│   │       ├── Models/            # CV event types
│   │       └── Views/             # CV UI components
│   │
│   └── Games/                     # Game implementations
│       ├── Tangram/
│       │   ├── TangramGameModule.swift    # Module definition
│       │   ├── TangramScene.swift         # Inherits BaseGameScene
│       │   ├── TangramViewModel.swift     # Inherits BaseGameViewModel
│       │   ├── TangramEditor.swift        # Puzzle editor
│       │   ├── TangramPlayView.swift      # Play interface
│       │   ├── Models/                    # Data models
│       │   └── CV/                        # CV processors
│       │
│       └── Sudoku/
│           └── [Similar structure]
│
└── osmo.xcodeproj/                # Xcode project
```

## Core Architecture

### Layered Architecture

```
┌────────────────────────────────────────────────────────┐
│                    App Layer                           │
│         osmoApp → LaunchScreen → RootView             │
└────────────────────────────────────────────────────────┘
                           ↓
┌────────────────────────────────────────────────────────┐
│                Navigation Layer                        │
│       NavigationStack → AppRoute → Destinations       │
└────────────────────────────────────────────────────────┘
                           ↓
┌────────────────────────────────────────────────────────┐
│                Foundation Layer                        │
│   BaseGameScene → BaseGameViewModel → GamePuzzleProtocol │
└────────────────────────────────────────────────────────┘
                           ↓
┌────────────────────────────────────────────────────────┐
│                   Game Host Layer                      │
│         GameHost → GameContext → SKScene              │
└────────────────────────────────────────────────────────┘
                           ↓
┌────────────────────────────────────────────────────────┐
│                    Game Layer                          │
│    GameModule → GameScene → ViewModel → Models        │
└────────────────────────────────────────────────────────┘
                           ↓
┌────────────────────────────────────────────────────────┐
│                   Service Layer                        │
│    CV • Audio • Analytics • Persistence • Storage     │
└────────────────────────────────────────────────────────┘
```

### Initialization Flow

1. **App Launch** (`osmoApp.swift`):
   ```swift
   @main
   struct osmoApp: App {
       @StateObject private var services = ServiceContainer()
       @State private var navigationPath = NavigationPath()
       
       var body: some Scene {
           WindowGroup {
               RootView()
                   .injectServices(from: services)
                   .task {
                       await services.initialize()
                   }
           }
       }
   }
   ```

2. **Service Initialization** (`ServiceContainer.swift`):
   - Services are initialized in dependency order
   - Persistence → Analytics → Audio → CV → GridEditor → Storage
   - Each service implements `ServiceLifecycle` protocol

3. **Navigation Setup** (`RootView.swift`):
   - Uses native NavigationStack with AppRoute enum
   - No custom coordinators or navigation patterns
   - Direct value-based navigation

## Foundation Layer

### BaseGameScene

All games inherit from `BaseGameScene` which provides:

```swift
class BaseGameScene: SKScene {
    weak var gameContext: GameContext?
    @Published var viewModel: BaseGameViewModel<any GamePuzzleProtocol>?
    
    // Unit coordinate system
    var unitSize: CGFloat = 50.0
    var gridEnabled: Bool = false
    
    // Standard gesture recognizers (no manual touch handling)
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var tapGestureRecognizer: UITapGestureRecognizer?
    private var rotationGestureRecognizer: UIRotationGestureRecognizer?
    
    // Grid snapping and coordinate conversion
    func screenToUnit(_ point: CGPoint) -> CGPoint
    func unitToScreen(_ point: CGPoint) -> CGPoint
    func snapToGrid(_ point: CGPoint) -> CGPoint
}
```

### BaseGameViewModel

Generic view model that all games extend:

```swift
@Observable
class BaseGameViewModel<PuzzleType: GamePuzzleProtocol> {
    @Published var currentPuzzle: PuzzleType?
    @Published var gameState: GameState = .initializing
    @Published var isComplete: Bool = false
    
    // Undo/Redo support
    private var undoStack: [PuzzleType.StateType] = []
    private var redoStack: [PuzzleType.StateType] = []
    
    // Storage integration
    private let storage: PuzzleStorageProtocol
    
    // Common game operations
    func startGame()
    func pauseGame()
    func resetToInitial()
    func validateCurrentState() -> Bool
    func saveUndoState()
    func undo()
    func redo()
}
```

### GamePuzzleProtocol

All puzzle types conform to this protocol:

```swift
protocol GamePuzzleProtocol: Identifiable, Codable, Hashable {
    associatedtype PieceType: Codable, Hashable
    associatedtype StateType: Codable, Hashable
    
    var id: String { get }
    var name: String { get set }
    var difficulty: PuzzleDifficulty { get set }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    
    var initialState: StateType { get }
    var targetState: StateType { get }
    var currentState: StateType { get set }
    
    func isCompleted() -> Bool
    func isValid() -> Bool
    func reset()
}
```

### Shared Components

#### PuzzleCardView
Unified puzzle card component used by all games:
- Replaces duplicate implementations
- Consistent visual design
- Supports preview, metadata, actions
- Uses UIConstants for styling

## Service Layer

### Service Container & Dependency Injection

The `ServiceContainer` is the central dependency injection container:

```swift
@MainActor
final class ServiceContainer: ObservableObject {
    @Published private(set) var persistence: PersistenceServiceProtocol?
    @Published private(set) var analytics: AnalyticsServiceProtocol?
    @Published private(set) var audio: AudioServiceProtocol?
    @Published private(set) var cv: CVServiceProtocol?
    @Published private(set) var gridEditor: GridEditorServiceProtocol?
    @Published private(set) var storage: PuzzleStorageProtocol?
    
    func initialize() async {
        // Initialize in dependency order
        // Handle errors and report progress
    }
}
```

### Core Services

#### 1. Persistence Service (`SwiftDataService`)
- **Purpose**: Game progress, settings, custom content
- **Implementation**: SwiftData with type-safe models

#### 2. Storage Service (`PuzzleStorageProtocol`)
- **Purpose**: Puzzle save/load operations
- **Implementation**: File-based JSON storage
- **Note**: Some games use singleton pattern for initialization guarantees

#### 3. Analytics Service
- **Purpose**: Event tracking, telemetry, error logging
- **Implementation**: In-memory queue with persistence

#### 4. Audio Service
- **Purpose**: Sound effects, music, haptic feedback
- **Implementation**: AVFoundation + CoreHaptics

#### 5. CV Service
- **Purpose**: Camera management, vision processing
- **Implementation**: Vision Framework with game-specific processors

### Service Injection Pattern

Services are injected through SwiftUI environment:

```swift
extension View {
    func injectServices(from container: ServiceContainer) -> some View {
        self
            .environment(\.persistenceService, container.persistence)
            .environment(\.analyticsService, container.analytics)
            .environment(\.audioService, container.audio)
            .environment(\.cvService, container.cv)
            .environment(\.storageService, container.storage)
    }
}
```

## Game Module System

### Game Module Protocol

Every game implements the `GameModule` protocol:

```swift
protocol GameModule: AnyObject {
    static var gameId: String { get }
    static var gameInfo: GameInfo { get }
    
    init()
    func createGameScene(size: CGSize, context: GameContext) -> SKScene
    func cleanup()
}
```

### Game Context

Games receive services through `GameContext`:

```swift
protocol GameContext: AnyObject {
    var cvService: CVServiceProtocol { get }
    var audioService: AudioServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var persistenceService: PersistenceServiceProtocol { get }
    var storageService: PuzzleStorageProtocol { get }
}
```

### Game Registration

Games are registered in `GameHost.swift` via switch statement:

```swift
private func createGameModule(for gameId: String, context: GameContext) -> (any GameModule)? {
    switch gameId {
    case "tangram":
        return TangramGameModule()
    case "sudoku":
        return SudokuGameModule()
    default:
        return nil
    }
}
```

### Game Structure Pattern

All games follow this structure and inherit from base classes:

```
Games/[GameName]/
├── [GameName]GameModule.swift      # Implements GameModule protocol
├── [GameName]Scene.swift           # Inherits from BaseGameScene
├── [GameName]ViewModel.swift       # Inherits from BaseGameViewModel
├── [GameName]Editor.swift          # Puzzle editor view
├── [GameName]PlayView.swift        # Game play interface
├── Models/
│   ├── [GameName]Puzzle.swift      # Implements GamePuzzleProtocol
│   ├── [GameName]Models.swift      # Game-specific models
│   └── [GameName]Storage.swift     # Storage (often inherits BasePuzzleStorage)
├── CV/
│   └── [GameName]Processor.swift   # CV processing (if needed)
└── Views/
    └── [GameName]Views.swift       # Game-specific UI components
```

## Navigation System

### Native iOS Navigation

The platform uses **native NavigationStack** with value-based routing:

```swift
// AppRoute.swift - Simple, type-safe navigation
enum AppRoute: Hashable {
    case settings
    case cvTest
    case gameSettings
    
    // Tangram routes
    case tangramEditor(puzzleId: String? = nil)
    case tangramPuzzleSelect
    
    // Sudoku routes  
    case sudokuEditor(puzzleId: String? = nil)
    case sudokuPuzzleSelect
    
    // Game launch
    case game(gameId: String, puzzleId: String? = nil)
}
```

### Navigation Implementation

```swift
// RootView.swift
struct RootView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            LobbyView()
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
        }
    }
    
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .game(let gameId, let puzzleId):
            GameHost(gameId: gameId, puzzleId: puzzleId)
        // ... other destinations
        }
    }
}
```

### Navigation Pattern

- **NO custom coordinators** - removed NavigationCoordinator entirely
- **NO protocol abstractions** - direct NavigationStack usage
- **Simple navigation** - push/pop with NavigationPath
- **Type-safe routes** - AppRoute enum ensures compile-time safety

## Unified Coordinate System

### Overview

The platform uses a unified mathematical coordinate system across all games.

### Core Unit System

- **1 Unit** = The fundamental measurement unit
- **Physical Mapping**: 1 unit ≈ 50 screen points on standard iPad
- **Play Area**: Standard 8×8 unit square for all games
- **Origin**: Bottom-left corner at (0, 0)
- **Grid System**:
  - Primary: 1.0 unit increments
  - Secondary: 0.25 unit increments (snapping)
  - Storage: 0.1 unit precision

### Implementation in BaseGameScene

```swift
// All coordinate operations are in BaseGameScene
extension BaseGameScene {
    func screenToUnit(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x / unitSize,
            y: point.y / unitSize
        )
    }
    
    func unitToScreen(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * unitSize,
            y: point.y * unitSize
        )
    }
    
    func snapToGrid(_ point: CGPoint, gridStep: CGFloat = 0.25) -> CGPoint {
        return CGPoint(
            x: round(point.x / gridStep) * gridStep,
            y: round(point.y / gridStep) * gridStep
        )
    }
}
```

## Computer Vision Pipeline

### CV Event Flow

```
1. Camera captures frame (30-60 FPS)
           ↓
2. CameraVisionService routes to game processor
           ↓
3. GameCVProcessor analyzes frame
           ↓
4. Processor yields CVEvent to AsyncStream
           ↓
5. Game subscribes with 'for await event in stream'
           ↓
6. ViewModel processes event and updates state
           ↓
7. Scene reflects state changes
```

### AsyncStream Pattern

Direct point-to-point connection without intermediaries:

```swift
// In game scene
for await event in cvService.eventStream(gameId: gameId, events: []) {
    handleCVEvent(event)
}
```

## Data Flow

### Service Communication

```
User Action → View → ViewModel → Service → Response
                         ↓                     ↓
                    State Update          Side Effect
                         ↓                     ↓
                    UI Refresh            Analytics
```

### Game Launch Sequence

```
1. User selects game in LobbyView
2. NavigationPath.append(.game(gameId, puzzleId))
3. NavigationStack presents GameHost
4. GameHost creates GameContext with services
5. Switch statement instantiates specific GameModule
6. Module creates scene (inheriting from BaseGameScene)
7. Scene creates ViewModel (inheriting from BaseGameViewModel)
8. CV session starts (if required)
9. Game connects to event stream
10. Gameplay begins
```

## Grid Editor System

### Architecture

The Grid Editor provides visual content creation for puzzles with constraint-based editing.

### Key Components

1. **PoseSource**: Provides object positions (touch or CV)
2. **AnchorManager**: Manages relative positioning
3. **ConstraintValidator**: Validates arrangements
4. **GridEditorService**: Manages editor instances

## Adding New Games

### Step-by-Step Guide

1. **Create Game Directory**:
   ```
   osmo/Games/NewGame/
   ```

2. **Create Puzzle Model** (implements GamePuzzleProtocol):
   ```swift
   struct NewGamePuzzle: GamePuzzleProtocol {
       // Required protocol properties
       var id: String
       var name: String
       var difficulty: PuzzleDifficulty
       // Game-specific properties
   }
   ```

3. **Create Scene** (inherits from BaseGameScene):
   ```swift
   class NewGameScene: BaseGameScene {
       override func didMove(to view: SKView) {
           super.didMove(to: view)
           // Game-specific setup
       }
   }
   ```

4. **Create ViewModel** (inherits from BaseGameViewModel):
   ```swift
   @Observable
   final class NewGameViewModel: BaseGameViewModel<NewGamePuzzle> {
       // Game-specific logic only
       // Common operations inherited
   }
   ```

5. **Implement GameModule**:
   ```swift
   final class NewGameModule: GameModule {
       static let gameId = "new-game"
       static let gameInfo = GameInfo(...)
       
       func createGameScene(size: CGSize, context: GameContext) -> SKScene {
           let scene = NewGameScene(size: size)
           scene.gameContext = context
           return scene
       }
   }
   ```

6. **Register in GameHost**:
   ```swift
   case "new-game":
       return NewGameModule()
   ```

7. **Add Navigation Routes** (if needed):
   ```swift
   // In AppRoute.swift
   case newGameEditor(puzzleId: String? = nil)
   case newGamePuzzleSelect
   ```

## Testing & Development

### Architecture Validation

Run the verification script to ensure proper implementation:
```bash
./Scripts/verify-refactor.sh
```

### Key Testing Areas

1. **Foundation Classes**: Verify inheritance and overrides
2. **Navigation**: Test NavigationStack routing
3. **Service Integration**: Mock protocols for testing
4. **Game Logic**: Test ViewModels in isolation
5. **Storage**: Verify save/load operations

### Development Best Practices

1. **Always inherit from base classes** - Don't reinvent the wheel
2. **Use native iOS patterns** - NavigationStack, @Observable, async/await
3. **Follow the established structure** - Consistency matters
4. **No custom navigation** - Use AppRoute and NavigationStack
5. **Leverage shared components** - PuzzleCardView, UIConstants
6. **Test with verification script** - Ensure compliance

## Summary

The Osmo platform architecture emphasizes:

- **Native iOS patterns** throughout (NavigationStack, @Observable)
- **Foundation-based development** (BaseGameScene, BaseGameViewModel)
- **Consistent game structure** across all implementations
- **Service-oriented design** with proper dependency injection
- **Shared components** to eliminate duplication
- **Simple, direct patterns** over complex abstractions

The architecture has been simplified from earlier versions:
- Removed NavigationCoordinator in favor of native NavigationStack
- Consolidated duplicate components into shared implementations
- Established clear inheritance hierarchy with base classes
- Standardized on native iOS patterns

This document reflects the actual implementation after the comprehensive refactor completed in November 2024.