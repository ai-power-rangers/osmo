//
//  AppRoute.swift
//  osmo
//
//  Native iOS NavigationStack routing (replaces NavigationCoordinator)
//

import Foundation

/// Simple navigation routes for native iOS NavigationStack
enum AppRoute: Hashable {
    case settings
    case cvTest
    case gameSettings
    
    // Tangram routes
    case tangramEditor(puzzleId: String? = nil)
    case tangramPuzzleSelect
    
    // Sudoku routes  
    case sudokuEditor(puzzleId: String? = nil)
    case sudokuPuzzleSelect
    
    // Game routes (fullscreen)
    case game(gameId: String, puzzleId: String? = nil)
    
    // Grid editor
    case gridEditor(gameType: String)
}