# iOS Patterns & Architecture Guide

## Core Principles

This document defines the **DEFINITIVE** patterns for the osmo codebase. These are not suggestions - they are requirements.

### Platform Requirements
- **Minimum iOS Version**: iOS 17.0
- **No UIKit**: SwiftUI and SpriteKit only
- **Modern Swift**: Swift 5.9+ features including @Observable macro

## 1. Observation & State Management

### ✅ CORRECT Pattern (iOS 17+)

```swift
// View Models use @Observable
@Observable
final class GameViewModel {
    var score: Int = 0
    var isPlaying: Bool = false
    // NO @Published - all properties are automatically observable
}

// Views use @State for ownership
struct GameView: View {
    @State private var viewModel = GameViewModel()
    
    var body: some View {
        // Automatic observation - no manual binding needed
        Text("Score: \(viewModel.score)")
    }
}

// Environment injection
struct RootView: View {
    @State private var services = ServiceContainer()
    
    var body: some View {
        ContentView()
            .environment(services) // NOT .environmentObject()
    }
}
```

### ❌ INCORRECT Patterns

```swift
// DON'T use ObservableObject
class OldViewModel: ObservableObject {
    @Published var score: Int = 0  // WRONG
}

// DON'T use @StateObject or @ObservedObject
struct OldView: View {
    @StateObject var viewModel = OldViewModel() // WRONG
    @ObservedObject var viewModel: OldViewModel  // WRONG
    @EnvironmentObject var services: ServiceContainer // WRONG
}

// DON'T mix Combine with @Observable
@Observable
class BadViewModel {
    var score: Int = 0
    var cancellables = Set<AnyCancellable>() // WRONG - no Combine
}
```

## 2. Framework Boundaries

### SwiftUI vs SpriteKit

| Component | Framework | Purpose | Communication |
|-----------|-----------|---------|--------------|
| Views | SwiftUI | UI, navigation, user input | Direct property binding to ViewModels |
| Scenes | SpriteKit | Game rendering, animations | Read from ViewModels, notify via delegates |
| ViewModels | Pure Swift | Game logic, state management | @Observable for SwiftUI, delegates for SpriteKit |
| Services | Pure Swift | Infrastructure (audio, storage, etc.) | Injected via environment or initializers |

### SpriteKit Integration Pattern

```swift
// CORRECT: Scene reads from ViewModel, notifies via delegate
protocol GameSceneDelegate: AnyObject {
    func sceneDidSelectNode(at position: CGPoint)
    func sceneDidCompleteLevel()
}

class GameScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?
    
    // Direct property access for reading
    func updateFromViewModel(_ viewModel: GameViewModel) {
        scoreLabel.text = "\(viewModel.score)"
    }
    
    // Delegate for writing
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameDelegate?.sceneDidSelectNode(at: location)
    }
}

// ViewModel implements delegate
@Observable
final class GameViewModel: GameSceneDelegate {
    func sceneDidSelectNode(at position: CGPoint) {
        // Update state
        score += 1
    }
}
```

### ❌ WRONG: Don't use Combine in SpriteKit

```swift
// DON'T DO THIS
class BadScene: SKScene {
    var cancellables = Set<AnyCancellable>() // WRONG
    
    func observeViewModel(_ vm: GameViewModel) {
        vm.$score.sink { [weak self] score in  // WRONG - @Observable doesn't have publishers
            self?.updateScore(score)
        }.store(in: &cancellables)
    }
}
```

## 3. Service Architecture

### Service Definition

```swift
// Protocol for abstraction
public protocol AudioServiceProtocol: AnyObject {
    func playSound(_ name: String)
    func stopSound(_ name: String)
}

// Concrete implementation
@Observable
final class AudioService: AudioServiceProtocol {
    func playSound(_ name: String) { /* implementation */ }
    func stopSound(_ name: String) { /* implementation */ }
}
```

### Service Injection

```swift
// CORRECT: Via environment
@Observable
final class ServiceContainer {
    let audio: AudioServiceProtocol
    let storage: StorageServiceProtocol
    
    init() {
        self.audio = AudioService()
        self.storage = StorageService()
    }
}

// In views
struct GameView: View {
    @Environment(ServiceContainer.self) private var services
    
    var body: some View {
        Button("Play") {
            services.audio.playSound("click")
        }
    }
}

// In ViewModels - via initializer
@Observable
final class GameViewModel {
    private let audioService: AudioServiceProtocol
    
    init(audioService: AudioServiceProtocol) {
        self.audioService = audioService
    }
}
```

## 4. Navigation

### Use NavigationStack Exclusively

```swift
// CORRECT: NavigationStack with value-based routing
struct RootView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            MenuView()
                .navigationDestination(for: GameRoute.self) { route in
                    switch route {
                    case .sudoku:
                        SudokuGameView()
                    case .tangram:
                        TangramGameView()
                    }
                }
        }
    }
}

// Navigate programmatically
Button("Play Sudoku") {
    path.append(GameRoute.sudoku)
}
```

### ❌ AVOID These Patterns

```swift
// DON'T use fullScreenCover for navigation
.fullScreenCover(isPresented: $showGame) { // WRONG for navigation
    GameView()
}

// DON'T use NavigationView (deprecated)
NavigationView { // WRONG - use NavigationStack
    Content()
}
```

## 5. File Structure

```
osmo/
├── App/                      # App lifecycle, main views
│   ├── osmoApp.swift        # @main App struct
│   └── Views/               # Root navigation views
├── Core/                    # Shared infrastructure
│   ├── Services/            # @Observable services
│   ├── GameBase/           # Base classes for games
│   │   ├── ViewModels/     # BaseGameViewModel
│   │   └── Scenes/         # BaseGameScene
│   └── UI/                 # Shared SwiftUI components
├── Games/                   # Individual games
│   └── [GameName]/
│       ├── Models/         # Data models (Codable structs)
│       ├── [Game]ViewModel.swift  # @Observable view model
│       ├── [Game]Scene.swift      # SKScene for rendering
│       ├── [Game]View.swift       # SwiftUI container
│       └── Views/          # Game-specific UI components
```

## 6. Type Visibility Rules

### Public vs Internal

```swift
// Protocols that cross module boundaries must be public
public protocol GameModule { }

// Types used in protocols must match visibility
public struct GameInfo { // Must be public if used in public protocol
    public let id: String // Properties must also be public
}

// Internal by default for module-only types
struct InternalModel { } // Only visible within module
```

## 7. Color System

### ✅ Use SwiftUI Colors

```swift
// CORRECT
Color.blue
Color.secondary
Color(red: 0.5, green: 0.5, blue: 0.5)

// For SpriteKit
SKColor.blue  // This is UIColor on iOS but type-aliased
```

### ❌ Don't Use UIKit Colors

```swift
// WRONG
UIColor.systemBlue
Color(UIColor.systemBackground)
```

## 8. Enforcement Mechanisms

### SwiftLint Configuration

Create `.swiftlint.yml`:

```yaml
# Enforce no UIKit imports except in specific allowed files
custom_rules:
  no_uikit:
    name: "No UIKit"
    regex: '^import UIKit'
    match_kinds:
      - keyword
    message: "UIKit is not allowed. Use SwiftUI instead."
    severity: error
    excluded:
      - "*/CameraPreviewView.swift"  # Allowed for camera integration

  no_combine_with_observable:
    name: "No Combine with @Observable"
    regex: '@Observable[\s\S]*import Combine'
    message: "@Observable classes should not use Combine"
    severity: error

  no_published:
    name: "No @Published"
    regex: '@Published'
    message: "Use @Observable instead of @Published"
    severity: error

  no_stateobject:
    name: "No @StateObject"
    regex: '@StateObject|@ObservedObject|@EnvironmentObject'
    message: "Use @State and @Environment with @Observable"
    severity: error
```

### Build Phase Script

Add to Xcode build phases:

```bash
#!/bin/bash

# Check for pattern violations
if grep -r "ObservableObject" --include="*.swift" .; then
    echo "error: ObservableObject found. Use @Observable instead."
    exit 1
fi

if grep -r "@Published" --include="*.swift" .; then
    echo "error: @Published found. Use @Observable instead."
    exit 1
fi

if grep -r "UIColor\|UIScreen\|UIViewController" --include="*.swift" \
   --exclude="CameraPreviewView.swift" .; then
    echo "error: UIKit usage found. Use SwiftUI equivalents."
    exit 1
fi
```

### Code Review Checklist

- [ ] No ObservableObject or @Published
- [ ] No @StateObject, @ObservedObject, or @EnvironmentObject
- [ ] No Combine in @Observable classes
- [ ] No UIKit except in designated wrapper views
- [ ] SpriteKit scenes use delegates, not Combine
- [ ] Services injected via environment or initializer
- [ ] Navigation uses NavigationStack exclusively
- [ ] All public protocol requirements have public types

## 9. Migration Guide

### From ObservableObject to @Observable

```swift
// Before
class OldViewModel: ObservableObject {
    @Published var score = 0
    func increment() {
        score += 1
    }
}

// After
@Observable
final class NewViewModel {
    var score = 0
    func increment() {
        score += 1
    }
}
```

### From Combine to Direct Observation

```swift
// Before (in SKScene)
viewModel.$score
    .sink { [weak self] score in
        self?.updateScore(score)
    }
    .store(in: &cancellables)

// After (in SKScene)
// Call this when scene needs to sync
func syncWithViewModel() {
    updateScore(viewModel.score)
}
```

### From UIKit to SwiftUI

| UIKit | SwiftUI |
|-------|---------|
| UIColor.systemBlue | Color.blue |
| UIColor.label | Color.primary |
| UIColor.secondaryLabel | Color.secondary |
| UIColor.systemBackground | Color(UIColor.systemBackground) or Color.clear |
| UIScreen.main.bounds | GeometryReader { geo in ... } |
| UIActivityViewController | ShareLink (iOS 16+) |

## 10. Testing Patterns

```swift
// ViewModels are easily testable
@Test
func testScoreIncrement() {
    let viewModel = GameViewModel()
    viewModel.incrementScore()
    #expect(viewModel.score == 1)
}

// Mock services for testing
final class MockAudioService: AudioServiceProtocol {
    var playSoundCalled = false
    func playSound(_ name: String) {
        playSoundCalled = true
    }
}
```

## Enforcement

**This document is enforced through:**

1. **Automated linting** via SwiftLint custom rules
2. **Build phase scripts** that fail on violations
3. **Code review requirements** using the checklist
4. **CI/CD pipeline** that runs pattern checks

**Violations will block:**
- Local builds (via build scripts)
- Pull request merges (via CI checks)
- Production deployments

## Version History

- v1.0 (2024-01-03): Initial patterns document
- Core requirement: iOS 17+ with @Observable
- No UIKit except for camera integration
- SpriteKit/SwiftUI boundary via delegates