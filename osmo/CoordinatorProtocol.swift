//
//  CoordinatorProtocol.swift
//  osmo
//
//  Created by Phase 1 Implementation
//

import SwiftUI

// MARK: - Navigation Destination
enum NavigationDestination: Hashable {
    case lobby
    case game(gameId: String)
    case settings
    case parentGate
    case cvTest
    case tangramPuzzleSelect
}

// MARK: - Coordinator Protocol
protocol CoordinatorProtocol: ObservableObject {
    var navigationPath: NavigationPath { get set }
    
    func navigateTo(_ destination: NavigationDestination)
    func navigateBack()
    func navigateToRoot()
    func showError(_ message: String)
}

// MARK: - App Error
enum AppError: LocalizedError {
    case gameLoadFailed(gameId: String)
    case cameraPermissionDenied
    case cameraUnavailable
    case serviceInitializationFailed(service: String)
    
    var errorDescription: String? {
        switch self {
        case .gameLoadFailed(let gameId):
            return "Could not load game \(gameId)"
        case .cameraPermissionDenied:
            return "Camera access is needed to play"
        case .cameraUnavailable:
            return "Camera is not available"
        case .serviceInitializationFailed(let service):
            return "\(service) service failed to start"
        }
    }
}
