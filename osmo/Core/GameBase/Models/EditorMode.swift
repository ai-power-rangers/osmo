//
//  EditorMode.swift
//  osmo
//
//  Editor mode enum for puzzle editors
//

import Foundation

/// Represents the editing mode for puzzle creation and testing
public enum EditorMode: String, CaseIterable {
    /// Editing the initial state (starting position)
    case initial = "initial"
    
    /// Editing the target/solution state
    case target = "target"
    
    /// Testing the puzzle by playing it
    case testing = "testing"
    
    var displayName: String {
        switch self {
        case .initial:
            return "Initial State"
        case .target:
            return "Target State"
        case .testing:
            return "Test Play"
        }
    }
    
    var description: String {
        switch self {
        case .initial:
            return "Set up the starting position for the puzzle"
        case .target:
            return "Define the solution or target state"
        case .testing:
            return "Test play the puzzle to verify it works"
        }
    }
}