import Foundation

/// Protocol that defines the contract for all game puzzles
/// Ensures consistent structure across all puzzle types (Tangram, Sudoku, etc.)
public protocol GamePuzzleProtocol: Identifiable, Codable, Hashable {
    
    // MARK: - Required Properties
    
    /// Unique identifier for the puzzle
    var id: String { get }
    
    /// Human-readable name of the puzzle
    var name: String { get set }
    
    /// Difficulty level of the puzzle
    var difficulty: PuzzleDifficulty { get set }
    
    /// When the puzzle was created
    var createdAt: Date { get }
    
    /// When the puzzle was last modified
    var updatedAt: Date { get set }
    
    // MARK: - Associated Types
    
    /// The type representing a piece or element in this puzzle
    associatedtype PieceType: Codable, Hashable
    
    /// The type representing the game state for this puzzle
    associatedtype StateType: Codable, Hashable
    
    // MARK: - State Properties
    
    /// The initial state of the puzzle (how it starts)
    var initialState: StateType { get }
    
    /// The target/solution state of the puzzle (what success looks like)
    var targetState: StateType { get }
    
    /// The current state of the puzzle (for saved games)
    var currentState: StateType { get set }
    
    // MARK: - Puzzle Content
    
    /// The pieces or elements that make up this puzzle
    var pieces: [PieceType] { get set }
    
    /// Optional preview image data for the puzzle
    var previewImageData: Data? { get set }
    
    /// Optional tags for categorizing puzzles
    var tags: Set<String> { get set }
    
    // MARK: - Metadata
    
    /// Author or creator of the puzzle
    var author: String? { get set }
    
    /// Description or instructions for the puzzle
    var puzzleDescription: String? { get set }
    
    /// Version of the puzzle format (for migration)
    var version: Int { get }
    
    // MARK: - Statistics
    
    /// Number of times this puzzle has been played
    var playCount: Int { get set }
    
    /// Best completion time in seconds (nil if never completed)
    var bestTime: TimeInterval? { get set }
    
    /// Average completion time in seconds (nil if never completed)
    var averageTime: TimeInterval? { get set }
    
    /// Number of times this puzzle has been completed
    var completionCount: Int { get set }
    
    // MARK: - Required Methods
    
    /// Creates a new puzzle with default initial state
    init(name: String, difficulty: PuzzleDifficulty)
    
    /// Validates that the puzzle is solvable and well-formed
    /// - Returns: True if the puzzle is valid
    func isValid() -> Bool
    
    /// Checks if the current state matches the target state (puzzle is solved)
    /// - Returns: True if the puzzle is completed
    func isCompleted() -> Bool
    
    /// Resets the puzzle to its initial state
    mutating func reset()
    
    /// Creates a copy of the puzzle for independent play
    /// - Returns: A new puzzle instance with the same configuration
    func copy() -> Self
    
    /// Calculates a difficulty score for this specific puzzle instance
    /// - Returns: A numeric difficulty score (higher = more difficult)
    func calculateDifficultyScore() -> Double
    
    /// Updates the puzzle's updatedAt timestamp
    mutating func touch()
    
    /// Records a play session
    /// - Parameters:
    ///   - completed: Whether the puzzle was completed
    ///   - time: Time taken in seconds
    mutating func recordPlay(completed: Bool, time: TimeInterval)
}

// MARK: - Default Implementations

public extension GamePuzzleProtocol {
    
    /// Default implementation updates the timestamp
    mutating func touch() {
        updatedAt = Date()
    }
    
    /// Default implementation for recording play statistics
    mutating func recordPlay(completed: Bool, time: TimeInterval) {
        playCount += 1
        
        if completed {
            completionCount += 1
            
            // Update best time
            if let currentBest = bestTime {
                if time < currentBest {
                    bestTime = time
                }
            } else {
                bestTime = time
            }
            
            // Update average time
            if let currentAverage = averageTime {
                averageTime = ((currentAverage * Double(completionCount - 1)) + time) / Double(completionCount)
            } else {
                averageTime = time
            }
        }
        
        touch()
    }
    
    /// Default completion check compares current state to target state
    func isCompleted() -> Bool {
        return currentState == targetState
    }
    
    /// Default reset implementation
    mutating func reset() {
        currentState = initialState
        touch()
    }
    
    /// Default difficulty score calculation based on difficulty enum
    func calculateDifficultyScore() -> Double {
        return Double(difficulty.numericValue)
    }
    
    /// Default validation - subclasses should override for specific validation
    func isValid() -> Bool {
        return !name.isEmpty && !pieces.isEmpty
    }
    
    /// Completion percentage (0.0 to 1.0)
    var completionRate: Double {
        guard playCount > 0 else { return 0.0 }
        return Double(completionCount) / Double(playCount)
    }
    
    /// Whether this puzzle has ever been completed
    var hasBeenCompleted: Bool {
        return completionCount > 0
    }
    
    /// Whether this puzzle has been played before
    var hasBeenPlayed: Bool {
        return playCount > 0
    }
    
    /// Human-readable completion status
    var completionStatus: String {
        if !hasBeenPlayed {
            return "Not played"
        } else if !hasBeenCompleted {
            return "Not completed"
        } else if completionCount == 1 {
            return "Completed once"
        } else {
            return "Completed \(completionCount) times"
        }
    }
    
    /// Formatted best time string
    var bestTimeFormatted: String? {
        guard let bestTime = bestTime else { return nil }
        return formatTime(bestTime)
    }
    
    /// Formatted average time string
    var averageTimeFormatted: String? {
        guard let averageTime = averageTime else { return nil }
        return formatTime(averageTime)
    }
    
    /// Helper to format time intervals
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Puzzle Collection Extensions

public extension Array where Element: GamePuzzleProtocol {
    
    /// Filters puzzles by difficulty level
    /// - Parameter difficulty: The difficulty to filter by
    /// - Returns: Puzzles matching the difficulty
    func byDifficulty(_ difficulty: PuzzleDifficulty) -> [Element] {
        return filter { $0.difficulty == difficulty }
    }
    
    /// Filters puzzles by completion status
    /// - Parameter completed: Whether to include completed or uncompleted puzzles
    /// - Returns: Filtered puzzles
    func byCompletionStatus(_ completed: Bool) -> [Element] {
        return filter { $0.hasBeenCompleted == completed }
    }
    
    /// Sorts puzzles by difficulty (easiest first)
    /// - Returns: Sorted puzzles
    func sortedByDifficulty() -> [Element] {
        return sorted { $0.difficulty < $1.difficulty }
    }
    
    /// Sorts puzzles by best time (fastest first)
    /// - Returns: Sorted puzzles
    func sortedByBestTime() -> [Element] {
        return sorted { puzzle1, puzzle2 in
            guard let time1 = puzzle1.bestTime else { return false }
            guard let time2 = puzzle2.bestTime else { return true }
            return time1 < time2
        }
    }
    
    /// Sorts puzzles by creation date (newest first)
    /// - Returns: Sorted puzzles
    func sortedByCreationDate() -> [Element] {
        return sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Filters puzzles that contain any of the specified tags
    /// - Parameter tags: Tags to search for
    /// - Returns: Puzzles containing at least one of the tags
    func withTags(_ tags: Set<String>) -> [Element] {
        return filter { !$0.tags.isDisjoint(with: tags) }
    }
}