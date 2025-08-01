//
//  AppCoordinator.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI
import Observation
import os.log

// MARK: - App Coordinator
@Observable
final class AppCoordinator: CoordinatorProtocol, ObservableObject {
    private let logger = Logger(subsystem: "com.osmoapp", category: "navigation")
    var navigationPath = NavigationPath()
    var errorMessage: String?
    var showError = false
    
    // MARK: - Navigation
    func navigateTo(_ destination: NavigationDestination) {
        logger.info("[Navigation] Navigating to: \(String(describing: destination))")
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
