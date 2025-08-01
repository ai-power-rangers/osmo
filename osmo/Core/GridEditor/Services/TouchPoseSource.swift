import Foundation
import SpriteKit

/// Touch-based implementation of PoseSource for editor and touch-based games
public class TouchPoseSource: PoseSource {
    private var poses: [String: SE2Pose] = [:]
    private var anchorPieceId: String?
    internal let coordinateSystem: CoordinateSystem
    
    /// Initialize with a coordinate system for unit conversion
    public init(coordinateSystem: CoordinateSystem) {
        self.coordinateSystem = coordinateSystem
    }
    
    /// Initialize with screen size (creates default coordinate system)
    public convenience init(screenSize: CGSize) {
        self.init(coordinateSystem: CoordinateSystem(screenSize: screenSize))
    }
    
    // MARK: - PoseSource Protocol
    
    public func currentPoses() -> [String: SE2Pose] {
        return poses
    }
    
    public func currentAnchorPieceId() -> String? {
        return anchorPieceId
    }
    
    // MARK: - Touch Interaction Methods
    
    /// Update pose for a piece (from touch/drag events)
    public func updatePose(for pieceId: String, position: CGPoint, rotation: Double) {
        // Convert screen position to unit space
        let unitPosition = coordinateSystem.toUnit(position)
        poses[pieceId] = SE2Pose(x: Double(unitPosition.x), y: Double(unitPosition.y), theta: rotation)
        
        // Set as anchor if it's the first piece
        if anchorPieceId == nil {
            anchorPieceId = pieceId
        }
    }
    
    /// Update pose from unit space (for loading saved arrangements)
    public func setPose(for pieceId: String, pose: SE2Pose) {
        poses[pieceId] = pose
        
        // Set as anchor if it's the first piece
        if anchorPieceId == nil {
            anchorPieceId = pieceId
        }
    }
    
    /// Remove a piece
    public func removePiece(_ pieceId: String) {
        poses.removeValue(forKey: pieceId)
        
        // Update anchor if removed
        if anchorPieceId == pieceId {
            anchorPieceId = poses.keys.first
        }
    }
    
    /// Set preferred anchor piece
    public func setAnchor(_ pieceId: String?) {
        anchorPieceId = pieceId
    }
    
    /// Clear all poses
    public func reset() {
        poses.removeAll()
        anchorPieceId = nil
    }
    
    /// Check if a piece exists
    public func hasPiece(_ pieceId: String) -> Bool {
        return poses[pieceId] != nil
    }
    
    /// Get screen position for a piece
    public func screenPosition(for pieceId: String) -> CGPoint? {
        guard let pose = poses[pieceId] else { return nil }
        return coordinateSystem.toScreen(CGPoint(x: pose.x, y: pose.y))
    }
}

/// Touch-based pose source for SpriteKit scenes
public final class SKTouchPoseSource: TouchPoseSource {
    private weak var scene: SKScene?
    private var pieceNodes: [String: SKNode] = [:]
    
    /// Initialize with a SpriteKit scene
    public init(scene: SKScene) {
        self.scene = scene
        super.init(coordinateSystem: CoordinateSystem(screenSize: scene.size))
    }
    
    /// Register a node for a piece
    public func registerNode(_ node: SKNode, for pieceId: String) {
        pieceNodes[pieceId] = node
        
        // Update pose from node position
        let unitPos = coordinateSystem.toUnit(node.position)
        setPose(for: pieceId, pose: SE2Pose(
            x: Double(unitPos.x),
            y: Double(unitPos.y),
            theta: Double(node.zRotation)
        ))
    }
    
    /// Unregister a node
    public func unregisterNode(for pieceId: String) {
        pieceNodes.removeValue(forKey: pieceId)
        removePiece(pieceId)
    }
    
    /// Update poses from current node positions
    public func updateFromNodes() {
        for (pieceId, node) in pieceNodes {
            let unitPos = coordinateSystem.toUnit(node.position)
            updatePose(
                for: pieceId,
                position: node.position,
                rotation: Double(node.zRotation)
            )
        }
    }
    
    /// Get node for a piece
    public func node(for pieceId: String) -> SKNode? {
        return pieceNodes[pieceId]
    }
}