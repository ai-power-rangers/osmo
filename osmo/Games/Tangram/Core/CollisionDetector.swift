import Foundation
import simd

struct CollisionDetector {
    
    struct CollisionResult {
        let intersects: Bool
        let mtv: SIMD2<Double>? // Minimum Translation Vector
        let penetrationDepth: Double
    }
    
    static func detectCollision(between piece1: TangramPiece, and piece2: TangramPiece, in editor: ImprovedTangramEditor) -> CollisionResult {
        let vertices1 = editor.getPieceVertices(piece1)
        let vertices2 = editor.getPieceVertices(piece2)
        
        return polygonsIntersect(vertices1, vertices2)
    }
    
    static func polygonsIntersect(_ poly1: [SIMD2<Double>], _ poly2: [SIMD2<Double>]) -> CollisionResult {
        var minOverlap = Double.infinity
        var smallestAxis = SIMD2<Double>(0, 0)
        
        // Check all edges of both polygons
        let axes1 = getAxes(poly1)
        let axes2 = getAxes(poly2)
        let axes = axes1 + axes2
        
        for axis in axes {
            let projection1 = projectPolygon(poly1, onto: axis)
            let projection2 = projectPolygon(poly2, onto: axis)
            
            let overlap = min(projection1.max, projection2.max) - max(projection1.min, projection2.min)
            
            // If there's no overlap on this axis, polygons don't intersect
            if overlap < 0 {
                return CollisionResult(intersects: false, mtv: nil, penetrationDepth: 0)
            }
            
            // Track the axis with minimum overlap
            if overlap < minOverlap {
                minOverlap = overlap
                smallestAxis = axis
            }
        }
        
        // Calculate center-to-center direction
        let center1 = polygonCenter(poly1)
        let center2 = polygonCenter(poly2)
        let direction = center1 - center2
        
        // Ensure MTV points away from poly2
        if simd_dot(smallestAxis, direction) < 0 {
            smallestAxis = -smallestAxis
        }
        
        let mtv = smallestAxis * minOverlap
        
        return CollisionResult(
            intersects: true,
            mtv: mtv,
            penetrationDepth: minOverlap
        )
    }
    
    private static func getAxes(_ polygon: [SIMD2<Double>]) -> [SIMD2<Double>] {
        var axes: [SIMD2<Double>] = []
        
        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]
            
            // Get edge vector
            let edge = p2 - p1
            
            // Get perpendicular (normal) vector
            let normal = simd_normalize(SIMD2<Double>(-edge.y, edge.x))
            
            // Check if this axis is unique (avoid duplicates from parallel edges)
            if !axes.contains(where: { abs(simd_dot($0, normal)) > 0.999 }) {
                axes.append(normal)
            }
        }
        
        return axes
    }
    
    private static func projectPolygon(_ polygon: [SIMD2<Double>], onto axis: SIMD2<Double>) -> (min: Double, max: Double) {
        var min = Double.infinity
        var max = -Double.infinity
        
        for vertex in polygon {
            let projection = simd_dot(vertex, axis)
            min = Swift.min(min, projection)
            max = Swift.max(max, projection)
        }
        
        return (min, max)
    }
    
    private static func polygonCenter(_ polygon: [SIMD2<Double>]) -> SIMD2<Double> {
        let sum = polygon.reduce(SIMD2<Double>(0, 0), +)
        return sum / Double(polygon.count)
    }
    
    // Check if a point is inside a polygon (for vertex connections)
    static func pointInPolygon(_ point: SIMD2<Double>, polygon: [SIMD2<Double>]) -> Bool {
        var inside = false
        let p1 = polygon.last!
        
        for p2 in polygon {
            if ((p2.y > point.y) != (p1.y > point.y)) &&
               (point.x < (p1.x - p2.x) * (point.y - p2.y) / (p1.y - p2.y) + p2.x) {
                inside = !inside
            }
        }
        
        return inside
    }
    
    // Find all pieces that would be affected by pushing a piece
    static func findAffectedPieces(
        movingPiece: TangramPiece,
        direction: SIMD2<Double>,
        allPieces: [TangramPiece],
        editor: ImprovedTangramEditor
    ) -> [TangramPiece] {
        var affectedIds: Set<String> = []
        var toCheck: [TangramPiece] = [movingPiece]
        
        while !toCheck.isEmpty {
            let currentPiece = toCheck.removeFirst()
            
            for piece in allPieces {
                guard piece.id != currentPiece.id && !affectedIds.contains(piece.id) else { continue }
                
                let collision = detectCollision(between: currentPiece, and: piece, in: editor)
                if collision.intersects {
                    affectedIds.insert(piece.id)
                    toCheck.append(piece)
                }
            }
        }
        
        return allPieces.filter { affectedIds.contains($0.id) }
    }
}