import SwiftUI

struct SavePuzzleView: View {
    @Binding var isPresented: Bool
    @Binding var puzzleName: String
    @Binding var difficulty: TangramPuzzle.Difficulty
    let onSave: () -> Void
    
    @State private var tempName: String = ""
    @State private var tempDifficulty: TangramPuzzle.Difficulty = .medium
    @FocusState private var nameFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Puzzle Name", text: $tempName)
                        .focused($nameFieldFocused)
                        .onAppear {
                            tempName = puzzleName.isEmpty || puzzleName == "New Puzzle" ? "" : puzzleName
                            tempDifficulty = difficulty
                            nameFieldFocused = true
                        }
                } header: {
                    Text("Name Your Puzzle")
                } footer: {
                    Text("Choose a descriptive name for your puzzle")
                }
                
                Section {
                    Picker("Difficulty Level", selection: $tempDifficulty) {
                        ForEach(TangramPuzzle.Difficulty.allCases, id: \.self) { level in
                            HStack {
                                Text(level.rawValue.capitalized)
                                Spacer()
                                Text(difficultyDescription(for: level))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Select Difficulty")
                } footer: {
                    Text("This helps players find puzzles that match their skill level")
                }
            }
            .navigationTitle("Save Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            puzzleName = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                            difficulty = tempDifficulty
                            onSave()
                            isPresented = false
                        }
                    }
                    .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func difficultyDescription(for difficulty: TangramPuzzle.Difficulty) -> String {
        switch difficulty {
        case .easy:
            return "Simple shapes"
        case .medium:
            return "Moderate challenge"
        case .hard:
            return "Complex patterns"
        case .expert:
            return "Very challenging"
        }
    }
}