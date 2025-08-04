//
//  CVEvent.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import Foundation
import CoreGraphics

// MARK: - CV Event Types
public enum CVEventType: Equatable {
    case objectDetected(type: String, objectId: UUID)
    case objectMoved(type: String, objectId: UUID, from: CGPoint, to: CGPoint)
    case objectRemoved(type: String, objectId: UUID)
    case gestureRecognized(type: GestureType)
    case fingerCountDetected(count: Int) // For our mock game
    
    // Rectangle/quadrilateral detection
    case rectangleDetected(rectangles: [CVRectangle])
    case rectangleLost
    
    // Text detection
    case textDetected(text: String, boundingBox: CGRect)
    
    // Sudoku-specific events
    case sudokuGridDetected(gridId: UUID, corners: [CGPoint])
    case sudokuCellWritten(gridId: UUID, row: Int, col: Int, digit: Int)
    case sudokuGridLost(gridId: UUID)
    case sudokuCompleted(gridId: UUID)
    
    // Hand tracking events
    case handDetected(handId: UUID, chirality: HandChirality)
    case handLost(handId: UUID)
    case handPoseChanged(handId: UUID, pose: HandPose)
}

// MARK: - Hand Types
public enum HandChirality: String, Equatable {
    case left
    case right
    case unknown
}

public enum HandPose: Equatable {
    case open
    case closed
    case pointing
    case peace
    case thumbsUp
    case ok
    case custom(String)
    
    var rawValue: String {
        switch self {
        case .open: return "open"
        case .closed: return "closed"
        case .pointing: return "pointing"
        case .peace: return "peace"
        case .thumbsUp: return "thumbsUp"
        case .ok: return "ok"
        case .custom(let value): return value
        }
    }
}

public enum GestureType: String, Equatable {
    case tap
    case swipe
    case pinch
    case rotate
}

// MARK: - CV Event
public struct CVEvent {
    public let id: UUID = UUID()
    public let type: CVEventType
    public let position: CGPoint // Normalized 0-1
    public let confidence: Float // 0-1
    public let timestamp: TimeInterval
    public let metadata: CVMetadata?
    
    public init(type: CVEventType, 
         position: CGPoint = CGPoint(x: 0.5, y: 0.5),
         confidence: Float = 1.0,
         timestamp: TimeInterval = Date().timeIntervalSince1970,
         metadata: CVMetadata? = nil) {
        self.type = type
        self.position = position
        self.confidence = confidence
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - CV Metadata
public struct CVMetadata {
    public let boundingBox: CGRect?
    public let rotation: Float?
    public let additionalProperties: [String: Any]
    
    public init(boundingBox: CGRect? = nil,
         rotation: Float? = nil,
         additionalProperties: [String: Any] = [:]) {
        self.boundingBox = boundingBox
        self.rotation = rotation
        self.additionalProperties = additionalProperties
    }
}

// MARK: - CV Rectangle
public struct CVRectangle: Equatable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint
    public let confidence: Float
    
    public var center: CGPoint {
        CGPoint(
            x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
            y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
        )
    }
}
