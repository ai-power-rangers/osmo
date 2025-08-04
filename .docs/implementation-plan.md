# Architecture Refactor Implementation Plan

## Overview
This document outlines the step-by-step implementation of the architecture refactor based on `.docs/new-plan.md`.

## Files Requiring Updates

### Critical Path (Blocking other changes)
1. **BaseGameScene.swift** - Remove Combine, implement SceneUpdateReceiver
2. **BaseGameViewModel.swift** - Add explicit scene update methods
3. **ServiceContainer.swift** - Make services non-optional

### High Priority (Core functionality)
4. **TangramScene.swift** - Remove Combine observation
5. **TangramViewModel.swift** - Clean up service access
6. **SudokuScene.swift** - Implement proper update pattern
7. **SudokuViewModel.swift** - Remove Combine, use base timer

### Medium Priority (Clean architecture)
8. **EnvironmentServices.swift** - Non-optional services
9. **GameHost.swift** - Simplify service access
10. **UniversalPuzzleStorage.swift** - Simplify generics

### Low Priority (Future CV foundation)
11. Create **SceneUpdateProtocol.swift**
12. Create **GameInputProcessor.swift**
13. Create **NavigationState.swift**

## Phase 1: Scene Update Protocol (Immediate)

### Step 1.1: Create Protocol Files
```bash
# New files to create
osmo/Core/Protocols/SceneUpdateProtocol.swift
osmo/Core/Protocols/GameActionHandler.swift
osmo/Core/Models/GameStateSnapshot.swift
osmo/Core/Models/InputSource.swift
```

### Step 1.2: Update BaseGameViewModel
- Add `weak var sceneReceiver: SceneUpdateReceiver?`
- Add `notifyScene()` method
- Add `createStateSnapshot()` method
- Remove any Combine publishers

### Step 1.3: Update BaseGameScene
- Remove `import Combine`
- Remove `private var cancellables`
- Implement `SceneUpdateReceiver` protocol
- Replace binding setup with explicit updates
- Add `viewModel as? GameActionHandler` pattern

### Step 1.4: Update Concrete Scenes
- **TangramScene**: Remove Combine, implement updateDisplay()
- **SudokuScene**: Implement updateDisplay()
- **RockPaperScissorsGameScene**: Implement updateDisplay()

## Phase 2: Service Access Unification

### Step 2.1: ServiceContainer Updates
- Make all service properties non-optional with defaults
- Remove `requireX()` methods
- Add MockServices as defaults
- Ensure configure() method works properly

### Step 2.2: Environment Services
- Change all service environment keys to non-optional
- Update ServiceRequirement views
- Simplify injection patterns

### Step 2.3: ViewModel Service Access
- Update all `gameContext?.service` to `services.service`
- Remove defensive optional chaining
- Ensure services are injected in init

## Phase 3: Remove Combine Dependencies

### Step 3.1: Timer Management
- SudokuViewModel: Use inherited timer from BaseGameViewModel
- Remove custom timer implementations
- Standardize timer start/stop patterns

### Step 3.2: Property Observation
- Remove all `@Published` properties
- Remove all `.sink` subscriptions
- Remove all `AnyCancellable` storage
- Use direct property access with @Observable

## Phase 4: Storage Simplification

### Step 4.1: Create Enum-Based Storage
```swift
enum PuzzleType: Codable {
    case tangram(TangramPuzzle)
    case sudoku(SudokuPuzzle)
    case rps(RPSGameState)
}
```

### Step 4.2: Simplify UniversalPuzzleStorage
- Replace generic methods with PuzzleType enum
- Remove type casting logic
- Simplify save/load operations

## Phase 5: Navigation State Machine

### Step 5.1: Create NavigationState
- Observable navigation state manager
- Route enum with associated values
- Transition validation

### Step 5.2: Update RootView
- Use NavigationState for routing
- Remove sheet/fullscreen presentation logic
- Centralize navigation decisions

## Phase 6: CV Foundation (Future-Ready)

### Step 6.1: Input Abstraction
- Create GameInputProcessor protocol
- Add InputSource enum with .cv case
- Create TouchInputProcessor implementation

### Step 6.2: State Reconciliation
- Create StateReconciliation protocol
- Add GameStateMemento structure
- Prepare for physical/digital sync

## Implementation Order

### Day 1: Foundation
1. ✅ Create protocol files (SceneUpdateProtocol, GameActionHandler)
2. ✅ Update BaseGameViewModel with scene notification
3. ✅ Update BaseGameScene to remove Combine
4. ✅ Test with one game (Tangram)

### Day 2: Service Cleanup  
5. ⏳ Make ServiceContainer services non-optional
6. ⏳ Update EnvironmentServices
7. ⏳ Fix all optional service access in ViewModels
8. ⏳ Test service injection

### Day 3: Complete Combine Removal
9. ⏳ Remove Combine from TangramScene
10. ⏳ Fix SudokuViewModel timer
11. ⏳ Remove all remaining Combine imports
12. ⏳ Verify no regressions

### Day 4: Storage & Navigation
13. ⏳ Implement PuzzleType enum
14. ⏳ Simplify UniversalPuzzleStorage
15. ⏳ Create NavigationState
16. ⏳ Update RootView

### Day 5: CV Foundation & Testing
17. ⏳ Add input abstraction layer
18. ⏳ Create compliance tests
19. ⏳ Performance testing
20. ⏳ Documentation

## Verification Checklist

### After Phase 1
- [ ] No Combine imports in game files
- [ ] Scenes update when ViewModels change
- [ ] Touch interactions work properly

### After Phase 2
- [ ] No optional service access
- [ ] No service-related crashes
- [ ] Consistent service patterns

### After Phase 3
- [ ] All @Published removed
- [ ] All cancellables removed
- [ ] Timers work correctly

### After Phase 4
- [ ] Storage operations work
- [ ] Type safety maintained
- [ ] No generic casting issues

### After Phase 5
- [ ] Navigation is predictable
- [ ] No presentation issues
- [ ] State transitions validated

### After Phase 6
- [ ] Input abstraction in place
- [ ] CV foundation ready
- [ ] No functionality regression

## Risk Mitigation

1. **Test after each phase** - Don't accumulate changes
2. **Keep old code commented** - For quick rollback
3. **Focus on one game first** - Tangram as pilot
4. **Maintain functionality** - No feature regression
5. **Document gotchas** - For team knowledge

## Success Metrics

- Zero Combine imports in game layer
- Zero optional service crashes
- All tests passing
- Performance maintained or improved
- Clean architecture compliance

---

*Implementation Start: [Today]*  
*Target Completion: 5 Days*  
*Priority: High*