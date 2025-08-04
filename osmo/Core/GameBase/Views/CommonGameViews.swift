import SwiftUI

// MARK: - Game UI Constants

/// Constants for consistent UI styling across all games
public struct GameUIConstants {
    
    // MARK: - Spacing
    public static let smallSpacing: CGFloat = 8
    public static let mediumSpacing: CGFloat = 16
    public static let largeSpacing: CGFloat = 24
    public static let extraLargeSpacing: CGFloat = 32
    
    // MARK: - Corner Radius
    public static let smallCornerRadius: CGFloat = 8
    public static let mediumCornerRadius: CGFloat = 12
    public static let largeCornerRadius: CGFloat = 16
    
    // MARK: - Animation
    public static let standardAnimation: Animation = .easeInOut(duration: 0.3)
    public static let quickAnimation: Animation = .easeInOut(duration: 0.15)
    public static let slowAnimation: Animation = .easeInOut(duration: 0.6)
    
    // MARK: - Sizes
    public static let buttonHeight: CGFloat = 44
    public static let cardMinHeight: CGFloat = 120
    public static let iconSize: CGFloat = 24
    public static let largeIconSize: CGFloat = 32
    
    // MARK: - Shadow
    public static let cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
        (.black.opacity(0.1), 4, 0, 2)
}

// MARK: - Game Status Badge

/// Badge showing current game status
public struct GameStatusBadge: View {
    let gameState: GameState
    let isComplete: Bool
    
    public init(gameState: GameState, isComplete: Bool = false) {
        self.gameState = gameState
        self.isComplete = isComplete
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: gameState.iconName)
                .font(.caption)
            
            Text(gameState.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        if isComplete {
            return .green.opacity(0.2)
        }
        
        switch gameState {
        case .playing:
            return .blue.opacity(0.2)
        case .paused:
            return .orange.opacity(0.2)
        case .error:
            return .red.opacity(0.2)
        default:
            return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        if isComplete {
            return .green
        }
        
        switch gameState {
        case .playing:
            return .blue
        case .paused:
            return .orange
        case .error:
            return .red
        default:
            return .secondary
        }
    }
}

// MARK: - Difficulty Badge

/// Badge showing puzzle difficulty level
public struct DifficultyBadge: View {
    let difficulty: PuzzleDifficulty
    let style: BadgeStyle
    
    public enum BadgeStyle {
        case full      // Shows full name
        case compact   // Shows abbreviation
        case icon      // Shows icon only
    }
    
    public init(difficulty: PuzzleDifficulty, style: BadgeStyle = .full) {
        self.difficulty = difficulty
        self.style = style
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difficulty.iconName)
                .font(.caption)
            
            if style != .icon {
                Text(displayText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, style == .icon ? 6 : 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .clipShape(Capsule())
    }
    
    private var displayText: String {
        switch style {
        case .full:
            return difficulty.displayName
        case .compact:
            return difficulty.abbreviation
        case .icon:
            return ""
        }
    }
    
    private var backgroundColor: Color {
        switch difficulty {
        case .beginner:
            return .green.opacity(0.2)
        case .easy:
            return .blue.opacity(0.2)
        case .medium:
            return .yellow.opacity(0.2)
        case .hard:
            return .orange.opacity(0.2)
        case .expert:
            return .red.opacity(0.2)
        case .master:
            return .purple.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch difficulty {
        case .beginner:
            return .green
        case .easy:
            return .blue
        case .medium:
            return .yellow
        case .hard:
            return .orange
        case .expert:
            return .red
        case .master:
            return .purple
        }
    }
}

// MARK: - Game Timer View

/// View displaying elapsed time in a game
public struct GameTimerView: View {
    let elapsedTime: TimeInterval
    let isRunning: Bool
    
    public init(elapsedTime: TimeInterval, isRunning: Bool) {
        self.elapsedTime = elapsedTime
        self.isRunning = isRunning
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isRunning ? "timer" : "pause.circle")
                .font(.caption)
                .foregroundColor(isRunning ? .blue : .orange)
            
            Text(formattedTime)
                .font(.caption.monospacedDigit())
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }
    
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Progress Ring

/// Circular progress indicator for game completion
public struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    public init(progress: Double, lineWidth: CGFloat = 4, size: CGFloat = 40) {
        self.progress = max(0, min(1, progress))
        self.lineWidth = lineWidth
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    .blue,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Progress text
            if progress > 0 {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Action Buttons

/// Primary action button with consistent styling
public struct GameActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: ButtonStyle
    let isEnabled: Bool
    
    public enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    public init(
        title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: GameUIConstants.iconSize))
                }
                
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: GameUIConstants.buttonHeight)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: GameUIConstants.mediumCornerRadius))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .blue
        case .secondary:
            return .gray.opacity(0.2)
        case .destructive:
            return .red
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .primary
        }
    }
}

// MARK: - Game Statistics View

/// View showing game statistics
public struct GameStatsView: View {
    let moveCount: Int
    let score: Int
    let bestTime: TimeInterval?
    
    public init(moveCount: Int, score: Int, bestTime: TimeInterval? = nil) {
        self.moveCount = moveCount
        self.score = score
        self.bestTime = bestTime
    }
    
    public var body: some View {
        HStack(spacing: GameUIConstants.mediumSpacing) {
            StatItem(
                title: "Moves",
                value: "\(moveCount)",
                icon: "arrow.clockwise"
            )
            
            StatItem(
                title: "Score",
                value: "\(score)",
                icon: "star.fill"
            )
            
            if let bestTime = bestTime {
                StatItem(
                    title: "Best",
                    value: formatTime(bestTime),
                    icon: "trophy.fill"
                )
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Individual statistic item
private struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Empty State View

/// View displayed when no content is available
public struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        title: String,
        message: String,
        icon: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: GameUIConstants.mediumSpacing) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: GameUIConstants.smallSpacing) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                GameActionButton(
                    title: actionTitle,
                    action: action
                )
                .frame(maxWidth: 200)
            }
        }
        .padding(GameUIConstants.extraLargeSpacing)
    }
}

// MARK: - Loading View

/// Standard loading view for games
public struct GameLoadingView: View {
    let message: String
    
    public init(message: String = "Loading...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: GameUIConstants.mediumSpacing) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}