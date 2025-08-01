# Visual Grid Editor System

## Overview

The Visual Grid Editor is a reusable framework within the osmo platform that enables visual creation and editing of puzzle arrangements, game boards, and success conditions. It provides an intuitive drag-and-drop interface for developers, educators, and parents to create content using a **relation graph** approach - where pieces are connected through explicit geometric constraints, allowing for rotation/translation invariant validation for freeform puzzles and discrete grid-based validation for lattice puzzles.

## Purpose

The Grid Editor serves as a universal content creation tool for:

### Freeform Puzzles (SE(2) - translation/rotation invariant)
- **Tangram Puzzles**: Geometric piece arrangements with rigid-body constraints
- **Jigsaw Puzzles**: Edge-matching with rotation allowed
- **Shape Construction**: Free-form geometric compositions

### Lattice Puzzles (discrete grid-based)
- **Sudoku Boards**: Cell-indexed number placement
- **Word Games**: Letter tile arrangements on fixed grids
- **Math Puzzles**: Grid-aligned equation builders

## Architecture

### Core Components

#### 1. **GridEditorService**
Central service following osmo's protocol-driven architecture:
```swift
protocol GridEditorServiceProtocol: AnyObject {
    func createEditor(for gameType: GameType, configuration: GridConfiguration) -> GridEditor
    func saveArrangement(_ arrangement: GridArrangement) async throws
    func loadArrangements(for gameType: GameType) async -> [GridArrangement]
}
```

#### 2. **PoseSource (Abstraction)**
Abstracts piece position reading for both touch and future CV modes:
```swift
/// x, y in Tangram unit space; theta in radians (counterclockwise)
public struct SE2Pose: Codable { 
    public var x: Double
    public var y: Double
    public var theta: Double
}

public protocol PoseSource: AnyObject {
    func currentPoses() -> [String: SE2Pose]  // pieceId → pose in world/table space
    func currentAnchorPieceId() -> String?    // optional hint; may be nil
}
```

#### 3. **AnchorManager (Policy)**
Centralizes anchoring strategy and relative pose computation:
```swift
public protocol AnchorManagerProtocol: AnyObject {
    // Returns T_anchor_i for all i, computed from PoseSource world poses each frame
    func anchorRelativePoses(from worldPoses: [String: SE2Pose]) -> (anchorId: String, relPoses: [String: SE2Pose])
}

final class AnchorManager: AnchorManagerProtocol {
    // Touch mode: prefer the first placed (or editor-selected) piece as anchor
    //   - Fixed to editor-chosen (or first placed) unless that piece is removed
    // CV mode (future): prefer the longest-stable, highest-confidence piece
    //   - Re-anchor only after hysteresis (e.g., 0.5s stable visibility + higher confidence) to avoid flicker
}
```

**Key rule:** Never chain relatives. Each frame compute `T_anchor_i = (T_table_anchor)^(-1) · T_table_i`

#### 4. **ConstraintValidator (Win Engine)**
Central validation engine used by both editor preview and game runtime:
```swift
public protocol ConstraintValidatorProtocol {
    func validate(arrangement: GridArrangement,
                  relPoses: [String: SE2Pose]) -> ValidationResult
}

public struct ValidationResult {
    public var passed: Bool
    public var violatedConstraints: [String]   // ids of RelationConstraint
    public var overlaps: [(a:String, b:String, area:Double)]
    public var nearMissHints: [String: String] // optional editor/game hints
    public var globalRotationIndex: Int?       // for analytics/debug HUD
    public var anchorId: String?               // for analytics/debug HUD
}
```

#### 5. **Constraint-Based Positioning System**
A relation graph approach with rigid-body constraints:
- **Relation Graph**: Pieces connected through explicit geometric constraints
- **Constraint Types**:
  - Corner-to-corner coincidence
  - Edge-to-edge coincidence (full or partial)
  - Gap constraints (minimum separation)
- **Transformation Groups**: Define allowed invariances (translation, rotation, reflection)
- **Anchorless Validation**: Compare relative transforms between pieces, not absolute positions

#### 6. **GridArrangement**
Universal data structure for storing arrangements:
```swift
struct GridArrangement: Codable {
    let id: String
    let gameType: GameType
    let name: String
    let elements: [PlacedElement]           // Authoring poses for preview
    let constraints: [RelationConstraint]   // Graph of geometric relations
    let metadata: ArrangementMetadata
}

struct PlacedElement: Codable {
    let elementId: String
    let elementType: String      // References canonical geometry
    let rotationIndex: Int       // Discrete rotation (0-7 for 45° steps)
    let mirrored: Bool
    let position: CGPoint        // Unit space (Tangram units), authoring/preview only
                                 // Runtime validation ignores absolute positions
}

enum EdgeOrientation: String, Codable { 
    case sameDirection
    case oppositeDirection 
}

struct RelationConstraint: Codable {
    let id: String
    let pieceA: String
    let pieceB: String
    let kind: ConstraintKind
    let featureA: String
    let featureB: String
    let edgeOrientation: EdgeOrientation?  // for edge constraints
    let gap: Double?                       // >= 0 for spacing; nil for coincidence
    let mirrorAware: Bool                  // default true
    let rotationIndexDelta: Int?           // optional, relative discrete rotation
    let overlapRatioMin: Double?           // for edge-to-edge (1.0=full, 0.5=half); nil=endpoints
}

enum ConstraintKind: String, Codable {
    case cornerToCorner
    case edgeToEdge
}
```

#### 7. **Shape Geometry & Features**
Canonical shape definitions with semantic features:
```swift
struct ShapeGeometry: Codable {
    let shapeId: String
    let vertices: [CGPoint]      // In unit space, origin at bottom-left
    let corners: [Corner]        // Named corners with canonical order
    let edges: [Edge]           // Named edges between corners
    let centerOfMass: CGPoint   // For rotation calculations
}

struct Corner: Codable {
    let id: String              // Semantic name: "right-angle", "acute-1", etc.
    let vertexIndex: Int        // Index into vertices array
    let angle: Double           // Interior angle at this corner
}

struct Edge: Codable {
    let id: String              // Semantic name: "hypotenuse", "base", etc.
    let startCornerId: String   // Defines edge direction
    let endCornerId: String     // start → end is positive direction
    let length: Double          // In unit space
}

// Chirality mapping for mirrored shapes
struct ChiralityMapping: Codable {
    let shapeId: String
    let cornerMapping: [String: String]  // original → mirrored corner IDs
    let edgeMapping: [String: String]    // original → mirrored edge IDs
}

// Canonical Frames & Zero Rotation
// Each shape has a canonical zero-rotation orientation:
// - Right triangles: right angle at origin, base on +x, height on +y
// - Square: axis-aligned with bottom-left at origin
// - Parallelogram: bottom-left at origin, base on +x
// This anchors rotationIndex unambiguously (0 = canonical orientation)

// Transformation metadata
struct ArrangementMetadata: Codable {
    let mode: PuzzleMode                    // .freeform or .lattice
    let rotationStep: Int?                  // 8 for 45°, 4 for 90°, nil for continuous
    let allowedGlobalRotations: [Int]       // Which rotations validate as correct
    let allowGlobalMirror: Bool
    let tolerances: Tolerances
}

struct Tolerances: Codable {
    let positionTolerance: Double   // Unit space distance
    let angleTolerance: Double      // Degrees
    let edgeAlignment: Double       // Max deviation for collinearity
}

enum PuzzleMode: String, Codable {
    case freeform   // SE(2) invariant (Tangram)
    case lattice    // Grid-indexed (Sudoku)
}

// Mirror Policy:
// - allowGlobalMirror: false means scene-wide mirroring is invalid
// - Per-piece mirroring is allowed ONLY if the piece can mirror AND 
//   constraints are mirrorAware == true with ChiralityMapping applied
```

### Runtime Layering

The system cleanly separates authoring from runtime validation:

**Editor (Authoring)**
- Produces `GridArrangement` + metadata
- Previews using same `ConstraintValidator` with **TouchPoseSource** (drag pose → world pose)
- Visual affordances for constraint creation

**Game (Runtime)**
- **PoseSource**: `TouchPoseSource` (today) or `CVPoseSource` (later)
- **AnchorManager**: Picks anchor & produces relative poses
- **ConstraintValidator**: Decides win, overlap, near-miss
- **Game UI**: Reacts to `ValidationResult`

This separation enables reusing the editor preview engine verbatim when CV arrives.

### Integration Architecture

The Grid Editor integrates seamlessly with osmo's existing service architecture:

```
ServiceLocator
    ├── GridEditorService ─── Creates ──→ GridEditor
    ├── PersistenceService ─── Saves ──→ GridArrangements
    ├── AudioService ─── Provides ──→ Feedback sounds
    └── AnalyticsService ─── Tracks ──→ Editor usage
```

## How It Works

### 1. **Editor Initialization**
Games request an editor instance through the GridEditorService:
```swift
let editor = gridEditorService.createEditor(
    for: .tangram,
    configuration: TangramGridConfiguration()
)
```

### 2. **Visual Editing Interface**
The editor provides:
- **Component Palette**: Draggable elements with semantic features highlighted
- **Canvas**: Mode-specific workspace (freeform or grid-aligned)
- **Anchor Selector**: Star icon to mark preferred anchor piece (defaults to first placed)
- **Constraint Visualizer**: 
  - Green: Exact feature alignment
  - Yellow: Within tolerance
  - Red: Invalid placement
- **Constraint Probe Mode**: Tap edge/corner to reveal feature IDs and live deltas
  - Shows: distance to corner, signed edge distance, angle delta, overlap area (same metrics validator uses)
- **Feature Snapping**: Snap to corners/edges, not arbitrary positions (authoring gridStep = 0.25 units)
- **Discrete Rotation**: 45° increments for Tangram (visual + numeric feedback)
- **Mirror Toggle**: When shape allows chirality changes
- **Overlap Checker**: Highlights positive-area intersections in red
- **Re-anchor Preview**: Toggle to simulate anchor loss and re-selection
- **Constraint Graph View**: Shows all active relations between pieces

### 3. **Constraint-Based Workflow**
- **Place First Piece**: Sets initial reference frame
- **Add Constraints**: As pieces connect, create explicit relations:
  - Drag near a corner → snap and create corner constraint
  - Align edges → create edge coincidence constraint
- **Build Constraint Graph**: Sufficient constraints to eliminate unwanted DOF
- **Real-time Validation**: 
  - Check constraint satisfaction
  - Detect over/under-constrained configurations
  - Preview allowed transformations
- **Export**: Normalized arrangement with constraint graph

### 4. **Validation System**

#### WinConditionEngine
Orchestrates validation for the game runtime:
```swift
final class WinConditionEngine {
    private let poseSource: PoseSource
    private let anchorManager: AnchorManagerProtocol
    private let validator: ConstraintValidatorProtocol
    private let arrangement: GridArrangement

    func evaluate() -> ValidationResult {
        let worldPoses = poseSource.currentPoses()
        let (_, relPoses) = anchorManager.anchorRelativePoses(from: worldPoses)
        return validator.validate(arrangement: arrangement, relPoses: relPoses)
    }
}
```
- **Touch mode today:** `poseSource = TouchPoseSource(scene: TangramGameScene)`
- **CV mode later:** `poseSource = CVPoseSource(session: CVSession)`
- **Same engine, no rewrites**

#### Freeform Mode (Anchorless Validation)
1. Read **world poses** from `PoseSource`
2. Use `AnchorManager` to compute **anchor-relative** poses T^a_i (one inversion + multiply per piece)
3. Compute **global rotation index** from the anchor frame and subtract it before comparing per-piece `rotationIndexDelta`, constrained by `allowedGlobalRotations`
4. For each constraint edge (i,j):
   - Build canonical **feature transforms** from shape geometry
   - Compare **relative transforms** T^a_i and T^a_j projected to selected features
   - Check within **tolerances** and **allowed invariances** (global rotation indices, optional mirror)
5. Run **polygon overlap** test (SAT/CGPath)
   - **Zero-area** edge and corner contacts are allowed
   - Positive-area polygon intersections are failures
6. `passed = (all constraints satisfied) ∧ (no positive-area overlaps)`

This keeps win detection stable when the player slides or rotates the whole figure.

#### Lattice Mode
- Direct cell index comparison
- Rule-based validation (uniqueness, adjacency, etc.)
- No geometric transformation allowed

#### Robust Features
- **Polygon-Polygon Intersection**: SAT or CGPath with tolerances
- **Discrete Rotation Indices**: Avoid floating-point drift
- **Normalized Export**: Quantize to canonical values
- **Chirality Handling**: Explicit corner/edge mapping under reflection

### 5. **Export & Integration**
Arrangements can be:
- Saved to device persistence
- Exported as JSON files
- Shared via system share sheet
- Directly loaded into games
- Uploaded to cloud storage (future)

## Game-Specific Integrations

### Tangram Integration
```swift
// Define semantic features for each Tangram shape
struct TangramShapeLibrary {
    static let shapes: [String: ShapeGeometry] = [
        "smallTriangle": ShapeGeometry(
            shapeId: "smallTriangle",
            vertices: [CGPoint(0,0), CGPoint(1,0), CGPoint(0,1)],
            corners: [
                Corner(id: "right-angle", vertexIndex: 0, angle: 90),
                Corner(id: "acute-1", vertexIndex: 1, angle: 45),
                Corner(id: "acute-2", vertexIndex: 2, angle: 45)
            ],
            edges: [
                Edge(id: "base", startCornerId: "right-angle", endCornerId: "acute-1", length: 1),
                Edge(id: "height", startCornerId: "right-angle", endCornerId: "acute-2", length: 1),
                Edge(id: "hypotenuse", startCornerId: "acute-1", endCornerId: "acute-2", length: 1.4142135624) // sqrt(2)
            ]
        ),
        // ... other shapes with semantic corner/edge names
    ]
}

// Tangram-specific configuration
let tangramDefaults = ArrangementMetadata(
    mode: .freeform,
    rotationStep: 8,                      // 45° increments
    allowedGlobalRotations: Array(0..<8), // All 45° rotations valid
    allowGlobalMirror: false,             // Traditional tangram doesn't allow mirror
    tolerances: Tolerances(
        positionTolerance: 0.1,           // unit-space distance (40% of 0.25 gridStep)
        angleTolerance: 0.5,              // degrees
        edgeAlignment: 0.1                // unit-space distance (signed)
    )
)
```

### Sudoku Integration
```swift
extension SudokuCell {
    // Maps number cells to PlacedElement + Sudoku element registry
}

class SudokuGridEditor: GridEditor {
    // Enforces Sudoku rules during editing
}
```

### Future Game Support
Any game implementing the `GridElement` protocol can use the editor:
- Chess: Piece arrangements for puzzles
- Word games: Letter tile layouts
- Math equations: Number and operator placement
- Pattern matching: Shape sequence creation

## Data Flow

```
User Places First Piece → Becomes Anchor → Store as Reference
                                    ↓
User Places Next Piece → Calculate Relative Position → Validate Corners
                                    ↓
                        Store Relative to Anchor → Update Visual
                                    ↓
                             Save Arrangement → Game Integration
```

## Benefits

1. **Flexible Validation**: Puzzles work regardless of rotation or position
2. **Natural Puzzle Creation**: Define puzzles by how pieces connect, not absolute positions
3. **Rotation Invariant**: Same puzzle can be solved at any angle
4. **Corner-Based Logic**: More intuitive than center-point positioning
5. **Relative Simplicity**: No complex coordinate calculations needed

## Usage Example

### Creating a Tangram Puzzle
```swift
// 1. Place first piece (sets reference frame)
let piece1 = editor.placePiece("largeTriangle1", at: CGPoint(x: 100, y: 100), rotation: 0)

// 2. Place second piece - snaps to corner
let piece2 = editor.placePiece("square", near: piece1.corner("acute-1"))
// Automatically creates constraint:
let constraint1 = RelationConstraint(
    pieceA: "largeTriangle1",
    pieceB: "square",
    kind: .cornerToCorner,
    featureA: "acute-1",
    featureB: "bottom-left"
)

// 3. Place third piece - aligns edge
let piece3 = editor.placePiece("smallTriangle1", alongEdge: piece2.edge("right"))
// Creates edge constraint:
let constraint2 = RelationConstraint(
    pieceA: "square",
    pieceB: "smallTriangle1", 
    kind: .edgeToEdge,
    featureA: "right",
    featureB: "base",
    edgeOrientation: .sameDirection
)

// 4. Export with normalized data
let arrangement = GridArrangement(
    elements: [
        PlacedElement("largeTriangle1", rotationIndex: 0, position: CGPoint(x: 4, y: 4)),
        PlacedElement("square", rotationIndex: 1, position: CGPoint(x: 5, y: 4.7)),
        PlacedElement("smallTriangle1", rotationIndex: 3, position: CGPoint(x: 5.7, y: 4))
    ],
    constraints: [constraint1, constraint2],
    metadata: tangramDefaults
)
```

### Creating a Sudoku Board
```swift
// 1. Configure editor for Sudoku
let config = SudokuGridConfiguration(size: .nineByNine)
let editor = gridEditorService.createEditor(for: .sudoku, configuration: config)

// 2. Place pre-filled numbers
// 3. Validate difficulty and uniqueness

// 4. Export as game board
let board = SudokuBoard(from: editor.currentArrangement)
```

## Key Differences from Absolute Positioning

### Current Implementation (Absolute)
```
Grid coordinates:
Square at (3, 5)
Triangle at (4, 5)
Validation: Square MUST be at (3,5)
```

### Proposed Implementation (Relative)
```
First piece (anchor): LargeTriangle1
Square: Connect bottom-left corner to anchor's top-right corner
SmallTriangle: Connect right-angle corner to Square's left edge

Valid solutions:
- Entire puzzle rotated 45°? ✓ Still valid
- Entire puzzle moved to different position? ✓ Still valid
- Square at different absolute position but same relative position? ✓ Valid
```

### Visual Example
```
Editor Creation:
    [Triangle1] ← Anchor (can be anywhere)
         ╱╲
        ╱  ╲ 
       ╱____╲
      corner A
         |
    [Square] ← Connects corner to corner A
    
Validation accepts ANY of these:
- Same shape rotated 90° clockwise
- Same shape moved 5 units right
- Same shape rotated and moved
(As long as relative positions match)
```

### Corner-Based vs Center-Based
```
Center-Based (Current):
- Piece position = center point
- Hard to connect pieces precisely
- Requires offset calculations

Corner-Based (Proposed):
- Each piece has named corners
- Pieces connect corner-to-corner
- Natural tangram-like connections
- Example: Triangle's "right-angle corner" connects to Square's "top-left corner"
```

## Automated Testing Battery

### Constraint Satisfaction Tests
1. For every constraint edge, verify semantic feature coincidence within tolerances
2. Validate relative transforms between all constrained pairs
3. Test with random global rotations from allowed set

### Overlap Tests  
1. Polygon intersection area ≈ 0 (use SAT or CGPath boolean operations)
2. Allow shared edges/corners (zero area)
3. Flag positive area overlaps as errors

### Invariance Tests
1. **Anchor Independence**: Re-anchor to different piece → validation still passes
2. **Rotation Invariance**: Apply allowed global rotations → validation passes
3. **Mirror Test**: If `allowGlobalMirror = false`, mirrored solution fails

### Robustness Tests
1. **Quantization**: Export → Import → Validate successfully
2. **Parallelogram Chirality**: Test corner/edge ID mapping under reflection
3. **Floating Point**: Verify no drift after multiple transformations

## Implementation Risks & Mitigations

### Risk: Floating Point Precision
- **Mitigation**: Use discrete rotation indices (0-7 for 45°)
- Store canonical geometry in unit space
- Quantize positions at export time

### Risk: Parallelogram Chirality  
- **Mitigation**: Explicit corner/edge ID remapping table for mirrored state
- Unit tests for all mirrored configurations

### Risk: Over/Under-Constrained Systems
- **Mitigation**: Constraint graph analysis tool
- Visual indicators for degrees of freedom
- Validation warnings for contradictory constraints

### Risk: Edge Case Geometries
- **Mitigation**: Comprehensive shape library tests
- Validate all corner/edge semantic names
- Test degenerate cases (collinear points, zero-length edges)

---

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

#### 1.1 Create Core Abstractions
- [ ] Implement `PoseSource`, `AnchorManager`, `ConstraintValidator` protocols
- [ ] Create `TouchPoseSource` for editor and game
- [ ] Build `AnchorManager` with first-piece policy
- [ ] Implement `ConstraintValidator` for win detection

#### 1.2 Define Shape System
- [ ] Create shape geometry with semantic corners/edges
- [ ] Define edge direction (start → end)
- [ ] Add chirality mapping for parallelogram
- [ ] Switch authoring grid step to 0.25

#### 1.3 Update Data Models  
- [ ] Add `EdgeOrientation`, `mirrorAware`, `rotationIndexDelta`, `overlapRatioMin` to constraints
- [ ] Keep geometry in unit space (continuous)
- [ ] Use discrete rotation indices for storage

#### 1.4 Create GridEditorService
- [ ] Implement `GridEditorServiceProtocol` following existing patterns
- [ ] Register with `ServiceLocator` 
- [ ] Add factory methods for creating game-specific editors
- [ ] Implement arrangement persistence using `PersistenceServiceProtocol`

### Phase 2: Visual Editor UI (Week 2)

#### 2.1 Enhanced Editor Interface
- [ ] Add anchor selector UI (star icon)
- [ ] Implement constraint probe mode
- [ ] Create re-anchor preview toggle
- [ ] Update grid to 1/4 unit steps
- [ ] Snap to features first, grid second

#### 2.2 Component Palette
- [ ] Design `ComponentPalette` view for available elements
- [ ] Implement drag source for palette items
- [ ] Add search and filtering for large element sets
- [ ] Create preview rendering for elements

#### 2.3 Property Inspector
- [ ] Build `PropertyInspector` panel for selected elements
- [ ] Add rotation controls with visual feedback
- [ ] Implement custom property editors per game type
- [ ] Create preset system for common configurations

#### 2.4 Editor Controls
- [ ] Implement undo/redo system with command pattern
- [ ] Add zoom and pan controls for large grids
- [ ] Create save/load UI with arrangement management
- [ ] Build export options (JSON, share, direct integration)

### Phase 3: Game Integration (Week 3)

#### 3.1 Tangram Integration
- [ ] Extend `TangramPieceDefinition` to implement `GridElement`
- [ ] Create `TangramGridEditor` with piece-specific features
- [ ] Add Tangram validation rules (overlap, boundaries)
- [ ] Integrate with existing `BlueprintStore` for saving

#### 3.2 Sudoku Integration
- [ ] Create `SudokuGridElement` for number cells
- [ ] Build `SudokuGridEditor` with number palette
- [ ] Implement Sudoku-specific validation rules
- [ ] Add difficulty analysis for created boards

#### 3.3 Integration Framework
- [ ] Create `GridEditorAdapter` protocol for game-specific logic
- [ ] Build registration system for game-specific validators
- [ ] Implement preview system using actual game renderers
- [ ] Add migration tools for existing JSON puzzles

### Phase 4: Advanced Features (Week 4)

#### 4.1 Multi-Element Operations
- [ ] Implement multi-select with marquee or tap selection
- [ ] Add group operations (move, rotate, duplicate)
- [ ] Create alignment tools (distribute, align edges)
- [ ] Build grouping system for complex arrangements

#### 4.2 Templates and Presets
- [ ] Create template system for common patterns
- [ ] Add preset arrangements for quick starts
- [ ] Implement variation generator (rotate, mirror, shuffle)
- [ ] Build difficulty progression tools

#### 4.3 Collaboration Features
- [ ] Add arrangement sharing via system share sheet
- [ ] Implement import from photos (future: CV integration)
- [ ] Create arrangement library management
- [ ] Build rating and feedback system

#### 4.4 Developer Tools
- [ ] Add arrangement validation API for CI/CD
- [ ] Create batch processing for multiple arrangements
- [ ] Implement A/B testing support for arrangements
- [ ] Build analytics integration for usage tracking

### Phase 5: Polish and Optimization (Week 5)

#### 5.1 Performance Optimization
- [ ] Optimize rendering for large grids
- [ ] Implement element pooling for palette
- [ ] Add level-of-detail for zoomed views
- [ ] Profile and optimize touch handling

#### 5.2 Accessibility
- [ ] Add VoiceOver support for all controls
- [ ] Implement keyboard navigation (iPad)
- [ ] Create high contrast mode
- [ ] Add haptic feedback for actions

#### 5.3 Testing and Documentation
- [ ] Write comprehensive unit tests
- [ ] Create integration tests with games
- [ ] Build example arrangements for each game
- [ ] Write developer documentation

#### 5.4 Future Preparation
- [ ] Design plugin architecture for custom validators
- [ ] Plan cloud sync architecture
- [ ] Create versioning system for arrangements
- [ ] Design monetization hooks (premium arrangements)

### Technical Considerations

1. **Memory Management**: Implement element pooling for large arrangements
2. **Performance**: Use Metal for grid rendering on complex boards
3. **Persistence**: Leverage existing SwiftData infrastructure
4. **Compatibility**: Ensure backwards compatibility with existing JSON formats
5. **Modularity**: Keep editor independent of specific game logic

### Success Metrics

- Time to create arrangement: < 2 minutes (vs 20+ minutes manual)
- User satisfaction: > 90% prefer visual editor
- Adoption rate: > 80% of new puzzles created with editor
- Bug rate: < 0.1% of arrangements have validation issues