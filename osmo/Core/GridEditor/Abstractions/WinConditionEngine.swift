import Foundation

/// Central engine for evaluating win conditions
/// Orchestrates PoseSource → AnchorManager → ConstraintValidator flow
public final class WinConditionEngine {
    private let poseSource: PoseSource
    private let anchorManager: AnchorManagerProtocol
    private let validator: ConstraintValidatorProtocol
    private let arrangement: GridArrangement
    
    public init(poseSource: PoseSource,
                anchorManager: AnchorManagerProtocol,
                validator: ConstraintValidatorProtocol,
                arrangement: GridArrangement) {
        self.poseSource = poseSource
        self.anchorManager = anchorManager
        self.validator = validator
        self.arrangement = arrangement
    }
    
    /// Evaluate current state against win conditions
    /// - Returns: ValidationResult indicating if puzzle is solved
    public func evaluate() -> ValidationResult {
        // 1. Get current world poses from source
        let worldPoses = poseSource.currentPoses()
        
        // 2. Compute anchor-relative poses
        let (anchorId, relPoses) = anchorManager.anchorRelativePoses(from: worldPoses)
        
        // 3. Validate against constraints
        var result = validator.validate(arrangement: arrangement, relPoses: relPoses)
        
        // 4. Add anchor info to result
        result.anchorId = anchorId
        
        return result
    }
    
    /// Update the arrangement (e.g., when loading a new puzzle)
    public func updateArrangement(_ newArrangement: GridArrangement) -> WinConditionEngine {
        return WinConditionEngine(
            poseSource: poseSource,
            anchorManager: anchorManager,
            validator: validator,
            arrangement: newArrangement
        )
    }
}