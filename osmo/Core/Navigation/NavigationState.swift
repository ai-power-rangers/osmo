//
//  NavigationState.swift
//  osmo
//
//  Central navigation state machine for predictable routing
//

import Foundation
import SwiftUI

@MainActor
@Observable
public final class NavigationState {
    
    // MARK: - Route Definition
    
    public enum Route {
        case home
        case lobby
        case game(GameInfo)
        case settings
        case editor(GameInfo, EditorMode)
    }
    
    // MARK: - State
    
    private(set) public var currentRoute: Route = .home
    public var navigationPath = NavigationPath()
    private(set) public var isPresented: Bool = false
    
    // For sheet presentations
    private(set) public var presentedSheet: SheetType?
    
    public enum SheetType: Identifiable {
        case settings
        case puzzleSelector(GameInfo)
        case parentGate
        
        public var id: String {
            switch self {
            case .settings: return "settings"
            case .puzzleSelector(let info): return "selector_\(info.id)"
            case .parentGate: return "parentGate"
            }
        }
    }
    
    // MARK: - Navigation Methods
    
    public func navigate(to route: Route) {
        guard canNavigate(from: currentRoute, to: route) else {
            print("[NavigationState] Invalid transition from \(currentRoute) to \(route)")
            return
        }
        
        currentRoute = route
        
        // Handle navigation path updates
        switch route {
        case .home:
            navigationPath = NavigationPath()
        case .lobby:
            navigationPath.append(route)
        case .game(let info):
            navigationPath.append(route)
        case .settings:
            presentSheet(.settings)
        case .editor(let info, let mode):
            navigationPath.append(route)
        }
    }
    
    public func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        
        // Update current route based on path
        if navigationPath.isEmpty {
            currentRoute = .home
        }
    }
    
    public func goHome() {
        navigationPath = NavigationPath()
        currentRoute = .home
        dismissSheet()
    }
    
    public func presentSheet(_ sheet: SheetType) {
        presentedSheet = sheet
        isPresented = true
    }
    
    public func dismissSheet() {
        presentedSheet = nil
        isPresented = false
    }
    
    // MARK: - Validation
    
    private func canNavigate(from: Route, to: Route) -> Bool {
        // Define valid transitions
        switch (from, to) {
        case (.home, .lobby): return true
        case (.home, .settings): return true
        case (.lobby, .game): return true
        case (.lobby, .editor): return true
        case (.lobby, .home): return true
        case (.lobby, .settings): return true
        case (.game, .home): return true
        case (.game, .lobby): return true
        case (.game, .settings): return true
        case (.editor, .home): return true
        case (.editor, .lobby): return true
        case (.settings, _): return true // Can go anywhere from settings
        case (_, .home): return true // Can always go home
        default: return false
        }
    }
}

// MARK: - Route Extensions

extension NavigationState.Route: Equatable {
    public static func == (lhs: NavigationState.Route, rhs: NavigationState.Route) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.lobby, .lobby), (.settings, .settings):
            return true
        case (.game(let lInfo), .game(let rInfo)):
            return lInfo.id == rInfo.id
        case (.editor(let lInfo, let lMode), .editor(let rInfo, let rMode)):
            return lInfo.id == rInfo.id && lMode == rMode
        default:
            return false
        }
    }
}

extension NavigationState.Route: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .home:
            hasher.combine("home")
        case .lobby:
            hasher.combine("lobby")
        case .game(let info):
            hasher.combine("game")
            hasher.combine(info.id)
        case .settings:
            hasher.combine("settings")
        case .editor(let info, let mode):
            hasher.combine("editor")
            hasher.combine(info.id)
            hasher.combine(mode)
        }
    }
}