import SwiftUI

/// Simple default grid configuration
struct DefaultGridConfiguration: GridConfiguration {
    var gridStep: Double { 0.25 }
    var canvasSize: CGSize { CGSize(width: 8, height: 8) }
    var rotationStep: Int { 8 }
    var defaultMetadata: ArrangementMetadata {
        ArrangementMetadata(
            author: "User",
            tags: []
        )
    }
}

struct GridEditorHostView: View {
    let gameType: String
    @Environment(\.gridEditorService) private var gridEditorService
    @State private var editor: GridEditor?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if let editor = editor {
                editor.createEditorView()
            } else {
                ProgressView("Loading Editor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.gameBackground)
                    .onAppear {
                        loadEditor()
                    }
            }
        }
        .navigationTitle("\(gameType.capitalized) Editor")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadEditor() {
        guard let gameTypeEnum = GameType(rawValue: gameType) else {
            errorMessage = "Invalid game type: \(gameType)"
            showingError = true
            return
        }
        
        guard let service = gridEditorService else {
            errorMessage = "Grid editor service not available"
            showingError = true
            return
        }
        
        // Create default configuration
        let configuration = DefaultGridConfiguration()
        
        editor = service.createEditor(for: gameTypeEnum, configuration: configuration)
    }
}

#Preview {
    NavigationStack {
        GridEditorHostView(gameType: "tangram")
    }
}