# Rock-Paper-Scissors Game Design Document

## Overview
Real-time hand gesture recognition game where players use physical hand gestures to play rock-paper-scissors against an AI opponent. The game leverages advanced hand pose detection to recognize rock (fist), paper (open hand), and scissors (two fingers) gestures.

## Game Flow

### 1. Setup Phase
- User positions hand in camera view
- Game shows hand detection overlay
- Confirms hand tracking is active
- User presses "Start Game" to begin

### 2. Gameplay Phase
**Round Structure:**
- 3-second countdown with audio/visual cues
- "Rock... Paper... Scissors... Shoot!"
- Both player and AI reveal simultaneously
- Player makes physical hand gesture
- AI shows choice on screen

**Gesture Recognition:**
- Continuous hand tracking during countdown
- Gesture locked at "Shoot!" moment
- Immediate result calculation
- Visual feedback for win/lose/tie

### 3. Match Structure
- Best of 5 rounds
- Running score display
- Match winner celebration
- Statistics tracking (win rate, most used gesture)

## Technical Integration

### CV Events Required
```swift
enum RockPaperScissorsCVEvent {
    case handDetected(handId: UUID, chirality: HandChirality)
    case handPoseChanged(handId: UUID, pose: HandPose)
    case handLost(handId: UUID)
    case gestureConfidence(gesture: Gesture, confidence: Float)
}

enum HandPose {
    case rock      // Closed fist
    case paper     // Open palm
    case scissors  // Index and middle finger extended
    case unknown   // Transitioning or unclear
}
```

### CV Detection Strategy

#### Hand Pose Recognition
1. **Hand Tracking**: Use ARKit hand tracking with 21 joint positions
2. **Gesture Classification**:
   - **Rock**: All fingers curled (low fingertip Y positions)
   - **Paper**: All fingers extended (high fingertip Y positions)
   - **Scissors**: Index + middle extended, others curled
3. **Confidence Scoring**: Require 80%+ confidence for valid gesture
4. **Temporal Smoothing**: Average last 3 frames to reduce jitter

#### Advanced Detection Features
```swift
struct HandMetrics {
    let fingerExtensions: [Bool]  // Per finger: extended or curled
    let palmOrientation: simd_float3
    let handOpenness: Float       // 0.0 (fist) to 1.0 (open)
    let gestureStability: Float   // How long held in position
}
```

### Game Architecture

#### RockPaperScissorsGameModule
```swift
final class RockPaperScissorsGameModule: GameModule {
    static let gameId = "rock-paper-scissors"
    static let gameInfo = GameInfo(
        title: "Rock Paper Scissors",
        description: "Classic hand gesture game with AI opponent",
        iconName: "hand.raised",
        category: .action,
        minPlayers: 1,
        maxPlayers: 1
    )
    
    func createGameScene(size: CGSize, context: GameContext) -> SKScene {
        return RockPaperScissorsGameScene(size: size, gameContext: context)
    }
}
```

#### RockPaperScissorsViewModel
```swift
@Observable
final class RockPaperScissorsViewModel {
    // Game state
    var currentRound = 1
    var playerScore = 0
    var aiScore = 0
    var roundPhase: RoundPhase = .waiting
    var matchResult: MatchResult?
    
    // CV state
    var isHandDetected = false
    var currentGesture: HandPose = .unknown
    var gestureConfidence: Float = 0.0
    var handChirality: HandChirality = .right
    
    // AI state
    var aiDifficulty: Difficulty = .medium
    var aiChoice: HandPose?
    var aiStrategy: AIStrategy = .adaptive
    
    // Timing
    var countdownValue = 3
    private var countdownTimer: Task<Void, Never>?
    
    // Game logic
    func startRound() { }
    func lockInGesture() -> HandPose { }
    func calculateResult(player: HandPose, ai: HandPose) -> RoundResult { }
    func updateMatchScore(_ result: RoundResult) { }
}
```

#### RockPaperScissorsGameScene
```swift
final class RockPaperScissorsGameScene: SKScene, GameSceneProtocol {
    // Visual elements
    private var countdownLabel: SKLabelNode!
    private var playerGestureNode: SKSpriteNode!
    private var aiGestureNode: SKSpriteNode!
    private var scoreBoard: SKNode!
    
    // Animation sequences
    private func animateCountdown() {
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.3)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        
        countdownLabel.run(pulse)
    }
    
    private func revealGestures() {
        // Simultaneous reveal animation
        let flipDuration = 0.3
        let firstHalf = SKAction.scaleX(to: 0.0, duration: flipDuration/2)
        let changeTexture = SKAction.run { [weak self] in
            self?.updateGestureTextures()
        }
        let secondHalf = SKAction.scaleX(to: 1.0, duration: flipDuration/2)
        
        let flip = SKAction.sequence([firstHalf, changeTexture, secondHalf])
        playerGestureNode.run(flip)
        aiGestureNode.run(flip)
    }
}
```

### AI Strategy

#### Difficulty Levels

1. **Easy Mode**
   - Random selection with equal probability
   - No pattern recognition
   - 33% win rate expected

2. **Medium Mode**
   - Basic pattern recognition
   - Tracks last 3 player moves
   - Slightly favors counter to most frequent
   - ~40-45% win rate

3. **Hard Mode**
   - Advanced pattern matching
   - Markov chain prediction
   - Adapts to player tendencies
   - Psychological modeling
   - ~55-60% win rate

#### Adaptive AI Implementation
```swift
class AdaptiveAI {
    private var moveHistory: [HandPose] = []
    private var transitionMatrix: [[Double]] = Array(
        repeating: Array(repeating: 0.33, count: 3), 
        count: 3
    )
    
    func predictNextMove() -> HandPose {
        guard let lastMove = moveHistory.last else {
            return randomMove()
        }
        
        // Use transition probabilities
        let probabilities = transitionMatrix[lastMove.index]
        let prediction = weightedRandom(probabilities)
        
        // Return counter move
        return counterMove(for: prediction)
    }
    
    func updateHistory(_ playerMove: HandPose) {
        moveHistory.append(playerMove)
        if moveHistory.count > 2 {
            updateTransitionMatrix()
        }
    }
}
```

### Visual Design

#### Hand Tracking Overlay
- Wireframe hand skeleton showing tracked joints
- Color coding: Green (detected), Yellow (low confidence), Red (lost)
- Gesture icon preview in corner
- Confidence meter bar

#### Game Animation
- Countdown: Large centered numbers with bounce effect
- Gesture reveal: Card flip animation
- Win effect: Particle burst in winning color
- Lose effect: Subtle shake animation
- Tie effect: Split-screen pulse

#### UI Layout
```
┌─────────────────────────────┐
│  Score: Player 2 - 1 AI     │
├─────────────────────────────┤
│                             │
│         [Camera             │
│          Preview            │
│          with Hand          │
│          Overlay]           │
│                             │
├─────────────────────────────┤
│     Player  ?  vs  ?  AI    │
│                             │
│         ROUND 3/5           │
└─────────────────────────────┘
```

### Performance Optimization

#### Real-time Requirements
- 30 FPS minimum for smooth hand tracking
- < 100ms gesture recognition latency
- Gesture lock-in within 1 frame of "Shoot!"

#### Optimization Strategies
1. **Efficient Hand Processing**
   ```swift
   // Process only essential joints for gestures
   let criticalJoints: Set<HandSkeleton.JointName> = [
       .indexFingerTip, .middleFingerTip,
       .ringFingerTip, .littleFingerTip,
       .thumbTip, .wrist
   ]
   ```

2. **Gesture Caching**
   - Pre-calculate gesture templates
   - Use lookup tables for comparisons
   - Cache confidence thresholds

3. **Frame Skipping**
   - Full processing every 2nd frame
   - Interpolate for visual smoothness

### Audio Design

#### Sound Effects
- Countdown beats: "tick" sound for each number
- "Shoot!" announcement: Energetic voice clip
- Win sound: Triumphant chord
- Lose sound: Descending notes
- Tie sound: Neutral buzz

#### Haptic Feedback
- Light tap: Each countdown beat
- Medium impact: Gesture lock-in
- Success pattern: Win round
- Error buzz: Invalid gesture

### Error Handling

#### CV Challenges
1. **Hand Not Detected**
   - Show positioning guide
   - "Please show your hand to the camera"
   - Pause countdown until detected

2. **Ambiguous Gesture**
   - Request clearer gesture
   - Show example images
   - Allow gesture retry

3. **Multiple Hands**
   - Track dominant hand only
   - Show which hand is active
   - Ignore second hand

4. **Poor Lighting**
   - Suggest better lighting
   - Increase exposure compensation
   - Fallback to high-contrast mode

### Accessibility

#### Features
- Voice announcements for all game events
- High contrast gesture indicators
- Adjustable countdown speed
- One-handed play support
- Alternative input via buttons

#### VoiceOver Support
```swift
countdownLabel.accessibilityLabel = "Countdown: \(value) seconds"
playerGestureNode.accessibilityLabel = "Your gesture: \(gesture.name)"
scoreLabel.accessibilityLabel = "Score: Player \(playerScore), AI \(aiScore)"
```

### Analytics Events

```swift
struct RPSAnalytics {
    static let matchStarted = "rps_match_started"
    static let roundPlayed = "rps_round_played"
    static let matchCompleted = "rps_match_completed"
    static let gestureRecognized = "rps_gesture_recognized"
    static let recognitionFailed = "rps_recognition_failed"
    
    // Properties
    struct Properties {
        static let gesture = "gesture"
        static let confidence = "confidence"
        static let roundNumber = "round_number"
        static let difficulty = "difficulty"
        static let result = "result"
        static let finalScore = "final_score"
    }
}
```

### Testing Strategy

#### Unit Tests
- Gesture classification accuracy
- AI strategy behavior
- Score calculation
- Round state management

#### Performance Tests
- Gesture recognition latency
- Frame rate under load
- Memory usage during matches

#### Integration Tests
- CV service communication
- Audio/haptic timing
- Analytics event firing

### Future Enhancements

1. **Multiplayer Mode**: Two players via split screen
2. **Tournament Mode**: Bracket-style competition
3. **Custom Gestures**: Lizard, Spock variants
4. **Motion Gestures**: Detect throwing motion
5. **AR Overlays**: Virtual game elements
6. **Gesture Training**: Practice mode with feedback
7. **Global Leaderboard**: Online score tracking
8. **Replay System**: Record and share matches

### Success Metrics

- Hand detection rate > 98%
- Gesture recognition accuracy > 95%
- Average round time < 10 seconds
- Player retention > 70% after 5 matches
- Frame rate consistently ≥ 30 FPS