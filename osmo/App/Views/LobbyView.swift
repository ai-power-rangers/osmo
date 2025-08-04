//
//  LobbyView.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI

struct LobbyView: View {
    @Binding var navigationPath: NavigationPath
    let onGameSelected: (String) -> Void
    
    @State private var showingParentGate = false
    @State private var pendingAction: (() -> Void)?
    
    // App icons including games and settings
    let appIcons = [
        AppIcon(
            id: "tangram",
            displayName: "Tangram",
            iconName: "square.on.square",
            backgroundColor: .orange,
            action: .game("tangram")
        ),
        AppIcon(
            id: "settings",
            displayName: "Settings",
            iconName: "gearshape.fill",
            backgroundColor: Color(uiColor: .systemGray),
            action: .settings
        )
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 85, maximum: 95), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.l) {
                ForEach(appIcons) { icon in
                    AppIconView(icon: icon) {
                        handleIconTap(icon)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.m)
        }
        .navigationTitle("Osmo")
        .navigationBarTitleDisplayMode(.large)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .systemGray6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .parentGate(isPresented: $showingParentGate) {
            // Execute the pending action after successful parent gate
            pendingAction?()
            pendingAction = nil
        }
    }
    
    private func handleIconTap(_ icon: AppIcon) {
        if icon.isLocked {
            return
        }
        
        switch icon.action {
        case .game(let gameId):
            onGameSelected(gameId)
        case .settings:
            // Show parent gate for settings access
            pendingAction = {
                navigationPath.append(AppRoute.settings)
            }
            showingParentGate = true
        }
    }
}

// MARK: - App Icon Model
struct AppIcon: Identifiable {
    enum Action {
        case game(String)
        case settings
    }
    
    let id: String
    let displayName: String
    let iconName: String
    let backgroundColor: Color
    let action: Action
    let isLocked: Bool
    
    init(id: String,
         displayName: String,
         iconName: String,
         backgroundColor: Color,
         action: Action,
         isLocked: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        self.action = action
        self.isLocked = isLocked
    }
}

// MARK: - App Icon View
struct AppIconView: View {
    let icon: AppIcon
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon button
            Button(action: action) {
                ZStack {
                    // App icon background
                    RoundedRectangle(cornerRadius: 18)
                        .fill(icon.isLocked ? Color.gray.opacity(0.5) : icon.backgroundColor)
                        .frame(width: 70, height: 70)
                        .shadow(
                            color: icon.isLocked ? .clear : icon.backgroundColor.opacity(0.3),
                            radius: isPressed ? 2 : 5,
                            y: isPressed ? 1 : 3
                        )
                    
                    // Icon
                    Image(systemName: icon.iconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Coming soon overlay
                    if icon.isLocked {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 70, height: 70)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 20))
                            Text("SOON")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
            }
            .disabled(icon.isLocked)
            .buttonStyle(PlainButtonStyle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                              pressing: { pressing in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isPressed = pressing
                                }
                              }, perform: {})
            
            // App name
            Text(icon.displayName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
    }
}

#Preview {
    NavigationStack {
        LobbyView(
            navigationPath: .constant(NavigationPath()),
            onGameSelected: { _ in }
        )
    }
}