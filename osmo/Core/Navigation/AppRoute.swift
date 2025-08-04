//
//  AppRoute.swift
//  osmo
//
//  Single source of truth for all navigation
//

import Foundation

/// All navigation routes in the app
public enum AppRoute: Hashable {
    // Main
    case lobby
    case settings
    
    // Tangram
    case tangramGame(puzzleId: String? = nil)
    case tangramEditor(puzzleId: String? = nil)
    case tangramPuzzleSelect
    
    // Utility
    case cvTest
}