//
//  SudokuModels.swift
//  osmo
//
//  Models and data structures for Sudoku game
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Game Types

enum GridSize: Int, CaseIterable {
    case fourByFour = 4
    case nineByNine = 9
    
    var displayName: String {
        switch self {
        case .fourByFour: return "4×4 Mini"
        case .nineByNine: return "9×9 Classic"
        }
    }
    
    var boxSize: Int {
        switch self {
        case .fourByFour: return 2
        case .nineByNine: return 3
        }
    }
    
    var maxNumber: Int {
        return rawValue
    }
}

enum GameMode {
    case setup
    case solving
    case completed
}

enum PlacementResult {
    case valid
    case invalid(reason: String)
    case alreadyFilled
    case originalTile
}

struct Position: Equatable, Hashable {
    let row: Int
    let col: Int
    
    func box(for gridSize: GridSize) -> Int {
        let boxSize = gridSize.boxSize
        let boxRow = row / boxSize
        let boxCol = col / boxSize
        return boxRow * boxSize + boxCol
    }
}

// MARK: - Board State

struct TileDetection {
    let position: Position
    let number: Int?
    let confidence: Float
    let timestamp: Date
    let boundingBox: CGRect
}

struct BoardDetection {
    let corners: [CGPoint]  // 4 corners of quadrilateral
    let confidence: Float
    let timestamp: Date
    let transform: CGAffineTransform  // Perspective transform to normalize
}

// MARK: - Game Configuration

struct SudokuConfiguration {
    let gridSize: GridSize
    let detectionConfidenceThreshold: Float
    let temporalConsistencyFrames: Int
    let tileAnimationDuration: TimeInterval
    
    static let fourByFour = SudokuConfiguration(
        gridSize: .fourByFour,
        detectionConfidenceThreshold: 0.6,
        temporalConsistencyFrames: 3,
        tileAnimationDuration: 0.3
    )
    
    static let nineByNine = SudokuConfiguration(
        gridSize: .nineByNine,
        detectionConfidenceThreshold: 0.6,
        temporalConsistencyFrames: 3,
        tileAnimationDuration: 0.3
    )
}

// MARK: - Validation Result

enum ValidationResult {
    case valid
    case duplicateInRow(position: Position, number: Int)
    case duplicateInColumn(position: Position, number: Int)
    case duplicateInBox(position: Position, number: Int)
    case invalidNumber(number: Int)
    
    var isValid: Bool {
        switch self {
        case .valid: return true
        default: return false
        }
    }
    
    var errorMessage: String {
        switch self {
        case .valid:
            return ""
        case .duplicateInRow(_, let number):
            return "\(number) already in row"
        case .duplicateInColumn(_, let number):
            return "\(number) already in column"
        case .duplicateInBox(_, let number):
            return "\(number) already in box"
        case .invalidNumber(let number):
            return "\(number) is invalid"
        }
    }
}

// MARK: - Animation Types

enum FeedbackAnimation {
    case correctPlacement
    case incorrectPlacement
    case originalTileWarning
    case puzzleComplete
    
    var emoji: String {
        switch self {
        case .correctPlacement: return "👍"
        case .incorrectPlacement: return "👎"
        case .originalTileWarning: return "⚠️"
        case .puzzleComplete: return "🎉"
        }
    }
}

// MARK: - CV Event Types

struct QuadrilateralDetection {
    let points: [CGPoint]  // 4 corner points
    let area: CGFloat
    let confidence: Float
    
    var isValidBoard: Bool {
        // Check if roughly square-ish (with tolerance for perspective)
        guard points.count == 4 else { return false }
        
        // Calculate aspect ratio using perspective-corrected dimensions
        // This is simplified - real implementation would be more sophisticated
        return confidence > 0.5 && area > 10000  // Minimum area threshold
    }
}

// MARK: - Detection States

enum BoardDetectionState {
    case searching      // No rectangles detected
    case detecting      // Rectangle detected but not validated
    case stabilizing    // Valid board, building confidence
    case confirmed      // Stable detection for 10+ frames
    
    var displayMessage: String {
        switch self {
        case .searching:
            return "Place board in view"
        case .detecting:
            return "Board found, analyzing..."
        case .stabilizing:
            return "Hold steady..."
        case .confirmed:
            return "Board locked! Reading tiles..."
        }
    }
    
    var outlineColor: Color {
        switch self {
        case .searching:
            return .clear
        case .detecting:
            return .yellow
        case .stabilizing:
            return .green.opacity(0.7)
        case .confirmed:
            return .green
        }
    }
}

// MARK: - Game State

struct SudokuGameState {
    var mode: GameMode = .setup
    var configuration: SudokuConfiguration
    var startTime: Date?
    var endTime: Date?
    
    var elapsedTime: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }
    
    var formattedTime: String {
        let time = Int(elapsedTime)
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}