import CoreGraphics
import SpriteKit

/// Validates piece placement against puzzle targets
class PlacementValidator {
    let puzzle: Puzzle
    let coordinateSystem: CoordinateSystem
    let screenUnit: CGFloat
    
    enum PlacementError {
        case tooFar
        case wrongPiece
        case needsRotation
    }
    
    init(puzzle: Puzzle, coordinateSystem: CoordinateSystem, screenUnit: CGFloat) {
        self.puzzle = puzzle
        self.coordinateSystem = coordinateSystem
        self.screenUnit = screenUnit
    }
    
    func validatePlacement(piece: TangramPiece, at position: CGPoint, rotation: CGFloat) -> (Bool, PlacementError?) {
        guard let targetPiece = puzzle.pieces.first(where: { $0.pieceId == piece.pieceId }) else {
            return (false, .wrongPiece)
        }
        
        // Convert screen position to unit coordinates
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
        
        // Allow for full rotation (handle 2π wrap-around)
        let rotationDiff = abs(snappedRotation - targetRot)
        let normalizedDiff = min(rotationDiff, 2 * .pi - rotationDiff)
        
        if normalizedDiff > 0.01 {  // Tiny epsilon for float precision
            return (false, .needsRotation)
        }
        
        // Check mirroring for parallelogram
        if piece.pieceId == "parallelogram" {
            let targetMirrored = targetPiece.isMirrored ?? false
            if piece.isMirrored != targetMirrored {
                return (false, .needsRotation)  // Treat wrong mirror as rotation issue
            }
        }
        
        return (true, nil)
    }
    
    func getTargetDefinition(for pieceId: String) -> PieceDefinition? {
        return puzzle.pieces.first(where: { $0.pieceId == pieceId })
    }
    
    /// Check if a specific piece can be placed at its target
    func checkPlacement(piece: TangramPiece) -> Bool {
        let (isValid, _) = validatePlacement(
            piece: piece,
            at: piece.position,
            rotation: piece.zRotation
        )
        return isValid
    }
}