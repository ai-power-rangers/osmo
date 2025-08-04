import CoreGraphics
import SpriteKit

/// Validates piece placement against puzzle targets
class PlacementValidator {
    let puzzle: Puzzle
    let screenUnit: CGFloat
    
    enum PlacementError {
        case tooFar
        case wrongPiece
        case needsRotation
    }
    
    init(puzzle: Puzzle, screenUnit: CGFloat) {
        self.puzzle = puzzle
        self.screenUnit = screenUnit
    }
    
    func validatePlacement(piece: TangramPiece, at position: CGPoint, rotation: CGFloat) -> (Bool, PlacementError?) {
        guard let targetPiece = puzzle.pieces.first(where: { $0.pieceId == piece.shape.rawValue }) else {
            return (false, .wrongPiece)
        }
        
        // Simple unit conversion
        let unitPos = CGPoint(
            x: position.x / screenUnit,
            y: position.y / screenUnit
        )
        let targetPos = CGPoint(
            x: CGFloat(targetPiece.targetPosition.x),
            y: CGFloat(targetPiece.targetPosition.y)
        )
        
        // Check distance
        let distance = hypot(unitPos.x - targetPos.x, unitPos.y - targetPos.y)
        let tolerance = TangramGridConstants.snapTolerance(for: screenUnit)
        
        if distance > tolerance {
            return (false, .tooFar)
        }
        
        // Check rotation (exact match after snapping)
        let targetRot = CGFloat(targetPiece.targetRotation)
        // Snap rotation to 45-degree increments
        let snappedRotation = round(rotation / (CGFloat.pi / 4)) * (CGFloat.pi / 4)
        
        // Allow for full rotation (handle 2π wrap-around)
        let rotationDiff = abs(snappedRotation - targetRot)
        let normalizedDiff = min(rotationDiff, 2 * .pi - rotationDiff)
        
        if normalizedDiff > 0.01 {  // Tiny epsilon for float precision
            return (false, .needsRotation)
        }
        
        // Check mirroring for parallelogram
        if piece.shape == .parallelogram {
            let targetMirrored = targetPiece.isMirrored ?? false
            if piece.isFlipped != targetMirrored {
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
            rotation: CGFloat(piece.rotation)
        )
        return isValid
    }
}