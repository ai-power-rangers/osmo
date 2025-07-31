//
//  AppCoordinator.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI

// MARK: - App Coordinator
final class AppCoordinator: CoordinatorProtocol {
    @Published var navigationPath = NavigationPath()
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Navigation
    func navigateTo(_ destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func navigateToRoot() {
        navigationPath = NavigationPath()
    }
    
    // MARK: - Error Handling
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Game Launch
    func launchGame(_ gameId: String) {
        // Analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("game_selected", parameters: ["game_id": gameId])
        
        // Navigate
        navigateTo(.game(gameId: gameId))
    }
}

// MARK: - Environment Key
struct CoordinatorKey: EnvironmentKey {
    static let defaultValue = AppCoordinator()
}

extension EnvironmentValues {
    var coordinator: AppCoordinator {
        get { self[CoordinatorKey.self] }
        set { self[CoordinatorKey.self] = newValue }
    }
}