//
//  RockPaperScissorsGameScene.swift
//  osmo
//
//  SpriteKit scene for Rock-Paper-Scissors game
//

import SpriteKit
import SwiftUI

// MARK: - SKTexture Extension for Gradients
extension SKTexture {
    enum GradientDirection {
        case vertical
        case horizontal
    }
    
    convenience init(size: CGSize, color1: UIColor, color2: UIColor, direction: GradientDirection) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [color1.cgColor, color2.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0.0, 1.0]
            
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
                return
            }
            
            let startPoint = CGPoint.zero
            let endPoint = direction == .vertical ? CGPoint(x: 0, y: size.height) : CGPoint(x: size.width, y: 0)
            
            context.cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
        self.init(image: image)
    }
}

final class RockPaperScissorsGameScene: SKScene, GameSceneProtocol {
    
    // MARK: - Properties
    
    weak var gameContext: GameContext?
    private var viewModel: RockPaperScissorsViewModel!
    
    // MARK: - Visual Nodes
    
    private var backgroundNode: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!
    private var instructionLabel: SKLabelNode!
    
    // Exit button (moved from GameHost)
    private var exitButton: SKShapeNode!
    private var exitButtonIcon: SKLabelNode!
    
    // Gesture display
    private var playerGestureNode: SKSpriteNode!
    private var aiGestureNode: SKSpriteNode!
    private var playerLabel: SKLabelNode!
    private var aiLabel: SKLabelNode!
    
    // Result display
    private var resultLabel: SKLabelNode!
    private var playAgainButton: SKShapeNode!
    private var playAgainLabel: SKLabelNode!
    
    // Start button
    private var startButton: SKShapeNode!
    private var startButtonLabel: SKLabelNode!
    
    // Real-time gesture feedback
    private var gestureDebugLabel: SKLabelNode!
    private var gestureDebugBackground: SKShapeNode!
    
    // Gesture guide
    private var gestureGuideBackground: SKShapeNode!
    private var gestureGuideNodes: [SKNode] = []
    
    // Hand tracking indicator
    private var handIndicator: SKShapeNode!
    private var confidenceBar: SKShapeNode!
    private var confidenceFill: SKShapeNode!
    
    // MARK: - CV Integration
    
    private var cvEventStream: AsyncStream<CVEvent>?
    private var cvTask: Task<Void, Never>?
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Initialize ViewModel
        viewModel = RockPaperScissorsViewModel(context: gameContext)
        
        // Setup scene
        setupScene()
        setupNodes()
        layoutNodes()
        
        // Subscribe to CV events
        subscribeToCV()
        
        // Start new match
        viewModel.startNewMatch()
        showWaitingState()
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        backgroundColor = .clear  // Transparent to show camera
        scaleMode = .resizeFill  // Changed from aspectFill to ensure full coverage
    }
    
    private func setupNodes() {
        // Light semi-transparent background overlay
        backgroundNode = SKSpriteNode(color: .black.withAlphaComponent(0.3), size: size)
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(backgroundNode)
        
        // Score display with modern styling
        scoreLabel = createLabel(
            text: "Player 0 - 0 AI",
            fontSize: 24,
            fontWeight: .bold
        )
        
        // Exit button
        exitButton = SKShapeNode(circleOfRadius: 20)
        exitButton.fillColor = UIColor.black.withAlphaComponent(0.5)
        exitButton.strokeColor = UIColor.white.withAlphaComponent(0.8)
        exitButton.lineWidth = 2
        exitButton.name = "exitButton"
        
        exitButtonIcon = createLabel(text: "✕", fontSize: 20, fontWeight: .bold)
        exitButtonIcon.verticalAlignmentMode = .center
        exitButton.addChild(exitButtonIcon)
        
        // Countdown with larger size
        countdownLabel = createLabel(
            text: "",
            fontSize: 120,
            fontWeight: .heavy
        )
        
        // Instructions with better visibility
        instructionLabel = createLabel(
            text: "Practice your gestures",
            fontSize: 20,
            fontWeight: .medium
        )
        
        // Gesture nodes
        playerGestureNode = createGestureNode()
        aiGestureNode = createGestureNode()
        
        playerLabel = createLabel(text: "You", fontSize: 16, fontWeight: .semibold)
        aiLabel = createLabel(text: "AI", fontSize: 16, fontWeight: .semibold)
        
        // Result with larger text
        resultLabel = createLabel(
            text: "",
            fontSize: 48,
            fontWeight: .heavy
        )
        
        // Play again button
        playAgainButton = createButton(size: CGSize(width: 240, height: 60))
        playAgainLabel = createLabel(
            text: "Play Again",
            fontSize: 22,
            fontWeight: .semibold
        )
        playAgainButton.addChild(playAgainLabel)
        
        // Start button - same style as play again
        startButton = createButton(size: CGSize(width: 240, height: 60))
        startButtonLabel = createLabel(
            text: "Start Round",
            fontSize: 22,
            fontWeight: .semibold
        )
        startButton.addChild(startButtonLabel)
        startButton.name = "startButton"
        
        // Gesture debug display
        gestureDebugBackground = SKShapeNode(rectOf: CGSize(width: 320, height: 60), cornerRadius: 30)
        gestureDebugBackground.fillColor = UIColor.black.withAlphaComponent(0.8)
        gestureDebugBackground.strokeColor = UIColor.white.withAlphaComponent(0.3)
        gestureDebugBackground.lineWidth = 1
        
        gestureDebugLabel = createLabel(
            text: "Detecting hand...",
            fontSize: 16,
            fontWeight: .medium
        )
        gestureDebugBackground.addChild(gestureDebugLabel)
        
        // Gesture guide
        createGestureGuide()
        
        // Hand tracking indicator - smaller and more subtle
        handIndicator = SKShapeNode(circleOfRadius: 8)
        handIndicator.fillColor = .systemGreen.withAlphaComponent(0.8)
        handIndicator.strokeColor = .white.withAlphaComponent(0.5)
        handIndicator.lineWidth = 1
        handIndicator.alpha = 0.7
        
        // Confidence bar - hidden by default
        let barWidth: CGFloat = 200
        let barHeight: CGFloat = 8
        
        confidenceBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 4)
        confidenceBar.fillColor = SKColor.white.withAlphaComponent(0.2)
        confidenceBar.strokeColor = .clear
        confidenceBar.isHidden = true // Hide by default
        
        confidenceFill = SKShapeNode(rectOf: CGSize(width: 0, height: barHeight), cornerRadius: 4)
        confidenceFill.fillColor = .systemBlue
        confidenceFill.strokeColor = .clear
        confidenceBar.addChild(confidenceFill)
        
        // Add all nodes
        [scoreLabel, countdownLabel, instructionLabel,
         playerGestureNode, aiGestureNode, playerLabel, aiLabel,
         resultLabel, playAgainButton, startButton, handIndicator, exitButton,
         confidenceBar, gestureDebugBackground, gestureGuideBackground].forEach {
            addChild($0)
        }
    }
    
    private func layoutNodes() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let safeTop = size.height - 60 // Account for safe area
        
        // UI Layout:
        // 1. Top bar: hand indicator (left), score (center), exit button (right)
        // 2. Gesture guide (below top bar)
        // 3. Game area (center)
        // 4. Instructions/buttons (below game)
        // 5. Debug info (bottom)
        
        // TOP BAR - Single row with three elements
        let topBarY = safeTop
        
        // Hand tracking indicator (left)
        handIndicator.position = CGPoint(x: 30, y: topBarY)
        
        // Score (center)
        scoreLabel.position = CGPoint(x: center.x, y: topBarY)
        
        // Exit button (right)
        exitButton.position = CGPoint(x: size.width - 30, y: topBarY)
        
        // Confidence bar (hidden - not needed in new design)
        confidenceBar.isHidden = true
        
        // Gesture guide - below top bar
        gestureGuideBackground.position = CGPoint(x: center.x, y: topBarY - 60)
        
        // Game area - centered
        // Countdown in the middle
        countdownLabel.position = center
        
        // Gesture nodes side by side with proper spacing
        let gestureY = center.y
        let gestureSpacing: CGFloat = 120
        playerGestureNode.position = CGPoint(x: center.x - gestureSpacing, y: gestureY)
        aiGestureNode.position = CGPoint(x: center.x + gestureSpacing, y: gestureY)
        
        // Labels below gestures
        playerLabel.position = CGPoint(x: playerGestureNode.position.x, y: gestureY - 75)
        aiLabel.position = CGPoint(x: aiGestureNode.position.x, y: gestureY - 75)
        
        // Result - positioned to avoid cutoff
        resultLabel.position = CGPoint(x: center.x, y: gestureY + 80)
        
        // Instructions/Play button area - below game area
        instructionLabel.position = CGPoint(x: center.x, y: center.y - 150)
        startButton.position = CGPoint(x: center.x, y: center.y - 200)
        playAgainButton.position = CGPoint(x: center.x, y: center.y - 200)
        
        // Gesture debug display (bottom)
        gestureDebugBackground.position = CGPoint(x: center.x, y: 80)
    }
    
    // MARK: - Node Creation Helpers
    
    private func createLabel(text: String, fontSize: CGFloat, fontWeight: UIFont.Weight) -> SKLabelNode {
        let label = SKLabelNode()
        label.text = text
        label.fontSize = fontSize
        
        // Use SF Rounded like the SwiftUI app
        let font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight).fontDescriptor.withDesign(.rounded)
        if let roundedFont = font {
            label.fontName = UIFont(descriptor: roundedFont, size: fontSize).fontName
        } else {
            label.fontName = UIFont.systemFont(ofSize: fontSize, weight: fontWeight).fontName
        }
        
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }
    
    private func createGestureNode() -> SKSpriteNode {
        let node = SKSpriteNode()
        node.size = CGSize(width: 100, height: 100)
        node.color = .clear
        return node
    }
    
    private func createButton(size: CGSize) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        button.fillColor = .systemBlue
        button.strokeColor = .white
        button.lineWidth = 2
        button.name = "playAgainButton"
        return button
    }
    
    // MARK: - CV Integration
    
    private func subscribeToCV() {
        guard let cvService = gameContext?.cvService else { return }
        
        // Subscribe to all events for debugging
        cvEventStream = cvService.eventStream(
            gameId: RockPaperScissorsGameModule.gameId,
            events: [] // Empty means subscribe to all events
        )
        
        cvTask = Task { [weak self] in
            guard let stream = self?.cvEventStream else { return }
            for await event in stream {
                await MainActor.run {
                    self?.handleCVEvent(event)
                }
            }
        }
        
        print("[RPS] Subscribed to CV events")
    }
    
    func handleCVEvent(_ event: CVEvent) {
        switch event.type {
        case .handDetected(let handId, let chirality):
            // Update hand indicator
            handIndicator.fillColor = .systemGreen
            print("[RPS] Hand detected: \(handId), chirality: \(chirality)")
            
        case .fingerCountDetected(let count):
            // Extract enhanced metadata from CV processor
            var handOpenness: Float = 0.5
            var inferredGesture: RPSHandPose = .unknown
            var gestureConfidence: Float = event.confidence
            
            if let metadata = event.metadata {
                handOpenness = metadata.additionalProperties["hand_openness"] as? Float ?? 0.5
                
                // Get the validated gesture from CV processor
                if let gestureString = metadata.additionalProperties["inferred_gesture"] as? String {
                    inferredGesture = RPSHandPose(rawValue: gestureString) ?? .unknown
                }
                
                // Use smoothed confidence if available
                if let smoothedConf = metadata.additionalProperties["smoothed_confidence"] as? Float {
                    gestureConfidence = smoothedConf
                }
                
                // Debug: log raw vs smoothed
                if let rawGesture = metadata.additionalProperties["raw_gesture"] as? String {
                    print("[RPS-Scene] Raw: \(rawGesture), Smoothed: \(inferredGesture), Confidence: \(String(format: "%.2f", gestureConfidence))")
                }
            }
            
            // Create metrics with all the data
            let metrics = HandMetrics(
                fingerCount: count,
                handOpenness: handOpenness,
                stability: gestureConfidence,
                position: CGPoint(x: size.width / 2, y: size.height / 2)
            )
            
            viewModel.processHandMetrics(metrics)
            updateGestureDebugDisplay(
                fingerCount: count,
                confidence: gestureConfidence,
                handOpenness: handOpenness,
                gesture: inferredGesture
            )
            updateConfidenceBar()
            
        case .handLost(let handId):
            print("[RPS] Hand lost: \(handId)")
            viewModel.handleHandLost()
            handIndicator.fillColor = .systemRed
            updateConfidenceBar()
            gestureDebugLabel.text = "No hand detected"
            
        default:
            break
        }
    }
    
    private func updateGestureDebugDisplay(fingerCount: Int, confidence: Float, handOpenness: Float, gesture: RPSHandPose? = nil) {
        let displayGesture = gesture ?? HandMetrics(fingerCount: fingerCount, handOpenness: handOpenness, stability: confidence, position: .zero).inferredPose
        let confidencePercent = Int(confidence * 100)
        let opennessPercent = Int(handOpenness * 100)
        
        gestureDebugLabel.text = "Detected: \(displayGesture.emoji) \(displayGesture.displayName) (\(confidencePercent)%) Open: \(opennessPercent)%"
        
        // Color based on confidence
        if confidence > 0.8 {
            gestureDebugLabel.fontColor = .systemGreen
        } else if confidence > 0.5 {
            gestureDebugLabel.fontColor = .systemYellow
        } else {
            gestureDebugLabel.fontColor = .systemOrange
        }
        
        // Highlight the detected gesture in the guide
        highlightDetectedGesture(displayGesture)
    }
    
    private func highlightDetectedGesture(_ gesture: RPSHandPose) {
        // Reset all gesture nodes
        for (_, node) in gestureGuideNodes.enumerated() {
            node.removeAllActions()
            node.setScale(1.0)
            node.alpha = 0.5
        }
        
        // Highlight the detected gesture
        let index: Int
        switch gesture {
        case .rock: index = 0
        case .scissors: index = 1
        case .paper: index = 2
        case .unknown: return
        }
        
        if index < gestureGuideNodes.count {
            let node = gestureGuideNodes[index]
            node.alpha = 1.0
            
            // Pulse animation
            let scaleUp = SKAction.scale(to: 1.15, duration: 0.3)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            node.run(SKAction.repeatForever(pulse))
        }
    }
    
    // MARK: - Game State Updates
    
    private func showWaitingState() {
        // Hide game elements
        countdownLabel.isHidden = true
        playerGestureNode.alpha = 0
        aiGestureNode.alpha = 0
        playerLabel.alpha = 0
        aiLabel.alpha = 0
        resultLabel.isHidden = true
        playAgainButton.isHidden = true
        
        // Show pre-game UI
        instructionLabel.text = "Practice your gestures"
        instructionLabel.isHidden = false
        startButton.isHidden = false
        gestureGuideBackground.isHidden = false
        gestureDebugBackground.isHidden = false
        
        // Pulse the start button
        startButton.removeAllActions()
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        startButton.run(SKAction.repeatForever(pulse))
        
        updateScoreDisplay()
    }
    
    private func showCountdown() {
        // Hide pre-game UI
        instructionLabel.isHidden = true
        startButton.isHidden = true
        gestureGuideBackground.isHidden = true
        gestureDebugBackground.isHidden = true
        
        // Show countdown
        countdownLabel.isHidden = false
        resultLabel.isHidden = true
        playAgainButton.isHidden = true
        
        // Prepare gesture areas
        playerGestureNode.alpha = 0
        aiGestureNode.alpha = 0
        playerLabel.alpha = 0.5
        aiLabel.alpha = 0.5
    }
    
    private func showResult() {
        countdownLabel.isHidden = true
        instructionLabel.isHidden = true
        
        // Update gesture displays
        if let lastRound = viewModel.matchState.rounds.last {
            // Show both gestures with fade-in animation
            playerGestureNode.alpha = 0
            aiGestureNode.alpha = 0
            
            playerGestureNode.texture = getGestureTexture(lastRound.playerGesture ?? .unknown)
            aiGestureNode.texture = getGestureTexture(lastRound.aiGesture ?? .unknown)
            
            // Fade in gestures
            playerGestureNode.run(SKAction.fadeIn(withDuration: 0.3))
            aiGestureNode.run(SKAction.fadeIn(withDuration: 0.3))
            
            // Update and show gesture labels - just show who played what
            playerLabel.text = "You"
            aiLabel.text = "AI"
            playerLabel.alpha = 1.0
            aiLabel.alpha = 1.0
            
            // Show result with color coding
            let resultText = lastRound.result?.displayText ?? ""
            resultLabel.text = resultText
            resultLabel.isHidden = false
            
            // Color code the result
            switch lastRound.result {
            case .playerWin:
                resultLabel.fontColor = .systemGreen
            case .aiWin:
                resultLabel.fontColor = .systemRed
            case .tie:
                resultLabel.fontColor = .systemYellow
            default:
                resultLabel.fontColor = .white
            }
            
            // Animate result
            animateResult(lastRound.result ?? .tie)
        }
        
        updateScoreDisplay()
        
        // Show play again after delay
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.showPlayAgainOption()
            }
        ]))
    }
    
    private func showPlayAgainOption() {
        if viewModel.matchState.matchResult.isComplete {
            // Match is complete
            playAgainLabel.text = "New Match"
            
            // Show final score in result label with better positioning
            let winner = viewModel.matchState.playerScore > viewModel.matchState.aiScore ? "You Win! 🎉" : "AI Wins!"
            if viewModel.matchState.playerScore == viewModel.matchState.aiScore {
                resultLabel.text = "Match Tied!"
                resultLabel.fontColor = .systemYellow
            } else {
                resultLabel.text = winner
                resultLabel.fontColor = viewModel.matchState.playerScore > viewModel.matchState.aiScore ? .systemGreen : .systemRed
            }
            
            // Adjust font size for match result to ensure it fits
            resultLabel.fontSize = 42
            
            // Hide instruction label for cleaner look
            instructionLabel.isHidden = true
        } else {
            // Just another round
            playAgainLabel.text = "Next Round"
            instructionLabel.isHidden = true
        }
        
        playAgainButton.isHidden = false
        
        // Modern bounce animation for button
        playAgainButton.setScale(0.8)
        playAgainButton.alpha = 0.0
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.3)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
        scaleDown.timingMode = .easeInEaseOut
        
        let appearGroup = SKAction.group([fadeIn, scaleUp])
        let bounce = SKAction.sequence([appearGroup, scaleDown])
        
        playAgainButton.run(bounce) { [weak self] in
            // Gentle pulse after appearing
            let gentlePulse = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 1.0),
                SKAction.scale(to: 1.0, duration: 1.0)
            ])
            self?.playAgainButton.run(SKAction.repeatForever(gentlePulse))
        }
    }
    
    // MARK: - Visual Updates
    
    private func updateScoreDisplay() {
        scoreLabel.text = "Player \(viewModel.matchState.playerScore) - \(viewModel.matchState.aiScore) AI"
    }
    
    private func updateConfidenceBar() {
        let confidence = CGFloat(viewModel.gestureConfidence)
        let maxWidth: CGFloat = 200
        
        // Animate confidence bar
        let resizeAction = SKAction.resize(
            toWidth: maxWidth * confidence,
            height: 8,
            duration: 0.1
        )
        confidenceFill.run(resizeAction)
        
        // Update color based on confidence
        if confidence > 0.8 {
            confidenceFill.fillColor = .systemGreen
        } else if confidence > 0.5 {
            confidenceFill.fillColor = .systemYellow
        } else {
            confidenceFill.fillColor = .systemRed
        }
        
        // Update instruction based on gesture during countdown
        if viewModel.isHandDetected && viewModel.roundPhase.isActive {
            if let gesture = viewModel.currentGesture {
                instructionLabel.text = "Detecting: \(gesture.emoji) \(gesture.displayName)"
                instructionLabel.fontColor = .systemGreen
            } else {
                instructionLabel.text = "Show Rock, Paper, or Scissors!"
                instructionLabel.fontColor = .systemYellow
            }
        }
    }
    
    private func getGestureTexture(_ pose: RPSHandPose) -> SKTexture? {
        // Create modern card-like background
        let bgNode = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 25)
        bgNode.fillColor = UIColor.white.withAlphaComponent(0.95)
        bgNode.strokeColor = UIColor.white
        bgNode.lineWidth = 2
        
        // Add subtle shadow effect
        let shadowNode = SKShapeNode(rectOf: CGSize(width: 100, height: 100), cornerRadius: 25)
        shadowNode.fillColor = UIColor.black.withAlphaComponent(0.3)
        shadowNode.position = CGPoint(x: 2, y: -2)
        shadowNode.zPosition = -1
        
        // Add emoji label
        let emojiLabel = SKLabelNode(text: pose.emoji)
        emojiLabel.fontSize = 60
        emojiLabel.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        bgNode.addChild(emojiLabel)
        
        // Create container for shadow and card
        let container = SKNode()
        container.addChild(shadowNode)
        container.addChild(bgNode)
        
        return view?.texture(from: container)
    }
    
    private func createGestureGuide() {
        // Background for guide
        gestureGuideBackground = SKShapeNode(rectOf: CGSize(width: 340, height: 90), cornerRadius: 20)
        gestureGuideBackground.fillColor = UIColor.black.withAlphaComponent(0.7)
        gestureGuideBackground.strokeColor = UIColor.white.withAlphaComponent(0.3)
        gestureGuideBackground.lineWidth = 1
        
        // No title needed - gestures are self-explanatory
        
        // Gesture options
        let gestures: [(emoji: String, name: String, fingers: String)] = [
            ("✊", "Rock", "0 fingers"),
            ("✌️", "Scissors", "2 fingers"),
            ("✋", "Paper", "5 fingers")
        ]
        
        let spacing: CGFloat = 110
        let startX: CGFloat = -spacing
        
        for (index, gesture) in gestures.enumerated() {
            let container = SKNode()
            container.position = CGPoint(x: startX + CGFloat(index) * spacing, y: 0)
            
            // Emoji
            let emojiLabel = SKLabelNode(text: gesture.emoji)
            emojiLabel.fontSize = 32
            emojiLabel.position = CGPoint(x: 0, y: 8)
            container.addChild(emojiLabel)
            
            // Name
            let nameLabel = createLabel(text: gesture.name, fontSize: 16, fontWeight: .medium)
            nameLabel.position = CGPoint(x: 0, y: -20)
            container.addChild(nameLabel)
            
            // Fingers - smaller and dimmer
            let fingersLabel = createLabel(text: gesture.fingers, fontSize: 11, fontWeight: .regular)
            fingersLabel.fontColor = UIColor.systemGray.withAlphaComponent(0.8)
            fingersLabel.position = CGPoint(x: 0, y: -35)
            container.addChild(fingersLabel)
            
            gestureGuideBackground.addChild(container)
            gestureGuideNodes.append(container)
        }
    }
    
    // MARK: - Animations
    
    private func animateCountdown(_ value: Int) {
        if value > 0 {
            countdownLabel.text = "\(value)"
            countdownLabel.fontSize = 120
        } else {
            countdownLabel.text = "SHOOT!"
            countdownLabel.fontSize = 80  // Smaller for SHOOT
        }
        
        // Modern spring animation
        countdownLabel.setScale(0.8)
        countdownLabel.alpha = 0.0
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        scaleDown.timingMode = .easeInEaseOut
        
        let group = SKAction.group([fadeIn, scaleUp])
        let sequence = SKAction.sequence([group, scaleDown])
        
        countdownLabel.run(sequence)
    }
    
    private func animateResult(_ result: RoundResult) {
        // Modern animations based on result
        switch result {
        case .playerWin:
            // Victory bounce for player
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            scaleDown.timingMode = .easeInEaseOut
            let rotate = SKAction.rotate(byAngle: .pi * 0.1, duration: 0.2)
            let rotateBack = SKAction.rotate(byAngle: -.pi * 0.1, duration: 0.2)
            
            let victory = SKAction.sequence([scaleUp, SKAction.group([scaleDown, rotate, rotateBack])])
            playerGestureNode.run(victory)
            
            // Shrink AI gesture
            aiGestureNode.run(SKAction.scale(to: 0.8, duration: 0.3))
            
        case .aiWin:
            // Victory bounce for AI
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            scaleDown.timingMode = .easeInEaseOut
            let rotate = SKAction.rotate(byAngle: -.pi * 0.1, duration: 0.2)
            let rotateBack = SKAction.rotate(byAngle: .pi * 0.1, duration: 0.2)
            
            let victory = SKAction.sequence([scaleUp, SKAction.group([scaleDown, rotate, rotateBack])])
            aiGestureNode.run(victory)
            
            // Shrink player gesture
            playerGestureNode.run(SKAction.scale(to: 0.8, duration: 0.3))
            
        case .tie:
            // Both gestures shake
            let shake1 = SKAction.rotate(byAngle: .pi * 0.05, duration: 0.1)
            let shake2 = SKAction.rotate(byAngle: -.pi * 0.1, duration: 0.1)
            let shake3 = SKAction.rotate(byAngle: .pi * 0.05, duration: 0.1)
            let shakeSequence = SKAction.sequence([shake1, shake2, shake3])
            
            playerGestureNode.run(shakeSequence)
            aiGestureNode.run(shakeSequence)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = atPoint(location)
        
        if node.name == "playAgainButton" || node.parent?.name == "playAgainButton" {
            handlePlayAgain()
        } else if node.name == "startButton" || node.parent?.name == "startButton" {
            if viewModel.roundPhase == .waiting {
                startButton.removeAllActions()
                startRound()
            }
        } else if node.name == "exitButton" || node.parent?.name == "exitButton" {
            // Exit the game by notifying the game context
            NotificationCenter.default.post(name: Notification.Name("ExitGame"), object: nil)
        }
    }
    
    private func startRound() {
        viewModel.startRound()
        showCountdown()
        
        // Observe countdown changes
        Task { @MainActor in
            var lastCountdownValue = -1  // Start with -1 so first value always shows
            var hasShownShoot = false
            
            while true {
                switch viewModel.roundPhase {
                case .countdown(let value):
                    if value != lastCountdownValue {
                        lastCountdownValue = value
                        animateCountdown(value)
                    }
                case .reveal:
                    if !hasShownShoot {
                        hasShownShoot = true
                        countdownLabel.text = "SHOOT!"
                        animateCountdown(0)
                    }
                case .result:
                    // Give a small delay to ensure the result is ready
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
                    showResult()
                    return
                case .waiting:
                    return
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
        }
    }
    
    private func handlePlayAgain() {
        playAgainButton.removeAllActions()
        
        if viewModel.matchState.matchResult.isComplete {
            viewModel.startNewMatch()
        } else {
            viewModel.resetToWaiting()
        }
        
        showWaitingState()
    }
    
    // MARK: - GameSceneProtocol
    
    func pauseGame() {
        isPaused = true
    }
    
    func resumeGame() {
        isPaused = false
    }
    
    // MARK: - Cleanup
    
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        // Cancel CV task immediately to prevent any further events
        cvTask?.cancel()
        cvTask = nil
        
        // Cancel any active timers in view model
        viewModel.cleanup()
    }
}
