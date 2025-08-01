# Tangram Game Implementation Tracker

## Overview
This document provides a comprehensive implementation plan for the Tangram puzzle game as a universal iOS touch-based experience. The game will adapt to both iPhone and iPad screen sizes with responsive layouts. CV integration with physical pieces will be added in a future phase.

## Core Features (Phase 1)
- **Platform**: Universal iOS (iPhone & iPad)
- **Orientation**: Both portrait and landscape supported
- **Interaction**: Touch-based drag and rotate
- **Puzzle Selection**: Visual grid of completed puzzle images
- **Gameplay**: Drag pieces from tray to match outline, with snap-to-place mechanics
- **Feedback**: Positive/negative signals, rotation hints, completion celebration
- **Timer**: Track completion time for each puzzle
- **Responsive Design**: Adaptive layouts for different screen sizes

## Project Status: 🚀 Ready to Start

### Phase 1: Foundation & Core Touch Gameplay (Week 1-2)
- [ ] **1.1 Create Game Module Structure**
  - [ ] Create `osmo/Games/Tangram/` directory
  - [ ] Implement `TangramGameModule.swift` (universal iOS)
  - [ ] Define game metadata in GameInfo
  - [ ] Register game in `GameHost.swift`
  - [ ] Support both portrait and landscape orientations

- [ ] **1.2 Puzzle Selection Screen**
  - [ ] Create `TangramPuzzleSelectView.swift` 
  - [ ] Design adaptive grid layout (2 columns iPhone, 3-4 iPad)
  - [ ] Show completed cat puzzle image
  - [ ] Add placeholder slots for future puzzles
  - [ ] Implement navigation to game scene
  - [ ] Scale thumbnails based on screen size

- [ ] **1.3 Data Models & Assets**
  - [ ] Create `Models/TangramModels.swift` with SIMD2 support
  - [ ] Migrate cat.json and camel.json to `Games/Tangram/Puzzles/`
  - [ ] Create BlueprintStore for puzzle loading
  - [ ] Implement TangramPieceFactory for SKShapeNode generation
  - [ ] Setup programmatic rendering (NO PNG assets needed)
  - [ ] Define canonical shape vertices from math spec

- [ ] **1.4 Core Game Scene**
  - [ ] Implement `TangramGameScene.swift` (full screen)
  - [ ] Create responsive game board layout
  - [ ] Adaptive piece tray (bottom landscape, side portrait)
  - [ ] Scale UI elements based on screen size
  - [ ] Implement exit button overlay
  - [ ] Add timer display with readable font sizes

### Phase 2: Touch Mechanics & Feedback (Week 2-3)
- [ ] **2.1 Target Outline Display**
  - [ ] Generate grey/black outlines from puzzle definition
  - [ ] Display target silhouette on game board
  - [ ] Ensure proper positioning and scale
  - [ ] Add subtle shadow effects

- [ ] **2.2 Piece Rendering & Tray**
  - [ ] Create colorful tangram pieces (7 distinct colors)
  - [ ] Position pieces randomly in bottom tray
  - [ ] Add visual separation from game board
  - [ ] Implement piece highlighting on selection

- [ ] **2.3 Touch & Drag Implementation**
  - [ ] Single finger drag for piece movement
  - [ ] Two-finger rotate gesture (or rotate button)
  - [ ] Piece follows finger smoothly
  - [ ] Constrain movement to screen bounds
  - [ ] Visual feedback on piece selection

- [ ] **2.4 Rotation Mechanics**
  - [ ] Implement 45-degree rotation snapping
  - [ ] Add rotation visual indicator
  - [ ] Smooth rotation animations
  - [ ] Alternative: dedicated rotate button

### Phase 3: Snap Logic & Intelligent Feedback (Week 3-4)
- [ ] **3.1 Snap Detection Algorithm**
  - [ ] Define snap tolerance (position & rotation)
  - [ ] Implement proximity checking to targets
  - [ ] Create smooth snap animations
  - [ ] Lock pieces when correctly placed

- [ ] **3.2 Intelligent Hint System**
  - [ ] Detect if piece is correct but needs rotation
  - [ ] Show rotation hint message/animation
  - [ ] Detect wrong piece for target position
  - [ ] Display "try different piece" feedback
  - [ ] Progressive hints on repeated attempts

- [ ] **3.3 Feedback System**
  - [ ] Positive feedback: success sound + visual pulse
  - [ ] Negative feedback: gentle shake + error sound
  - [ ] Haptic feedback for all interactions
  - [ ] Visual indicators for near-snap positions

- [ ] **3.4 Timer & Progress**
  - [ ] Start timer when first piece moved
  - [ ] Display elapsed time prominently
  - [ ] Track pieces placed counter
  - [ ] Save best times per puzzle

### Phase 4: Completion & Polish (Week 4-5)
- [ ] **4.1 Win Celebration**
  - [ ] Detect puzzle completion
  - [ ] Trigger confetti animation
  - [ ] Play celebration sound/music
  - [ ] Show completion time
  - [ ] Display "Play Again" / "Next Puzzle" options

- [ ] **4.2 Game Controls**
  - [ ] Reset puzzle button
  - [ ] Return to puzzle selection
  - [ ] Sound on/off toggle
  - [ ] Help/tutorial overlay

- [ ] **4.3 Visual Polish**
  - [ ] Piece shadows and depth
  - [ ] Smooth animations throughout
  - [ ] Particle effects for feedback
  - [ ] Professional color scheme

- [ ] **4.4 Audio Integration**
  - [ ] Piece pickup/drop sounds
  - [ ] Snap success sound
  - [ ] Error/hint sounds
  - [ ] Background ambient music
  - [ ] Victory fanfare

### Phase 5: Testing & Future Preparation (Week 5)
- [ ] **5.1 Device Testing**
  - [ ] Test on iPhone SE (smallest)
  - [ ] Test on iPhone 15 Pro Max
  - [ ] Test on iPad mini
  - [ ] Test on iPad Pro 12.9"
  - [ ] Verify rotation handling
  - [ ] Ensure 60fps on all devices

- [ ] **5.2 Comprehensive Testing**
  - [ ] Unit tests for snap detection
  - [ ] UI tests for responsive layouts
  - [ ] Performance benchmarks per device
  - [ ] Touch accuracy testing
  - [ ] Memory profiling on older devices

- [ ] **5.3 CV Preparation (Future)**
  - [ ] Document piece detection requirements
  - [ ] Plan physical piece design specs
  - [ ] Define CV event integration points
  - [ ] Create hybrid touch/CV architecture

## Technical Architecture

### 1. TangramGameModule Implementation (Universal iOS)
```swift
final class TangramGameModule: GameModule {
    static let gameId = "tangram"
    
    static let gameInfo = GameInfo(
        gameId: gameId,
        displayName: "Tangram Puzzles",
        description: "Classic shape puzzles - arrange colorful pieces to match the target",
        iconName: "square.on.square",
        minAge: 5,
        maxAge: 99,
        category: .spatialReasoning,
        isLocked: false,
        bundleSize: 15,
        requiredCVEvents: [] // No CV in Phase 1
    )
    
    required init() {}
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        let scene = TangramGameScene(size: size)
        scene.gameContext = context
        scene.scaleMode = .aspectFill
        
        // Configure scene for device type
        scene.deviceType = UIDevice.current.userInterfaceIdiom
        
        return scene
    }
    
    func cleanup() {
        // Release resources
    }
}
```

### 2. Data Model Architecture (Exact Implementation)
```swift
// TangramModels.swift
import simd

enum TangramShape: String, Codable {
    case largeTriangle1, largeTriangle2
    case mediumTriangle  // No suffix - matches "mediumTriangle" in JSON
    case smallTriangle1, smallTriangle2
    case square         // No suffix - matches "square" in JSON
    case parallelogram  // No suffix - matches "parallelogram" in JSON
}

struct PieceDefinition: Codable {
    let pieceId: String  // String to match JSON exactly
    let targetPosition: SIMD2<Double>   // Unit grid 0-8, using SIMD for performance
    let targetRotation: Double          // Radians, multiples of π/4
    let isMirrored: Bool?               // Only for parallelogram
    
    // Custom decoding to handle x,y structure from JSON
    private enum CodingKeys: String, CodingKey {
        case pieceId, targetRotation, isMirrored
        case targetPosition
    }
    
    private struct Position: Codable {
        let x: Double
        let y: Double
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pieceId = try container.decode(String.self, forKey: .pieceId)
        let pos = try container.decode(Position.self, forKey: .targetPosition)
        targetPosition = SIMD2<Double>(pos.x, pos.y)
        targetRotation = try container.decode(Double.self, forKey: .targetRotation)
        isMirrored = try container.decodeIfPresent(Bool.self, forKey: .isMirrored)
    }
}

struct Puzzle: Codable, Identifiable {
    let id: String
    let name: String
    let imageName: String
    let pieces: [PieceDefinition]
}

// Updated cat.json structure (normalized coordinates)
/*
{
  "id": "cat",
  "name": "Cat",
  "imageName": "cat_icon",
  "difficulty": "easy",
  "pieces": [
    {
      "pieceId": "square",
      "description": "face (rotated to diamond)",
      "targetPosition": { "x": 3.2, "y": 5.5 },
      "targetRotation": 0.785398,  // 45° (π/4)
      "isMirrored": false
    },
    {
      "pieceId": "smallTriangle1", 
      "description": "left ear",
      "targetPosition": { "x": 2.8, "y": 6.5 },
      "targetRotation": 2.356194,  // 135° (3π/4)
      "isMirrored": false
    },
    {
      "pieceId": "smallTriangle2",
      "description": "right ear",
      "targetPosition": { "x": 3.6, "y": 6.5 },
      "targetRotation": 0.785398,  // 45° (π/4)
      "isMirrored": false
    },
    {
      "pieceId": "largeTriangle1",
      "description": "main body",
      "targetPosition": { "x": 3.2, "y": 3.5 },
      "targetRotation": 3.926991,  // 225° (5π/4)
      "isMirrored": false
    },
    {
      "pieceId": "mediumTriangle",
      "description": "front shoulder/chest",
      "targetPosition": { "x": 2.0, "y": 3.5 },
      "targetRotation": 4.712389,  // 270° (3π/2)
      "isMirrored": false
    },
    {
      "pieceId": "largeTriangle2",
      "description": "back haunch", 
      "targetPosition": { "x": 4.4, "y": 2.5 },
      "targetRotation": 1.570796,  // 90° (π/2)
      "isMirrored": false
    },
    {
      "pieceId": "parallelogram",
      "description": "tail",
      "targetPosition": { "x": 5.8, "y": 2.5 },
      "targetRotation": 0.000000,  // 0°
      "isMirrored": true
    }
  ]
}
*/
```

### 3. ViewModel Pattern (Matching Osmo Architecture)
```swift
import Observation

@Observable
final class TangramViewModel {
    // MARK: - Game State
    private(set) var gamePhase: GamePhase = .waiting
    private(set) var currentPuzzle: Puzzle?
    private(set) var placedPieces: Set<TangramShape> = []
    private(set) var piecesPlaced: Int = 0
    private(set) var totalPieces: Int = 7
    private(set) var isComplete = false
    
    // MARK: - Timer State
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var timerActive = false
    private var timerTask: Task<Void, Never>?
    
    // MARK: - Feedback State
    private(set) var lastHint: HintType?
    private(set) var attemptCount: [TangramShape: Int] = [:]
    
    // MARK: - Dependencies
    private let context: GameContext?
    private var audioService: AudioServiceProtocol? { context?.audioService }
    private var analyticsService: AnalyticsServiceProtocol? { context?.analyticsService }
    private var persistenceService: PersistenceServiceProtocol? { context?.persistenceService }
    
    // MARK: - Types
    enum GamePhase {
        case waiting
        case playing
        case completed
        case paused
    }
    
    enum HintType {
        case needsRotation
        case wrongPiece
        case almostThere
    }
    
    enum PlacementResult {
        case success
        case needsRotation
        case wrongPosition
        case tooFar
    }
    
    // MARK: - Initialization
    init(context: GameContext?) {
        self.context = context
    }
    
    // MARK: - Game Management
    func loadPuzzle(_ puzzle: Puzzle) {
        self.currentPuzzle = puzzle
        self.totalPieces = puzzle.pieces.count
        self.placedPieces.removeAll()
        self.piecesPlaced = 0
        self.attemptCount.removeAll()
        self.gamePhase = .waiting
        
        // Analytics
        analyticsService?.logEvent("tangram_puzzle_loaded", parameters: [
            "puzzle_id": puzzle.id,
            "puzzle_name": puzzle.name
        ])
    }
    
    func startGame() {
        guard gamePhase == .waiting else { return }
        gamePhase = .playing
        startTimer()
        
        analyticsService?.logEvent("tangram_game_started", parameters: [
            "puzzle_id": currentPuzzle?.id ?? "unknown"
        ])
    }
    
    func pauseGame() {
        guard gamePhase == .playing else { return }
        gamePhase = .paused
        pauseTimer()
    }
    
    func resumeGame() {
        guard gamePhase == .paused else { return }
        gamePhase = .playing
        resumeTimer()
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        guard !timerActive else { return }
        timerActive = true
        
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.1))
                await MainActor.run {
                    self?.elapsedTime += 0.1
                }
            }
        }
    }
    
    private func pauseTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerActive = false
    }
    
    private func resumeTimer() {
        startTimer()
    }
    
    func stopTimer() {
        pauseTimer()
    }
    
    // MARK: - Piece Placement
    func attemptPlacement(piece: TangramShape, at position: CGPoint, rotation: CGFloat) -> PlacementResult {
        // Track attempts
        attemptCount[piece, default: 0] += 1
        
        // Placement logic will be in GameScene
        // This just manages state
        return .tooFar
    }
    
    func recordSuccessfulPlacement(piece: TangramShape) {
        placedPieces.insert(piece)
        piecesPlaced = placedPieces.count
        
        analyticsService?.logEvent("tangram_piece_placed", parameters: [
            "piece": piece.rawValue,
            "attempts": attemptCount[piece] ?? 1,
            "time_elapsed": elapsedTime
        ])
        
        // Check completion
        if piecesPlaced == totalPieces {
            completeGame()
        }
    }
    
    // MARK: - Game Completion
    private func completeGame() {
        gamePhase = .completed
        stopTimer()
        isComplete = true
        
        // Save best time
        Task { [weak self] in
            guard let self, let puzzleId = currentPuzzle?.id else { return }
            await self.saveBestTime(for: puzzleId, time: self.elapsedTime)
        }
        
        analyticsService?.logEvent("tangram_puzzle_completed", parameters: [
            "puzzle_id": currentPuzzle?.id ?? "unknown",
            "time": elapsedTime,
            "total_attempts": attemptCount.values.reduce(0, +)
        ])
    }
    
    // MARK: - Persistence
    private func saveBestTime(for puzzleId: String, time: TimeInterval) async {
        // Save to persistence service
        // Implementation depends on persistence setup
    }
    
    // MARK: - Reset
    func resetPuzzle() {
        placedPieces.removeAll()
        piecesPlaced = 0
        attemptCount.removeAll()
        elapsedTime = 0
        isComplete = false
        gamePhase = .waiting
        lastHint = nil
        
        analyticsService?.logEvent("tangram_puzzle_reset", parameters: [
            "puzzle_id": currentPuzzle?.id ?? "unknown"
        ])
    }
}
```

### 4. Responsive Layout System

```swift
struct TangramLayoutConfig {
    let screenSize: CGSize
    let deviceType: UIUserInterfaceIdiom
    let orientation: UIInterfaceOrientation
    
    // Computed layout properties
    var boardSize: CGSize {
        let margin: CGFloat = deviceType == .pad ? 100 : 40
        let maxWidth = screenSize.width - (margin * 2)
        let maxHeight = screenSize.height - trayHeight - margin - 100 // UI space
        
        // Keep board square and fit within bounds
        let size = min(maxWidth, maxHeight)
        return CGSize(width: size, height: size)
    }
    
    var trayHeight: CGFloat {
        deviceType == .pad ? 150 : 100
    }
    
    var pieceScale: CGFloat {
        // Scale pieces based on board size
        boardSize.width / 400.0 // Base size 400pt
    }
    
    var fontSize: (small: CGFloat, medium: CGFloat, large: CGFloat) {
        if deviceType == .pad {
            return (18, 24, 32)
        } else {
            return (14, 18, 24)
        }
    }
}
```

### 5. Game Scene Implementation (Osmo Pattern)

```swift
final class TangramGameScene: SKScene, GameSceneProtocol {
    // MARK: - Properties
    
    weak var gameContext: GameContext?
    private var viewModel: TangramViewModel!
    private var layoutConfig: TangramLayoutConfig!
    private var coordinateSystem: CoordinateSystem!
    private var dragHandler: DragHandler!
    private var placementValidator: PlacementValidator!
    
    // MARK: - Visual Nodes
    
    private var backgroundNode: SKSpriteNode!
    private var gameBoard: SKNode!
    private var pieceTray: SKNode!
    private var targetOutlines: [String: SKShapeNode] = [:]
    private var pieces: [String: TangramPiece] = [:]
    
    // UI Elements
    private var timerLabel: SKLabelNode!
    private var progressLabel: SKLabelNode!
    private var hintLabel: SKLabelNode!
    private var exitButton: SKShapeNode!
    private var resetButton: SKShapeNode!
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Initialize components
        viewModel = TangramViewModel(context: gameContext)
        dragHandler = DragHandler()
        
        // Setup scene
        setupScene()
        setupLayout()
        setupNodes()
        
        // Load puzzle if provided
        if let puzzle = (userData?["puzzle"] as? Puzzle) {
            loadPuzzle(puzzle)
        }
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        backgroundColor = .clear  // Transparent for camera view
        scaleMode = .resizeFill
        
        // Light overlay like RockPaperScissors
        backgroundNode = SKSpriteNode(color: .black.withAlphaComponent(0.3), size: size)
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.zPosition = -10
        addChild(backgroundNode)
    }
    
    private func setupLayout() {
        // Initialize layout configuration
        let deviceType = UIDevice.current.userInterfaceIdiom
        layoutConfig = TangramLayoutConfig(
            screenSize: size,
            deviceType: deviceType,
            orientation: currentOrientation()
        )
        
        coordinateSystem = CoordinateSystem(screenSize: size)
    }
    
    private func setupNodes() {
        // Game board container
        gameBoard = SKNode()
        gameBoard.position = CGPoint(x: size.width/2, y: size.height/2 + 50)
        addChild(gameBoard)
        
        // Piece tray
        pieceTray = SKNode()
        pieceTray.position = CGPoint(x: size.width/2, y: layoutConfig.trayHeight/2 + 20)
        addChild(pieceTray)
        
        // UI Elements
        setupUIElements()
    }
    
    private func setupUIElements() {
        // Timer label
        timerLabel = createLabel(
            text: "00:00",
            fontSize: layoutConfig.fontSize.large,
            fontWeight: .semibold
        )
        timerLabel.position = CGPoint(x: size.width/2, y: size.height - 50)
        addChild(timerLabel)
        
        // Progress label
        progressLabel = createLabel(
            text: "0/7 Pieces",
            fontSize: layoutConfig.fontSize.medium,
            fontWeight: .medium
        )
        progressLabel.position = CGPoint(x: size.width/2, y: size.height - 80)
        addChild(progressLabel)
        
        // Exit button (top left)
        exitButton = createCircleButton(radius: 20)
        exitButton.position = CGPoint(x: 40, y: size.height - 40)
        exitButton.name = "exitButton"
        let exitIcon = createLabel(text: "✕", fontSize: 20, fontWeight: .bold)
        exitIcon.verticalAlignmentMode = .center
        exitButton.addChild(exitIcon)
        addChild(exitButton)
        
        // Reset button (top right)
        resetButton = createCircleButton(radius: 20)
        resetButton.position = CGPoint(x: size.width - 40, y: size.height - 40)
        resetButton.name = "resetButton"
        let resetIcon = createLabel(text: "↻", fontSize: 20, fontWeight: .bold)
        resetIcon.verticalAlignmentMode = .center
        resetButton.addChild(resetIcon)
        addChild(resetButton)
        
        // Hint label (hidden by default)
        hintLabel = createLabel(
            text: "",
            fontSize: layoutConfig.fontSize.medium,
            fontWeight: .medium
        )
        hintLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 100)
        hintLabel.alpha = 0
        addChild(hintLabel)
    }
    
    // MARK: - Puzzle Loading
    
    private func loadPuzzle(_ puzzle: Puzzle) {
        viewModel.loadPuzzle(puzzle)
        placementValidator = PlacementValidator(
            puzzle: puzzle,
            coordinateSystem: coordinateSystem,
            screenUnit: coordinateSystem.screenUnit
        )
        
        // Create target outlines
        createTargetOutlines(for: puzzle)
        
        // Create puzzle pieces
        createPuzzlePieces(for: puzzle)
        
        // Update UI
        updateProgressDisplay()
    }
    
    private func createTargetOutlines(for puzzle: Puzzle) {
        // Clear existing outlines
        targetOutlines.values.forEach { $0.removeFromParent() }
        targetOutlines.removeAll()
        
        // Create new outlines
        for pieceDef in puzzle.pieces {
            let outline = createTargetOutline(for: pieceDef)
            gameBoard.addChild(outline)
            targetOutlines[pieceDef.pieceId] = outline
        }
    }
    
    private func createPuzzlePieces(for puzzle: Puzzle) {
        // Clear existing pieces
        pieces.values.forEach { $0.removeFromParent() }
        pieces.removeAll()
        
        // Create pieces in tray
        let trayWidth = size.width - 100
        let pieceSpacing = trayWidth / CGFloat(puzzle.pieces.count + 1)
        
        for (index, pieceDef) in puzzle.pieces.enumerated() {
            let piece = TangramPiece(
                pieceId: pieceDef.pieceId,  // Changed from shape:
                scale: coordinateSystem.screenUnit * 0.5 // Half size in tray
            )
            
            // Position in tray
            piece.position = CGPoint(
                x: -trayWidth/2 + pieceSpacing * CGFloat(index + 1),
                y: 0
            )
            piece.originalPosition = piece.position
            
            pieceTray.addChild(piece)
            pieces[pieceDef.pieceId] = piece
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        
        // Handle UI buttons
        if node.name == "exitButton" || node.parent?.name == "exitButton" {
            handleExitButton()
            return
        }
        
        if node.name == "resetButton" || node.parent?.name == "resetButton" {
            handleResetButton()
            return
        }
        
        // Handle piece selection
        if let piece = node as? TangramPiece ?? node.parent as? TangramPiece,
           !piece.isLocked {
            dragHandler.beginDrag(piece: piece, at: location)
            viewModel.startGame() // Start timer on first interaction
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        dragHandler.updateDrag(to: touch.location(in: self))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragHandler.endDrag(coordinateSystem: coordinateSystem, validator: placementValidator)
        // Check placement will trigger callbacks
    }
    
    // MARK: - GameSceneProtocol
    
    func handleCVEvent(_ event: CVEvent) {
        // Future CV implementation
    }
    
    func pauseGame() {
        viewModel.pauseGame()
        isPaused = true
    }
    
    func resumeGame() {
        viewModel.resumeGame()
        isPaused = false
    }
    
    // MARK: - Helpers
    
    private func createLabel(text: String, fontSize: CGFloat, fontWeight: UIFont.Weight) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = UIFont.systemFont(ofSize: fontSize, weight: fontWeight).fontName
        label.fontSize = fontSize
        label.fontColor = .white
        return label
    }
    
    private func createCircleButton(radius: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: radius)
        button.fillColor = UIColor.black.withAlphaComponent(0.5)
        button.strokeColor = UIColor.white.withAlphaComponent(0.8)
        button.lineWidth = 2
        return button
    }
    
    private func currentOrientation() -> UIInterfaceOrientation {
        if let windowScene = view?.window?.windowScene {
            return windowScene.interfaceOrientation
        }
        return .portrait
    }
}
```

### 6. Blueprint Store & Puzzle Loading

```swift
// BlueprintStore implementation from spec
final class BlueprintStore: ObservableObject {
    @Published private(set) var puzzles: [Puzzle] = []
    
    func loadAll() {
        guard let puzzlesPath = Bundle.main.path(forResource: nil, ofType: nil, inDirectory: "Games/Tangram/Puzzles") else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: puzzlesPath)
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            
            puzzles = jsonFiles.compactMap { filename in
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: puzzlesPath).appendingPathComponent(filename)),
                      let puzzle = try? JSONDecoder().decode(Puzzle.self, from: data) else { return nil }
                return puzzle
            }
        } catch {
            print("Error loading puzzles: \(error)")
        }
    }
}

// Adaptive Puzzle Selection View
struct TangramPuzzleSelectView: View {
    @Environment(AppCoordinator.self) var coordinator
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var blueprintStore = BlueprintStore()
    
    private var gridColumns: [GridItem] {
        let minSize: CGFloat = horizontalSizeClass == .compact ? 150 : 200
        return [GridItem(.adaptive(minimum: minSize), spacing: 20)]
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(blueprintStore.puzzles) { puzzle in
                    PuzzleThumbnail(puzzle: puzzle, imageName: puzzle.imageName) {
                        coordinator.navigate(to: .tangramGame(puzzle: puzzle))
                    }
                    .frame(height: horizontalSizeClass == .compact ? 150 : 200)
                }
                
                // Placeholder slots
                ForEach(0..<5, id: \.self) { _ in
                    ComingSoonThumbnail()
                        .frame(height: horizontalSizeClass == .compact ? 150 : 200)
                }
            }
            .padding(horizontalSizeClass == .compact ? 10 : 20)
        }
        .navigationTitle("Select a Puzzle")
        .onAppear { blueprintStore.loadAll() }
    }
}
```

### 7. Feedback & Hint System (Integrated)

```swift
extension TangramGameScene {
    // Setup drag handler callbacks
    private func setupDragHandlerCallbacks() {
        dragHandler.onPieceSnapped = { [weak self] shape in
            self?.handleSuccessfulPlacement(shape: shape)
        }
        
        dragHandler.onPieceMissed = { [weak self] shape, error in
            self?.handleFailedPlacement(shape: shape, error: error)
        }
    }
    
    private func handleSuccessfulPlacement(shape: TangramShape) {
        // Update view model
        viewModel.recordSuccessfulPlacement(piece: shape)
        
        // Audio feedback
        gameContext?.audioService.playSound(named: "snap", category: .gameEffect)
        gameContext?.audioService.playHaptic(type: .impact, intensity: 0.7)
        
        // Visual celebration
        if let piece = pieces[shape] {
            createSnapEffect(at: piece.position)
        }
        
        // Update UI
        updateProgressDisplay()
        
        // Check for completion
        if viewModel.isComplete {
            celebrateCompletion()
        }
    }
    
    private func handleFailedPlacement(shape: TangramShape, error: PlacementValidator.PlacementError) {
        // Audio feedback
        gameContext?.audioService.playSound(named: "error", category: .gameEffect)
        gameContext?.audioService.playHaptic(type: .notification, intensity: 0.5)
        
        // Show appropriate hint
        switch error {
        case .needsRotation:
            showHint("Try rotating this piece! 🔄")
            // Visual rotation hint
            if let piece = pieces[shape] {
                let wiggle = SKAction.sequence([
                    SKAction.rotate(byAngle: 0.1, duration: 0.1),
                    SKAction.rotate(byAngle: -0.2, duration: 0.1),
                    SKAction.rotate(byAngle: 0.1, duration: 0.1)
                ])
                piece.run(wiggle)
            }
            
        case .wrongPiece:
            showHint("This piece goes somewhere else 🤔")
            
        case .tooFar:
            // No hint for too far - piece just returns
            break
        }
        
        // Update view model hint
        viewModel.lastHint = error == .needsRotation ? .needsRotation : .wrongPiece
    }
    
    private func showHint(_ text: String) {
        hintLabel.text = text
        hintLabel.removeAllActions()
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        
        hintLabel.run(SKAction.sequence([fadeIn, wait, fadeOut]))
    }
    
    private func createSnapEffect(at position: CGPoint) {
        // Particle effect for successful snap
        if let snapEffect = SKEmitterNode(fileNamed: "SnapEffect") {
            snapEffect.position = position
            snapEffect.zPosition = 150
            addChild(snapEffect)
            
            // Remove after animation
            snapEffect.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        } else {
            // Fallback: simple scale animation on target outline
            // Find the corresponding outline and pulse it
        }
    }
    
    private func updateProgressDisplay() {
        progressLabel.text = "\(viewModel.piecesPlaced)/\(viewModel.totalPieces) Pieces"
        
        // Update timer
        let minutes = Int(viewModel.elapsedTime) / 60
        let seconds = Int(viewModel.elapsedTime) % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
}
```

### 8. Completion Celebration (Osmo Style)

```swift
extension TangramGameScene {
    func celebrateCompletion() {
        // Analytics
        gameContext?.analyticsService.logEvent("tangram_celebrate_shown", parameters: [
            "puzzle_id": viewModel.currentPuzzle?.id ?? "unknown"
        ])
        
        // Victory sound and haptics
        gameContext?.audioService.playSound(named: "win", category: .gameEffect)
        gameContext?.audioService.playHaptic(type: .success, intensity: 1.0)
        
        // Create celebration overlay
        let overlayBackground = SKSpriteNode(color: .black.withAlphaComponent(0.7), size: size)
        overlayBackground.position = CGPoint(x: size.width/2, y: size.height/2)
        overlayBackground.zPosition = 200
        overlayBackground.alpha = 0
        addChild(overlayBackground)
        
        // Fade in overlay
        overlayBackground.run(SKAction.fadeIn(withDuration: 0.3))
        
        // Victory message
        let victoryLabel = createLabel(
            text: "Puzzle Complete! 🎉",
            fontSize: layoutConfig.fontSize.large * 1.5,
            fontWeight: .heavy
        )
        victoryLabel.position = CGPoint(x: 0, y: 100)
        overlayBackground.addChild(victoryLabel)
        
        // Time display
        let timeText = "Time: \(viewModel.elapsedTime.timerString)"
        let timeLabel = createLabel(
            text: timeText,
            fontSize: layoutConfig.fontSize.medium,
            fontWeight: .semibold
        )
        timeLabel.position = CGPoint(x: 0, y: 50)
        overlayBackground.addChild(timeLabel)
        
        // Buttons
        let buttonSpacing: CGFloat = 150
        
        // Play Again button
        let playAgainButton = createButton(size: CGSize(width: 120, height: 50))
        playAgainButton.position = CGPoint(x: -buttonSpacing/2, y: -50)
        playAgainButton.name = "playAgainButton"
        let playAgainLabel = createLabel(text: "Play Again", fontSize: 18, fontWeight: .semibold)
        playAgainButton.addChild(playAgainLabel)
        overlayBackground.addChild(playAgainButton)
        
        // Next Puzzle button
        let nextButton = createButton(size: CGSize(width: 120, height: 50))
        nextButton.position = CGPoint(x: buttonSpacing/2, y: -50)
        nextButton.name = "nextPuzzleButton"
        let nextLabel = createLabel(text: "Next Puzzle", fontSize: 18, fontWeight: .semibold)
        nextButton.addChild(nextLabel)
        overlayBackground.addChild(nextButton)
        
        // Confetti effect
        createConfettiEffect()
    }
    
    private func createConfettiEffect() {
        // Multiple confetti emitters for full coverage
        let positions = [
            CGPoint(x: size.width * 0.2, y: size.height),
            CGPoint(x: size.width * 0.5, y: size.height),
            CGPoint(x: size.width * 0.8, y: size.height)
        ]
        
        for position in positions {
            if let confetti = SKEmitterNode(fileNamed: "Confetti") {
                confetti.position = position
                confetti.zPosition = 250
                addChild(confetti)
                
                // Remove after 5 seconds
                confetti.run(SKAction.sequence([
                    SKAction.wait(forDuration: 5.0),
                    SKAction.fadeOut(withDuration: 1.0),
                    SKAction.removeFromParent()
                ]))
            } else {
                // Fallback: create simple particle effect
                createSimpleConfetti(at: position)
            }
        }
    }
    
    private func createSimpleConfetti(at position: CGPoint) {
        // Simple colored squares falling
        for _ in 0..<20 {
            let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink]
            let particle = SKShapeNode(rectOf: CGSize(width: 10, height: 10))
            particle.fillColor = colors.randomElement()!
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 250
            
            // Random horizontal offset
            let xOffset = CGFloat.random(in: -100...100)
            let fallDuration = TimeInterval.random(in: 2...4)
            
            let moveAction = SKAction.moveBy(x: xOffset, y: -size.height - 100, duration: fallDuration)
            let rotateAction = SKAction.rotate(byAngle: .pi * 4, duration: fallDuration)
            let fadeAction = SKAction.fadeOut(withDuration: fallDuration)
            
            particle.run(SKAction.group([moveAction, rotateAction, fadeAction])) {
                particle.removeFromParent()
            }
            
            addChild(particle)
        }
    }
    
    private func createButton(size: CGSize) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: size.height/4)
        button.fillColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.strokeColor = .white
        button.lineWidth = 2
        return button
    }
}

## Key Implementation Details

## Programmatic Shape Rendering Plan

### Why SKShapeNode Over PNG/SVG
- **Resolution Independence**: Crisp at any screen size
- **Dynamic Coloring**: Easy theme changes
- **Smaller App Size**: No texture assets needed
- **Performance**: Hardware-accelerated vector rendering
- **Runtime Flexibility**: Can modify shapes programmatically

### Mathematical Foundation (From Spec)

```swift
// Base Unit = 1, all shapes defined relative
struct TangramMath {
    // Core Principles
    static let baseUnit: CGFloat = 1.0
    static let gridResolution: CGFloat = 0.1
    static let playAreaSize: CGFloat = 8.0  // 8×8 units
    static let rotationIncrement: CGFloat = .pi / 4  // 45°
    
    // Shape Properties (verified areas)
    static let smallTriangleArea: CGFloat = 0.5
    static let squareArea: CGFloat = 1.0
    static let mediumTriangleArea: CGFloat = 1.0
    static let largeTriangleArea: CGFloat = 2.0
    static let parallelogramArea: CGFloat = 2.0
    static let totalTangramArea: CGFloat = 9.0  // 2×2 + 1 + 1 + 2×0.5 + 2 = 9
}

// Grid System Constants
struct GridConstants {
    static let resolution: CGFloat = 0.1
    static let playAreaSize: CGFloat = 8.0
    
    // Auto-scaling snap tolerance
    static func snapTolerance(for screenUnit: CGFloat) -> CGFloat {
        return max(0.2, 0.0375 * screenUnit)
    }
    
    static let rotationIncrement: CGFloat = .pi / 4  // 45°
    static let visualRotationIncrement: CGFloat = .pi / 16  // 11.25° for smooth feedback
}
```

### Canonical Shape Vertices (Definitive Specification)

```swift
// Mathematical constant for precision
extension CGFloat {
    static let sqrt2: CGFloat = 1.4142135623730951
}

struct TangramShapes {
    // All vertices start at origin (0,0) bottom-left
    static let shapes: [TangramShape: [CGPoint]] = [
        // Small Triangles (1×1 right triangles)
        .smallTriangle1: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ],
        .smallTriangle2: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ],
        
        // Square (1×1)
        .square: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ],
        
        // Medium Triangle (√2×√2 right triangle)
        .mediumTriangle: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: .sqrt2, y: 0),  // Use constant
            CGPoint(x: 0, y: .sqrt2)    // Use constant
        ],
        
        // Large Triangles (2×2 right triangles)
        .largeTriangle1: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ],
        .largeTriangle2: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ],
        
        // Parallelogram (base 2, height 1) - CORRECT VERTICES
        .parallelogram: [
            CGPoint(x: 0, y: 0),     // Bottom-left anchor
            CGPoint(x: 2, y: 0),
            CGPoint(x: 3, y: 1),     // FIXED: was (1, 1)
            CGPoint(x: 1, y: 1)      // FIXED: was (-1, 1)
        ]
    ]
}
```

### SKShapeNode Factory Implementation

```swift
class TangramPieceFactory {
    // Convert vertices to CGPath
    static func createPath(for shape: TangramShape) -> CGPath {
        let path = CGMutablePath()
        guard let vertices = TangramShapes.shapes[shape] else { return path }
        
        if vertices.isEmpty { return path }
        
        path.move(to: vertices[0])
        for i in 1..<vertices.count {
            path.addLine(to: vertices[i])
        }
        path.closeSubpath()
        
        return path
    }
    
    // Create game piece as SKShapeNode
    static func createPiece(shape: TangramShape, scale: CGFloat) -> SKShapeNode {
        let path = createPath(for: shape)
        
        // Scale path to screen units
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledPath = path.copy(using: &transform) ?? path
        
        let piece = SKShapeNode(path: scaledPath)
        piece.name = shape.rawValue
        
        // Visual properties
        piece.fillColor = pieceColors[shape] ?? .gray
        piece.strokeColor = .black
        piece.lineWidth = 2.0
        piece.lineCap = .round
        piece.lineJoin = .round
        
        // Physics properties (for touch detection)
        piece.isUserInteractionEnabled = false  // Handle at scene level
        
        // Add subtle shadow for depth
        piece.shadowCastBitMask = 1
        piece.shadowedBitMask = 1
        
        return piece
    }
}

// Piece colors from spec
let pieceColors: [TangramShape: UIColor] = [
    .largeTriangle1: .systemBlue,
    .largeTriangle2: .systemRed,
    .mediumTriangle: .systemGreen,     // No suffix
    .smallTriangle1: .systemCyan,
    .smallTriangle2: .systemPink,
    .square: .systemYellow,            // No suffix
    .parallelogram: .systemOrange      // No suffix
]
```

### Coordinate System Implementation

```swift
class CoordinateSystem {
    let screenSize: CGSize
    let margin: CGFloat = 20
    
    // Points per unit (computed to fit screen)
    var screenUnit: CGFloat {
        let availableSize = min(screenSize.width, screenSize.height) - (margin * 2)
        return availableSize / GridConstants.playAreaSize
    }
    
    // Convert unit coordinates (0-8) to screen coordinates
    // Origin (4,4) in unit space maps to (0,0) in screen space
    func toScreen(_ unitPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: (unitPoint.x - 4) * screenUnit,
            y: (unitPoint.y - 4) * screenUnit
        )
    }
    
    // Convert screen coordinates to unit coordinates
    func toUnit(_ screenPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: screenPoint.x / screenUnit + 4,
            y: screenPoint.y / screenUnit + 4
        )
    }
}

// Grid snapping extensions
extension CGPoint {
    // Snap to nearest grid point (0.1 resolution)
    func snappedToGrid() -> CGPoint {
        return CGPoint(
            x: round(x / GridConstants.resolution) * GridConstants.resolution,
            y: round(y / GridConstants.resolution) * GridConstants.resolution
        )
    }
    
    // Check if within snap tolerance of target
    func isNear(_ target: CGPoint, tolerance: CGFloat) -> Bool {
        let distance = hypot(x - target.x, y - target.y)
        return distance < tolerance
    }
}

extension CGFloat {
    // Snap rotation to nearest 45°
    func snappedRotation() -> CGFloat {
        let increment = GridConstants.rotationIncrement
        return round(self / increment) * increment
    }
}
```

### Target Outline & Placement System

```swift
extension TangramGameScene {
    // Create target outline from puzzle definition
    func createTargetOutline(for definition: PieceDefinition) -> SKShapeNode {
        // Convert string pieceId to enum for factory
        guard let shape = TangramShape(rawValue: definition.pieceId) else {
            fatalError("Unknown piece: \(definition.pieceId)")
        }
        
        let path = TangramPieceFactory.createPath(for: shape)
        let coordSystem = CoordinateSystem(screenSize: size)
        
        // Convert unit position to screen coordinates
        let screenPos = coordSystem.toScreen(CGPoint(
            x: CGFloat(definition.targetPosition.x),
            y: CGFloat(definition.targetPosition.y)
        ))
        
        // Apply transformations
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: coordSystem.screenUnit, y: coordSystem.screenUnit)
        transform = transform.rotated(by: CGFloat(definition.targetRotation))
        
        // Handle parallelogram mirroring
        if definition.isMirrored == true {
            transform = transform.scaledBy(x: -1, y: 1)
        }
        
        let transformedPath = path.copy(using: &transform) ?? path
        
        let outline = SKShapeNode(path: transformedPath)
        outline.position = screenPos
        outline.strokeColor = UIColor.gray.withAlphaComponent(0.25)
        outline.lineWidth = 2.0
        outline.fillColor = .clear
        outline.isUserInteractionEnabled = false
        outline.zPosition = -1  // Behind pieces
        
        return outline
    }
}

// Placement validation from spec
struct PlacementValidator {
    let puzzle: Puzzle
    let coordinateSystem: CoordinateSystem
    let screenUnit: CGFloat
    
    func checkPlacement(piece: TangramPiece, at position: CGPoint, rotation: CGFloat) -> Bool {
        guard let targetPiece = puzzle.pieces.first(where: { $0.pieceId == piece.pieceId }) else {
            return false
        }
        
        // Convert to unit coordinates for comparison
        let unitPos = coordinateSystem.toUnit(position)
        let targetPos = CGPoint(
            x: CGFloat(targetPiece.targetPosition.x),
            y: CGFloat(targetPiece.targetPosition.y)
        )
        let targetRot = CGFloat(targetPiece.targetRotation)
        
        // Check position (using auto-scaled tolerance)
        let tolerance = GridConstants.snapTolerance(for: screenUnit)
        let positionCorrect = unitPos.isNear(targetPos, tolerance: tolerance)
        
        // Check rotation (exact match after snapping)
        let snappedRotation = rotation.snappedRotation()
        let rotationCorrect = abs(snappedRotation - targetRot) < 0.01  // Tiny epsilon for float precision
        
        return positionCorrect && rotationCorrect
    }
}
```

### Drag & Drop System (Osmo Architecture)

```swift
class DragHandler {
    var isDragging = false
    var selectedPiece: TangramPiece?
    var dragOffset: CGPoint = .zero
    
    // Callbacks for game integration
    var onPieceSnapped: ((TangramShape) -> Void)?
    var onPieceMissed: ((TangramShape, PlacementValidator.PlacementError) -> Void)?
    
    func beginDrag(piece: TangramPiece, at touchPoint: CGPoint) {
        isDragging = true
        selectedPiece = piece
        dragOffset = CGPoint(
            x: touchPoint.x - piece.position.x,
            y: touchPoint.y - piece.position.y
        )
        piece.zPosition = 100  // Bring to front
        
        // Visual feedback
        piece.run(SKAction.scale(to: 1.1, duration: 0.1))
    }
    
    func updateDrag(to touchPoint: CGPoint) {
        guard let piece = selectedPiece else { return }
        
        // Follow finger exactly (no grid snapping while dragging)
        piece.position = CGPoint(
            x: touchPoint.x - dragOffset.x,
            y: touchPoint.y - dragOffset.y
        )
    }
    
    func endDrag(coordinateSystem: CoordinateSystem, validator: PlacementValidator) {
        guard let piece = selectedPiece else { return }
        
        isDragging = false
        piece.zPosition = 1
        piece.run(SKAction.scale(to: 1.0, duration: 0.1))
        
        // Convert to unit coordinates for validation
        let screenPos = piece.convert(piece.position, to: piece.parent!)
        let (isValid, error) = validator.validatePlacement(
            piece: piece,
            at: screenPos,
            rotation: piece.zRotation
        )
        
        if isValid {
            // Successful placement
            handleSuccessfulPlacement(piece: piece, validator: validator)
        } else {
            // Failed placement
            handleFailedPlacement(piece: piece, error: error)
        }
        
        selectedPiece = nil
    }
    
    private func handleSuccessfulPlacement(piece: TangramPiece, validator: PlacementValidator) {
        guard let targetDef = validator.getTargetDefinition(for: piece.pieceId) else { return }
        
        // Get exact target position
        let targetScreenPos = validator.coordinateSystem.toScreen(CGPoint(
            x: CGFloat(targetDef.targetPosition.x),
            y: CGFloat(targetDef.targetPosition.y)
        ))
        
        // Snap animation
        piece.isLocked = true
        piece.run(SKAction.group([
            SKAction.move(to: targetScreenPos, duration: 0.15),
            SKAction.rotate(toAngle: CGFloat(targetDef.targetRotation), duration: 0.15)
        ]))
        
        // Callback - convert pieceId back to enum
        if let shape = TangramShape(rawValue: piece.pieceId) {
            onPieceSnapped?(shape)
        }
    }
    
    private func handleFailedPlacement(piece: TangramPiece, error: PlacementValidator.PlacementError?) {
        // Return to original position
        let returnAction = SKAction.move(to: piece.originalPosition, duration: 0.2)
        piece.run(returnAction)
        
        // Callback with error type - convert pieceId back to enum
        if let error = error, let shape = TangramShape(rawValue: piece.pieceId) {
            onPieceMissed?(shape, error)
        }
    }
}

// Updated PlacementValidator
extension PlacementValidator {
    enum PlacementError {
        case tooFar
        case wrongPiece
        case needsRotation
    }
    
    func validatePlacement(piece: TangramPiece, at position: CGPoint, rotation: CGFloat) -> (Bool, PlacementError?) {
        guard let targetPiece = puzzle.pieces.first(where: { $0.pieceId == piece.pieceId }) else {
            return (false, .wrongPiece)
        }
        
        // Convert to unit coordinates
        let unitPos = coordinateSystem.toUnit(position)
        let targetPos = CGPoint(
            x: CGFloat(targetPiece.targetPosition.x),
            y: CGFloat(targetPiece.targetPosition.y)
        )
        
        // Check distance
        let distance = hypot(unitPos.x - targetPos.x, unitPos.y - targetPos.y)
        let tolerance = GridConstants.snapTolerance(for: screenUnit)
        if distance > tolerance {
            return (false, .tooFar)
        }
        
        // Check rotation (exact match after snapping)
        let targetRot = CGFloat(targetPiece.targetRotation)
        let snappedRotation = rotation.snappedRotation()
        if abs(snappedRotation - targetRot) > 0.01 {  // Tiny epsilon for float precision
            return (false, .needsRotation)
        }
        
        // Check mirroring for parallelogram
        if piece.pieceId == "parallelogram" {
            let targetMirrored = targetPiece.isMirrored ?? false
            if piece.isMirrored != targetMirrored {
                return (false, .wrongPiece)  // Wrong orientation
            }
        }
        
        return (true, nil)
    }
    
    func getTargetDefinition(for pieceId: String) -> PieceDefinition? {
        return puzzle.pieces.first(where: { $0.pieceId == pieceId })
    }
}
```

### Timer Display Format
```swift
extension TimeInterval {
    var timerString: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

## Game Flow

### 1. Launch Flow
```
Lobby → Tangram Tile → Puzzle Selection → Game Scene
```

### 2. Gameplay Flow
```
Show Outline → Player Drags Piece → Check Proximity → 
  ├─ Too Far: Return to Tray
  ├─ Wrong Piece: Show Hint
  ├─ Needs Rotation: Suggest Rotation
  └─ Success: Snap & Lock
```

### 3. Completion Flow
```
All Pieces Placed → Stop Timer → Confetti → Show Time → Options:
  ├─ Play Again (same puzzle)
  └─ Next Puzzle (return to selection)
```

## Integration Checklist

### GameHost Integration
```swift
// In GameHost.swift loadGame()
case "tangram":
    let module = TangramGameModule()
    gameModule = module
    gameScene = module.createGameScene(
        size: UIScreen.main.bounds.size,
        context: context
    )
    
    // Note: No CV session needed for Phase 1
```

### Required Services
- [x] AudioService - Sound effects and haptics
- [x] AnalyticsService - Track gameplay metrics
- [x] PersistenceService - Save best times
- [ ] CVService - Deferred to Phase 2

## Future CV Integration (Phase 2)

### Physical Piece Requirements
- Distinct colors matching digital pieces
- Clear shape boundaries for detection
- Unique markers for orientation detection
- Non-reflective material for consistent tracking

### CV Event Types
```swift
extension CVEventType {
    static let tangramPieceDetected = CVEventType("tangramPieceDetected")
    static let tangramPieceLifted = CVEventType("tangramPieceLifted")
    static let tangramPiecePlaced = CVEventType("tangramPiecePlaced")
    static let tangramPieceRotated = CVEventType("tangramPieceRotated")
}
```

### Hybrid Mode Design
- Digital outline remains on screen
- Physical pieces tracked in real-time
- Snap feedback when correctly placed
- Seamless switch between touch/physical

## Visual Feedback & Performance Guidelines

### Visual Feedback (From Spec)
1. **Grid Hints** (optional): Show faint dots at 0.1 intervals near dragged piece
2. **Snap Preview**: Highlight target outline when piece is within snap tolerance
3. **Rotation Feedback**: Show rotation handle or gesture indicator
4. **Completion Effects**: Particle burst + sound when piece locks in place

### Performance Considerations
- **Grid Points**: 81×81 = 6,561 possible positions (8×8 unit space with 0.1 resolution)
- **Touch Precision**: 0.1 units ≈ 4-5 screen pixels on most devices
- **Animation Duration**: 0.1-0.15 seconds for snap animations
- **Z-Fighting**: Use distinct zPosition values (0, 1, 100) to prevent overlap issues

### TangramPiece Class Implementation

```swift
class TangramPiece: SKShapeNode {
    let pieceId: String  // Changed from TangramShape to match JSON
    var isLocked: Bool = false
    var isMirrored: Bool = false  // For parallelogram
    var targetRotation: CGFloat = 0
    var originalPosition: CGPoint = .zero
    
    init(pieceId: String, scale: CGFloat) {
        self.pieceId = pieceId
        super.init()
        
        // Find corresponding enum case for factory
        guard let shape = TangramShape(rawValue: pieceId) else {
            fatalError("Unknown piece: \(pieceId)")
        }
        
        // Create from factory
        let path = TangramPieceFactory.createPath(for: shape)
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        self.path = path.copy(using: &transform)
        
        // Visual setup
        self.fillColor = pieceColors[shape] ?? .gray
        self.strokeColor = .black
        self.lineWidth = 2.0
        self.lineCap = .round
        self.lineJoin = .round
        self.name = pieceId
        
        // Enable touch
        self.isUserInteractionEnabled = false  // Handle at scene level
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Mirror the parallelogram
    func setMirrored(_ mirrored: Bool) {
        guard pieceId == "parallelogram", mirrored != isMirrored else { return }
        
        isMirrored = mirrored
        xScale = mirrored ? -1 : 1
    }
}
```

## Scene Size and Tolerance Calculations (Critical)

```swift
// From render.md and integration.md
override func didMove(to view: SKView) {
    backgroundColor = .systemBackground
    
    // Calculate screen unit
    let margin: CGFloat = 40
    let availableSize = min(size.width, size.height) - margin * 2
    screenUnit = availableSize / 8.0
    
    // Calculate snap tolerance using auto-scaling formula
    snapTolerance = max(0.2, 0.0375 * screenUnit)
    
    setupPuzzle()
    setupPieces()
}

override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    
    // Recalculate screen unit and tolerance on size change (rotation, etc.)
    let margin: CGFloat = 40
    let availableSize = min(size.width, size.height) - margin * 2
    screenUnit = availableSize / 8.0
    
    // Update cached tolerance
    snapTolerance = max(0.2, 0.0375 * screenUnit)
    
    // Update all piece and outline positions
    updateAllPositions()
}
```

## File Structure (Programmatic Rendering)

### Directory Structure
```
osmo/Games/Tangram/
├── TangramGameModule.swift
├── TangramGameScene.swift
├── TangramViewModel.swift
├── Models/
│   ├── TangramModels.swift    # Data structures
│   ├── TangramShapes.swift    # Shape definitions
│   └── TangramMath.swift      # Math constants
├── Views/
│   ├── TangramPieceFactory.swift
│   └── TangramPiece.swift
├── Puzzles/
│   ├── cat.json          # Migrated from .docs/cat.json
│   └── camel.json        # Migrated from .docs/camel.json
└── Sounds/
    ├── snap.wav          # < 100KB total for all sounds
    ├── rotate.wav
    ├── error.wav
    └── win.wav
```

### Key Benefits of Programmatic Rendering
1. **No PNG Assets**: All shapes generated at runtime
2. **Perfect Scaling**: Resolution-independent vectors
3. **Dynamic Theming**: Easy to change colors/styles
4. **Smaller App Size**: ~100KB for sounds only
5. **Smooth Animations**: Hardware-accelerated paths

## Device-Specific Considerations

### iPhone Optimization
- Compact piece tray layout
- Larger touch targets relative to screen
- Simplified UI with essential elements only
- Portrait-first design with landscape support

### iPad Optimization
- Spacious layouts with comfortable margins
- Support for split-screen multitasking
- Enhanced visual effects
- Both orientations equally supported

### Universal Features
- Consistent game mechanics across devices
- Scalable vector graphics for all screen densities
- Adaptive font sizes for readability
- Responsive touch areas

## Success Metrics
- [ ] 60 FPS on all iOS devices
- [ ] < 1 second scene load time
- [ ] Intuitive controls on both phone and tablet
- [ ] Clear visual feedback at all screen sizes
- [ ] Smooth orientation changes

## Next Steps
1. Create TangramGameModule.swift with universal support
2. Implement responsive puzzle selection view
3. Build adaptive game scene with layout system
4. Add device-aware touch mechanics
5. Implement scaled snap detection
6. Test across all device sizes
7. Optimize performance per device
8. Polish universal experience

---
*Last Updated: [Current Date]*
*Status: Ready for Universal iOS Implementation*