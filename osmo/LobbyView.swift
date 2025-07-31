//
//  LobbyView.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI

struct LobbyView: View {
    @Environment(\.coordinator) var coordinator
    @State private var selectedCategory: GameCategory?
    
    // Mock game data for Phase 1
    let mockGames = [
        GameInfo(
            gameId: "finger_count",
            displayName: "Finger Count",
            description: "Show the right number of fingers!",
            iconName: "hand.raised.fill",
            minAge: 3,
            category: .math
        ),
        GameInfo(
            gameId: "shape_match",
            displayName: "Shape Match",
            description: "Match shapes with real objects",
            iconName: "square.on.circle",
            minAge: 4,
            category: .spatialReasoning,
            isLocked: true
        ),
        GameInfo(
            gameId: "color_hunt",
            displayName: "Color Hunt",
            description: "Find colors in your room",
            iconName: "paintpalette.fill",
            minAge: 3,
            category: .creativity,
            isLocked: true
        )
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 20)
    ]
    
    var body: some View {
        NavigationStack {
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
                                        coordinator.launchGame(game.gameId)
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
                        .fill(gameInfo.isLocked ? Color.gray : Color.blue)
                        .frame(height: 150)
                    
                    Image(systemName: gameInfo.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    if gameInfo.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)).frame(width: 50, height: 50))
                            .offset(x: 60, y: -60)
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
