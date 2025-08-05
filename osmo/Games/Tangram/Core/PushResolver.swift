import Foundation
import SwiftUI
import simd

struct PushResolver {
    
    struct PushResult {
        let pushedPieces: [(piece: TangramPiece, newPosition: CGPoint)]
        let success: Bool
    }
    
    static func resolvePush(
        movingPiece: TangramPiece,
        targetPosition: SIMD2<Double>,
        allPieces: [TangramPiece],
        editor: ImprovedTangramEditor,
        gridBounds: CGSize
    ) -> PushResult {
        var pushedPieces: [(piece: TangramPiece, newPosition: CGPoint)] = []
        var piecePositions: [String: CGPoint] = [:]
        
        // Initialize with current positions
        for piece in allPieces {
            piecePositions[piece.id] = piece.position
        }
        
        // Update moving piece position
        piecePositions[movingPiece.id] = CGPoint(x: targetPosition.x, y: targetPosition.y)
        
        // Iteratively resolve collisions
        var iterations = 0
        let maxIterations = 20
        var hasCollisions = true
        
        while hasCollisions && iterations < maxIterations {
            hasCollisions = false
            iterations += 1
            
            // Check all piece pairs for collisions
            for i in 0..<allPieces.count {
                for j in (i + 1)..<allPieces.count {
                    let piece1 = allPieces[i]
                    let piece2 = allPieces[j]
                    
                    // Create temporary pieces with updated positions
                    var tempPiece1 = piece1
                    var tempPiece2 = piece2
                    tempPiece1.position = piecePositions[piece1.id]!
                    tempPiece2.position = piecePositions[piece2.id]!
                    
                    let collision = CollisionDetector.detectCollision(
                        between: tempPiece1,
                        and: tempPiece2,
                        in: editor
                    )
                    
                    if collision.intersects, let mtv = collision.mtv {
                        hasCollisions = true
                        
                        // Determine which piece to push
                        let (pieceToPush, pushVector) = determinePushTarget(
                            piece1: tempPiece1,
                            piece2: tempPiece2,
                            movingPieceId: movingPiece.id,
                            mtv: mtv,
                            editor: editor
                        )
                        
                        // Apply push with boundary constraints
                        let newPosition = applyPushWithConstraints(
                            piece: pieceToPush,
                            pushVector: pushVector,
                            gridBounds: gridBounds,
                            editor: editor
                        )
                        
                        piecePositions[pieceToPush.id] = newPosition
                    }
                }
            }
        }
        
        // Collect all pieces that moved
        for piece in allPieces {
            let newPos = piecePositions[piece.id]!
            let oldPos = piece.position
            if abs(newPos.x - oldPos.x) > 0.01 || abs(newPos.y - oldPos.y) > 0.01 {
                pushedPieces.append((piece: piece, newPosition: newPos))
            }
        }
        
        // Check if all pieces are within bounds and non-overlapping
        let success = iterations < maxIterations && allPiecesValid(
            pieces: allPieces,
            positions: piecePositions,
            gridBounds: gridBounds,
            editor: editor
        )
        
        return PushResult(pushedPieces: pushedPieces, success: success)
    }
    
    private static func determinePushTarget(
        piece1: TangramPiece,
        piece2: TangramPiece,
        movingPieceId: String,
        mtv: SIMD2<Double>,
        editor: ImprovedTangramEditor
    ) -> (pieceToPush: TangramPiece, pushVector: SIMD2<Double>) {
        // Never push the piece being dragged
        if piece1.id == movingPieceId {
            return (piece2, mtv)
        } else if piece2.id == movingPieceId {
            return (piece1, -mtv)
        }
        
        // Push the smaller piece (by area)
        let area1 = calculatePieceArea(piece1.shape)
        let area2 = calculatePieceArea(piece2.shape)
        
        if area1 < area2 {
            return (piece1, -mtv)
        } else {
            return (piece2, mtv)
        }
    }
    
    private static func calculatePieceArea(_ shape: TangramPiece.Shape) -> Double {
        switch shape {
        case .largeTriangle: return 2.0
        case .mediumTriangle: return 1.0
        case .smallTriangle: return 0.5
        case .square: return 1.0
        case .parallelogram: return 1.0
        }
    }
    
    private static func applyPushWithConstraints(
        piece: TangramPiece,
        pushVector: SIMD2<Double>,
        gridBounds: CGSize,
        editor: ImprovedTangramEditor
    ) -> CGPoint {
        var newPosition = CGPoint(
            x: piece.position.x + pushVector.x,
            y: piece.position.y + pushVector.y
        )
        
        // Get piece bounds
        let vertices = editor.getPieceVertices(piece)
        let bounds = getBounds(vertices: vertices)
        
        // Constrain to grid
        let margin = 0.5
        newPosition.x = max(margin - bounds.min.x, min(8.0 - margin - bounds.max.x, newPosition.x))
        newPosition.y = max(margin - bounds.min.y, min(8.0 - margin - bounds.max.y, newPosition.y))
        
        // Snap to grid
        newPosition.x = round(newPosition.x * 4) / 4
        newPosition.y = round(newPosition.y * 4) / 4
        
        return newPosition
    }
    
    private static func getBounds(vertices: [SIMD2<Double>]) -> (min: SIMD2<Double>, max: SIMD2<Double>) {
        var minPoint = SIMD2<Double>(Double.infinity, Double.infinity)
        var maxPoint = SIMD2<Double>(-Double.infinity, -Double.infinity)
        
        for vertex in vertices {
            minPoint.x = min(minPoint.x, vertex.x)
            minPoint.y = min(minPoint.y, vertex.y)
            maxPoint.x = max(maxPoint.x, vertex.x)
            maxPoint.y = max(maxPoint.y, vertex.y)
        }
        
        return (minPoint, maxPoint)
    }
    
    private static func allPiecesValid(
        pieces: [TangramPiece],
        positions: [String: CGPoint],
        gridBounds: CGSize,
        editor: ImprovedTangramEditor
    ) -> Bool {
        // Check all pieces are within bounds
        for piece in pieces {
            var tempPiece = piece
            tempPiece.position = positions[piece.id]!
            
            let vertices = editor.getPieceVertices(tempPiece)
            for vertex in vertices {
                if vertex.x < 0 || vertex.x > 8 || vertex.y < 0 || vertex.y > 8 {
                    return false
                }
            }
        }
        
        return true
    }
    
    // Find the nearest valid position for a piece that avoids all collisions
    static func findNearestValidPosition(
        piece: TangramPiece,
        targetPosition: SIMD2<Double>,
        otherPieces: [TangramPiece],
        editor: ImprovedTangramEditor
    ) -> SIMD2<Double>? {
        let searchRadius = 2.0
        let searchStep = 0.25
        var bestPosition: SIMD2<Double>? = nil
        var minDistance = Double.infinity
        
        // Search in a spiral pattern
        for radius in stride(from: 0, through: searchRadius, by: searchStep) {
            let angleStep = searchStep / max(radius, 0.25)
            
            for angle in stride(from: 0, to: 2 * .pi, by: angleStep) {
                let offset = SIMD2<Double>(
                    cos(angle) * radius,
                    sin(angle) * radius
                )
                let testPosition = targetPosition + offset
                
                // Check if position is valid
                var tempPiece = piece
                tempPiece.position = CGPoint(x: testPosition.x, y: testPosition.y)
                
                var hasCollision = false
                for otherPiece in otherPieces {
                    if otherPiece.id == piece.id { continue }
                    
                    let collision = CollisionDetector.detectCollision(
                        between: tempPiece,
                        and: otherPiece,
                        in: editor
                    )
                    
                    if collision.intersects {
                        hasCollision = true
                        break
                    }
                }
                
                if !hasCollision {
                    let distance = simd_distance(targetPosition, testPosition)
                    if distance < minDistance {
                        minDistance = distance
                        bestPosition = testPosition
                    }
                }
            }
            
            // If we found a valid position, return it
            if bestPosition != nil {
                return bestPosition
            }
        }
        
        return nil
    }
}