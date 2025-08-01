# Tangram Game - Definitive Mathematical Specification

## Core Principles

- **Base Unit**: 1 (all shapes defined relative to this)
- **Grid Resolution**: 0.1 units (for smooth positioning)  
- **Play Area**: 8×8 units (provides margin around 3×3 tangram)
- **Total Tangram Area**: 9 square units (3×3 when assembled)
- **Rotation Increment**: π/4 radians (45°)
- **Visual Rotation**: π/16 radians (11.25° for feedback)
- **Snap Tolerance**: Auto-scaling based on screen size
  - ≈ 0.3 units on tablets (8mm finger target)
  - ≈ 0.2 units on small phones (minimum tolerance)

## Shape Definitions (Base Unit = 1)

### Mathematical Properties

```
Small Triangle:
- Legs: 1 × 1
- Hypotenuse: √2 ≈ 1.414
- Area: 0.5

Square:
- Sides: 1 × 1
- Diagonal: √2 ≈ 1.414
- Area: 1

Medium Triangle:
- Legs: √2 × √2
- Hypotenuse: 2
- Area: 1

Large Triangle:
- Legs: 2 × 2
- Hypotenuse: 2√2 ≈ 2.828
- Area: 2

Parallelogram:
- Base: 2
- Height: 1
- Slant sides: √2 ≈ 1.414
- Area: 2

Total Tangram Area: 9 square units
```

### Canonical Shape Vertices (Origin at bottom-left)

```swift
// Mathematical constant for precision
extension CGFloat {
    static let sqrt2: CGFloat = 1.4142135623730951
}

// IMPORTANT: All shapes use (0,0) as bottom-left anchor point.
// All targetPositions in JSON are measured from this anchor.
struct TangramShapes {
    static let shapes: [String: [CGPoint]] = [
        "smallTriangle1": [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ],
        "smallTriangle2": [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1)
        ],
        
        "square": [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ],
        
        "mediumTriangle": [
            CGPoint(x: 0, y: 0),
            CGPoint(x: .sqrt2, y: 0),
            CGPoint(x: 0, y: .sqrt2)
        ],
        
        "largeTriangle1": [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ],
        "largeTriangle2": [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 0, y: 2)
        ],
        
        "parallelogram": [
            CGPoint(x: 0, y: 0),     // Bottom-left anchor (ALL positions measured from here)
            CGPoint(x: 2, y: 0),
            CGPoint(x: 3, y: 1),
            CGPoint(x: 1, y: 1)
        ]
    ]
}
```

## Grid System (0.1 Resolution)

### Grid Properties

- **Resolution**: 0.1 units
- **Total Grid Points**: 81×81 in an 8×8 unit space
- **Snap Tolerance**: ≈ 0.2–0.3 units (see auto-scaling formula below)
- **Valid Positions**: Any multiple of 0.1 (e.g., 2.3, 4.7, 5.0)

### Implementation

```swift
struct GridConstants {
    static let resolution: CGFloat = 0.1
    static let playAreaSize: CGFloat = 8.0
    
    // Auto-scaling snap tolerance
    static func snapTolerance(for screenUnit: CGFloat) -> CGFloat {
        return max(0.2, 0.0375 * screenUnit)
    }
}

struct RotationConstants {
    static let visualIncrement: CGFloat = .pi / 16  // 11.25° for smooth feedback
    static let snapIncrement: CGFloat = .pi / 4     // 45° for final placement
}

extension CGPoint {
    // Snap to nearest grid point
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
        let increment = RotationConstants.snapIncrement
        return round(self / increment) * increment
    }
}
```

## JSON Puzzle Format

**Important**: All position coordinates must be rounded to one decimal place (0.1 precision).

```json
{
  "id": "cat",
  "name": "Cat",
  "difficulty": "easy",
  "pieces": [
    {
      "pieceId": "largeTriangle1",
      "targetPosition": { "x": 2.5, "y": 3.2 },  // ✓ One decimal place
      "targetRotation": 0.785398,               // π/4 radians
      "isMirrored": false
    },
    {
      "pieceId": "parallelogram",
      "targetPosition": { "x": 5.7, "y": 1.3 },
      "targetRotation": 0.0,
      "isMirrored": true                        // Only parallelogram can mirror
    }
    // ... other pieces
  ]
}
```

## Screen Coordinate Conversion

```swift
class CoordinateSystem {
    let screenSize: CGSize
    let margin: CGFloat = 20
    
    // Points per unit (computed to fit screen)
    var screenUnit: CGFloat {
        let availableSize = min(screenSize.width, screenSize.height) - (margin * 2)
        return availableSize / GridConstants.playAreaSize
    }
    
    // Convert unit coordinates to screen coordinates
    func toScreen(_ unitPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: margin + (unitPoint.x * screenUnit),
            y: margin + (unitPoint.y * screenUnit)
        )
    }
    
    // Convert screen coordinates to unit coordinates
    func toUnit(_ screenPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: (screenPoint.x - margin) / screenUnit,
            y: (screenPoint.y - margin) / screenUnit
        )
    }
}
```

## Piece Placement Logic

```swift
struct PlacementValidator {
    let puzzle: Puzzle
    let screenUnit: CGFloat
    
    func checkPlacement(piece: TangramPiece, at position: CGPoint, rotation: CGFloat) -> Bool {
        guard let targetPiece = puzzle.pieces.first(where: { $0.pieceId == piece.id }) else {
            return false
        }
        
        let targetPos = CGPoint(x: targetPiece.targetPosition.x, 
                               y: targetPiece.targetPosition.y)
        let targetRot = targetPiece.targetRotation
        
        // Check position (using auto-scaled tolerance)
        let tolerance = GridConstants.snapTolerance(for: screenUnit)
        let positionCorrect = position.isNear(targetPos, tolerance: tolerance)
        
        // Check rotation (compare snapped values to avoid float precision issues)
        let snappedRotation = rotation.snappedRotation()
        let rotationCorrect = abs(snappedRotation - targetRot) < 0.01
        
        return positionCorrect && rotationCorrect
    }
}
```

## Drag & Drop Behavior

```swift
class DragHandler {
    var isDragging = false
    var selectedPiece: TangramPiece?
    var dragOffset: CGPoint = .zero
    
    func beginDrag(piece: TangramPiece, at touchPoint: CGPoint) {
        isDragging = true
        selectedPiece = piece
        dragOffset = CGPoint(x: touchPoint.x - piece.position.x,
                           y: touchPoint.y - piece.position.y)
        piece.zPosition = 100  // Bring to front
    }
    
    func updateDrag(to touchPoint: CGPoint) {
        guard let piece = selectedPiece else { return }
        
        // Follow finger exactly (no grid snapping while dragging)
        piece.position = CGPoint(x: touchPoint.x - dragOffset.x,
                               y: touchPoint.y - dragOffset.y)
    }
    
    func endDrag() {
        guard let piece = selectedPiece else { return }
        
        isDragging = false
        piece.zPosition = 1
        
        // Snap to grid
        let snappedPos = piece.position.snappedToGrid()
        
        // Animate to snapped position
        piece.run(SKAction.move(to: snappedPos, duration: 0.1))
        
        // Check if placement is correct
        if PlacementValidator.checkPlacement(piece, at: snappedPos, rotation: piece.rotation) {
            piece.lock()  // Disable further interaction
            SoundManager.playSnapSound()
        }
        
        selectedPiece = nil
    }
}
```

## Visual Feedback Guidelines

1. **Grid Hints** (optional): Show faint dots at 0.1 intervals near dragged piece
2. **Snap Preview**: Highlight target outline when piece is within snap tolerance
3. **Rotation Feedback**: Show rotation handle or gesture indicator
4. **Completion Effects**: Particle burst + sound when piece locks in place

## Performance Considerations

- **Grid Points**: 81×81 = 6,561 possible positions (very manageable)
- **Touch Precision**: 0.1 units ≈ 4-5 screen pixels on most devices
- **Snap Tolerance**: Auto-scales with screen size
  - Formula: `max(0.2, 0.0375 * screenUnit)`
  - Prevents adjacent pieces from competing on small screens
  - Maintains comfortable tolerance on larger screens
- **Animation Duration**: 0.1-0.15 seconds for snap animations
- **Z-Fighting**: Use distinct zPosition values (0, 1, 100) to prevent overlap issues
- **Floating Point**: Use exact constants (√2) to prevent cumulative drift

This specification provides the complete mathematical foundation for implementing a professional tangram game with smooth, intuitive controls.

## JSON Generation Note

When creating puzzle definitions, ensure all positions are snapped to the grid:

```swift
extension Double {
    func roundedToGrid() -> Double {
        return (self * 10).rounded() / 10  // Round to 0.1 precision
    }
}

// Usage when creating puzzles:
let position = CGPoint(x: 2.537, y: 3.281)

// Apply transformations first (rotation, mirroring)
let transformedPosition = applyTransforms(position)

// Then round to grid
let snappedPosition = CGPoint(
    x: transformedPosition.x.roundedToGrid(),  // 2.5
    y: transformedPosition.y.roundedToGrid()   // 3.3
)

// This ensures negative values round correctly: -1.23 → -1.2
```

## Pre-Ship Sanity Checklist

### 1. Unit Tests
```swift
// Verify shape edges match expected lengths
func testShapeEdgeLengths() {
    // Small triangle edges: [1, 1, √2]
    // Medium triangle edges: [√2, √2, 2]
    // Large triangle edges: [2, 2, 2√2]
    // Square edges: [1, 1, 1, 1]
    // Parallelogram edges: [2, √2, 2, √2]
}

// Test rotation snapping
func testRotationSnapping() {
    XCTAssertEqual(CGFloat(0.3).snappedRotation(), 0.0)        // < π/8 (halfway)
    XCTAssertEqual(CGFloat(0.4).snappedRotation(), 0.785398)   // ≥ π/8 (halfway) 
    XCTAssertEqual(CGFloat(0.8).snappedRotation(), 0.785398)   // π/4
    XCTAssertEqual(CGFloat(1.5).snappedRotation(), 1.570796)   // π/2
}
```

### 2. Device Testing
- **iPhone 14 mini (5.4")**: Verify snap tolerance feels right
- **iPad Pro 12.9"**: Ensure pieces aren't too small
- **Dynamic Type**: Test with accessibility sizes

### 3. Performance Benchmarks
- Target: <1ms CPU per frame with 6,561 grid points
- Memory: ~50MB for all assets loaded
- Touch latency: <16ms response time