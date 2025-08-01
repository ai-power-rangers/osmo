import SwiftUI
import SpriteKit

struct TangramGridEditorView: View {
    @ObservedObject var editor: TangramGridEditor
    @State private var showingPiecePalette = true
    @State private var showingValidation = false
    @State private var draggedShape: TangramShape?
    @State private var dragLocation: CGPoint = .zero
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                GridEditorScene(editor: editor, size: geometry.size)
                    .ignoresSafeArea()
                
                // UI Overlay
                VStack {
                    // Top toolbar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        
                        Spacer()
                        
                        TextField("Puzzle Name", text: $editor.arrangementName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 200)
                        
                        Spacer()
                        
                        Menu {
                            Button("Easy") { updateDifficulty("easy") }
                            Button("Medium") { updateDifficulty("medium") }
                            Button("Hard") { updateDifficulty("hard") }
                        } label: {
                            Label(editor.currentArrangement.metadata.difficulty ?? "medium", systemImage: "star.fill")
                        }
                        
                        Button("Save") {
                            saveArrangement()
                        }
                        .disabled(!editor.isValid)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack {
                        // Selected piece controls
                        if let selectedPieceId = editor.selectedPieceId,
                           let selectedPieceData = editor.getPieceData(selectedPieceId) {
                            HStack(spacing: 20) {
                                Button(action: {
                                    editor.rotatePiece(selectedPieceId)
                                }) {
                                    Image(systemName: "rotate.right")
                                        .font(.title2)
                                }
                                
                                if selectedPieceData.shape == .parallelogram {
                                    Button(action: {
                                        editor.mirrorPiece(selectedPieceId)
                                    }) {
                                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                            .font(.title2)
                                    }
                                }
                                
                                Button(action: {
                                    editor.removePiece(selectedPieceId)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                        
                        // Piece palette
                        if showingPiecePalette {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(TangramShape.allCases, id: \.self) { shape in
                                        PiecePaletteItem(shape: shape)
                                            .onTapGesture {
                                                // Add piece at center of grid
                                                let centerScreen = CGPoint(
                                                    x: geometry.size.width / 2,
                                                    y: geometry.size.height * 0.45
                                                )
                                                editor.addPiece(shape, at: centerScreen)
                                            }
                                    }
                                }
                                .padding()
                            }
                            .background(Color(UIColor.systemBackground).opacity(0.9))
                            .cornerRadius(15)
                        }
                        
                        // Bottom toolbar
                        HStack {
                            Button(action: {
                                showingPiecePalette.toggle()
                            }) {
                                Image(systemName: showingPiecePalette ? "rectangle.bottomthird.inset.filled" : "rectangle")
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingValidation.toggle()
                            }) {
                                Image(systemName: "checkmark.shield")
                            }
                            
                            Button(action: {
                                editor.clearAll()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                    }
                }
                
                // Validation overlay
                if showingValidation {
                    ValidationOverlay(errors: editor.validate())
                        .transition(.opacity)
                }
            }
        }
    }
    
    private func updateDifficulty(_ difficulty: String) {
        // Update the arrangement's metadata
        editor.objectWillChange.send()
    }
    
    private func saveArrangement() {
        Task {
            do {
                let arrangement = editor.currentArrangement
                let gridEditorService = ServiceLocator.shared.resolve(GridEditorServiceProtocol.self)
                try await gridEditorService.saveArrangement(arrangement)
                dismiss()
            } catch {
                print("Failed to save arrangement: \(error)")
            }
        }
    }
}

// MARK: - GridEditorScene

struct GridEditorScene: UIViewRepresentable {
    let editor: TangramGridEditor
    let size: CGSize
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.allowsTransparency = true
        view.backgroundColor = .clear
        
        let scene = TangramEditorSKScene(editor: editor, size: size)
        scene.backgroundColor = .clear
        scene.scaleMode = .resizeFill
        
        view.presentScene(scene)
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        if let scene = uiView.scene as? TangramEditorSKScene {
            scene.size = size
            scene.updateDisplay()
        }
    }
}

// MARK: - TangramEditorSKScene

class TangramEditorSKScene: SKScene {
    weak var editor: TangramGridEditor?
    private var gridNode: SKNode?
    private var pieceNodes: [String: SKNode] = [:]
    
    init(editor: TangramGridEditor, size: CGSize) {
        self.editor = editor
        super.init(size: size)
        setupGrid()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        updateDisplay()
    }
    
    private func setupGrid() {
        // Create grid background
        gridNode = SKNode()
        addChild(gridNode!)
        
        // Draw grid lines
        let gridSize = 8
        let coordinateSystem = CoordinateSystem(screenSize: size)
        
        for i in 0...gridSize {
            // Vertical lines
            let vLine = SKShapeNode(rect: CGRect(x: -0.5, y: -size.height/2, width: 1, height: size.height))
            vLine.fillColor = .gray.withAlphaComponent(0.3)
            vLine.strokeColor = .clear
            vLine.position = coordinateSystem.toScreen(CGPoint(x: Double(i), y: 4))
            gridNode?.addChild(vLine)
            
            // Horizontal lines
            let hLine = SKShapeNode(rect: CGRect(x: -size.width/2, y: -0.5, width: size.width, height: 1))
            hLine.fillColor = .gray.withAlphaComponent(0.3)
            hLine.strokeColor = .clear
            hLine.position = coordinateSystem.toScreen(CGPoint(x: 4, y: Double(i)))
            gridNode?.addChild(hLine)
        }
        
        // Add center marker
        let center = SKShapeNode(circleOfRadius: 5)
        center.fillColor = .red.withAlphaComponent(0.5)
        center.position = coordinateSystem.toScreen(CGPoint(x: 4, y: 4))
        gridNode?.addChild(center)
    }
    
    func updateDisplay() {
        guard let editor = editor else { return }
        
        // Remove old piece nodes
        pieceNodes.values.forEach { $0.removeFromParent() }
        pieceNodes.removeAll()
        
        // Add piece nodes
        for (pieceId, pieceData) in editor.getAllPieces() {
            let node = createPieceNode(pieceId: pieceId, pieceData: pieceData)
            addChild(node)
            pieceNodes[pieceId] = node
        }
    }
    
    private func createPieceNode(pieceId: String, pieceData: TangramEditorPieceData) -> SKNode {
        let coordinateSystem = CoordinateSystem(screenSize: size)
        
        // Get shape data
        guard let vertices = TangramShapeData.shapes[pieceData.shape],
              let color = TangramShapeData.colors[pieceData.shape] else {
            return SKNode()
        }
        
        let path = CGMutablePath()
        path.move(to: vertices[0])
        for i in 1..<vertices.count {
            path.addLine(to: vertices[i])
        }
        path.closeSubpath()
        
        let shapeNode = SKShapeNode(path: path)
        shapeNode.fillColor = color.withAlphaComponent(0.8)
        shapeNode.strokeColor = color
        shapeNode.lineWidth = 2
        
        // Apply transformations
        let scale = coordinateSystem.pieceScale
        shapeNode.setScale(scale)
        let angle = Double(pieceData.rotationIndex) * .pi / 4
        shapeNode.zRotation = CGFloat(angle)
        
        if pieceData.isMirrored {
            shapeNode.xScale *= -1
        }
        
        if let screenPos = editor?.getScreenPosition(for: pieceId) {
            shapeNode.position = screenPos
        }
        
        // Add selection highlight if selected
        if editor?.selectedPieceId == pieceId {
            let glow = SKShapeNode(path: path)
            glow.strokeColor = .yellow
            glow.lineWidth = 4
            glow.glowWidth = 10
            glow.alpha = 0.5
            shapeNode.addChild(glow)
        }
        
        return shapeNode
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let editor = editor else { return }
        
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Check if we tapped on a piece
        for (pieceId, node) in pieceNodes {
            if nodes.contains(node) {
                editor.selectedPieceId = pieceId
                updateDisplay()
                return
            }
        }
        
        // Tapped on empty space - deselect
        editor.selectedPieceId = nil
        updateDisplay()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let editor = editor,
              let selectedPieceId = editor.selectedPieceId else { return }
        
        let location = touch.location(in: self)
        let snappedLocation = editor.snapToGrid(location)
        
        editor.updatePiecePosition(selectedPieceId, to: snappedLocation)
        updateDisplay()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Validation happens automatically in the editor
        updateDisplay()
    }
}

// MARK: - PiecePaletteItem

struct PiecePaletteItem: View {
    let shape: TangramShape
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(colorForShape(shape))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: iconForShape(shape))
                        .foregroundColor(.white)
                        .font(.title2)
                )
            
            Text(displayName(for: shape))
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 80)
    }
    
    private func iconForShape(_ shape: TangramShape) -> String {
        switch shape {
        case .square: return "square.fill"
        case .parallelogram: return "rhombus.fill"
        case .smallTriangle1, .smallTriangle2: return "triangle.fill"
        case .mediumTriangle: return "triangle.fill"
        case .largeTriangle1, .largeTriangle2: return "triangle.fill"
        }
    }
    
    private func colorForShape(_ shape: TangramShape) -> Color {
        switch shape {
        case .square: return .yellow
        case .parallelogram: return .orange
        case .smallTriangle1: return .cyan
        case .smallTriangle2: return .pink
        case .mediumTriangle: return .green
        case .largeTriangle1: return .blue
        case .largeTriangle2: return .red
        }
    }
    
    private func displayName(for shape: TangramShape) -> String {
        switch shape {
        case .square: return "Square"
        case .parallelogram: return "Parallel"
        case .smallTriangle1, .smallTriangle2: return "Small Tri"
        case .mediumTriangle: return "Med Tri"
        case .largeTriangle1, .largeTriangle2: return "Large Tri"
        }
    }
}

// MARK: - ValidationOverlay

struct ValidationOverlay: View {
    let errors: [ValidationError]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Validation Results")
                .font(.headline)
            
            if errors.isEmpty {
                Label("All checks passed!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                ForEach(errors.indices, id: \.self) { index in
                    Label(errors[index].message, systemImage: errorIcon(for: errors[index].severity))
                        .foregroundColor(errorColor(for: errors[index].severity))
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding()
    }
    
    private func errorIcon(for severity: ValidationError.Severity) -> String {
        switch severity {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    private func errorColor(for severity: ValidationError.Severity) -> Color {
        switch severity {
        case .warning: return .orange
        case .error: return .red
        }
    }
}

