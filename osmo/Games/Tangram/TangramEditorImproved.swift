//
//  TangramEditorImproved.swift
//  osmo
//
//  Improved Tangram puzzle editor with proper constraints
//

import SwiftUI

// MARK: - Constants
struct TangramConstants {
    static let sqrt2: CGFloat = 1.4142135623730951
    static let gridSize: CGFloat = 30  // Screen pixels per unit
    static let snapIncrement: CGFloat = 0.25  // Grid snap in units
    static let rotationIncrement: CGFloat = .pi / 4  // 45 degrees
    
    // The 7 classic Tangram pieces
    enum PieceType: String, CaseIterable {
        case largeTriangle1 = "Tri-L1"
        case largeTriangle2 = "Tri-L2"
        case mediumTriangle = "Tri-M"
        case smallTriangle1 = "Tri-S1"
        case smallTriangle2 = "Tri-S2"
        case square = "Square"
        case parallelogram = "Para"
        
        var shape: TangramPiece.Shape {
            switch self {
            case .largeTriangle1, .largeTriangle2:
                return .largeTriangle
            case .mediumTriangle:
                return .mediumTriangle
            case .smallTriangle1, .smallTriangle2:
                return .smallTriangle
            case .square:
                return .square
            case .parallelogram:
                return .parallelogram
            }
        }
        
        var color: UIColor {
            switch self {
            case .largeTriangle1: return .systemRed
            case .largeTriangle2: return .systemBlue
            case .mediumTriangle: return .systemGreen
            case .smallTriangle1: return .systemYellow
            case .smallTriangle2: return .systemPurple
            case .square: return .systemOrange
            case .parallelogram: return .systemPink
            }
        }
        
        // Size in grid units
        var size: CGSize {
            switch self {
            case .largeTriangle1, .largeTriangle2:
                return CGSize(width: 2, height: 2)
            case .mediumTriangle:
                return CGSize(width: sqrt2, height: sqrt2)
            case .smallTriangle1, .smallTriangle2:
                return CGSize(width: 1, height: 1)
            case .square:
                return CGSize(width: 1, height: 1)
            case .parallelogram:
                return CGSize(width: 2, height: 1)
            }
        }
    }
}

struct ImprovedTangramEditor: View {
    let puzzleId: String?
    
    @State private var puzzleName = "New Puzzle"
    @State private var placedPieces: [TangramConstants.PieceType: PlacedPiece] = [:]
    @State private var selectedPieceType: TangramConstants.PieceType?
    @State private var difficulty = TangramPuzzle.Difficulty.medium
    @State private var showingSaveAlert = false
    @State private var showGrid = true
    @Environment(\.dismiss) private var dismiss
    
    struct PlacedPiece {
        var position: CGPoint  // In grid units
        var rotation: Double
        var isFlipped: Bool = false
        
        mutating func snapToGrid() {
            let snap = TangramConstants.snapIncrement
            position.x = round(position.x / snap) * snap
            position.y = round(position.y / snap) * snap
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Canvas
                    ZStack {
                        // Grid
                        if showGrid {
                            GridOverlay()
                        }
                        
                        // Placed pieces
                        ForEach(Array(placedPieces.keys), id: \.self) { pieceType in
                            if let piece = placedPieces[pieceType] {
                                PlacedPieceView(
                                    type: pieceType,
                                    piece: piece,
                                    isSelected: selectedPieceType == pieceType,
                                    canvasSize: geometry.size
                                )
                                .onTapGesture {
                                    selectedPieceType = pieceType
                                    GameKit.haptics.selection()
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            updatePiecePosition(pieceType, to: value.location, canvasSize: geometry.size)
                                        }
                                        .onEnded { _ in
                                            snapPieceToGrid(pieceType)
                                            GameKit.audio.play(.pieceDrop)
                                        }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                    .onTapGesture {
                        selectedPieceType = nil
                    }
                    
                    // Controls
                    VStack(spacing: 16) {
                        // Selected piece controls
                        if let selected = selectedPieceType {
                            HStack(spacing: 20) {
                                Button {
                                    rotatePiece(selected)
                                } label: {
                                    Label("Rotate", systemImage: "rotate.right")
                                }
                                
                                if selected == .parallelogram {
                                    Button {
                                        flipPiece(selected)
                                    } label: {
                                        Label("Flip", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                    }
                                }
                                
                                Button {
                                    deletePiece(selected)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .foregroundColor(.red)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        // Available pieces palette
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(TangramConstants.PieceType.allCases, id: \.self) { pieceType in
                                    PiecePaletteButton(
                                        type: pieceType,
                                        isPlaced: placedPieces[pieceType] != nil,
                                        action: {
                                            if placedPieces[pieceType] == nil {
                                                addPiece(pieceType)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Settings
                        HStack {
                            Toggle("Grid", isOn: $showGrid)
                                .toggleStyle(.button)
                            
                            Spacer()
                            
                            Picker("Difficulty", selection: $difficulty) {
                                ForEach(TangramPuzzle.Difficulty.allCases, id: \.self) { diff in
                                    Text(diff.rawValue).tag(diff)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle(puzzleName)
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
                
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear All") {
                        clearPuzzle()
                    }
                }
            }
        }
        .alert("Save Puzzle", isPresented: $showingSaveAlert) {
            TextField("Puzzle Name", text: $puzzleName)
            Button("Save") {
                performSave()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Actions
    
    private func addPiece(_ type: TangramConstants.PieceType) {
        // Find a free spot on the grid that doesn't overlap
        let position = findFreePosition(for: type)
        
        placedPieces[type] = PlacedPiece(
            position: position,
            rotation: 0
        )
        selectedPieceType = type
        
        GameKit.audio.play(.piecePickup)
        GameKit.haptics.playHaptic(.light)
    }
    
    private func findFreePosition(for pieceType: TangramConstants.PieceType) -> CGPoint {
        let size = pieceType.size
        
        // Try different positions in a grid pattern
        let positions: [CGPoint] = [
            CGPoint(x: 1, y: 4),   // Upper left
            CGPoint(x: 4, y: 4),   // Upper middle
            CGPoint(x: 6, y: 4),   // Upper right
            CGPoint(x: 1, y: 2),   // Middle left
            CGPoint(x: 4, y: 2),   // Center
            CGPoint(x: 6, y: 2),   // Middle right
            CGPoint(x: 1, y: 1),   // Lower left
            CGPoint(x: 4, y: 1),   // Lower middle
            CGPoint(x: 6, y: 1),   // Lower right
        ]
        
        // Check each position for overlaps
        for pos in positions {
            // Check if piece would fit within bounds
            if pos.x + size.width > 8 || pos.y + size.height > 8 {
                continue
            }
            
            // Check for overlaps with existing pieces
            var hasOverlap = false
            for (existingType, existingPiece) in placedPieces {
                let existingSize = existingType.size
                
                // Simple bounding box check
                let overlap = !(pos.x + size.width < existingPiece.position.x ||
                               existingPiece.position.x + existingSize.width < pos.x ||
                               pos.y + size.height < existingPiece.position.y ||
                               existingPiece.position.y + existingSize.height < pos.y)
                
                if overlap {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                return pos
            }
        }
        
        // Fallback: place at a random position
        return CGPoint(x: 2, y: 3)
    }
    
    private func updatePiecePosition(_ type: TangramConstants.PieceType, to screenPoint: CGPoint, canvasSize: CGSize) {
        guard var piece = placedPieces[type] else { return }
        
        // Convert screen coordinates to grid units
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        piece.position = CGPoint(
            x: screenPoint.x / gridUnit,
            y: (canvasSize.height - screenPoint.y) / gridUnit  // Flip Y for bottom-left origin
        )
        
        placedPieces[type] = piece
    }
    
    private func snapPieceToGrid(_ type: TangramConstants.PieceType) {
        guard var piece = placedPieces[type] else { return }
        piece.snapToGrid()
        placedPieces[type] = piece
    }
    
    private func rotatePiece(_ type: TangramConstants.PieceType) {
        guard var piece = placedPieces[type] else { return }
        piece.rotation += TangramConstants.rotationIncrement
        if piece.rotation >= 2 * .pi {
            piece.rotation -= 2 * .pi
        }
        placedPieces[type] = piece
        
        GameKit.audio.play(.pieceRotate)
        GameKit.haptics.playHaptic(.light)
    }
    
    private func flipPiece(_ type: TangramConstants.PieceType) {
        guard type == .parallelogram,
              var piece = placedPieces[type] else { return }
        piece.isFlipped.toggle()
        placedPieces[type] = piece
        
        GameKit.audio.play(.pieceRotate)
        GameKit.haptics.playHaptic(.light)
    }
    
    private func deletePiece(_ type: TangramConstants.PieceType) {
        placedPieces.removeValue(forKey: type)
        if selectedPieceType == type {
            selectedPieceType = nil
        }
        
        GameKit.audio.play(.delete)
        GameKit.haptics.playHaptic(.medium)
    }
    
    private func clearPuzzle() {
        placedPieces.removeAll()
        selectedPieceType = nil
        
        GameKit.audio.play(.delete)
        GameKit.haptics.playHaptic(.heavy)
    }
    
    private func savePuzzle() {
        if puzzleName.isEmpty || puzzleName == "New Puzzle" {
            showingSaveAlert = true
        } else {
            performSave()
        }
    }
    
    private func performSave() {
        // Convert to TangramPuzzle format
        let pieces = TangramConstants.PieceType.allCases.compactMap { type -> TangramPiece? in
            guard let placed = placedPieces[type] else { return nil }
            return TangramPiece(
                shape: type.shape,
                position: placed.position,
                rotation: placed.rotation,
                color: type.color
            )
        }
        
        let solution = TangramSolution(
            targetPositions: pieces.map { piece in
                TangramSolution.TargetPosition(
                    pieceId: piece.id,
                    position: piece.position,
                    rotation: piece.rotation,
                    isFlipped: false
                )
            }
        )
        
        Task {
            let puzzle = TangramPuzzle(
                id: puzzleId ?? UUID().uuidString,
                name: puzzleName,
                pieces: pieces,
                solution: solution,
                difficulty: difficulty,
                createdAt: Date()
            )
            
            try? await SimplePuzzleStorage().save(puzzle)
            
            GameKit.audio.play(.save)
            GameKit.haptics.notification(.success)
            
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct PlacedPieceView: View {
    let type: TangramConstants.PieceType
    let piece: ImprovedTangramEditor.PlacedPiece
    let isSelected: Bool
    let canvasSize: CGSize
    
    var body: some View {
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        let size = type.size
        let screenSize = CGSize(
            width: size.width * gridUnit,
            height: size.height * gridUnit
        )
        let screenPosition = CGPoint(
            x: piece.position.x * gridUnit,
            y: canvasSize.height - (piece.position.y * gridUnit)  // Flip Y
        )
        
        return ImprovedShapeView(pieceType: type)
            .fill(Color(type.color))
            .overlay(
                ImprovedShapeView(pieceType: type)
                    .stroke(isSelected ? Color.blue : Color.black, lineWidth: isSelected ? 3 : 1)
            )
            .frame(width: screenSize.width, height: screenSize.height)
            .rotationEffect(.radians(piece.rotation))
            .scaleEffect(x: piece.isFlipped ? -1 : 1, y: 1)
            .position(screenPosition)
            .allowsHitTesting(true)
    }
}

struct PiecePaletteButton: View {
    let type: TangramConstants.PieceType
    let isPlaced: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ImprovedShapeView(pieceType: type)
                    .fill(isPlaced ? Color.gray.opacity(0.3) : Color(type.color))
                    .frame(width: 40, height: 40)
                
                Text(type.rawValue)
                    .font(.caption2)
                    .foregroundColor(isPlaced ? .gray : .primary)
            }
            .frame(width: 60, height: 60)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .disabled(isPlaced)
    }
}

struct ImprovedShapeView: Shape {
    let pieceType: TangramConstants.PieceType
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch pieceType.shape {
        case .largeTriangle, .mediumTriangle, .smallTriangle:
            // Right isosceles triangle
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
            
        case .square:
            path.addRect(rect)
            
        case .parallelogram:
            // Correct parallelogram shape based on math spec
            let skew = rect.width * 0.25
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + skew, y: rect.minY))
            path.closeSubpath()
        }
        
        return path
    }
}

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            // Ensure we have valid dimensions
            guard geometry.size.width > 0, geometry.size.height > 0 else {
                return AnyView(EmptyView())
            }
            
            let gridUnit = max(1, min(geometry.size.width, geometry.size.height) / 8.0)
            let maxWidth = geometry.size.width
            let maxHeight = geometry.size.height
            
            return AnyView(
                ZStack {
                    // Major grid lines (1 unit)
                    Path { path in
                        // Vertical lines
                        for i in 0...8 {
                            let x = CGFloat(i) * gridUnit
                            if x <= maxWidth {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: maxHeight))
                            }
                        }
                        
                        // Horizontal lines - use a reasonable max count
                        let maxLines = min(20, Int(maxHeight / gridUnit) + 1)
                        for i in 0..<maxLines {
                            let y = CGFloat(i) * gridUnit
                            if y <= maxHeight {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: maxWidth, y: y))
                            }
                        }
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    
                    // Minor grid lines (0.25 units)
                    Path { path in
                        let minorStep = gridUnit * 0.25
                        guard minorStep > 0.5 else { return }  // Skip if too small
                        
                        // Vertical minor lines
                        let maxVerticalLines = min(40, Int(maxWidth / minorStep) + 1)
                        for i in 0..<maxVerticalLines {
                            let x = CGFloat(i) * minorStep
                            if i % 4 != 0 && x <= maxWidth {  // Skip major lines
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: maxHeight))
                            }
                        }
                        
                        // Horizontal minor lines
                        let maxHorizontalLines = min(80, Int(maxHeight / minorStep) + 1)
                        for i in 0..<maxHorizontalLines {
                            let y = CGFloat(i) * minorStep
                            if i % 4 != 0 && y <= maxHeight {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: maxWidth, y: y))
                            }
                        }
                    }
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ImprovedTangramEditor(puzzleId: nil)
}