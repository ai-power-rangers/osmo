//
//  CVInputProcessor.swift
//  osmo
//
//  Processes computer vision input into game actions (future implementation)
//

import Foundation
import CoreGraphics

/// Processes computer vision input into game actions
/// This will replace TouchInputProcessor when CV mode is active
public final class CVInputProcessor: GameInputProcessor {
    
    // MARK: - Properties
    
    private var lastDetectedPieces: [String: CGPoint] = [:]
    private var selectedPieceId: String?
    private let confidenceThreshold: Float = 0.7
    
    // MARK: - Initialization
    
    public init() {
        // CV processor doesn't need scene reference
        // It works with normalized coordinates from CV service
    }
    
    // MARK: - GameInputProcessor Implementation
    
    public func processInput(at point: CGPoint, source: InputSource) -> GameAction? {
        guard source == .cv else { return nil }
        
        // CV input is already normalized (0...1 range)
        // Find closest detected piece to the point
        if let pieceId = findClosestPiece(to: point) {
            selectedPieceId = pieceId
            return .selectPiece(id: pieceId)
        }
        
        return nil
    }
    
    public func validateInput(_ input: GameInput) -> Bool {
        // Check if input source is CV
        guard input.source == .cv else { return false }
        
        // Check confidence level if provided in metadata
        if let confidence = input.metadata?["confidence"] as? Float {
            guard confidence >= confidenceThreshold else { return false }
        }
        
        // Check if coordinates are normalized (0...1 range)
        guard input.point.x >= 0 && input.point.x <= 1 &&
              input.point.y >= 0 && input.point.y <= 1 else {
            return false
        }
        
        return true
    }
    
    public func processGesture(_ gesture: GameGesture, source: InputSource) -> GameAction? {
        guard source == .cv else { return nil }
        
        // CV gestures are different from touch gestures
        // They're based on hand poses or object movements
        switch gesture {
        case .tap(let location):
            // CV "tap" might be a quick hand movement
            return processCVTap(at: location)
            
        case .pan(let translation, let location):
            // CV pan is tracking object movement
            return processCVMovement(translation: translation, at: location)
            
        case .rotate(let angle, _):
            // CV rotation detected from object orientation
            return processCVRotation(angle: angle)
            
        default:
            // Other gestures not supported in CV mode yet
            return nil
        }
    }
    
    // MARK: - CV Event Processing
    
    /// Process a CV event into a game action
    public func processCVEvent(_ event: CVGameEvent) -> GameAction? {
        switch event.type {
        case .pieceDetected(let id):
            // New piece detected
            lastDetectedPieces[id] = event.position
            return nil // No action, just tracking
            
        case .pieceMoved(let id, _, let to):
            // Piece movement detected
            lastDetectedPieces[id] = to
            return .movePiece(id: id, to: to)
            
        case .pieceRemoved(let id):
            // Piece no longer visible
            lastDetectedPieces.removeValue(forKey: id)
            if id == selectedPieceId {
                selectedPieceId = nil
            }
            return .releasePiece(id: id)
            
        case .gestureRecognized(let type):
            // Handle CV-specific gestures
            return processCVGesture(type: type)
        }
    }
    
    /// Process physical state changes
    public func processPhysicalState(_ state: PhysicalState) -> [GameAction] {
        var actions: [GameAction] = []
        
        // Compare with last known state
        for (pieceId, newPosition) in state.detectedPieces {
            if let lastPosition = lastDetectedPieces[pieceId] {
                // Check if piece moved significantly
                let distance = hypot(newPosition.x - lastPosition.x, 
                                   newPosition.y - lastPosition.y)
                if distance > 0.05 { // 5% of normalized space
                    actions.append(.movePiece(id: pieceId, to: newPosition))
                }
            } else {
                // New piece detected
                actions.append(.selectPiece(id: pieceId))
            }
        }
        
        // Check for removed pieces
        for (pieceId, _) in lastDetectedPieces {
            if state.detectedPieces[pieceId] == nil {
                actions.append(.releasePiece(id: pieceId))
            }
        }
        
        // Update tracked state
        lastDetectedPieces = state.detectedPieces
        
        return actions
    }
    
    // MARK: - Private Methods
    
    private func processCVTap(at location: CGPoint) -> GameAction? {
        if let pieceId = findClosestPiece(to: location) {
            if pieceId == selectedPieceId {
                // Deselect
                selectedPieceId = nil
                return .releasePiece(id: pieceId)
            } else {
                // Select new piece
                selectedPieceId = pieceId
                return .selectPiece(id: pieceId)
            }
        }
        return nil
    }
    
    private func processCVMovement(translation: CGPoint, at location: CGPoint) -> GameAction? {
        guard let pieceId = selectedPieceId else { return nil }
        
        // Update piece position based on CV tracking
        let newPosition = CGPoint(
            x: location.x + translation.x,
            y: location.y + translation.y
        )
        
        // Clamp to normalized bounds
        let clampedPosition = CGPoint(
            x: max(0, min(1, newPosition.x)),
            y: max(0, min(1, newPosition.y))
        )
        
        return .movePiece(id: pieceId, to: clampedPosition)
    }
    
    private func processCVRotation(angle: Float) -> GameAction? {
        guard let pieceId = selectedPieceId else { return nil }
        return .rotatePiece(id: pieceId, angle: angle)
    }
    
    private func processCVGesture(type: String) -> GameAction? {
        switch type {
        case "thumbs_up":
            return .hint
        case "peace_sign":
            return .undo
        case "ok_sign":
            return .redo
        case "fist":
            return .reset
        default:
            return nil
        }
    }
    
    private func findClosestPiece(to point: CGPoint) -> String? {
        var closestPiece: String?
        var minDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        for (pieceId, piecePosition) in lastDetectedPieces {
            let distance = hypot(point.x - piecePosition.x, point.y - piecePosition.y)
            if distance < minDistance && distance < 0.1 { // Within 10% of normalized space
                minDistance = distance
                closestPiece = pieceId
            }
        }
        
        return closestPiece
    }
    
    // MARK: - Confidence Management
    
    /// Update confidence threshold for validation
    public func setConfidenceThreshold(_ threshold: Float) {
        guard threshold >= 0 && threshold <= 1 else { return }
        self.confidenceThreshold = threshold
    }
    
    /// Get current tracking confidence
    public func getCurrentConfidence() -> Float {
        // This would be calculated based on CV service feedback
        // For now, return a placeholder
        return 0.95
    }
}