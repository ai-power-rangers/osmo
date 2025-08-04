# Tangram Mathematics Specification

## Overview

This document defines the precise mathematical foundations for the Tangram game implementation, building on the platform's unified coordinate system.

## Shape Definitions

### The Seven Tangram Pieces

All measurements are in platform units (1 unit = base measurement).

#### 1. Large Triangles (×2)
```
Vertices: [(0, 0), (2, 0), (0, 2)]
Area: 2 square units
Hypotenuse: 2√2 units
Type: Right isosceles triangle
Center of mass: (2/3, 2/3)
```

#### 2. Medium Triangle (×1)
```
Vertices: [(0, 0), (√2, 0), (0, √2)]
Area: 1 square unit
Hypotenuse: 2 units
Type: Right isosceles triangle
Center of mass: (√2/3, √2/3)
```

#### 3. Small Triangles (×2)
```
Vertices: [(0, 0), (1, 0), (0, 1)]
Area: 0.5 square units
Hypotenuse: √2 units
Type: Right isosceles triangle
Center of mass: (1/3, 1/3)
```

#### 4. Square (×1)
```
Vertices: [(0, 0), (1, 0), (1, 1), (0, 1)]
Area: 1 square unit
Side length: 1 unit
Type: Square
Center of mass: (0.5, 0.5)
```

#### 5. Parallelogram (×1)
```
Vertices: [(0, 0), (2, 0), (1, 1), (-1, 1)]
Area: 2 square units
Base: 2 units, Height: 1 unit
Type: Parallelogram (can be flipped)
Center of mass: (0.5, 0.5)
```

### Mathematical Relationships

```
Total area = 2×2 + 1 + 2×0.5 + 1 + 2 = 8 square units
This forms a perfect 2√2 × 2√2 square when assembled
```

## Coordinate System

### Unit Space
- Origin: (0, 0) at bottom-left
- Play area: 8×8 units
- Storage precision: 0.1 units
- Interaction grid: 0.25 units (1/4 unit)

### Rotation System
- Base increment: π/4 radians (45°)
- Valid rotations: 0, π/4, π/2, 3π/4, π, 5π/4, 3π/2, 7π/4
- Storage: Radians with 0.001 precision

### Flip Transformation
- Only parallelogram can flip
- Flip axis: Vertical through center
- Matrix: `[[-1, 0], [0, 1]]` applied to local coordinates

## Piece Placement Mathematics

### Grid Snapping

```swift
func snapToGrid(position: CGPoint) -> CGPoint {
    let gridStep = 0.25  // 1/4 unit
    return CGPoint(
        x: round(position.x / gridStep) * gridStep,
        y: round(position.y / gridStep) * gridStep
    )
}
```

### Rotation Snapping

```swift
func snapRotation(angle: CGFloat) -> CGFloat {
    let step = CGFloat.pi / 4  // 45 degrees
    return round(angle / step) * step
}
```

### Valid Position Range

```swift
func isValidPosition(position: CGPoint, shape: TangramShape) -> Bool {
    let bounds = shapeBounds(for: shape)
    return position.x >= 0 && position.x + bounds.width <= 8 &&
           position.y >= 0 && position.y + bounds.height <= 8
}
```

## Collision Detection

### Point-in-Triangle Test

For triangular pieces, use barycentric coordinates:

```swift
func pointInTriangle(point: CGPoint, triangle: [CGPoint]) -> Bool {
    let v0 = CGVector(dx: triangle[2].x - triangle[0].x, 
                      dy: triangle[2].y - triangle[0].y)
    let v1 = CGVector(dx: triangle[1].x - triangle[0].x, 
                      dy: triangle[1].y - triangle[0].y)
    let v2 = CGVector(dx: point.x - triangle[0].x, 
                      dy: point.y - triangle[0].y)
    
    let dot00 = dot(v0, v0)
    let dot01 = dot(v0, v1)
    let dot02 = dot(v0, v2)
    let dot11 = dot(v1, v1)
    let dot12 = dot(v1, v2)
    
    let invDenom = 1 / (dot00 * dot11 - dot01 * dot01)
    let u = (dot11 * dot02 - dot01 * dot12) * invDenom
    let v = (dot00 * dot12 - dot01 * dot02) * invDenom
    
    return (u >= 0) && (v >= 0) && (u + v <= 1)
}
```

### Shape Overlap Detection

```swift
func shapesOverlap(shape1: PlacedShape, shape2: PlacedShape) -> Bool {
    // Quick bounding box check first
    if !boundingBoxesIntersect(shape1, shape2) {
        return false
    }
    
    // Detailed polygon intersection using Separating Axis Theorem
    return polygonsIntersect(
        vertices: shape1.transformedVertices,
        vertices: shape2.transformedVertices
    )
}
```

## Solution Validation

### Position Matching

Two positions match if they are within tolerance:

```swift
func positionsMatch(p1: CGPoint, p2: CGPoint) -> Bool {
    let tolerance: CGFloat = 0.05  // 0.05 units
    return abs(p1.x - p2.x) < tolerance && 
           abs(p1.y - p2.y) < tolerance
}
```

### Rotation Matching

```swift
func rotationsMatch(r1: CGFloat, r2: CGFloat) -> Bool {
    let tolerance: CGFloat = 0.01  // ~0.57 degrees
    let diff = abs(normalizeAngle(r1 - r2))
    return diff < tolerance || diff > (2 * .pi - tolerance)
}
```

### Complete Solution Check

```swift
func isSolutionComplete(current: TangramState, target: TangramState) -> Bool {
    // Must have same number of pieces
    guard current.pieces.count == target.pieces.count else { 
        return false 
    }
    
    // Each target piece must have a matching current piece
    for targetPiece in target.pieces {
        let hasMatch = current.pieces.contains { currentPiece in
            currentPiece.shape == targetPiece.shape &&
            positionsMatch(currentPiece.position, targetPiece.position) &&
            rotationsMatch(currentPiece.rotation, targetPiece.rotation) &&
            currentPiece.isFlipped == targetPiece.isFlipped
        }
        
        if !hasMatch { return false }
    }
    
    return true
}
```

## JSON Storage Format

### Piece Representation

```json
{
  "id": "uuid-string",
  "shape": "largeTriangle1",
  "position": {
    "x": 2.1,  // 0.1 precision
    "y": 3.4
  },
  "rotation": 0.7854,  // π/4 in radians, 0.001 precision
  "isFlipped": false
}
```

### Puzzle Format

```json
{
  "id": "puzzle-uuid",
  "name": "Cat",
  "difficulty": "medium",
  "initialState": {
    "pieces": []  // Empty for standard Tangram
  },
  "targetState": {
    "pieces": [
      // Array of piece definitions forming the solution
    ]
  },
  "metadata": {
    "author": "System",
    "createdAt": "2024-01-15T10:00:00Z",
    "tags": ["animals", "classic"],
    "solutionCount": 1
  }
}
```

## Mathematical Constants

```swift
struct TangramMathConstants {
    // Exact values for consistency
    static let sqrt2: CGFloat = 1.4142135623730951
    static let sqrt3: CGFloat = 1.7320508075688772
    
    // Rotation angles (radians)
    static let deg0: CGFloat = 0
    static let deg45: CGFloat = .pi / 4
    static let deg90: CGFloat = .pi / 2
    static let deg135: CGFloat = 3 * .pi / 4
    static let deg180: CGFloat = .pi
    static let deg225: CGFloat = 5 * .pi / 4
    static let deg270: CGFloat = 3 * .pi / 2
    static let deg315: CGFloat = 7 * .pi / 4
    
    // Grid and snapping
    static let gridMajor: CGFloat = 1.0    // Major grid lines
    static let gridMinor: CGFloat = 0.25   // Snapping grid
    static let gridStorage: CGFloat = 0.1  // Storage precision
    
    // Tolerances
    static let positionTolerance: CGFloat = 0.05
    static let rotationTolerance: CGFloat = 0.01
    static let snapDistance: CGFloat = 0.15
}
```

## Transformation Matrices

### Rotation Matrix

```swift
func rotationMatrix(angle: CGFloat) -> simd_float2x2 {
    let c = cos(angle)
    let s = sin(angle)
    return simd_float2x2(
        simd_float2(Float(c), Float(-s)),
        simd_float2(Float(s), Float(c))
    )
}
```

### Flip Matrix (for Parallelogram)

```swift
func flipMatrix() -> simd_float2x2 {
    return simd_float2x2(
        simd_float2(-1, 0),
        simd_float2(0, 1)
    )
}
```

### Combined Transformation

```swift
func transformPoint(_ point: CGPoint, 
                   position: CGPoint, 
                   rotation: CGFloat, 
                   flip: Bool) -> CGPoint {
    var p = simd_float2(Float(point.x), Float(point.y))
    
    // Apply flip if needed
    if flip {
        p = flipMatrix() * p
    }
    
    // Apply rotation
    p = rotationMatrix(rotation) * p
    
    // Apply translation
    return CGPoint(
        x: CGFloat(p.x) + position.x,
        y: CGFloat(p.y) + position.y
    )
}
```

## Performance Optimizations

### Spatial Indexing

For efficient collision detection with many pieces:

```swift
struct SpatialGrid {
    let cellSize: CGFloat = 1.0  // 1 unit cells
    var cells: [Int: [TangramPiece]] = [:]
    
    func cellIndex(for point: CGPoint) -> Int {
        let x = Int(floor(point.x / cellSize))
        let y = Int(floor(point.y / cellSize))
        return y * 8 + x  // 8 cells wide
    }
    
    func nearbyPieces(to piece: TangramPiece) -> [TangramPiece] {
        // Check piece's cell and adjacent cells
        var nearby: [TangramPiece] = []
        let index = cellIndex(for: piece.position)
        
        for offset in [-9, -8, -7, -1, 0, 1, 7, 8, 9] {
            if let pieces = cells[index + offset] {
                nearby.append(contentsOf: pieces)
            }
        }
        
        return nearby
    }
}
```

### Cached Transformations

```swift
struct TransformedShape {
    let original: TangramShape
    let vertices: [CGPoint]  // Pre-transformed vertices
    let bounds: CGRect       // Axis-aligned bounding box
    
    init(shape: TangramShape, position: CGPoint, rotation: CGFloat, flip: Bool) {
        self.original = shape
        self.vertices = shape.vertices.map { vertex in
            transformPoint(vertex, position: position, rotation: rotation, flip: flip)
        }
        self.bounds = calculateBounds(vertices: self.vertices)
    }
}
```

## Implementation Notes

1. **Floating Point Precision**: Use `CGFloat` for all calculations, round only for storage
2. **Coordinate Origin**: Bottom-left (0,0) following mathematical convention
3. **Rotation Direction**: Counter-clockwise positive (mathematical standard)
4. **Storage Format**: JSON with 0.1 position precision, 0.001 rotation precision
5. **Visual Grid**: Display at 1.0 unit intervals with 0.25 subdivisions
6. **Snapping**: Applied during interaction, not in game logic
7. **Validation**: Use tolerances to account for floating-point errors

## Testing Considerations

### Unit Tests Required

- [ ] Shape vertex definitions match mathematical specification
- [ ] Rotation matrices produce correct transformations
- [ ] Grid snapping rounds to nearest 0.25 units
- [ ] Position validation keeps pieces within bounds
- [ ] Solution matching works with tolerance
- [ ] JSON serialization maintains precision
- [ ] Collision detection catches all overlaps
- [ ] Spatial indexing improves performance

### Edge Cases

- Pieces at exact boundary (x=8 or y=8)
- Rotations at 0 and 2π (should match)
- Parallelogram flip state preservation
- Overlapping pieces with shared edges
- Very small position differences (< tolerance)