//
//  LobbyView.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI

struct LobbyView: View {
    @Environment(AppCoordinator.self) var coordinator
    @State private var selectedCategory: GameCategory?
    
    // Our three games
    let mockGames = [
        GameInfo(
            gameId: "rock-paper-scissors",
            displayName: "Rock Paper Scissors",
            description: "Classic hand gesture game - beat the AI!",
            iconName: "hand.raised",
            minAge: 4,
            category: .problemSolving
        ),
        GameInfo(
            gameId: "tic-tac-toe",
            displayName: "Tic-Tac-Toe",
            description: "Coming Soon - Play on paper against AI!",
            iconName: "grid",
            minAge: 5,
            category: .problemSolving,
            isLocked: true
        ),
        GameInfo(
            gameId: "sudoku",
            displayName: "Sudoku",
            description: "Place tiles to complete the grid - supports 4x4 and 9x9!",
            iconName: "square.grid.3x3",
            minAge: 8,
            category: .problemSolving,
            isLocked: false
        ),
        GameInfo(
            gameId: "tangram",
            displayName: "Tangram Puzzles",
            description: "Classic shape puzzles - arrange colorful pieces to match the target",
            iconName: "square.on.square",
            minAge: 5,
            category: .spatialReasoning,
            isLocked: false
        )
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        CategoryChip(
                            category: nil,
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(GameCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Games Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredGames) { game in
                            GameCard(gameInfo: game) {
                                if !game.isLocked {
                                    if game.gameId == "tangram" {
                                        // Navigate to puzzle selection for Tangram
                                        coordinator.navigateTo(.tangramPuzzleSelect)
                                    } else {
                                        coordinator.launchGame(game.gameId)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Choose a Game")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    coordinator.navigateTo(.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                }
            }
        }
    }
    
    private var filteredGames: [GameInfo] {
        guard let category = selectedCategory else { return mockGames }
        return mockGames.filter { $0.category == category }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: GameCategory?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let category = category {
                    Image(systemName: category.iconName)
                    Text(category.displayName)
                } else {
                    Image(systemName: "square.grid.2x2")
                    Text("All Games")
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(uiColor: .systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Game Card
struct GameCard: View {
    let gameInfo: GameInfo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(gameInfo.isLocked ? Color.gray.opacity(0.3) : Color.blue)
                        .overlay(
                            gameInfo.isLocked ? 
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray, lineWidth: 2) : nil
                        )
                        .frame(height: 150)
                    
                    Image(systemName: gameInfo.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(gameInfo.isLocked ? .gray : .white)
                    
                    if gameInfo.isLocked {
                        VStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.title2)
                            Text("COMING SOON")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                    }
                }
                
                // Title
                Text(gameInfo.displayName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Description
                Text(gameInfo.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Age badge
                HStack {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text("\(gameInfo.minAge)+")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray6))
                .clipShape(Capsule())
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        }
        .disabled(gameInfo.isLocked)
    }
}
