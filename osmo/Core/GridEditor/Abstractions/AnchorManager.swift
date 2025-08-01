import Foundation

/// Protocol for managing anchor selection and relative pose computation
/// Centralizes the policy for choosing which piece acts as the reference frame
public protocol AnchorManagerProtocol: AnyObject {
    /// Compute anchor-relative poses for all pieces
    /// - Parameter worldPoses: Dictionary of pieceId to world-space poses
    /// - Returns: Tuple of (selected anchorId, dictionary of pieceId to anchor-relative poses)
    /// - Note: Returns T_anchor_i for all i, computed as (T_table_anchor)^(-1) · T_table_i
    func anchorRelativePoses(from worldPoses: [String: SE2Pose]) -> (anchorId: String, relPoses: [String: SE2Pose])
    
    /// Set a preferred anchor piece (optional)
    /// - Parameter pieceId: The piece to prefer as anchor, or nil to use default policy
    func setPreferredAnchor(_ pieceId: String?)
}

/// Default implementation of AnchorManager
/// Touch mode: Uses first placed or user-selected piece as anchor
/// CV mode (future): Will prefer longest-stable, highest-confidence piece
public final class DefaultAnchorManager: AnchorManagerProtocol {
    private var preferredAnchorId: String?
    private var firstPlacedId: String?
    private let hysteresisThreshold: TimeInterval = 0.5
    
    public init() {}
    
    public func setPreferredAnchor(_ pieceId: String?) {
        self.preferredAnchorId = pieceId
    }
    
    public func anchorRelativePoses(from worldPoses: [String: SE2Pose]) -> (anchorId: String, relPoses: [String: SE2Pose]) {
        guard !worldPoses.isEmpty else {
            return ("", [:])
        }
        
        // Determine anchor piece
        let anchorId = selectAnchor(from: worldPoses)
        
        // Get anchor pose
        guard let anchorPose = worldPoses[anchorId] else {
            // Fallback to first available piece
            let fallbackId = worldPoses.keys.first!
            return computeRelativePoses(anchorId: fallbackId, worldPoses: worldPoses)
        }
        
        return computeRelativePoses(anchorId: anchorId, worldPoses: worldPoses)
    }
    
    private func selectAnchor(from worldPoses: [String: SE2Pose]) -> String {
        // 1. Use preferred anchor if it exists in current poses
        if let preferred = preferredAnchorId, worldPoses[preferred] != nil {
            return preferred
        }
        
        // 2. Use first placed piece if available
        if firstPlacedId == nil && !worldPoses.isEmpty {
            firstPlacedId = worldPoses.keys.first
        }
        
        if let firstPlaced = firstPlacedId, worldPoses[firstPlaced] != nil {
            return firstPlaced
        }
        
        // 3. Fallback to any available piece (alphabetically for consistency)
        return worldPoses.keys.sorted().first ?? ""
    }
    
    private func computeRelativePoses(anchorId: String, worldPoses: [String: SE2Pose]) -> (String, [String: SE2Pose]) {
        guard let anchorPose = worldPoses[anchorId] else {
            return (anchorId, [:])
        }
        
        var relativePoses: [String: SE2Pose] = [:]
        
        // Compute T_anchor_i = (T_world_anchor)^(-1) · T_world_i for each piece
        for (pieceId, worldPose) in worldPoses {
            relativePoses[pieceId] = anchorPose.relativeTo(worldPose)
        }
        
        return (anchorId, relativePoses)
    }
    
    /// Reset the manager state (useful when starting a new arrangement)
    public func reset() {
        preferredAnchorId = nil
        firstPlacedId = nil
    }
}