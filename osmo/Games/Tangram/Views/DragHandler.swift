import SpriteKit
import CoreGraphics

/// Handles drag and drop logic for Tangram pieces
class DragHandler {
    var isDragging = false
    var selectedPiece: TangramPiece?
    var dragOffset: CGPoint = .zero
    
    // Callbacks for game integration
    var onPieceSnapped: ((String) -> Void)?  // pieceId
    var onPieceMissed: ((String, PlacementValidator.PlacementError) -> Void)?
    
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
        let screenPos = piece.position
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
        let targetScreenPos = validator.coordinateSystem.toScreen(targetDef.targetPosition)
        
        // Convert to parent coordinates if piece is in a container
        let targetPos = piece.parent?.convert(targetScreenPos, from: piece.scene!) ?? targetScreenPos
        
        // Snap animation
        piece.isLocked = true
        piece.run(SKAction.group([
            SKAction.move(to: targetPos, duration: 0.15),
            SKAction.rotate(toAngle: CGFloat(targetDef.targetRotation), duration: 0.15),
            SKAction.scale(to: validator.coordinateSystem.screenUnit / (validator.coordinateSystem.screenUnit * 0.5), duration: 0.15) // Scale to full size
        ]))
        
        // Callback
        onPieceSnapped?(piece.pieceId)
    }
    
    private func handleFailedPlacement(piece: TangramPiece, error: PlacementValidator.PlacementError?) {
        // Return to original position
        let returnAction = SKAction.move(to: piece.originalPosition, duration: 0.2)
        piece.run(returnAction)
        
        // Callback with error type
        if let error = error {
            onPieceMissed?(piece.pieceId, error)
        }
    }
}