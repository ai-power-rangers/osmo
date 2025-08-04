import SpriteKit
import SwiftUI
import CoreGraphics

/// Base scene class that provides common functionality for all game scenes
/// Includes gesture handling, coordinate system, and GameContext integration
class BaseGameScene: SKScene, SceneUpdateReceiver {
    
    // MARK: - Properties
    
    /// Reference to the game context for accessing services
    weak var gameContext: GameContext?
    
    /// View model for SwiftUI integration
    /// Note: Subclasses should override with specific view model type
    var viewModel: AnyObject?
    
    // MARK: - Coordinate System Properties
    
    /// Unit size for consistent spacing across all games
    var unitSize: CGFloat = 50.0
    
    /// Grid origin point for coordinate calculations
    var gridOrigin: CGPoint = .zero
    
    /// Number of grid columns
    var gridColumns: Int = 10
    
    /// Number of grid rows
    var gridRows: Int = 10
    
    // MARK: - Gesture Recognition
    
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var tapGestureRecognizer: UITapGestureRecognizer?
    private var pinchGestureRecognizer: UIPinchGestureRecognizer?
    
    // MARK: - State Management
    
    private var isSetupComplete = false
    
    /// Game action handler (usually the ViewModel)
    private var actionHandler: GameActionHandler? {
        viewModel as? GameActionHandler
    }
    
    /// Track current input source
    private var currentInputSource: InputSource = .touch
    
    // MARK: - Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        guard !isSetupComplete else { return }
        
        setupScene()
        setupGestureRecognizers()
        setupCoordinateSystem()
        registerWithViewModel()
        
        isSetupComplete = true
        
        // Call overridable setup method for subclasses
        didCompleteSetup()
    }
    
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        cleanup()
    }
    
    // MARK: - Setup Methods
    
    private func setupScene() {
        backgroundColor = .clear
        scaleMode = .aspectFit
        
        // Enable user interaction
        isUserInteractionEnabled = true
    }
    
    private func setupGestureRecognizers() {
        guard let view = view else { return }
        
        // Pan gesture for dragging
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer?.delegate = self
        view.addGestureRecognizer(panGestureRecognizer!)
        
        // Tap gesture for selection
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGestureRecognizer?.delegate = self
        view.addGestureRecognizer(tapGestureRecognizer!)
        
        // Pinch gesture for scaling (optional, can be overridden)
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchGestureRecognizer?.delegate = self
        view.addGestureRecognizer(pinchGestureRecognizer!)
    }
    
    private func setupCoordinateSystem() {
        // Calculate grid origin to center the grid
        let gridWidth = CGFloat(gridColumns) * unitSize
        let gridHeight = CGFloat(gridRows) * unitSize
        
        gridOrigin = CGPoint(
            x: (size.width - gridWidth) / 2,
            y: (size.height - gridHeight) / 2
        )
    }
    
    private func registerWithViewModel() {
        // Register this scene to receive updates from the ViewModel
        if let updateProvider = viewModel as? SceneUpdateProvider {
            updateProvider.registerSceneReceiver(self)
        }
    }
    
    // MARK: - SceneUpdateReceiver Implementation
    
    /// Update the display with a new game state
    func updateDisplay(with state: GameStateSnapshot) {
        // Update input source tracking
        currentInputSource = state.inputSource
        
        // Call overridable method for subclasses
        updateGameDisplay(state)
    }
    
    /// Show an error to the user
    func showError(_ error: SceneError) {
        // Default implementation - subclasses can override
        print("[BaseGameScene] Error: \(error.localizedDescription)")
    }
    
    /// Play a specific animation
    func playAnimation(_ animation: GameAnimation) {
        // Call overridable method for subclasses
        performAnimation(animation)
    }
    
    /// Override point for subclasses to update display
    func updateGameDisplay(_ state: GameStateSnapshot) {
        // Override in subclasses to update visual elements
    }
    
    /// Override point for subclasses to perform animations
    func performAnimation(_ animation: GameAnimation) {
        // Override in subclasses to perform specific animations
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: view)
        let sceneLocation = convertPoint(fromView: location)
        
        switch gesture.state {
        case .began:
            handleTouchBegan(at: sceneLocation)
            actionHandler?.handleSelection(at: sceneLocation, source: currentInputSource)
        case .changed:
            let translation = gesture.translation(in: view)
            let sceneTranslation = CGPoint(x: translation.x, y: -translation.y) // Flip Y
            handleTouchMoved(to: sceneLocation, translation: sceneTranslation)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view)
            let sceneVelocity = CGPoint(x: velocity.x, y: -velocity.y) // Flip Y
            handleTouchEnded(at: sceneLocation, velocity: sceneVelocity)
            actionHandler?.handleRelease(at: sceneLocation, source: currentInputSource)
        default:
            break
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let sceneLocation = convertPoint(fromView: location)
        handleTap(at: sceneLocation)
        
        // Notify ViewModel of tap
        let tapGesture = GameGesture.tap(location: sceneLocation)
        actionHandler?.handleGesture(tapGesture, source: currentInputSource)
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        handlePinch(scale: gesture.scale, velocity: gesture.velocity)
        
        if gesture.state == .changed {
            let location = gesture.location(in: view)
            let sceneLocation = convertPoint(fromView: location)
            let pinchGesture = GameGesture.pinch(scale: Float(gesture.scale), location: sceneLocation)
            actionHandler?.handleGesture(pinchGesture, source: currentInputSource)
        }
        
        gesture.scale = 1.0 // Reset scale
    }
    
    // MARK: - Coordinate System Methods
    
    /// Converts a point to grid coordinates
    func pointToGridCoordinate(_ point: CGPoint) -> CGPoint {
        let x = (point.x - gridOrigin.x) / unitSize
        let y = (point.y - gridOrigin.y) / unitSize
        return CGPoint(x: x, y: y)
    }
    
    /// Converts grid coordinates to a point
    func gridCoordinateToPoint(_ coordinate: CGPoint) -> CGPoint {
        let x = gridOrigin.x + coordinate.x * unitSize
        let y = gridOrigin.y + coordinate.y * unitSize
        return CGPoint(x: x, y: y)
    }
    
    /// Snaps a point to the nearest grid intersection
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        let gridCoord = pointToGridCoordinate(point)
        let snappedCoord = CGPoint(
            x: round(gridCoord.x),
            y: round(gridCoord.y)
        )
        return gridCoordinateToPoint(snappedCoord)
    }
    
    /// Checks if a grid coordinate is within bounds
    func isValidGridCoordinate(_ coordinate: CGPoint) -> Bool {
        return coordinate.x >= 0 && coordinate.x < CGFloat(gridColumns) &&
               coordinate.y >= 0 && coordinate.y < CGFloat(gridRows)
    }
    
    // MARK: - Override Points for Subclasses
    
    /// Called after the scene setup is complete
    /// Subclasses should override this instead of didMove(to:)
    func didCompleteSetup() {
        // Override in subclasses
    }
    
    /// Handle touch began events
    /// - Parameter location: The touch location in scene coordinates
    func handleTouchBegan(at location: CGPoint) {
        // Override in subclasses
        // Note: ViewModel is notified via actionHandler?.handleSelection
    }
    
    /// Handle touch moved events
    /// - Parameters:
    ///   - location: Current touch location in scene coordinates
    ///   - translation: Translation from the initial touch point
    func handleTouchMoved(to location: CGPoint, translation: CGPoint) {
        // Override in subclasses
    }
    
    /// Handle touch ended events
    /// - Parameters:
    ///   - location: Final touch location in scene coordinates
    ///   - velocity: Touch velocity at the end
    func handleTouchEnded(at location: CGPoint, velocity: CGPoint) {
        // Override in subclasses
        // Note: ViewModel is notified via actionHandler?.handleRelease
    }
    
    /// Handle tap gestures
    /// - Parameter location: Tap location in scene coordinates
    func handleTap(at location: CGPoint) {
        // Override in subclasses
    }
    
    /// Handle pinch gestures
    /// - Parameters:
    ///   - scale: Pinch scale factor
    ///   - velocity: Pinch velocity
    func handlePinch(scale: CGFloat, velocity: CGFloat) {
        // Override in subclasses
    }
    
    // MARK: - Game State Integration
    
    /// Updates the scene based on game state changes
    func updateForGameState(_ gameState: GameState) {
        // Override in subclasses
    }
    
    /// Resets the scene to initial state
    func resetScene() {
        // Override in subclasses
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        // Remove gesture recognizers
        if let view = view {
            if let panGesture = panGestureRecognizer {
                view.removeGestureRecognizer(panGesture)
            }
            if let tapGesture = tapGestureRecognizer {
                view.removeGestureRecognizer(tapGesture)
            }
            if let pinchGesture = pinchGestureRecognizer {
                view.removeGestureRecognizer(pinchGesture)
            }
        }
        
        // Clear references
        gameContext = nil
        viewModel = nil
    }
}

// MARK: - UIGestureRecognizerDelegate

extension BaseGameScene: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition for tap and pan
        return (gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer) ||
               (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer)
    }
}