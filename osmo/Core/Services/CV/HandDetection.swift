//
//  HandDetection.swift
//  osmo
//
//  Created by Phase 3 Implementation
//

import Foundation
import Vision
import CoreGraphics

// MARK: - Hand Detection Types
struct HandObservation {
    var id: UUID
    let chirality: HandChirality
    let landmarks: HandLandmarks
    let confidence: Float
    let boundingBox: CGRect
}

struct HandLandmarks {
    let wrist: CGPoint
    let thumbTip: CGPoint
    let thumbIP: CGPoint
    let thumbMP: CGPoint
    let thumbCMC: CGPoint
    
    let indexTip: CGPoint
    let indexDIP: CGPoint
    let indexPIP: CGPoint
    let indexMCP: CGPoint
    
    let middleTip: CGPoint
    let middleDIP: CGPoint
    let middlePIP: CGPoint
    let middleMCP: CGPoint
    
    let ringTip: CGPoint
    let ringDIP: CGPoint
    let ringPIP: CGPoint
    let ringMCP: CGPoint
    
    let littleTip: CGPoint
    let littleDIP: CGPoint
    let littlePIP: CGPoint
    let littleMCP: CGPoint
    
    // Helper to get all fingertips
    var fingerTips: [CGPoint] {
        [thumbTip, indexTip, middleTip, ringTip, littleTip]
    }
}

// MARK: - Finger Detection
struct FingerDetectionResult {
    let count: Int
    let confidence: Float
    let raisedFingers: [Finger]
    let handChirality: HandChirality
}

enum Finger: String, CaseIterable {
    case thumb
    case index
    case middle
    case ring
    case little
}

// MARK: - Rectangle Detection (for Sudoku)
struct RectangleObservation {
    let id: UUID
    let corners: [CGPoint] // 4 corners in normalized coordinates
    let confidence: Float
    let boundingBox: CGRect
}

// MARK: - Text Detection
struct TextObservation {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let location: CGPoint // Center point
}

// MARK: - CV Errors
enum CVError: LocalizedError {
    case cameraPermissionDenied
    case cameraUnavailable
    case sessionFailure(Error)
    case detectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Camera permission was denied"
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .sessionFailure(let error):
            return "CV session failed: \(error.localizedDescription)"
        case .detectionFailed(let reason):
            return "Detection failed: \(reason)"
        }
    }
}