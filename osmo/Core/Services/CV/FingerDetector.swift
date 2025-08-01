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
    
    // Thresholds for finger detection - made more lenient
    private let extendedThreshold: Float = 0.6  // Reduced from 0.8 for better detection
    private let angleThreshold: CGFloat = 140  // Reduced from 150 degrees
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
        let isStraight = angle > angleThreshold
        
        // For rock-paper-scissors, we're more lenient
        // If finger is extending OR reasonably straight, count it
        return isExtending || (isStraight && tipToWrist > mcpToWrist * 1.2)
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
    
    // Calculate hand openness based on finger spread and extension
    func calculateHandOpenness(from hand: HandObservation) -> Float {
        let tips = hand.landmarks.fingerTips
        guard tips.count >= 5 else { return 0.0 }
        
        // Method 1: Average distance between fingertips (spread)
        var totalSpread: CGFloat = 0
        var spreadCount = 0
        
        // Distance between thumb and index
        totalSpread += distance(from: tips[0], to: tips[1])
        spreadCount += 1
        
        // Distance between consecutive fingers
        for index in 1..<(tips.count - 1) {
            totalSpread += distance(from: tips[index], to: tips[index + 1])
            spreadCount += 1
        }
        
        let avgSpread = totalSpread / CGFloat(spreadCount)
        let handSize = distance(from: hand.landmarks.wrist, to: hand.landmarks.middleMCP)
        let normalizedSpread = avgSpread / handSize
        
        // Method 2: Average finger extension (how far tips are from palm)
        let palmCenter = CGPoint(
            x: (hand.landmarks.indexMCP.x + hand.landmarks.middleMCP.x + hand.landmarks.ringMCP.x + hand.landmarks.littleMCP.x) / 4,
            y: (hand.landmarks.indexMCP.y + hand.landmarks.middleMCP.y + hand.landmarks.ringMCP.y + hand.landmarks.littleMCP.y) / 4
        )
        
        var totalExtension: CGFloat = 0
        for tip in tips {
            totalExtension += distance(from: tip, to: palmCenter)
        }
        let avgExtension = totalExtension / CGFloat(tips.count)
        let normalizedExtension = avgExtension / handSize
        
        // Method 3: Finger curl detection
        let fingersCurled = detectCurledFingers(from: hand)
        let curlFactor = 1.0 - (Float(fingersCurled) / 5.0)
        
        // Combine all methods with weights
        let spreadWeight: Float = 0.3
        let extensionWeight: Float = 0.4
        let curlWeight: Float = 0.3
        
        let combinedOpenness = (Float(normalizedSpread) * spreadWeight +
                               Float(normalizedExtension) * extensionWeight +
                               curlFactor * curlWeight)
        
        // Normalize to 0-1 range with adjusted thresholds
        // Closed fist: ~0.1-0.2, Scissors: ~0.4-0.6, Open hand: ~0.7-1.0
        let adjustedOpenness = min(max((combinedOpenness - 0.1) * 1.2, 0), 1)
        
        return adjustedOpenness
    }
    
    private func detectCurledFingers(from hand: HandObservation) -> Int {
        var curledCount = 0
        
        // Check each finger for curl by comparing tip to DIP distance vs DIP to MCP
        let fingers = [
            (hand.landmarks.indexTip, hand.landmarks.indexDIP, hand.landmarks.indexMCP),
            (hand.landmarks.middleTip, hand.landmarks.middleDIP, hand.landmarks.middleMCP),
            (hand.landmarks.ringTip, hand.landmarks.ringDIP, hand.landmarks.ringMCP),
            (hand.landmarks.littleTip, hand.landmarks.littleDIP, hand.landmarks.littleMCP)
        ]
        
        for (tip, dip, mcp) in fingers {
            let tipToDip = distance(from: tip, to: dip)
            let dipToMcp = distance(from: dip, to: mcp)
            
            // If tip is closer to DIP than DIP is to MCP, finger is likely curled
            if tipToDip < dipToMcp * 0.7 {
                curledCount += 1
            }
        }
        
        // Special handling for thumb
        let thumbTipToIP = distance(from: hand.landmarks.thumbTip, to: hand.landmarks.thumbIP)
        let thumbIPToMP = distance(from: hand.landmarks.thumbIP, to: hand.landmarks.thumbMP)
        if thumbTipToIP < thumbIPToMP * 0.7 {
            curledCount += 1
        }
        
        return curledCount
    }
}
