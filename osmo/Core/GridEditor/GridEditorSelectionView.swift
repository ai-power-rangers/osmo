import SwiftUI

struct GridEditorSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Game Type")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Choose which game you want to create puzzles for")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                ForEach(GameType.allCases, id: \.self) { gameType in
                    NavigationLink(value: AppRoute.gridEditor(gameType: gameType.rawValue)) {
                        GameTypeButton(gameType: gameType) {}
                    }
                    .disabled(gameType != .tangram) // Only tangram is implemented for now
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .font(.headline)
            .padding(.bottom, 40)
        }
        .navigationTitle("Grid Editor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GameTypeButton: View {
    let gameType: GameType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: gameType.icon)
                    .font(.title2)
                    .frame(width: 40)
                
                VStack(alignment: .leading) {
                    Text(gameType.displayName)
                        .font(.headline)
                    
                    if gameType != .tangram {
                        Text("Coming Soon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(gameType != .tangram ? 0.6 : 1.0)
    }
}

#Preview {
    NavigationStack {
        GridEditorSelectionView()
            // Removed deprecated AppCoordinator
    }
}