//
//  TangramSettingsProvider.swift
//  osmo
//
//  Settings provider for Tangram game
//

import SwiftUI

struct TangramSettingsProvider: GameSettingsProtocol {
    let gameId = "tangram"
    let displayName = "Tangram Puzzles"
    let iconName = "square.on.square"
    
    func hasSettings() -> Bool {
        return true  // Tangram has editor and puzzle management
    }
    
    func createSettingsView() -> AnyView {
        AnyView(TangramSettingsView())
    }
}

// Settings view for Tangram - now uses the launcher with proper navigation
struct TangramSettingsView: View {
    var body: some View {
        TangramEditorLauncher()
    }
}