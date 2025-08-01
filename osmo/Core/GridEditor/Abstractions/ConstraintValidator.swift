import Foundation

/// Result of constraint validation
public struct ValidationResult {
    public var passed: Bool
    public var violatedConstraints: [String]   // IDs of violated RelationConstraints
    public var overlaps: [(a: String, b: String, area: Double)]  // Piece pairs with overlap
    public var nearMissHints: [String: String] // Optional hints for the user
    public var globalRotationIndex: Int?       // For analytics/debug
    public var anchorId: String?               // For analytics/debug
    
    public init(passed: Bool = false,
                violatedConstraints: [String] = [],
                overlaps: [(a: String, b: String, area: Double)] = [],
                nearMissHints: [String: String] = [:],
                globalRotationIndex: Int? = nil,
                anchorId: String? = nil) {
        self.passed = passed
        self.violatedConstraints = violatedConstraints
        self.overlaps = overlaps
        self.nearMissHints = nearMissHints
        self.globalRotationIndex = globalRotationIndex
        self.anchorId = anchorId
    }
}

/// Protocol for validating arrangements against constraints
/// This is the central win detection engine used by both editor preview and game runtime
public protocol ConstraintValidatorProtocol: AnyObject {
    /// Validate an arrangement against its constraints
    /// - Parameters:
    ///   - arrangement: The arrangement containing pieces and constraints
    ///   - relPoses: Anchor-relative poses for all pieces
    /// - Returns: Validation result with details about violations
    func validate(arrangement: GridArrangement, relPoses: [String: SE2Pose]) -> ValidationResult
}

/// Composite validator that runs multiple validators
public final class CompositeConstraintValidator: ConstraintValidatorProtocol {
    private var validators: [ConstraintValidatorProtocol] = []
    
    public init(validators: [ConstraintValidatorProtocol] = []) {
        self.validators = validators
    }
    
    public func register(_ validator: ConstraintValidatorProtocol) {
        validators.append(validator)
    }
    
    public func validate(arrangement: GridArrangement, relPoses: [String: SE2Pose]) -> ValidationResult {
        var combinedResult = ValidationResult(passed: true)
        
        // Run all validators and combine results
        for validator in validators {
            let result = validator.validate(arrangement: arrangement, relPoses: relPoses)
            
            // Combine violations
            combinedResult.violatedConstraints.append(contentsOf: result.violatedConstraints)
            combinedResult.overlaps.append(contentsOf: result.overlaps)
            
            // Merge hints
            for (key, value) in result.nearMissHints {
                combinedResult.nearMissHints[key] = value
            }
            
            // Use first non-nil values for debug info
            if combinedResult.globalRotationIndex == nil {
                combinedResult.globalRotationIndex = result.globalRotationIndex
            }
            if combinedResult.anchorId == nil {
                combinedResult.anchorId = result.anchorId
            }
            
            // Overall pass requires all validators to pass
            if !result.passed {
                combinedResult.passed = false
            }
        }
        
        return combinedResult
    }
}