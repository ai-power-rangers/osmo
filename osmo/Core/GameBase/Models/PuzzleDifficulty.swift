import Foundation

/// Represents the difficulty level of a puzzle
/// Used across all games to provide consistent difficulty classification
public enum PuzzleDifficulty: String, CaseIterable, Codable {
    
    // MARK: - Difficulty Levels
    
    /// Very easy puzzles, suitable for beginners or children
    case beginner = "beginner"
    
    /// Easy puzzles with basic challenges
    case easy = "easy"
    
    /// Medium difficulty puzzles
    case medium = "medium"
    
    /// Hard puzzles that require significant skill
    case hard = "hard"
    
    /// Expert level puzzles for advanced players
    case expert = "expert"
    
    /// Master level puzzles, extremely challenging
    case master = "master"
    
    // MARK: - Computed Properties
    
    /// Numeric value for comparison and sorting
    public var numericValue: Int {
        switch self {
        case .beginner: return 1
        case .easy: return 2
        case .medium: return 3
        case .hard: return 4
        case .expert: return 5
        case .master: return 6
        }
    }
    
    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        case .master: return "Master"
        }
    }
    
    /// Short abbreviation for compact display
    public var abbreviation: String {
        switch self {
        case .beginner: return "B"
        case .easy: return "E"
        case .medium: return "M"
        case .hard: return "H"
        case .expert: return "X"
        case .master: return "★"
        }
    }
    
    /// Description of what the difficulty level means
    public var description: String {
        switch self {
        case .beginner:
            return "Perfect for first-time players and children"
        case .easy:
            return "Simple puzzles with clear solutions"
        case .medium:
            return "Moderate challenge requiring some thought"
        case .hard:
            return "Challenging puzzles for experienced players"
        case .expert:
            return "Very difficult puzzles requiring advanced skills"
        case .master:
            return "Extremely challenging puzzles for puzzle masters"
        }
    }
    
    /// Icon name for the difficulty (SF Symbols)
    public var iconName: String {
        switch self {
        case .beginner: return "1.circle"
        case .easy: return "2.circle"
        case .medium: return "3.circle"
        case .hard: return "4.circle"
        case .expert: return "5.circle"
        case .master: return "star.circle"
        }
    }
    
    /// Color associated with the difficulty level
    public var colorName: String {
        switch self {
        case .beginner: return "green"
        case .easy: return "blue"
        case .medium: return "yellow"
        case .hard: return "orange"
        case .expert: return "red"
        case .master: return "purple"
        }
    }
    
    /// Expected completion time range (in minutes)
    public var expectedTimeRange: ClosedRange<Int> {
        switch self {
        case .beginner: return 1...5
        case .easy: return 3...10
        case .medium: return 8...20
        case .hard: return 15...45
        case .expert: return 30...90
        case .master: return 60...180
        }
    }
    
    /// Suggested age range for this difficulty
    public var suggestedAgeRange: ClosedRange<Int> {
        switch self {
        case .beginner: return 4...8
        case .easy: return 6...12
        case .medium: return 10...99
        case .hard: return 12...99
        case .expert: return 16...99
        case .master: return 18...99
        }
    }
    
    // MARK: - Comparison
    
    /// Returns true if this difficulty is easier than the other
    public func isEasierThan(_ other: PuzzleDifficulty) -> Bool {
        return self.numericValue < other.numericValue
    }
    
    /// Returns true if this difficulty is harder than the other
    public func isHarderThan(_ other: PuzzleDifficulty) -> Bool {
        return self.numericValue > other.numericValue
    }
    
    /// Returns the next difficulty level, or nil if already at master
    public var nextLevel: PuzzleDifficulty? {
        switch self {
        case .beginner: return .easy
        case .easy: return .medium
        case .medium: return .hard
        case .hard: return .expert
        case .expert: return .master
        case .master: return nil
        }
    }
    
    /// Returns the previous difficulty level, or nil if already at beginner
    public var previousLevel: PuzzleDifficulty? {
        switch self {
        case .beginner: return nil
        case .easy: return .beginner
        case .medium: return .easy
        case .hard: return .medium
        case .expert: return .hard
        case .master: return .expert
        }
    }
}

// MARK: - Comparable Conformance

extension PuzzleDifficulty: Comparable {
    public static func < (lhs: PuzzleDifficulty, rhs: PuzzleDifficulty) -> Bool {
        return lhs.numericValue < rhs.numericValue
    }
}

// MARK: - Utility Extensions

extension Array where Element == PuzzleDifficulty {
    
    /// Returns the array sorted by difficulty (easiest first)
    public func sortedByDifficulty() -> [PuzzleDifficulty] {
        return self.sorted()
    }
    
    /// Returns difficulties up to and including the specified maximum
    public func upTo(_ maxDifficulty: PuzzleDifficulty) -> [PuzzleDifficulty] {
        return self.filter { $0 <= maxDifficulty }
    }
    
    /// Returns difficulties starting from the specified minimum
    public func from(_ minDifficulty: PuzzleDifficulty) -> [PuzzleDifficulty] {
        return self.filter { $0 >= minDifficulty }
    }
}