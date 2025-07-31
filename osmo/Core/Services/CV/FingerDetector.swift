//
//  FingerDetector.swift
//  osmo
//
//  Created by Phase 3 Implementation
//

import Foundation
import CoreGraphics

// MARK: - Finger Detector
final class FingerDetector {
    
    // Thresholds for finger detection
    private let extendedThreshold: Float = 0.8  // How straight the finger needs to be
    private let confidenceThreshold: Float = 0.7
    
    func detectRaisedFingers(from hand: HandObservation) -> FingerDetectionResult {
        var raisedFingers: [Finger] = []
        
        // Check each finger
        if isFingerExtended(
            tip: hand.landmarks.thumbTip,
            dip: hand.landmarks.thumbIP,
            pip: hand.landmarks.thumbMP,
            mcp: hand.landmarks.thumbCMC,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.thumb)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.indexTip,
            dip: hand.landmarks.indexDIP,
            pip: hand.landmarks.indexPIP,
            mcp: hand.landmarks.indexMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.index)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.middleTip,
            dip: hand.landmarks.middleDIP,
            pip: hand.landmarks.middlePIP,
            mcp: hand.landmarks.middleMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.middle)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.ringTip,
            dip: hand.landmarks.ringDIP,
            pip: hand.landmarks.ringPIP,
            mcp: hand.landmarks.ringMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.ring)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.littleTip,
            dip: hand.landmarks.littleDIP,
            pip: hand.landmarks.littlePIP,
            mcp: hand.landmarks.littleMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.little)
        }
        
        return FingerDetectionResult(
            count: raisedFingers.count,
            confidence: hand.confidence,
            raisedFingers: raisedFingers,
            handChirality: hand.chirality
        )
    }
    
    private func isFingerExtended(tip: CGPoint,
                                 dip: CGPoint,
                                 pip: CGPoint,
                                 mcp: CGPoint,
                                 wrist: CGPoint) -> Bool {
        // Calculate distances
        let tipToWrist = distance(from: tip, to: wrist)
        let dipToWrist = distance(from: dip, to: wrist)
        let pipToWrist = distance(from: pip, to: wrist)
        let mcpToWrist = distance(from: mcp, to: wrist)
        
        // Check if distances are increasing (finger is extended)
        let isExtending = tipToWrist > dipToWrist &&
                         dipToWrist > pipToWrist &&
                         pipToWrist > mcpToWrist
        
        // Check angle between joints (simplified)
        let angle = calculateAngle(p1: tip, p2: pip, p3: mcp)
        let isStraight = angle > 150 // degrees
        
        return isExtending && isStraight
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateAngle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let det = v1.x * v2.y - v1.y * v2.x
        
        let angle = atan2(det, dot) * 180 / .pi
        return abs(angle)
    }
}

// MARK: - Detection Helpers
extension FingerDetector {
    // Common gesture patterns
    func detectHandPose(from result: FingerDetectionResult) -> HandPose? {
        let fingers = Set(result.raisedFingers)
        
        // Peace sign
        if fingers == [.index, .middle] {
            return .peace
        }
        
        // Thumbs up
        if fingers == [.thumb] {
            return .thumbsUp
        }
        
        // OK sign (simplified - would need more complex detection)
        if fingers == [.thumb, .index] && result.count == 2 {
            return .ok
        }
        
        // Pointing
        if fingers == [.index] {
            return .pointing
        }
        
        return nil
    }
}