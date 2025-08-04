//
//  TouchInputProcessor.swift
//  osmo
//
//  Processes touch input into game actions
//

import Foundation
import SpriteKit
import CoreGraphics

/// Processes touch input into game actions
/// This abstraction allows for easy swapping with CVInputProcessor in the future
public final class TouchInputProcessor: GameInputProcessor {
    
    // MARK: - Properties
    
    private weak var scene: SKScene?
    private var selectedPieceId: String?
    private var lastTouchPoint: CGPoint = .zero
    private var touchStartTime: TimeInterval = 0
    
    // MARK: - Configuration
    
    private let tapThreshold: TimeInterval = 0.3  // Max time for tap
    private let moveThreshold: CGFloat = 10.0     // Min distance for move
    
    // MARK: - Initialization
    
    public init(scene: SKScene) {
        self.scene = scene
    }
    
    // MARK: - GameInputProcessor Implementation
    
    public func processInput(at point: CGPoint, source: InputSource) -> GameAction? {
        guard source == .touch else { return nil }
        
        // Find what's at this point
        if let piece = findPiece(at: point) {
            selectedPieceId = piece
            return .selectPiece(id: piece)
        }
        
        return nil
    }
    
    public func validateInput(_ input: GameInput) -> Bool {
        guard let scene = scene else { return false }
        
        // Check if point is within scene bounds
        let sceneBounds = scene.frame
        guard sceneBounds.contains(input.point) else { return false }
        
        // Check if input source is supported
        guard input.source == .touch || input.source == .keyboard else { return false }
        
        return true
    }
    
    public func processGesture(_ gesture: GameGesture, source: InputSource) -> GameAction? {
        switch gesture {
        case .tap(let location):
            return processTap(at: location)
            
        case .doubleTap(let location):
            return processDoubleTap(at: location)
            
        case .longPress(let location):
            return processLongPress(at: location)
            
        case .swipe(let direction, _):
            return processSwipe(direction: direction)
            
        case .pan(let translation, let location):
            return processPan(translation: translation, at: location)
            
        case .pinch(let scale, _):
            return processPinch(scale: scale)
            
        case .rotate(let angle, _):
            return processRotate(angle: angle)
        }
    }
    
    // MARK: - Touch Processing
    
    public func touchBegan(at point: CGPoint) -> GameAction? {
        lastTouchPoint = point
        touchStartTime = Date().timeIntervalSince1970
        
        if let piece = findPiece(at: point) {
            selectedPieceId = piece
            return .selectPiece(id: piece)
        }
        
        return nil
    }
    
    public func touchMoved(to point: CGPoint) -> GameAction? {
        guard let pieceId = selectedPieceId else { return nil }
        
        let distance = hypot(point.x - lastTouchPoint.x, point.y - lastTouchPoint.y)
        guard distance > moveThreshold else { return nil }
        
        lastTouchPoint = point
        return .movePiece(id: pieceId, to: point)
    }
    
    public func touchEnded(at point: CGPoint) -> GameAction? {
        defer {
            selectedPieceId = nil
            lastTouchPoint = .zero
        }
        
        guard let pieceId = selectedPieceId else { return nil }
        
        let touchDuration = Date().timeIntervalSince1970 - touchStartTime
        let distance = hypot(point.x - lastTouchPoint.x, point.y - lastTouchPoint.y)
        
        // If it was a quick touch without much movement, treat as tap
        if touchDuration < tapThreshold && distance < moveThreshold {
            return processTap(at: point)
        }
        
        // Otherwise, it's a release after drag
        return .releasePiece(id: pieceId)
    }
    
    // MARK: - Gesture Processing
    
    private func processTap(at location: CGPoint) -> GameAction? {
        if let piece = findPiece(at: location) {
            // If tapping on already selected piece, deselect
            if piece == selectedPieceId {
                selectedPieceId = nil
                return .releasePiece(id: piece)
            } else {
                selectedPieceId = piece
                return .selectPiece(id: piece)
            }
        }
        return nil
    }
    
    private func processDoubleTap(at location: CGPoint) -> GameAction? {
        if let piece = findPiece(at: location) {
            // Double tap to rotate
            return .rotatePiece(id: piece, angle: Float.pi / 4) // 45 degrees
        }
        return nil
    }
    
    private func processLongPress(at location: CGPoint) -> GameAction? {
        // Long press for hint
        return .hint
    }
    
    private func processSwipe(direction: SwipeDirection) -> GameAction? {
        switch direction {
        case .left:
            return .undo
        case .right:
            return .redo
        case .up, .down:
            return nil
        }
    }
    
    private func processPan(translation: CGPoint, at location: CGPoint) -> GameAction? {
        guard let pieceId = selectedPieceId else { return nil }
        return .movePiece(id: pieceId, to: location)
    }
    
    private func processPinch(scale: Float) -> GameAction? {
        // Could be used for zoom in future
        return nil
    }
    
    private func processRotate(angle: Float) -> GameAction? {
        guard let pieceId = selectedPieceId else { return nil }
        return .rotatePiece(id: pieceId, angle: angle)
    }
    
    // MARK: - Helper Methods
    
    private func findPiece(at point: CGPoint) -> String? {
        guard let scene = scene else { return nil }
        
        // Find nodes at point
        let nodes = scene.nodes(at: point)
        
        // Look for a node with a name (piece ID)
        for node in nodes {
            if let name = node.name, !name.isEmpty {
                // Check if it's a game piece (you might want more specific logic here)
                if node.parent?.name == "piecesContainer" || node.name?.contains("piece") == true {
                    return name
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Coordinate Normalization
    
    /// Normalize coordinates to 0...1 range for CV compatibility
    public func normalizeCoordinates(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        return CGPoint(
            x: (point.x - bounds.minX) / bounds.width,
            y: (point.y - bounds.minY) / bounds.height
        )
    }
    
    /// Denormalize coordinates from 0...1 range back to scene coordinates
    public func denormalizeCoordinates(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        return CGPoint(
            x: bounds.minX + (point.x * bounds.width),
            y: bounds.minY + (point.y * bounds.height)
        )
    }
}