import UIKit
import CoreGraphics

/// Responsive layout configuration for different device sizes
struct TangramLayoutConfig {
    let screenSize: CGSize
    let deviceType: UIUserInterfaceIdiom
    let orientation: UIInterfaceOrientation
    
    // Computed layout properties
    var boardSize: CGSize {
        let margin: CGFloat = deviceType == .pad ? 100 : 40
        let maxWidth = screenSize.width - (margin * 2)
        let maxHeight = screenSize.height - trayHeight - margin - 100 // UI space
        
        // Keep board square and fit within bounds
        let size = min(maxWidth, maxHeight)
        return CGSize(width: size, height: size)
    }
    
    var trayHeight: CGFloat {
        deviceType == .pad ? 150 : 100
    }
    
    var pieceScale: CGFloat {
        // Scale pieces based on board size
        boardSize.width / 400.0 // Base size 400pt
    }
    
    var fontSize: (small: CGFloat, medium: CGFloat, large: CGFloat) {
        if deviceType == .pad {
            return (18, 24, 32)
        } else {
            return (14, 18, 24)
        }
    }
    
    var buttonSize: CGFloat {
        deviceType == .pad ? 30 : 20
    }
    
    var margin: CGFloat {
        deviceType == .pad ? 40 : 20
    }
    
    var isLandscape: Bool {
        orientation.isLandscape
    }
}