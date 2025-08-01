import SwiftUI

struct TangramPuzzleSelectView: View {
    @Environment(AppCoordinator.self) var coordinator
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var blueprintStore = BlueprintStore()
    
    // Adaptive grid columns based on device size
    private var gridColumns: [GridItem] {
        let minSize: CGFloat = horizontalSizeClass == .compact ? 150 : 200
        let spacing: CGFloat = 20
        return [GridItem(.adaptive(minimum: minSize), spacing: spacing)]
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 20) {
                    // Available puzzles
                    ForEach(blueprintStore.puzzles) { puzzle in
                        PuzzleThumbnail(puzzle: puzzle) {
                            launchPuzzle(puzzle)
                        }
                        .frame(height: thumbnailHeight)
                    }
                    
                    // Placeholder slots for future puzzles
                    ForEach(0..<placeholderCount, id: \.self) { _ in
                        ComingSoonThumbnail()
                            .frame(height: thumbnailHeight)
                    }
                }
                .padding(horizontalSizeClass == .compact ? 10 : 20)
            }
        }
        .navigationTitle("Select a Puzzle")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            blueprintStore.loadAll()
        }
    }
    
    // MARK: - Computed Properties
    
    private var thumbnailHeight: CGFloat {
        horizontalSizeClass == .compact ? 150 : 200
    }
    
    private var placeholderCount: Int {
        max(0, 6 - blueprintStore.puzzles.count)
    }
    
    // MARK: - Actions
    
    private func launchPuzzle(_ puzzle: Puzzle) {
        // For now, just launch the game
        // In the future, we'll pass the puzzle data through GameContext
        coordinator.launchGame("tangram")
    }
}

// MARK: - Puzzle Thumbnail
struct PuzzleThumbnail: View {
    let puzzle: Puzzle
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Puzzle preview shape
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.gradient)
                        .shadow(radius: 4)
                    
                    // Placeholder shape icon until we have real previews
                    Image(systemName: iconForPuzzle(puzzle))
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                
                // Puzzle name
                Text(puzzle.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .padding()
        }
    }
    
    private func iconForPuzzle(_ puzzle: Puzzle) -> String {
        // Map puzzle IDs to appropriate SF Symbols
        switch puzzle.id {
        case "cat": return "cat.fill"
        case "house": return "house.fill"
        case "person": return "person.fill"
        case "bird": return "bird.fill"
        case "fish": return "fish.fill"
        case "tree": return "tree.fill"
        default: return "square.on.square.fill"
        }
    }
}

// MARK: - Coming Soon Thumbnail
struct ComingSoonThumbnail: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    )
                
                VStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("COMING SOON")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            // Placeholder text
            Text("New Puzzle")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding()
    }
}

