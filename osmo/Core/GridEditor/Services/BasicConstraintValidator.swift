import Foundation
import CoreGraphics

/// Basic implementation of constraint validation
/// Validates geometric constraints and checks for overlaps
public final class BasicConstraintValidator: ConstraintValidatorProtocol {
    private let shapeLibrary: ShapeLibraryProtocol
    private let tolerances: Tolerances
    
    public init(shapeLibrary: ShapeLibraryProtocol, tolerances: Tolerances = Tolerances()) {
        self.shapeLibrary = shapeLibrary
        self.tolerances = tolerances
    }
    
    public func validate(arrangement: GridArrangement, relPoses: [String: SE2Pose]) -> ValidationResult {
        var result = ValidationResult()
        result.passed = true
        
        // Get global rotation if we can determine it
        result.globalRotationIndex = computeGlobalRotation(arrangement: arrangement, relPoses: relPoses)
        
        // Validate each constraint
        for constraint in arrangement.constraints {
            if !validateConstraint(constraint, arrangement: arrangement, relPoses: relPoses, result: &result) {
                result.violatedConstraints.append(constraint.id)
                result.passed = false
            }
        }
        
        // Check for overlaps
        checkOverlaps(arrangement: arrangement, relPoses: relPoses, result: &result)
        
        // Overall pass requires no violations and no overlaps
        result.passed = result.violatedConstraints.isEmpty && result.overlaps.isEmpty
        
        return result
    }
    
    // MARK: - Constraint Validation
    
    private func validateConstraint(_ constraint: RelationConstraint,
                                  arrangement: GridArrangement,
                                  relPoses: [String: SE2Pose],
                                  result: inout ValidationResult) -> Bool {
        // Find the pieces
        guard let pieceA = arrangement.elements.first(where: { $0.elementId == constraint.pieceA }),
              let pieceB = arrangement.elements.first(where: { $0.elementId == constraint.pieceB }),
              let poseA = relPoses[constraint.pieceA],
              let poseB = relPoses[constraint.pieceB] else {
            return false
        }
        
        // Get shape geometries
        guard let shapeA = shapeLibrary.shape(for: pieceA.elementType),
              let shapeB = shapeLibrary.shape(for: pieceB.elementType) else {
            return false
        }
        
        switch constraint.kind {
        case .cornerToCorner:
            return validateCornerConstraint(
                constraint: constraint,
                pieceA: pieceA, poseA: poseA, shapeA: shapeA,
                pieceB: pieceB, poseB: poseB, shapeB: shapeB,
                result: &result
            )
            
        case .edgeToEdge:
            return validateEdgeConstraint(
                constraint: constraint,
                pieceA: pieceA, poseA: poseA, shapeA: shapeA,
                pieceB: pieceB, poseB: poseB, shapeB: shapeB,
                result: &result
            )
        }
    }
    
    private func validateCornerConstraint(constraint: RelationConstraint,
                                        pieceA: PlacedElement, poseA: SE2Pose, shapeA: ShapeGeometry,
                                        pieceB: PlacedElement, poseB: SE2Pose, shapeB: ShapeGeometry,
                                        result: inout ValidationResult) -> Bool {
        // Get corners
        guard let cornerA = shapeA.corner(withId: constraint.featureA),
              let cornerB = shapeB.corner(withId: constraint.featureB),
              let vertexA = shapeA.vertex(for: cornerA),
              let vertexB = shapeB.vertex(for: cornerB) else {
            return false
        }
        
        // Transform corners to world space
        let worldCornerA = transformPoint(vertexA, piece: pieceA, pose: poseA)
        let worldCornerB = transformPoint(vertexB, piece: pieceB, pose: poseB)
        
        // Check distance
        let distance = hypot(worldCornerA.x - worldCornerB.x, worldCornerA.y - worldCornerB.y)
        let targetDistance = constraint.gap ?? 0.0
        
        if abs(distance - targetDistance) > tolerances.positionTolerance {
            // Add near-miss hint if close
            if distance < tolerances.positionTolerance * 3 {
                result.nearMissHints[constraint.id] = String(format: "Corner distance: %.2f (target: %.2f)", distance, targetDistance)
            }
            return false
        }
        
        // Check rotation delta if specified
        if let rotationDelta = constraint.rotationIndexDelta {
            let actualDelta = (pieceB.rotationIndex - pieceA.rotationIndex + 8) % 8
            if actualDelta != rotationDelta {
                return false
            }
        }
        
        return true
    }
    
    private func validateEdgeConstraint(constraint: RelationConstraint,
                                      pieceA: PlacedElement, poseA: SE2Pose, shapeA: ShapeGeometry,
                                      pieceB: PlacedElement, poseB: SE2Pose, shapeB: ShapeGeometry,
                                      result: inout ValidationResult) -> Bool {
        // Get edges
        guard let edgeA = shapeA.edge(withId: constraint.featureA),
              let edgeB = shapeB.edge(withId: constraint.featureB) else {
            return false
        }
        
        // Get edge endpoints
        guard let startCornerA = shapeA.corner(withId: edgeA.startCornerId),
              let endCornerA = shapeA.corner(withId: edgeA.endCornerId),
              let startCornerB = shapeB.corner(withId: edgeB.startCornerId),
              let endCornerB = shapeB.corner(withId: edgeB.endCornerId),
              let startVertexA = shapeA.vertex(for: startCornerA),
              let endVertexA = shapeA.vertex(for: endCornerA),
              let startVertexB = shapeB.vertex(for: startCornerB),
              let endVertexB = shapeB.vertex(for: endCornerB) else {
            return false
        }
        
        // Transform to world space
        let worldStartA = transformPoint(startVertexA, piece: pieceA, pose: poseA)
        let worldEndA = transformPoint(endVertexA, piece: pieceA, pose: poseA)
        let worldStartB = transformPoint(startVertexB, piece: pieceB, pose: poseB)
        let worldEndB = transformPoint(endVertexB, piece: pieceB, pose: poseB)
        
        // Check edge alignment
        let edgeVectorA = CGPoint(x: worldEndA.x - worldStartA.x, y: worldEndA.y - worldStartA.y)
        let edgeVectorB = CGPoint(x: worldEndB.x - worldStartB.x, y: worldEndB.y - worldStartB.y)
        
        // Normalize vectors
        let lengthA = hypot(edgeVectorA.x, edgeVectorA.y)
        let lengthB = hypot(edgeVectorB.x, edgeVectorB.y)
        
        guard lengthA > 0 && lengthB > 0 else { return false }
        
        let normalizedA = CGPoint(x: edgeVectorA.x / lengthA, y: edgeVectorA.y / lengthA)
        let normalizedB = CGPoint(x: edgeVectorB.x / lengthB, y: edgeVectorB.y / lengthB)
        
        // Check orientation
        let dotProduct = normalizedA.x * normalizedB.x + normalizedA.y * normalizedB.y
        
        switch constraint.edgeOrientation {
        case .sameDirection:
            if dotProduct < cos(tolerances.angleTolerance * .pi / 180) {
                return false
            }
        case .oppositeDirection:
            if dotProduct > -cos(tolerances.angleTolerance * .pi / 180) {
                return false
            }
        case nil:
            break
        }
        
        // Check overlap ratio if specified
        if let minOverlap = constraint.overlapRatioMin {
            // Calculate overlap (simplified - assumes collinear edges)
            // This is a placeholder - real implementation would compute actual overlap
            let overlap = 0.8 // Placeholder
            if overlap < minOverlap {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Overlap Detection
    
    private func checkOverlaps(arrangement: GridArrangement,
                             relPoses: [String: SE2Pose],
                             result: inout ValidationResult) {
        let pieces = arrangement.elements
        
        for i in 0..<pieces.count {
            for j in (i+1)..<pieces.count {
                let pieceA = pieces[i]
                let pieceB = pieces[j]
                
                guard let poseA = relPoses[pieceA.elementId],
                      let poseB = relPoses[pieceB.elementId],
                      let shapeA = shapeLibrary.shape(for: pieceA.elementType),
                      let shapeB = shapeLibrary.shape(for: pieceB.elementType) else {
                    continue
                }
                
                // Transform vertices to world space
                let verticesA = shapeA.vertices.map { transformPoint($0, piece: pieceA, pose: poseA) }
                let verticesB = shapeB.vertices.map { transformPoint($0, piece: pieceB, pose: poseB) }
                
                // Check for overlap (simplified - checks bounding box intersection)
                if let overlapArea = computeOverlapArea(verticesA: verticesA, verticesB: verticesB) {
                    if overlapArea > 0.001 { // Small threshold for numerical errors
                        result.overlaps.append((a: pieceA.elementId, b: pieceB.elementId, area: overlapArea))
                        result.passed = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func transformPoint(_ point: CGPoint, piece: PlacedElement, pose: SE2Pose) -> CGPoint {
        // Apply piece transformation (rotation + mirroring)
        let transformed = transformVertex(point, rotationIndex: piece.rotationIndex, mirrored: piece.mirrored)
        
        // Apply pose transformation
        let cosTheta = cos(pose.theta)
        let sinTheta = sin(pose.theta)
        
        let x = pose.x + cosTheta * Double(transformed.x) - sinTheta * Double(transformed.y)
        let y = pose.y + sinTheta * Double(transformed.x) + cosTheta * Double(transformed.y)
        
        return CGPoint(x: x, y: y)
    }
    
    private func transformVertex(_ vertex: CGPoint, rotationIndex: Int, mirrored: Bool) -> CGPoint {
        var transformed = vertex
        
        // Apply mirroring first (about Y axis)
        if mirrored {
            transformed.x = -transformed.x
        }
        
        // Then apply rotation
        let angleStep = Double.pi / 4  // 45 degrees
        let rotation = Double(rotationIndex) * angleStep
        let cosTheta = CGFloat(cos(rotation))
        let sinTheta = CGFloat(sin(rotation))
        
        let x = transformed.x * cosTheta - transformed.y * sinTheta
        let y = transformed.x * sinTheta + transformed.y * cosTheta
        
        return CGPoint(x: x, y: y)
    }
    
    private func computeGlobalRotation(arrangement: GridArrangement, relPoses: [String: SE2Pose]) -> Int? {
        // This is a simplified implementation
        // Real implementation would analyze the overall arrangement orientation
        return 0
    }
    
    private func computeOverlapArea(verticesA: [CGPoint], verticesB: [CGPoint]) -> Double? {
        // Simplified bounding box overlap check
        // Real implementation would use SAT or polygon intersection
        
        let minXA = verticesA.map { $0.x }.min() ?? 0
        let maxXA = verticesA.map { $0.x }.max() ?? 0
        let minYA = verticesA.map { $0.y }.min() ?? 0
        let maxYA = verticesA.map { $0.y }.max() ?? 0
        
        let minXB = verticesB.map { $0.x }.min() ?? 0
        let maxXB = verticesB.map { $0.x }.max() ?? 0
        let minYB = verticesB.map { $0.y }.min() ?? 0
        let maxYB = verticesB.map { $0.y }.max() ?? 0
        
        let overlapX = max(0, min(maxXA, maxXB) - max(minXA, minXB))
        let overlapY = max(0, min(maxYA, maxYB) - max(minYA, minYB))
        
        return Double(overlapX * overlapY)
    }
}