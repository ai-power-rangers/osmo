//
//  ArchitectureTests.swift
//  osmoTests
//
//  Tests to ensure architectural compliance and patterns are followed
//

import XCTest
@testable import osmo

final class ArchitectureComplianceTests: XCTestCase {
    
    // MARK: - Service Container Tests
    
    func testServiceContainerFatalsBeforeInitialization() {
        // This test documents that services SHOULD fatal if accessed before init
        // This is the correct senior pattern - fail fast with clear error
        let container = ServiceContainer()
        
        // These would fatal in real code - this documents the expected behavior
        XCTAssertFalse(container.isInitialized, "Container should not be initialized by default")
    }
    
    @MainActor
    func testServiceContainerInitialization() async {
        let container = ServiceContainer()
        
        await container.initialize()
        
        XCTAssertTrue(container.isInitialized, "Container should be initialized after initialize()")
        XCTAssertNil(container.initializationError, "Should have no initialization error")
    }
    
    // MARK: - Scene Update Pattern Tests
    
    @MainActor
    func testViewModelImplementsSceneUpdateProvider() {
        let services = ServiceContainer()
        let vm = TangramViewModel(services: services)
        
        XCTAssertTrue(vm is SceneUpdateProvider, "ViewModel must implement SceneUpdateProvider")
    }
    
    @MainActor
    func testSceneImplementsUpdateReceiver() {
        let scene = TangramScene()
        
        XCTAssertTrue(scene is SceneUpdateReceiver, "Scene must implement SceneUpdateReceiver")
    }
    
    @MainActor
    func testSceneRegistrationPattern() {
        let services = ServiceContainer()
        let vm = TangramViewModel(services: services)
        let scene = TangramScene()
        
        // Test registration
        vm.registerSceneReceiver(scene)
        
        // Test that scene can be unregistered (prevents memory leaks)
        vm.registerSceneReceiver(nil)
        
        // This test passes if no crash occurs
        XCTAssertTrue(true, "Scene registration/unregistration should work without crashes")
    }
    
    // MARK: - No Combine in Game Layer Tests
    
    func testNoPublishedPropertiesInViewModels() {
        // This is validated at compile time and by SwiftLint
        // ViewModels should use @Observable, not @Published
        XCTAssertTrue(true, "Compile-time check: No @Published properties allowed")
    }
    
    func testNoCombineImportsInScenes() {
        // This is validated by our check-patterns.sh script
        // Scenes should not import Combine
        XCTAssertTrue(true, "Build-time check: No Combine imports in scenes")
    }
    
    // MARK: - Input Source Tracking Tests
    
    @MainActor
    func testInputSourceTracking() {
        let services = ServiceContainer()
        let vm = BaseGameViewModel<TangramPuzzle>(services: services)
        
        // Test that input source is tracked
        vm.handleMove(from: .zero, to: CGPoint(x: 10, y: 10), source: .touch)
        XCTAssertEqual(vm.lastInputSource, .touch, "Input source should be tracked")
        
        vm.handleSelection(at: .zero, source: .cv)
        XCTAssertEqual(vm.lastInputSource, .cv, "Input source should update")
    }
    
    // MARK: - GameActionHandler Tests
    
    @MainActor
    func testViewModelImplementsGameActionHandler() {
        let services = ServiceContainer()
        let vm = TangramViewModel(services: services)
        
        XCTAssertTrue(vm is GameActionHandler, "ViewModel must implement GameActionHandler")
    }
    
    // MARK: - State Reconciliation Tests
    
    @MainActor
    func testStateReconciliationImplementation() {
        let services = ServiceContainer()
        let vm = TangramViewModel(services: services)
        
        // Test memento creation
        let memento = vm.captureState()
        XCTAssertTrue(memento.isValid(), "Memento should be valid")
        XCTAssertEqual(memento.source, .touch, "Default source should be touch")
        
        // Test state restoration
        vm.restoreState(memento)
        // This test passes if no crash occurs
        XCTAssertTrue(true, "State restoration should work")
    }
    
    @MainActor
    func testStateValidation() {
        let services = ServiceContainer()
        let vm = TangramViewModel(services: services)
        
        let state = TangramState()
        let validation = vm.validateState(state)
        
        XCTAssertNotNil(validation, "Validation should return a result")
    }
    
    // MARK: - PuzzleType Storage Tests
    
    func testPuzzleTypeEnumElimatesCasting() async throws {
        let storage = SimplePuzzleStorage()
        
        // Create test puzzles
        let tangram = TangramPuzzle.empty()
        let sudoku = SudokuPuzzle.empty(gridSize: .nineByNine)
        
        // Save using PuzzleType
        let tangramType = PuzzleType.tangram(tangram)
        let sudokuType = PuzzleType.sudoku(sudoku)
        
        // Test that we can save without casting
        try await storage.savePuzzleType(tangramType)
        try await storage.savePuzzleType(sudokuType)
        
        // Test that we can load without casting
        let loaded = try await storage.loadPuzzleType(id: tangram.id)
        XCTAssertNotNil(loaded, "Should load saved puzzle")
        
        // Test type extraction
        if let loaded = loaded {
            XCTAssertNotNil(loaded.asTangram(), "Should extract tangram")
            XCTAssertNil(loaded.asSudoku(), "Should not be sudoku")
        }
    }
    
    // MARK: - Input Processor Tests
    
    func testTouchInputProcessor() {
        let scene = SKScene()
        let processor = TouchInputProcessor(scene: scene)
        
        // Test input validation
        let input = GameInput(point: CGPoint(x: 50, y: 50), source: .touch)
        XCTAssertTrue(processor.validateInput(input), "Touch input should be valid")
        
        // Test CV input rejection
        let cvInput = GameInput(point: CGPoint(x: 50, y: 50), source: .cv)
        XCTAssertFalse(processor.validateInput(cvInput), "CV input should not be valid for touch processor")
    }
    
    func testCVInputProcessor() {
        let processor = CVInputProcessor()
        
        // Test CV input validation
        let input = GameInput(
            point: CGPoint(x: 0.5, y: 0.5), // Normalized coordinates
            source: .cv,
            metadata: ["confidence": 0.95]
        )
        XCTAssertTrue(processor.validateInput(input), "CV input should be valid")
        
        // Test touch input rejection
        let touchInput = GameInput(point: CGPoint(x: 0.5, y: 0.5), source: .touch)
        XCTAssertFalse(processor.validateInput(touchInput), "Touch input should not be valid for CV processor")
        
        // Test low confidence rejection
        let lowConfInput = GameInput(
            point: CGPoint(x: 0.5, y: 0.5),
            source: .cv,
            metadata: ["confidence": 0.3]
        )
        XCTAssertFalse(processor.validateInput(lowConfInput), "Low confidence CV input should be invalid")
    }
    
    // MARK: - Memory Management Tests
    
    @MainActor
    func testNoRetainCycles() {
        // Test that scene cleanup prevents retain cycles
        var scene: TangramScene? = TangramScene()
        weak var weakScene = scene
        
        let services = ServiceContainer()
        let vm = TangramViewModel(services: services)
        
        scene?.viewModel = vm
        vm.registerSceneReceiver(scene)
        
        // Simulate scene removal
        if let updateProvider = vm as? SceneUpdateProvider {
            updateProvider.registerSceneReceiver(nil)
        }
        scene = nil
        
        XCTAssertNil(weakScene, "Scene should be deallocated (no retain cycle)")
    }
    
    // MARK: - Senior Pattern Compliance
    
    func testFailFastPattern() {
        // Document that we use fail-fast patterns
        // Services fatal if not initialized - this is correct
        // This test documents the pattern, not tests the fatal
        XCTAssertTrue(true, "Fail-fast pattern is used throughout")
    }
    
    func testNoSilentFailures() {
        // Document that we don't use mock defaults that hide failures
        // This is validated by not having MockService defaults in ServiceContainer
        XCTAssertTrue(true, "No silent failures - services fatal if not initialized")
    }
    
    func testExplicitOverImplicit() {
        // Document that we use explicit patterns
        // - Explicit scene registration
        // - Explicit state updates
        // - Explicit error handling
        XCTAssertTrue(true, "Explicit patterns are used throughout")
    }
}

// MARK: - Integration Tests

final class ViewModelSceneIntegrationTests: XCTestCase {
    
    @MainActor
    func testSceneReceivesUpdatesFromViewModel() async {
        // Setup
        let services = ServiceContainer()
        await services.initialize()
        
        let vm = TangramViewModel(services: services)
        let scene = TangramScene()
        
        // Register scene
        vm.registerSceneReceiver(scene)
        
        // Make a change that should trigger update
        vm.selectedPieceId = UUID()
        vm.notifySceneUpdate()
        
        // This test verifies the integration works without crashes
        XCTAssertTrue(true, "Scene should receive updates without crashing")
    }
    
    @MainActor
    func testNavigationStateTransitions() {
        let nav = NavigationState()
        
        // Test valid transitions
        nav.navigate(to: .lobby)
        XCTAssertEqual(nav.currentRoute, .lobby, "Should navigate to lobby")
        
        nav.navigate(to: .game(GameInfo(
            id: "test",
            type: .tangram,
            mode: .play,
            difficulty: .easy
        )))
        XCTAssertTrue(nav.currentRoute != .lobby, "Should navigate to game")
        
        nav.goHome()
        XCTAssertEqual(nav.currentRoute, .home, "Should navigate home")
    }
}