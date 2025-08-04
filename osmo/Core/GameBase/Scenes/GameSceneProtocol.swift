import SpriteKit
import SwiftUI

/// Protocol defining the interface for game scenes with type-safe view models
/// Ensures consistent behavior across all game implementations
protocol TypedGameSceneProtocol: AnyObject {
    
    // MARK: - Associated Types
    
    /// The puzzle type this scene works with
    associatedtype PuzzleType: GamePuzzleProtocol
    
    /// The view model type this scene uses
    associatedtype ViewModelType: BaseGameViewModel<PuzzleType>
    
    // MARK: - Required Properties
    
    /// Reference to the game context for accessing services
    var gameContext: GameContext? { get set }
    
    /// The view model managing game state
    var viewModel: ViewModelType? { get set }
    
    /// Unit size for consistent spacing
    var unitSize: CGFloat { get set }
    
    /// Grid origin point
    var gridOrigin: CGPoint { get set }
    
    /// Number of grid columns
    var gridColumns: Int { get set }
    
    /// Number of grid rows
    var gridRows: Int { get set }
    
    // MARK: - Required Methods
    
    /// Called after the scene setup is complete
    func didCompleteSetup()
    
    /// Handle touch began events
    /// - Parameter location: The touch location in scene coordinates
    func handleTouchBegan(at location: CGPoint)
    
    /// Handle touch moved events
    /// - Parameters:
    ///   - location: Current touch location in scene coordinates
    ///   - translation: Translation from the initial touch point
    func handleTouchMoved(to location: CGPoint, translation: CGPoint)
    
    /// Handle touch ended events
    /// - Parameters:
    ///   - location: Final touch location in scene coordinates
    ///   - velocity: Touch velocity at the end
    func handleTouchEnded(at location: CGPoint, velocity: CGPoint)
    
    /// Handle tap gestures
    /// - Parameter location: Tap location in scene coordinates
    func handleTap(at location: CGPoint)
    
    /// Handle pinch gestures
    /// - Parameters:
    ///   - scale: Pinch scale factor
    ///   - velocity: Pinch velocity
    func handlePinch(scale: CGFloat, velocity: CGFloat)
    
    /// Updates the scene based on game state changes
    /// - Parameter gameState: The new game state
    func updateForGameState(_ gameState: GameState)
    
    /// Resets the scene to initial state
    func resetScene()
    
    // MARK: - Coordinate System Methods
    
    /// Converts a point to grid coordinates
    /// - Parameter point: Point in scene coordinates
    /// - Returns: Grid coordinates
    func pointToGridCoordinate(_ point: CGPoint) -> CGPoint
    
    /// Converts grid coordinates to a point
    /// - Parameter coordinate: Grid coordinates
    /// - Returns: Point in scene coordinates
    func gridCoordinateToPoint(_ coordinate: CGPoint) -> CGPoint
    
    /// Snaps a point to the nearest grid intersection
    /// - Parameter point: Point to snap
    /// - Returns: Snapped point
    func snapToGrid(_ point: CGPoint) -> CGPoint
    
    /// Checks if a grid coordinate is within bounds
    /// - Parameter coordinate: Grid coordinate to check
    /// - Returns: True if valid, false otherwise
    func isValidGridCoordinate(_ coordinate: CGPoint) -> Bool
}

// MARK: - Default Implementations

extension TypedGameSceneProtocol where Self: BaseGameScene {
    
    /// Default implementation uses BaseGameScene's method
    func pointToGridCoordinate(_ point: CGPoint) -> CGPoint {
        let x = (point.x - gridOrigin.x) / unitSize
        let y = (point.y - gridOrigin.y) / unitSize
        return CGPoint(x: x, y: y)
    }
    
    /// Default implementation uses BaseGameScene's method
    func gridCoordinateToPoint(_ coordinate: CGPoint) -> CGPoint {
        let x = gridOrigin.x + coordinate.x * unitSize
        let y = gridOrigin.y + coordinate.y * unitSize
        return CGPoint(x: x, y: y)
    }
    
    /// Default implementation uses BaseGameScene's method
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        let gridCoord = pointToGridCoordinate(point)
        let snappedCoord = CGPoint(
            x: round(gridCoord.x),
            y: round(gridCoord.y)
        )
        return gridCoordinateToPoint(snappedCoord)
    }
    
    /// Default implementation uses BaseGameScene's method
    func isValidGridCoordinate(_ coordinate: CGPoint) -> Bool {
        return coordinate.x >= 0 && coordinate.x < CGFloat(gridColumns) &&
               coordinate.y >= 0 && coordinate.y < CGFloat(gridRows)
    }
}