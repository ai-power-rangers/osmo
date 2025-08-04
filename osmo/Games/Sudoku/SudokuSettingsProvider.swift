//
//  SudokuSettingsProvider.swift
//  osmo
//
//  Settings provider for Sudoku game
//

import SwiftUI

struct SudokuSettingsProvider: GameSettingsProtocol {
    let gameId = "sudoku"
    let displayName = "Sudoku Puzzles"
    let iconName = "square.grid.3x3"
    
    func hasSettings() -> Bool {
        return true  // Sudoku has editor and puzzle management
    }
    
    func createSettingsView() -> AnyView {
        AnyView(SudokuSettingsView())
    }
}

// Settings view for Sudoku
struct SudokuSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let storage = SudokuStorage.shared
    
    var body: some View {
        Form {
            Section("Puzzle Management") {
                NavigationLink(destination: SudokuEditorLauncher()) {
                    Label("Puzzle Editor", systemImage: "pencil.and.outline")
                        .foregroundColor(.blue)
                }
                
                NavigationLink(destination: SudokuPuzzleSelector()) {
                    Label("Browse Puzzles", systemImage: "square.grid.2x2")
                        .foregroundColor(.blue)
                }
            }
            
            Section("Game Settings") {
                Toggle("Show Candidates", isOn: .constant(true))
                Toggle("Show Timer", isOn: .constant(true))
                Toggle("Auto-Check Errors", isOn: .constant(true))
                Toggle("Sound Effects", isOn: .constant(true))
            }
            
            Section("Statistics") {
                HStack {
                    Text("Total Puzzles")
                    Spacer()
                    Text("\(storage.loadAll().count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("4×4 Puzzles")
                    Spacer()
                    Text("\(storage.loadAll().filter { $0.gridSize == .fourByFour }.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("9×9 Puzzles")
                    Spacer()
                    Text("\(storage.loadAll().filter { $0.gridSize == .nineByNine }.count)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Sudoku Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}