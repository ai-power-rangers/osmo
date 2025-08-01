//
//  SudokuBoardDetector.swift
//  osmo
//
//  Board detection and quadrilateral processing for Sudoku
//

import Foundation
import CoreGraphics
import Vision

final class SudokuBoardDetector {
    
    // MARK: - Properties
    
    private let gridSize: GridSize
    private var lastDetectedCorners: [CGPoint]?
    private let cornerSmoothingFactor: CGFloat = 0.3  // For exponential moving average
    
    // MARK: - Initialization
    
    init(gridSize: GridSize) {
        self.gridSize = gridSize
    }
    
    // MARK: - Public Methods
    
    func processQuadrilateral(_ quad: CVRectangle) -> BoardDetection? {
        guard isValidBoard(quad) else { return nil }
        
        // Smooth corners if we have previous detection
        let smoothedCorners = smoothCorners(quad.corners)
        
        // Calculate perspective transform
        let transform = calculatePerspectiveTransform(from: smoothedCorners)
        
        return BoardDetection(
            corners: smoothedCorners,
            confidence: quad.confidence,
            timestamp: Date(),
            transform: transform
        )
    }
    
    func mapScreenPointToGrid(_ point: CGPoint, boardDetection: BoardDetection) -> Position? {
        // Apply inverse transform to get normalized coordinates
        let normalizedPoint = point.applying(boardDetection.transform.inverted())
        
        // Map to grid position
        let dimension = gridSize.rawValue
        let col = Int(normalizedPoint.x * CGFloat(dimension))
        let row = Int(normalizedPoint.y * CGFloat(dimension))
        
        // Validate position
        if row >= 0 && row < dimension && col >= 0 && col < dimension {
            return Position(row: row, col: col)
        }
        
        return nil
    }
    
    func getCellBounds(for position: Position, boardDetection: BoardDetection) -> CGRect {
        let dimension = CGFloat(gridSize.rawValue)
        let cellSize = 1.0 / dimension
        
        // Calculate normalized cell bounds
        let normalizedRect = CGRect(
            x: CGFloat(position.col) * cellSize,
            y: CGFloat(position.row) * cellSize,
            width: cellSize,
            height: cellSize
        )
        
        // Transform to screen coordinates
        return normalizedRect.applying(boardDetection.transform)
    }
    
    // MARK: - Private Methods
    
    private func isValidBoard(_ quad: CVRectangle) -> Bool {
        guard quad.corners.count == 4 else { return false }
        
        // Check minimum area - more lenient
        if quad.area < 5000 { 
            print("[BoardDetector] Rejected: area too small (\(quad.area))")
            return false  
        }
        
        // Check aspect ratio (allow more distortion for perspective)
        let aspectRatio = calculateAspectRatio(corners: quad.corners)
        if aspectRatio < 0.3 || aspectRatio > 3.0 { 
            print("[BoardDetector] Rejected: aspect ratio out of range (\(aspectRatio))")
            return false 
        }
        
        // Check angles (allow more skew for angled boards)
        let angles = calculateAngles(corners: quad.corners)
        for (index, angle) in angles.enumerated() {
            if angle < 45 || angle > 135 {
                print("[BoardDetector] Rejected: angle \(index) out of range (\(angle)°)")
                return false  // Too skewed
            }
        }
        
        print("[BoardDetector] Valid board detected - area: \(quad.area), aspect: \(aspectRatio), confidence: \(quad.confidence)")
        return true
    }
    
    private func smoothCorners(_ corners: [CGPoint]) -> [CGPoint] {
        guard let lastCorners = lastDetectedCorners,
              lastCorners.count == corners.count else {
            lastDetectedCorners = corners
            return corners
        }
        
        // Apply exponential moving average
        var smoothed: [CGPoint] = []
        for i in 0..<corners.count {
            let x = corners[i].x * cornerSmoothingFactor + lastCorners[i].x * (1 - cornerSmoothingFactor)
            let y = corners[i].y * cornerSmoothingFactor + lastCorners[i].y * (1 - cornerSmoothingFactor)
            smoothed.append(CGPoint(x: x, y: y))
        }
        
        lastDetectedCorners = smoothed
        return smoothed
    }
    
    private func calculateAspectRatio(corners: [CGPoint]) -> CGFloat {
        guard corners.count == 4 else { return 0 }
        
        // Calculate average width and height
        let width1 = distance(from: corners[0], to: corners[1])
        let width2 = distance(from: corners[3], to: corners[2])
        let avgWidth = (width1 + width2) / 2
        
        let height1 = distance(from: corners[0], to: corners[3])
        let height2 = distance(from: corners[1], to: corners[2])
        let avgHeight = (height1 + height2) / 2
        
        return avgWidth / avgHeight
    }
    
    private func calculateAngles(corners: [CGPoint]) -> [CGFloat] {
        guard corners.count == 4 else { return [] }
        
        var angles: [CGFloat] = []
        
        for i in 0..<4 {
            let p1 = corners[i]
            let p2 = corners[(i + 1) % 4]
            let p3 = corners[(i + 2) % 4]
            
            let angle = angleAtPoint(p2, from: p1, to: p3)
            angles.append(angle)
        }
        
        return angles
    }
    
    private func angleAtPoint(_ center: CGPoint, from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - center.x, y: p1.y - center.y)
        let v2 = CGPoint(x: p2.x - center.x, y: p2.y - center.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let cross = v1.x * v2.y - v1.y * v2.x
        
        let angle = atan2(cross, dot) * 180 / .pi
        return abs(angle)
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculatePerspectiveTransform(from corners: [CGPoint]) -> CGAffineTransform {
        // For a proper implementation, we would calculate the homography matrix
        // For now, return a simplified transform
        
        // Find bounding box
        let minX = corners.map { $0.x }.min() ?? 0
        let maxX = corners.map { $0.x }.max() ?? 1
        let minY = corners.map { $0.y }.min() ?? 0
        let maxY = corners.map { $0.y }.max() ?? 1
        
        let width = maxX - minX
        let height = maxY - minY
        
        // Create transform that maps unit square to bounding box
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: minX, y: minY)
        transform = transform.scaledBy(x: width, y: height)
        
        return transform
    }
}

// MARK: - CVRectangle Extension

extension CVRectangle {
    var corners: [CGPoint] {
        // Convert normalized points to screen coordinates
        // This assumes CVRectangle provides corners in normalized coordinates
        return [
            CGPoint(x: topLeft.x, y: topLeft.y),
            CGPoint(x: topRight.x, y: topRight.y),
            CGPoint(x: bottomRight.x, y: bottomRight.y),
            CGPoint(x: bottomLeft.x, y: bottomLeft.y)
        ]
    }
    
    var area: CGFloat {
        // Calculate area using shoelace formula
        // For normalized coordinates (0-1), multiply by a scale factor
        let scaleFactor: CGFloat = 100000  // Scale up for meaningful area values
        
        let corners = self.corners
        var area: CGFloat = 0
        
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            area += corners[i].x * corners[j].y
            area -= corners[j].x * corners[i].y
        }
        
        return abs(area) * scaleFactor / 2
    }
}