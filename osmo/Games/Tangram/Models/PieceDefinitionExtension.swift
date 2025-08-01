import Foundation
import simd

extension PieceDefinition {
    /// Convenience initializer for creating piece definitions programmatically
    init(pieceId: String, targetPosition: SIMD2<Double>, targetRotation: Double, isMirrored: Bool?) {
        self.pieceId = pieceId
        self.targetPosition = targetPosition
        self.targetRotation = targetRotation
        self.isMirrored = isMirrored
    }
}