import SwiftUI

struct GridEditorHostView: View {
    let gameType: String
    @State private var editor: GridEditor?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if let editor = editor {
                editor.createEditorView()
            } else {
                ProgressView("Loading Editor...")
                    .onAppear {
                        loadEditor()
                    }
            }
        }
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
        
        guard ServiceLocator.shared.isInitialized else {
            errorMessage = "Services not initialized"
            showingError = true
            return
        }
        
        let gridEditorService = ServiceLocator.shared.resolve(GridEditorServiceProtocol.self)
        
        // Create default configuration based on game type
        let configuration: GridConfiguration
        switch gameTypeEnum {
        case .tangram:
            configuration = TangramGridConfiguration()
        default:
            // For now, use tangram config as default
            configuration = TangramGridConfiguration()
        }
        
        editor = gridEditorService.createEditor(for: gameTypeEnum, configuration: configuration)
    }
}

#Preview {
    NavigationStack {
        GridEditorHostView(gameType: "tangram")
    }
}