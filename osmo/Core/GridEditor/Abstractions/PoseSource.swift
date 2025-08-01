import Foundation
import CoreGraphics

/// Represents a 2D pose (position + rotation) in SE(2) space
/// x, y in Tangram unit space; theta in radians (counterclockwise)
public struct SE2Pose: Codable, Equatable {
    public var x: Double
    public var y: Double
    public var theta: Double
    
    public init(x: Double, y: Double, theta: Double) {
        self.x = x
        self.y = y
        self.theta = theta
    }
    
    /// Convert from CGPoint with zero rotation
    public init(point: CGPoint, theta: Double = 0) {
        self.x = Double(point.x)
        self.y = Double(point.y)
        self.theta = theta
    }
    
    /// Convert to CGPoint (ignoring rotation)
    public var point: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    /// Apply transformation to another pose
    public func transform(_ other: SE2Pose) -> SE2Pose {
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)
        
        let newX = x + cosTheta * other.x - sinTheta * other.y
        let newY = y + sinTheta * other.x + cosTheta * other.y
        let newTheta = theta + other.theta
        
        return SE2Pose(x: newX, y: newY, theta: newTheta)
    }
    
    /// Compute inverse transformation
    public var inverse: SE2Pose {
        let cosTheta = cos(-theta)
        let sinTheta = sin(-theta)
        
        let invX = -(cosTheta * x - sinTheta * y)
        let invY = -(sinTheta * x + cosTheta * y)
        
        return SE2Pose(x: invX, y: invY, theta: -theta)
    }
    
    /// Compute relative pose: self^(-1) * other
    public func relativeTo(_ other: SE2Pose) -> SE2Pose {
        return self.inverse.transform(other)
    }
}

/// Protocol for reading piece positions from various sources
/// This abstraction allows the same validation logic to work with both
/// touch-based editing and future CV-based detection
public protocol PoseSource: AnyObject {
    /// Get current poses of all pieces in world/table space
    /// - Returns: Dictionary mapping pieceId to pose
    func currentPoses() -> [String: SE2Pose]
    
    /// Get the ID of the current anchor piece (if any)
    /// - Returns: Optional pieceId that should be used as anchor
    func currentAnchorPieceId() -> String?
}