import SwiftUI

/// Generic puzzle card view that works with any GamePuzzleProtocol
/// Provides consistent UI for displaying puzzles across all games
public struct PuzzleCardView<Puzzle: GamePuzzleProtocol>: View {
    
    // MARK: - Properties
    
    let puzzle: Puzzle
    let onPlay: (Puzzle) -> Void
    let onEdit: ((Puzzle) -> Void)?
    let onDelete: ((Puzzle) -> Void)?
    let onDuplicate: ((Puzzle) -> Void)?
    
    @State private var showingDeleteConfirmation = false
    @State private var isPressed = false
    @State private var showingShareSheet = false
    
    // MARK: - Initialization
    
    public init(
        puzzle: Puzzle,
        onPlay: @escaping (Puzzle) -> Void,
        onEdit: ((Puzzle) -> Void)? = nil,
        onDelete: ((Puzzle) -> Void)? = nil,
        onDuplicate: ((Puzzle) -> Void)? = nil
    ) {
        self.puzzle = puzzle
        self.onPlay = onPlay
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Header with title and badges
            headerView
            
            // Preview area
            previewArea
            
            // Statistics and metadata
            statisticsView
            
            // Action buttons
            actionButtons
        }
        .padding(Spacing.m)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .shadow(
            color: AppColors.cardShadow,
            radius: Shadow.medium.radius,
            x: 0,
            y: Shadow.medium.y
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(Animations.quick, value: isPressed)
        .contextMenu {
            contextMenuContent
        }
        .confirmationDialog(
            "Delete Puzzle",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            deleteConfirmationButtons
        } message: {
            Text("Are you sure you want to delete '\(puzzle.name)'? This action cannot be undone.")
        }
        // Share functionality removed - UIKit dependency
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(puzzle.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let description = puzzle.puzzleDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let author = puzzle.author, !author.isEmpty {
                    Text("by \(author)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                DifficultyBadge(difficulty: puzzle.difficulty, style: .compact)
                
                if puzzle.hasBeenCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Preview Area
    
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(.quaternary)
                .frame(height: 80)
            
            if let previewData = puzzle.previewImageData,
               let uiImage = UIImage(data: previewData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            } else {
                // Default preview with puzzle type icon
                VStack {
                    Image(systemName: puzzleTypeIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Text(puzzleTypeName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Completion overlay
            if puzzle.hasBeenCompleted {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(.green.opacity(0.1))
                    .overlay {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
            }
        }
        .onTapGesture {
            withAnimation(Animations.quick) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(Animations.quick) {
                    isPressed = false
                }
                onPlay(puzzle)
            }
        }
    }
    
    // MARK: - Statistics View
    
    private var statisticsView: some View {
        HStack(spacing: Spacing.m) {
            // Play count
            StatisticItem(
                icon: "play.circle",
                label: "Played",
                value: "\(puzzle.playCount)"
            )
            
            // Completion rate
            if puzzle.playCount > 0 {
                StatisticItem(
                    icon: "chart.bar",
                    label: "Success",
                    value: "\(Int(puzzle.completionRate * 100))%"
                )
            }
            
            // Best time
            if let bestTimeFormatted = puzzle.bestTimeFormatted {
                StatisticItem(
                    icon: "timer",
                    label: "Best",
                    value: bestTimeFormatted
                )
            }
            
            Spacer()
            
            // Creation date
            Text(puzzle.createdAt, style: .date)
                .font(.caption2)
                .foregroundColor(Color.secondary.opacity(0.6))
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: Spacing.s) {
            // Primary play button
            GameActionButton(
                title: "Play",
                icon: "play.fill",
                style: .primary
            ) {
                onPlay(puzzle)
            }
            
            // Secondary actions
            if onEdit != nil || onDuplicate != nil {
                Menu {
                    if let onEdit = onEdit {
                        Button("Edit", systemImage: "pencil") {
                            onEdit(puzzle)
                        }
                    }
                    
                    if let onDuplicate = onDuplicate {
                        Button("Duplicate", systemImage: "doc.on.doc") {
                            onDuplicate(puzzle)
                        }
                    }
                    
                    Divider()
                    
                    // Share button removed - would require UIKit
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .frame(width: Layout.minButtonHeight, height: Layout.minButtonHeight)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    private var contextMenuContent: some View {
        Group {
            Button("Play", systemImage: "play.fill") {
                onPlay(puzzle)
            }
            
            if let onEdit = onEdit {
                Button("Edit", systemImage: "pencil") {
                    onEdit(puzzle)
                }
            }
            
            if let onDuplicate = onDuplicate {
                Button("Duplicate", systemImage: "doc.on.doc") {
                    onDuplicate(puzzle)
                }
            }
            
            Divider()
            
            Button("Share", systemImage: "square.and.arrow.up") {
                showingShareSheet = true
            }
            
            if let onDelete = onDelete {
                Divider()
                
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
    }
    
    // MARK: - Delete Confirmation
    
    private var deleteConfirmationButtons: some View {
        Group {
            Button("Delete", role: .destructive) {
                onDelete?(puzzle)
            }
            
            Button("Cancel", role: .cancel) {
                // Cancel action
            }
        }
    }
    
    // MARK: - Share Functionality
    
    private func generateShareText() -> String {
        var shareText = "🎮 \(puzzle.name)\n"
        shareText += "Difficulty: \(puzzle.difficulty.displayName)\n"
        
        if puzzle.hasBeenCompleted {
            shareText += "✅ Completed \(puzzle.completionCount) time\(puzzle.completionCount == 1 ? "" : "s")\n"
            if let bestTime = puzzle.bestTimeFormatted {
                shareText += "⏱️ Best time: \(bestTime)\n"
            }
        } else {
            shareText += "🎯 Not yet completed\n"
        }
        
        if let author = puzzle.author {
            shareText += "Created by: \(author)\n"
        }
        
        shareText += "\nPlayed with Osmo App!"
        
        return shareText
    }
    
    // MARK: - Computed Properties
    
    private var puzzleTypeIcon: String {
        // Default icon - can be customized per puzzle type
        let typeName = String(describing: type(of: puzzle))
        
        switch typeName {
        case let name where name.contains("Tangram"):
            return "triangle"
        case let name where name.contains("Sudoku"):
            return "grid"
        case let name where name.contains("Puzzle"):
            return "puzzlepiece"
        default:
            return "gamecontroller"
        }
    }
    
    private var puzzleTypeName: String {
        let typeName = String(describing: type(of: puzzle))
        return typeName.replacingOccurrences(of: "Puzzle", with: "")
    }
}

// MARK: - Statistic Item

/// Helper view for displaying individual statistics
private struct StatisticItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview Support

#if DEBUG
// Create a sample puzzle type for previews
private struct SamplePuzzle: GamePuzzleProtocol {
    let id: String = UUID().uuidString
    var name: String = "Sample Puzzle"
    var difficulty: PuzzleDifficulty = .medium
    let createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    typealias PieceType = String
    typealias StateType = String
    
    var initialState: String = "initial"
    var targetState: String = "target"
    var currentState: String = "initial"
    var pieces: [String] = ["piece1", "piece2"]
    var previewImageData: Data?
    var tags: Set<String> = ["sample"]
    var author: String? = "Sample Author"
    var puzzleDescription: String? = "A sample puzzle for testing"
    let version: Int = 1
    var playCount: Int = 5
    var bestTime: TimeInterval? = 120
    var averageTime: TimeInterval? = 180
    var completionCount: Int = 3
    
    init(name: String, difficulty: PuzzleDifficulty) {
        self.name = name
        self.difficulty = difficulty
    }
    
    func isValid() -> Bool { true }
    func copy() -> SamplePuzzle { self }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(PuzzleDifficulty.allCases, id: \.self) { difficulty in
                PuzzleCardView(
                    puzzle: SamplePuzzle(
                        name: "\(difficulty.displayName) Puzzle",
                        difficulty: difficulty
                    ),
                    onPlay: { _ in },
                    onEdit: { _ in },
                    onDelete: { _ in },
                    onDuplicate: { _ in }
                )
            }
        }
        .padding()
    }
}
#endif