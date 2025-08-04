//
//  TangramEditor.swift
//  osmo
//
//  Simple Tangram puzzle editor
//

import SwiftUI

struct TangramEditor: View {
    let puzzleId: String?
    
    @State private var puzzle = TangramPuzzle.empty
    @State private var selectedPiece: TangramPiece?
    @State private var isTesting = false
    @State private var showingSaveAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Canvas for arranging pieces
                    TangramEditorCanvas(
                        pieces: $puzzle.pieces,
                        selectedPiece: $selectedPiece,
                        size: geometry.size
                    )
                    .background(Color(.systemGray6))
                    
                    // Controls
                    VStack(spacing: 16) {
                        // Piece controls
                        if selectedPiece != nil {
                            HStack(spacing: 20) {
                                Button {
                                    rotatePiece()
                                } label: {
                                    Image(systemName: "rotate.right")
                                }
                                
                                Button {
                                    flipPiece()
                                } label: {
                                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                }
                                
                                Button {
                                    deletePiece()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .foregroundColor(.red)
                            }
                            .font(.title2)
                        }
                        
                        // Piece palette
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(TangramPiece.Shape.allCases, id: \.self) { shape in
                                    Button {
                                        addPiece(shape: shape)
                                    } label: {
                                        ShapePreview(shape: shape)
                                            .frame(width: 60, height: 60)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Difficulty selector
                        Picker("Difficulty", selection: $puzzle.difficulty) {
                            ForEach(TangramPuzzle.Difficulty.allCases, id: \.self) { diff in
                                Text(diff.rawValue).tag(diff)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(puzzle.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePuzzle()
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Clear") {
                        clearPuzzle()
                    }
                    
                    Spacer()
                    
                    Button("Test") {
                        testPuzzle()
                    }
                }
            }
        }
        .task {
            if let id = puzzleId {
                await loadPuzzle(id)
            }
        }
        .alert("Save Puzzle", isPresented: $showingSaveAlert) {
            TextField("Puzzle Name", text: $puzzle.name)
            Button("Save") {
                performSave()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Actions
    
    private func addPiece(shape: TangramPiece.Shape) {
        let piece = TangramPiece(
            shape: shape,
            position: CGPoint(x: 200, y: 200),
            color: randomColor()
        )
        puzzle.pieces.append(piece)
        selectedPiece = piece
        
        GameKit.audio.play(.piecePickup)
        GameKit.haptics.playHaptic(.light)
    }
    
    private func rotatePiece() {
        guard let selected = selectedPiece,
              let index = puzzle.pieces.firstIndex(where: { $0.id == selected.id }) else { return }
        
        puzzle.pieces[index].rotation += .pi / 4
        GameKit.audio.play(.pieceRotate)
    }
    
    private func flipPiece() {
        // Implement flip logic
        GameKit.audio.play(.pieceRotate)
    }
    
    private func deletePiece() {
        guard let selected = selectedPiece else { return }
        
        puzzle.pieces.removeAll { $0.id == selected.id }
        selectedPiece = nil
        
        GameKit.audio.play(.delete)
        GameKit.haptics.playHaptic(.medium)
    }
    
    private func clearPuzzle() {
        puzzle.pieces.removeAll()
        selectedPiece = nil
        
        GameKit.audio.play(.delete)
        GameKit.haptics.playHaptic(.heavy)
    }
    
    private func savePuzzle() {
        if puzzle.name.isEmpty {
            showingSaveAlert = true
        } else {
            performSave()
        }
    }
    
    private func performSave() {
        Task {
            // Create a new puzzle with the correct ID
            let id = puzzleId ?? UUID().uuidString
            let puzzleToSave = TangramPuzzle(
                id: id,
                name: puzzle.name,
                pieces: puzzle.pieces,
                solution: puzzle.solution,
                difficulty: puzzle.difficulty,
                createdAt: Date(),
                thumbnailData: puzzle.thumbnailData
            )
            
            try? await SimplePuzzleStorage().save(puzzleToSave)
            
            GameKit.audio.play(.save)
            GameKit.haptics.notification(.success)
            
            dismiss()
        }
    }
    
    private func loadPuzzle(_ id: String) async {
        do {
            if let loaded = try await SimplePuzzleStorage().load(id: id) {
                puzzle = loaded
            }
        } catch {
            print("[TangramEditor] Failed to load puzzle: \(error)")
        }
    }
    
    private func testPuzzle() {
        isTesting = true
        // In a real app, would present the game view with this puzzle
    }
    
    private func randomColor() -> UIColor {
        let colors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen,
            .systemYellow, .systemPurple, .systemOrange,
            .systemPink, .systemTeal, .systemIndigo
        ]
        return colors.randomElement() ?? .systemBlue
    }
}

// MARK: - Editor Canvas

struct TangramEditorCanvas: View {
    @Binding var pieces: [TangramPiece]
    @Binding var selectedPiece: TangramPiece?
    let size: CGSize
    
    var body: some View {
        ZStack {
            // Grid background
            GridPattern()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            
            // Pieces
            ForEach(pieces) { piece in
                PieceView(
                    piece: piece,
                    isSelected: selectedPiece?.id == piece.id
                )
                .position(piece.position)
                .rotationEffect(.radians(piece.rotation))
                .onTapGesture {
                    selectedPiece = piece
                    GameKit.haptics.selection()
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
                                pieces[index].position = value.location
                            }
                        }
                        .onEnded { _ in
                            GameKit.audio.play(.pieceDrop)
                        }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            // Deselect when tapping empty space
            selectedPiece = nil
        }
    }
}

// MARK: - Piece View

struct PieceView: View {
    let piece: TangramPiece
    let isSelected: Bool
    
    var body: some View {
        ShapeView(shape: piece.shape)
            .fill(Color(piece.color.uiColor))
            .overlay(
                ShapeView(shape: piece.shape)
                    .stroke(isSelected ? Color.blue : Color.black, lineWidth: isSelected ? 2 : 1)
            )
            .frame(width: shapeSize(for: piece.shape).width,
                   height: shapeSize(for: piece.shape).height)
    }
    
    private func shapeSize(for shape: TangramPiece.Shape) -> CGSize {
        switch shape {
        case .largeTriangle:
            return CGSize(width: 60, height: 60)
        case .mediumTriangle:
            return CGSize(width: 45, height: 45)
        case .smallTriangle:
            return CGSize(width: 30, height: 30)
        case .square:
            return CGSize(width: 30, height: 30)
        case .parallelogram:
            return CGSize(width: 45, height: 30)
        }
    }
}

// MARK: - Shape Views

struct ShapeView: Shape {
    let shape: TangramPiece.Shape
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch shape {
        case .largeTriangle, .mediumTriangle, .smallTriangle:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.closeSubpath()
            
        case .square:
            path.addRect(rect)
            
        case .parallelogram:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.7, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.3, y: rect.minY))
            path.closeSubpath()
        }
        
        return path
    }
}

struct ShapePreview: View {
    let shape: TangramPiece.Shape
    
    var body: some View {
        ShapeView(shape: shape)
            .fill(Color.gray)
            .padding(8)
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gridSize: CGFloat = 30
        
        // Vertical lines
        for x in stride(from: 0, through: rect.width, by: gridSize) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: rect.height, by: gridSize) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// MARK: - Preview

#Preview {
    TangramEditor(puzzleId: nil)
}