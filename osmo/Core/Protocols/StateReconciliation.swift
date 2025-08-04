//
//  StateReconciliation.swift
//  osmo
//
//  Foundation for state reconciliation between digital and physical game states
//

import Foundation
import CoreGraphics

/// Protocol for state reconciliation and memento pattern
/// Used for undo/redo now, will extend for physical/digital sync with CV
public protocol StateReconciliation {
    associatedtype StateType: Codable
    
    // MARK: - Current: Undo/Redo Support
    
    /// Capture the current state as a memento
    func captureState() -> GameStateMemento<StateType>
    
    /// Restore a previous state from a memento
    func restoreState(_ memento: GameStateMemento<StateType>)
    
    /// Validate if a state is valid
    func validateState(_ state: StateType) -> StateValidation
    
    // MARK: - Future: Physical/Digital Sync
    
    /// Reconcile digital state with detected physical state
    func reconcileWithPhysicalState(_ detected: PhysicalGameState) -> StateType
    
    /// Resolve conflicts between digital and physical states
    func resolveConflicts(_ digital: StateType, _ physical: PhysicalGameState) -> ConflictResolution<StateType>
    
    /// Calculate difference between two states
    func calculateStateDiff(_ from: StateType, _ to: StateType) -> StateDiff
}

/// Memento pattern for saving game state
public struct GameStateMemento<T: Codable>: Codable {
    public let state: T
    public let timestamp: Date
    public let source: InputSource
    public let checksum: String
    public let metadata: [String: String]?
    
    public init(state: T, 
                source: InputSource,
                metadata: [String: String]? = nil) {
        self.state = state
        self.timestamp = Date()
        self.source = source
        self.checksum = Self.calculateChecksum(for: state)
        self.metadata = metadata
    }
    
    /// Verify the memento hasn't been corrupted
    public func isValid() -> Bool {
        return checksum == Self.calculateChecksum(for: state)
    }
    
    private static func calculateChecksum<S: Codable>(for state: S) -> String {
        // Simple checksum using hash
        // In production, might use CRC32 or similar
        if let data = try? JSONEncoder().encode(state) {
            return "\(data.hashValue)"
        }
        return "invalid"
    }
}

/// Physical game state detected by CV
public struct PhysicalGameState {
    public let detectedPieces: [PhysicalPiece]
    public let confidence: Float
    public let timestamp: Date
    public let frameId: Int?
    
    public init(detectedPieces: [PhysicalPiece],
                confidence: Float,
                timestamp: Date = Date(),
                frameId: Int? = nil) {
        self.detectedPieces = detectedPieces
        self.confidence = confidence
        self.timestamp = timestamp
        self.frameId = frameId
    }
}

/// A physical game piece detected by CV
public struct PhysicalPiece: Codable {
    public let id: String
    public let type: String
    public let position: CGPoint
    public let rotation: CGFloat
    public let confidence: Float
    public let color: String?
    public let size: CGSize?
    
    public init(id: String,
                type: String,
                position: CGPoint,
                rotation: CGFloat = 0,
                confidence: Float = 1.0,
                color: String? = nil,
                size: CGSize? = nil) {
        self.id = id
        self.type = type
        self.position = position
        self.rotation = rotation
        self.confidence = confidence
        self.color = color
        self.size = size
    }
}

/// Result of state validation
public struct StateValidation {
    public let isValid: Bool
    public let errors: [StateValidationError]
    public let warnings: [ValidationWarning]
    
    public init(isValid: Bool = true,
                errors: [StateValidationError] = [],
                warnings: [ValidationWarning] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    public static var valid: StateValidation {
        StateValidation(isValid: true)
    }
}

/// State validation error
public struct StateValidationError {
    public let code: String
    public let message: String
    public let context: [String: Any]?
    
    public init(code: String, message: String, context: [String: Any]? = nil) {
        self.code = code
        self.message = message
        self.context = context
    }
}

/// Validation warning (non-fatal)
public struct ValidationWarning {
    public let code: String
    public let message: String
    
    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// Result of conflict resolution between digital and physical states
public struct ConflictResolution<T> {
    public let resolvedState: T
    public let strategy: ResolutionStrategy
    public let conflicts: [StateConflict]
    public let confidence: Float
    
    public init(resolvedState: T,
                strategy: ResolutionStrategy,
                conflicts: [StateConflict] = [],
                confidence: Float = 1.0) {
        self.resolvedState = resolvedState
        self.strategy = strategy
        self.conflicts = conflicts
        self.confidence = confidence
    }
}

/// Strategy used to resolve conflicts
public enum ResolutionStrategy {
    case trustDigital       // Keep digital state
    case trustPhysical      // Use physical state
    case merge              // Merge both states
    case userIntervention   // Ask user to resolve
    case automatic(String)  // Custom automatic resolution
}

/// A conflict between digital and physical states
public struct StateConflict {
    public let pieceId: String
    public let conflictType: ConflictType
    public let digitalValue: Any
    public let physicalValue: Any
    public let resolution: Any?
    
    public init(pieceId: String,
                conflictType: ConflictType,
                digitalValue: Any,
                physicalValue: Any,
                resolution: Any? = nil) {
        self.pieceId = pieceId
        self.conflictType = conflictType
        self.digitalValue = digitalValue
        self.physicalValue = physicalValue
        self.resolution = resolution
    }
}

/// Type of conflict between states
public enum ConflictType {
    case position           // Piece at different position
    case rotation           // Piece at different angle
    case existence          // Piece exists in one but not other
    case type              // Different piece type
    case custom(String)     // Game-specific conflict
}

/// Difference between two states
public struct StateDiff {
    public let additions: [String]      // IDs of added pieces
    public let removals: [String]       // IDs of removed pieces
    public let modifications: [String]  // IDs of modified pieces
    public let unchanged: [String]      // IDs of unchanged pieces
    
    public init(additions: [String] = [],
                removals: [String] = [],
                modifications: [String] = [],
                unchanged: [String] = []) {
        self.additions = additions
        self.removals = removals
        self.modifications = modifications
        self.unchanged = unchanged
    }
    
    public var hasChanges: Bool {
        return !additions.isEmpty || !removals.isEmpty || !modifications.isEmpty
    }
    
    public var changeCount: Int {
        return additions.count + removals.count + modifications.count
    }
}

// MARK: - Default Implementations

public extension StateReconciliation {
    
    /// Default reconciliation: trust digital state
    func reconcileWithPhysicalState(_ detected: PhysicalGameState) -> StateType {
        // Default: return current digital state
        // Override in concrete implementations
        return captureState().state
    }
    
    /// Default conflict resolution: trust digital
    func resolveConflicts(_ digital: StateType, _ physical: PhysicalGameState) -> ConflictResolution<StateType> {
        return ConflictResolution(
            resolvedState: digital,
            strategy: .trustDigital,
            confidence: 1.0
        )
    }
    
    /// Default validation: always valid
    func validateState(_ state: StateType) -> StateValidation {
        return .valid
    }
}