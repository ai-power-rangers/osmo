# Osmo Architecture Plan: Three-Layer Separation with CV Foundation

## Executive Summary

This plan establishes clear boundaries between SwiftUI (UI Layer), SpriteKit (Game Layer), and Services (Service Layer) to resolve architectural tensions without over-engineering. The architecture is designed with future CV (Computer Vision) integration in mind, allowing games to seamlessly transition from touch-based to physical-digital hybrid gameplay without major refactoring.

## Core Principle: Embrace the Boundaries

Each layer operates in its natural paradigm with explicit, simple contracts between them.

## The Three Layers

### 1. UI Layer (SwiftUI)
**Purpose**: User interface, navigation, and declarative state observation  
**Paradigm**: Declarative, value-based, automatic updates  
**Responsibilities**:
- Observe ViewModels via `@Observable`
- Handle navigation via NavigationState
- Display game state and UI controls
- User input that affects UI (menus, settings, navigation)

**What it DOESN'T do**:
- Direct game logic
- Touch handling for gameplay
- Animation of game pieces
- Service implementation

### 2. Game Layer (SpriteKit)
**Purpose**: Game rendering, animation, and touch interaction  
**Paradigm**: Imperative, reference-based, manual updates  
**Responsibilities**:
- Render game state visually
- Handle gameplay touch interactions
- Animate game pieces
- Receive explicit state updates from ViewModels

**What it DOESN'T do**:
- Observe ViewModels (no KVO, no Combine)
- Make state decisions
- Navigate between screens
- Access services directly

### 3. Service Layer
**Purpose**: Shared functionality and external integrations  
**Paradigm**: Protocol-based, stateless operations  
**Responsibilities**:
- Computer vision processing
- Audio playback
- Analytics tracking
- Data persistence
- Settings management

**What it DOESN'T do**:
- Hold game state
- Make UI decisions
- Depend on specific game implementations

## Layer Communication Contracts

### Contract 1: ViewModel → Scene Updates

**Problem**: SKScene can't observe @Observable ViewModels  
**Solution**: Explicit update protocol with defined update points

```swift
// Simple, explicit contract - ready for CV extension
protocol SceneUpdateReceiver {
    func updateDisplay(with state: GameStateSnapshot)
    // Future CV: func updateCVFeedback(with feedback: CVFeedback)
}

// Input source abstraction for future CV
enum InputSource {
    case touch      // Current: Direct touch input
    case keyboard   // Current: Keyboard shortcuts
    case cv         // Future: Computer vision input
}

// ViewModel pushes updates at specific moments
class BaseGameViewModel {
    weak var scene: SceneUpdateReceiver?
    
    private func notifyScene() {
        let snapshot = GameStateSnapshot(
            pieces: currentPuzzle?.pieces ?? [],
            isComplete: isComplete,
            moveCount: moveCount,
            inputSource: .touch  // Track input source
        )
        scene?.updateDisplay(with: snapshot)
    }
}
```

**Update Points** (explicit and predictable):
1. After successful move (touch or future CV)
2. After undo/redo
3. After puzzle completion
4. After error recovery
5. On scene initial load
6. (Future) After CV state reconciliation

### Contract 2: Scene → ViewModel Actions

**Problem**: Scenes need to trigger ViewModel logic  
**Solution**: Command pattern with clear action boundaries, extensible for CV

```swift
// Scene sends commands, doesn't make decisions
protocol GameActionHandler {
    func handleMove(from: CGPoint, to: CGPoint, source: InputSource)
    func handleSelection(at: CGPoint, source: InputSource)
    func handleGesture(_ gesture: GameGesture, source: InputSource)
    // Future CV: func handleCVEvent(_ event: CVGameEvent)
}

// ViewModel processes commands, updates state, notifies scene
extension BaseGameViewModel: GameActionHandler {
    func handleMove(from: CGPoint, to: CGPoint, source: InputSource = .touch) {
        // 1. Validate move (same logic for touch or CV)
        // 2. Update state
        // 3. Notify scene
        notifyScene()
    }
}
```

### Contract 3: Service Access Pattern

**Problem**: Inconsistent service access patterns  
**Solution**: Single ServiceContainer with guaranteed availability

```swift
// One way to access services everywhere
protocol ServiceProvider {
    var services: ServiceContainer { get }
}

// ViewModels get services through init
class BaseGameViewModel: ServiceProvider {
    let services: ServiceContainer
    
    init(services: ServiceContainer) {
        self.services = services
    }
}

// Scenes get services through ViewModel
class BaseGameScene {
    var services: ServiceContainer? {
        (viewModel as? ServiceProvider)?.services
    }
}
```

## Implementation Plan

### Phase 1: Establish Update Protocol (Week 1)

#### Step 1.1: Create Scene Update Contract
```swift
// GameStateSnapshot.swift - CV-ready structure
struct GameStateSnapshot {
    let pieces: [any Hashable]
    let isComplete: Bool
    let moveCount: Int
    let elapsedTime: TimeInterval
    let currentScore: Int
    let inputSource: InputSource  // Track input source for analytics/feedback
    let confidence: Float?         // Future CV: confidence level of detection
}

// SceneUpdateProtocol.swift
protocol SceneUpdateReceiver: AnyObject {
    func updateDisplay(with state: GameStateSnapshot)
    func showError(_ error: GameError)
    func playAnimation(_ animation: GameAnimation)
    // Future CV extensions:
    // func showCVGuidance(_ guidance: CVGuidance)
    // func updateConfidenceIndicator(_ level: Float)
}

// Input source tracking
enum InputSource {
    case touch
    case keyboard
    case cv  // Future: will replace touch for physical games
}
```

#### Step 1.2: Implement in BaseGameViewModel
```swift
extension BaseGameViewModel {
    weak var sceneReceiver: SceneUpdateReceiver?
    
    // Call after any state change
    private func notifySceneUpdate() {
        guard let scene = sceneReceiver else { return }
        
        let snapshot = createStateSnapshot()
        scene.updateDisplay(with: snapshot)
    }
}
```

#### Step 1.3: Implement in BaseGameScene
```swift
extension BaseGameScene: SceneUpdateReceiver {
    func updateDisplay(with state: GameStateSnapshot) {
        // Update visual elements based on state
        renderPieces(state.pieces)
        updateScoreLabel(state.currentScore)
        updateMoveCounter(state.moveCount)
    }
}
```

### Phase 2: Unify Service Access (Week 1)

#### Step 2.1: Establish ServiceContainer as Single Source
```swift
// ServiceContainer.swift
@MainActor
@Observable
final class ServiceContainer {
    // All services are non-optional with sensible defaults
    private(set) var audio: AudioServiceProtocol = MockAudioService()
    private(set) var analytics: AnalyticsServiceProtocol = MockAnalyticsService()
    private(set) var cv: CVServiceProtocol = MockCVService()
    private(set) var persistence: PersistenceServiceProtocol = MockPersistenceService()
    
    // Real services injected at app startup
    func configure(audio: AudioServiceProtocol? = nil,
                  analytics: AnalyticsServiceProtocol? = nil,
                  cv: CVServiceProtocol? = nil,
                  persistence: PersistenceServiceProtocol? = nil) {
        self.audio = audio ?? self.audio
        self.analytics = analytics ?? self.analytics
        self.cv = cv ?? self.cv
        self.persistence = persistence ?? self.persistence
    }
}
```

#### Step 2.2: Remove Optional Service Access
```swift
// Before: services?.audioService?.playSound() // Could fail silently
// After: services.audio.playSound() // Always works
```

### Phase 3: Simplify Storage Layer (Week 2)

#### Step 3.1: Replace Generic Storage with Enum
```swift
// PuzzleType.swift
enum PuzzleType: Codable {
    case tangram(TangramPuzzle)
    case sudoku(SudokuPuzzle)
    case rps(RPSGameState)
    
    var id: String {
        switch self {
        case .tangram(let p): return p.id
        case .sudoku(let p): return p.id
        case .rps(let s): return s.id
        }
    }
}

// SimplePuzzleStorage.swift
final class SimplePuzzleStorage {
    func save(_ puzzle: PuzzleType) async throws {
        let data = try JSONEncoder().encode(puzzle)
        try await persistence.save(data, for: puzzle.id)
    }
    
    func load(id: String, type: GameType) async throws -> PuzzleType? {
        guard let data = try await persistence.load(for: id) else { return nil }
        
        switch type {
        case .tangram:
            let puzzle = try JSONDecoder().decode(TangramPuzzle.self, from: data)
            return .tangram(puzzle)
        case .sudoku:
            let puzzle = try JSONDecoder().decode(SudokuPuzzle.self, from: data)
            return .sudoku(puzzle)
        case .rps:
            let state = try JSONDecoder().decode(RPSGameState.self, from: data)
            return .rps(state)
        }
    }
}
```

### Phase 4: Formalize Navigation State (Week 2)

#### Step 4.1: Create Navigation State Machine
```swift
// NavigationState.swift
@MainActor
@Observable
final class NavigationState {
    enum Route: Equatable {
        case home
        case lobby
        case game(GameType, GameMode)
        case settings
    }
    
    private(set) var currentRoute: Route = .home
    private(set) var isPresented: Bool = false
    
    func navigate(to route: Route) {
        // Validate transition
        guard canNavigate(from: currentRoute, to: route) else { return }
        currentRoute = route
    }
    
    private func canNavigate(from: Route, to: Route) -> Bool {
        // Define valid transitions
        switch (from, to) {
        case (.home, .lobby): return true
        case (.lobby, .game): return true
        case (.game, .home): return true
        default: return false
        }
    }
}
```

#### Step 4.2: Use in RootView
```swift
struct RootView: View {
    @State private var navigation = NavigationState()
    
    var body: some View {
        Group {
            switch navigation.currentRoute {
            case .home:
                HomeView()
            case .lobby:
                LobbyView()
            case .game(let type, let mode):
                GameHost(type: type, mode: mode)
            case .settings:
                SettingsView()
            }
        }
        .environment(navigation)
    }
}
```

### Phase 5: CV Foundation Setup (Week 3)

#### Step 5.1: Abstract Input Processing
```swift
// GameInputProcessor.swift - Abstraction for different input sources
protocol GameInputProcessor {
    func processInput(at point: CGPoint, source: InputSource) -> GameAction?
    func validateInput(_ input: GameInput) -> Bool
}

// CV-ready game action
enum GameAction {
    case movePiece(id: String, to: CGPoint)
    case selectPiece(id: String)
    case releasePiece(id: String)
    case rotatepiece(id: String, angle: Float)
}

// Future CV processor will implement this same protocol
class TouchInputProcessor: GameInputProcessor {
    func processInput(at point: CGPoint, source: InputSource) -> GameAction? {
        // Current touch logic
    }
}

// Future: CVInputProcessor will process CV events into same GameActions
```

#### Step 5.2: State Reconciliation Foundation
```swift
// StateReconciliation.swift - Foundation for physical/digital sync
protocol StateReconciliation {
    // Current: Used for undo/redo
    func captureState() -> GameStateMemento
    func restoreState(_ memento: GameStateMemento)
    
    // Future CV: Will extend for physical state sync
    // func reconcileWithPhysicalState(_ detected: PhysicalState)
}

struct GameStateMemento {
    let pieces: [PieceState]
    let timestamp: Date
    let source: InputSource
}
```

### Phase 6: Add Compliance Validation (Week 3)

#### Step 6.1: Architecture Tests
```swift
// ArchitectureTests.swift
final class ArchitectureComplianceTests: XCTestCase {
    func testViewModelsUseExplicitUpdates() {
        // Verify all ViewModels call notifySceneUpdate
    }
    
    func testScenesNeverObserveViewModels() {
        // Verify no KVO or Combine in Scenes
    }
    
    func testServicesAlwaysNonNil() {
        // Verify no optional service access
    }
}
```

#### Step 6.2: Debug Assertions
```swift
#if DEBUG
extension BaseGameScene {
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        assert(viewModel != nil, "ViewModel must be set")
        assert((viewModel as? ServiceProvider)?.services != nil, "Services must be available")
    }
}
#endif
```

## Migration Strategy

### Week 1: Foundation
1. Implement SceneUpdateReceiver protocol with InputSource tracking
2. Update BaseGameViewModel to use explicit updates
3. Update BaseGameScene to receive updates
4. Unify service access through ServiceContainer

### Week 2: Simplification
1. Replace generic storage with enum-based approach
2. Implement navigation state machine
3. Remove Combine/KVO from Scenes
4. Consolidate service injection

### Week 3: CV Foundation & Validation
1. Add input abstraction layer (GameInputProcessor)
2. Implement state reconciliation foundation
3. Add architecture compliance tests
4. Add debug assertions
5. Performance testing

## Success Criteria

### Immediate (Week 1)
- [ ] No crashes from nil services
- [ ] Scenes update when ViewModels change
- [ ] Clear update lifecycle

### Short-term (Week 2)
- [ ] Storage operations type-safe
- [ ] Navigation predictable
- [ ] No observation in Scenes

### Long-term (Week 3)
- [ ] All architecture tests pass
- [ ] No regression in functionality
- [ ] Performance metrics maintained

## Anti-Patterns to Avoid

### ❌ DON'T: Try to Make Scenes Observable
```swift
// BAD: Fighting the paradigm
class ObservableScene: SKScene, ObservableObject {
    @Published var someState: Int = 0 // Won't work properly
}
```

### ❌ DON'T: Add Complex Abstractions
```swift
// BAD: Over-engineering
protocol SceneUpdateMediatorFactoryDelegate {
    func createMediatorForUpdatingSceneViaViewModel() // Too complex
}
```

### ❌ DON'T: Mix Paradigms
```swift
// BAD: Declarative in imperative context
class GameScene: SKScene {
    @State var position: CGPoint // SwiftUI property wrapper in SpriteKit
}
```

### ✅ DO: Keep It Simple
```swift
// GOOD: Explicit and simple
func updateDisplay(with state: GameStateSnapshot) {
    // Just update the display
}
```

## Pattern Compliance Checklist

### UI Layer (SwiftUI)
- [ ] Uses @Observable for ViewModels
- [ ] No direct SpriteKit manipulation
- [ ] Navigation through NavigationState
- [ ] Services via Environment
- [ ] Input source tracking ready

### Game Layer (SpriteKit)
- [ ] Receives updates via protocol
- [ ] No observation of ViewModels
- [ ] Commands sent to ViewModel with InputSource
- [ ] Services via ViewModel reference
- [ ] Ready for CV feedback rendering

### Service Layer
- [ ] All protocols, no concrete types in APIs
- [ ] Stateless operations
- [ ] Mockable for testing
- [ ] No game-specific logic
- [ ] CV service slot prepared (MockCVService by default)

### CV Foundation (Future-Ready)
- [ ] InputSource enum includes .cv case
- [ ] GameAction abstraction for all inputs
- [ ] State reconciliation protocol defined
- [ ] GameInputProcessor abstraction ready
- [ ] CVService protocol in ServiceContainer

## CV Integration Path (Future)

When ready to add CV capabilities:

1. **Implement CVInputProcessor**
   - Inherits from GameInputProcessor
   - Converts CV events to GameActions
   - Same interface as TouchInputProcessor

2. **Extend SceneUpdateReceiver**
   - Uncomment CV feedback methods
   - Add confidence indicators
   - Show physical guidance overlays

3. **Add CV Event Stream**
   - ServiceContainer gets real CVService
   - ViewModel subscribes to CV events
   - Routes through same handleMove() logic

4. **Physical State Reconciliation**
   - Extend StateReconciliation protocol
   - Add physical/digital sync logic
   - Handle detection confidence

The key is that **all game logic remains unchanged** - only the input source changes from touch to CV.

## Conclusion

This plan ensures proper separation between layers by:

1. **Accepting paradigm differences** - Not trying to force observation on SpriteKit
2. **Explicit contracts** - Clear, simple protocols between layers
3. **Single patterns** - One way to do each thing
4. **No over-engineering** - Simple solutions to specific problems
5. **Testable boundaries** - Each layer independently testable
6. **CV-ready foundation** - Abstractions in place for seamless CV integration

The architecture embraces the natural boundaries between SwiftUI's declarative model, SpriteKit's imperative nature, and the Service layer's protocol-based design. By keeping contracts simple and explicit, we maintain flexibility without complexity. The CV foundation ensures that when physical gameplay is added, it will slot in naturally without requiring architectural changes.

## Next Steps

1. Review plan with team
2. Create feature branch for implementation
3. Implement Phase 1 (Update Protocol)
4. Test with one game module (suggest Tangram)
5. Roll out to other modules
6. Add compliance tests
7. Document for future development

---

*Document Version: 2.0*  
*Updated: 2025*  
*Architecture: Three-Layer Separation with CV Foundation*  
*Complexity: Deliberately Simple, CV-Ready*