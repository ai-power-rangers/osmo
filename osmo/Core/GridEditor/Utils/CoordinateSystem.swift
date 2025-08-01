import Foundation
import CoreGraphics

/// Coordinate system helper for converting between unit space and screen space
public class CoordinateSystem {
    public let screenSize: CGSize
    public let margin: CGFloat
    
    public init(screenSize: CGSize, margin: CGFloat = 20) {
        self.screenSize = screenSize
        self.margin = margin
    }
    
    /// Points per unit (computed to fit screen)
    public var screenUnit: CGFloat {
        let availableSize = min(screenSize.width, screenSize.height) - (margin * 2)
        return availableSize / GridConstants.playAreaSize
    }
    
    /// Get the scale factor for pieces (90% of grid square)
    /// This ensures consistent sizing throughout gameplay
    public var pieceScale: CGFloat {
        return screenUnit * 0.9
    }
    
    /// Convert unit coordinates (0-8) to screen coordinates
    public func toScreen(_ unitPoint: CGPoint) -> CGPoint {
        let x = margin + unitPoint.x * screenUnit
        let y = margin + unitPoint.y * screenUnit
        return CGPoint(x: x, y: y)
    }
    
    /// Convert screen coordinates to unit coordinates (0-8)
    public func toUnit(_ screenPoint: CGPoint) -> CGPoint {
        let x = (screenPoint.x - margin) / screenUnit
        let y = (screenPoint.y - margin) / screenUnit
        return CGPoint(x: x, y: y)
    }
    
    /// Get the center point in screen coordinates
    public var screenCenter: CGPoint {
        return CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
    }
    
    /// Get the center point in unit coordinates
    public var unitCenter: CGPoint {
        return toUnit(screenCenter)
    }
    
    /// Snap a unit point to the nearest grid position
    public func snapToGrid(_ unitPoint: CGPoint, gridStep: Double = 0.25) -> CGPoint {
        let x = round(unitPoint.x / gridStep) * gridStep
        let y = round(unitPoint.y / gridStep) * gridStep
        return CGPoint(x: x, y: y)
    }
    
    /// Check if a unit point is within the play area
    public func isInBounds(_ unitPoint: CGPoint) -> Bool {
        return unitPoint.x >= 0 && unitPoint.x <= GridConstants.playAreaSize &&
               unitPoint.y >= 0 && unitPoint.y <= GridConstants.playAreaSize
    }
}

/// Grid system constants (moved from TangramModels)
public struct GridConstants {
    public static let resolution: CGFloat = 0.1
    public static let playAreaSize: CGFloat = 8.0
    
    /// Auto-scaling snap tolerance
    public static func snapTolerance(for screenUnit: CGFloat) -> CGFloat {
        return max(0.2, 0.0375 * screenUnit)
    }
    
    public static let rotationIncrement: CGFloat = .pi / 4  // 45°
    public static let visualRotationIncrement: CGFloat = .pi / 16  // 11.25° for smooth feedback
}