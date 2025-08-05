//
//  TangramEditorImproved.swift
//  osmo
//
//  Improved Tangram puzzle editor with proper constraints
//

import SwiftUI

// MARK: - Placement System

enum PlacementMode {
    case firstPiece    // Snap vertices to grid intersections only
    case subsequent    // Must connect to existing pieces
}

struct ConnectionPoint: Equatable {
    let position: CGPoint  // In grid units
    let type: ConnectionType
    let parentPieceType: TangramConstants.PieceType
    
    enum ConnectionType: Equatable {
        case vertex
        case edge(start: CGPoint, end: CGPoint)
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        switch type {
        case .vertex:
            return hypot(position.x - point.x, position.y - point.y)
        case .edge(let start, let end):
            // Distance from point to line segment
            return pointToLineSegmentDistance(point: point, lineStart: start, lineEnd: end)
        }
    }
    
    private func pointToLineSegmentDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))
        let projection = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
        
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}

// MARK: - Constants
struct TangramConstants {
    static let sqrt2: CGFloat = 1.4142135623730951
    static let gridSize: CGFloat = 30  // Screen pixels per unit
    static let snapIncrement: CGFloat = 0.25  // Grid snap in units
    static let rotationIncrement: CGFloat = .pi / 4  // 45 degrees
    static let connectionSnapDistance: CGFloat = 0.5  // Distance in grid units to snap to connections
    
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
    @State private var selectedGroup: Set<TangramConstants.PieceType> = []
    @State private var difficulty = TangramPuzzle.Difficulty.medium
    @State private var showingSaveAlert = false
    @State private var enableAutoPush = true
    @State private var showConnectionHints = false
    @State private var lastTapTime: Date = Date()
    @State private var lastTappedPiece: TangramConstants.PieceType?
    @State private var dragOffset: CGPoint = .zero
    @State private var isDragging = false
    @State private var collisionFeedback: [TangramConstants.PieceType: Bool] = [:]
    @State private var ghostPosition: CGPoint? = nil
    @State private var pushAnimations: [TangramConstants.PieceType: CGPoint] = [:]
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
                        // Grid (always shown in editor)
                        GridLinesView(
                            gridUnit: min(geometry.size.width, geometry.size.height) / 8.0,
                            maxWidth: geometry.size.width,
                            maxHeight: geometry.size.height
                        )
                        
                        // Visual feedback layer
                        CollisionIndicatorView(
                            pieces: collisionFeedback,
                            placedPieces: placedPieces,
                            canvasSize: geometry.size
                        )
                        
                        // Connection hints
                        if showConnectionHints && !placedPieces.isEmpty {
                            ConnectionPointsView(
                                connections: getConnectionPoints(),
                                canvasSize: geometry.size
                            )
                        }
                        
                        // Ghost piece for snap preview
                        if let ghostPos = ghostPosition,
                           let selectedType = selectedPieceType,
                           let piece = placedPieces[selectedType] {
                            GhostPieceView(
                                type: selectedType,
                                position: ghostPos,
                                rotation: piece.rotation,
                                isFlipped: piece.isFlipped,
                                canvasSize: geometry.size
                            )
                        }
                        
                        // Placed pieces
                        ForEach(Array(placedPieces.keys), id: \.self) { pieceType in
                            if let piece = placedPieces[pieceType] {
                                PlacedPieceView(
                                    type: pieceType,
                                    piece: piece,
                                    isSelected: selectedPieceType == pieceType,
                                    isInSelectedGroup: selectedGroup.contains(pieceType),
                                    connectionStatus: getConnectionStatus(for: pieceType),
                                    canvasSize: geometry.size
                                )
                                .onTapGesture(count: 2) {
                                    // Double tap: Select only this piece
                                    handleDoubleTap(on: pieceType)
                                }
                                .onTapGesture {
                                    // Single tap: Select connected group
                                    handleSingleTap(on: pieceType)
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if selectedGroup.contains(pieceType) {
                                                updateGroupPosition(from: pieceType, to: value.location, canvasSize: geometry.size)
                                            } else {
                                                updatePiecePosition(pieceType, to: value.location, canvasSize: geometry.size)
                                            }
                                        }
                                        .onEnded { _ in
                                            if selectedGroup.contains(pieceType) {
                                                snapGroupToGrid(from: pieceType)
                                            } else {
                                                snapPieceToGrid(pieceType)
                                            }
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
                            Toggle("Auto Push", isOn: $enableAutoPush)
                                .toggleStyle(.button)
                            
                            Toggle("Hints", isOn: $showConnectionHints)
                                .toggleStyle(.button)
                            
                            Spacer()
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
        .sheet(isPresented: $showingSaveAlert) {
            SavePuzzleView(
                isPresented: $showingSaveAlert,
                puzzleName: $puzzleName,
                difficulty: $difficulty,
                onSave: performSave
            )
        }
        .onAppear {
            if let puzzleId = puzzleId {
                loadExistingPuzzle(puzzleId)
            }
        }
    }
    
    // MARK: - Actions
    
    private func addPiece(_ type: TangramConstants.PieceType) {
        // Find a free spot based on placement mode
        let position: CGPoint
        
        if placementMode == .firstPiece {
            // For first piece, place at a central grid intersection
            position = CGPoint(x: 4.0, y: 4.0)  // Center of 8x8 grid
        } else {
            // For subsequent pieces, find a spot near existing pieces
            position = findFreePosition(for: type)
        }
        
        placedPieces[type] = PlacedPiece(
            position: snapToPlacement(position, for: type),
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
    
    private func handleSingleTap(on pieceType: TangramConstants.PieceType) {
        // Find connected group
        let group = findConnectedGroup(starting: pieceType)
        selectedGroup = group
        selectedPieceType = pieceType
        GameKit.haptics.selection()
    }
    
    private func handleDoubleTap(on pieceType: TangramConstants.PieceType) {
        // Select only this piece
        selectedGroup = [pieceType]
        selectedPieceType = pieceType
        GameKit.haptics.playHaptic(.medium)
    }
    
    private func updatePiecePosition(_ type: TangramConstants.PieceType, to screenPoint: CGPoint, canvasSize: CGSize) {
        guard var piece = placedPieces[type] else { return }
        
        // Convert screen coordinates to grid units
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        let targetPosition = CGPoint(
            x: screenPoint.x / gridUnit,
            y: (canvasSize.height - screenPoint.y) / gridUnit  // Flip Y for bottom-left origin
        )
        
        // Convert to SIMD2 for calculations
        let targetPos = SIMD2<Double>(targetPosition.x, targetPosition.y)
        
        // Check for collisions and resolve them
        let otherPieces = placedPieces.compactMap { key, value in
            if key != type {
                var piece = TangramPiece(shape: key.shape, color: key.color)
                piece.position = CGPoint(x: value.position.x, y: value.position.y)
                piece.rotation = value.rotation
                piece.isFlipped = value.isFlipped
                return piece
            }
            return nil
        }
        
        // Update temporary piece position for collision checking
        var tempPiece = TangramPiece(shape: type.shape, color: type.color)
        tempPiece.position = targetPosition
        tempPiece.rotation = piece.rotation
        tempPiece.isFlipped = piece.isFlipped
        
        // Check for collisions
        var hasCollision = false
        for otherPiece in otherPieces {
            let collision = CollisionDetector.detectCollision(
                between: tempPiece,
                and: otherPiece,
                in: self
            )
            if collision.intersects {
                hasCollision = true
                break
            }
        }
        
        if hasCollision && enableAutoPush {
            // Try to resolve with push
            let pushResult = PushResolver.resolvePush(
                movingPiece: tempPiece,
                targetPosition: targetPos,
                allPieces: otherPieces + [tempPiece],
                editor: self,
                gridBounds: canvasSize
            )
            
            if pushResult.success {
                // Apply pushed positions with animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    for (pushedPiece, newPosition) in pushResult.pushedPieces {
                        // Find the corresponding piece type
                        for (pieceType, placedPiece) in placedPieces {
                            if pieceType.shape == pushedPiece.shape &&
                               abs(placedPiece.position.x - pushedPiece.position.x) < 0.01 &&
                               abs(placedPiece.position.y - pushedPiece.position.y) < 0.01 {
                                placedPieces[pieceType]?.position = newPosition
                                break
                            }
                        }
                    }
                }
                piece.position = targetPosition
            } else {
                // Find nearest valid position
                if let validPos = PushResolver.findNearestValidPosition(
                    piece: tempPiece,
                    targetPosition: targetPos,
                    otherPieces: otherPieces,
                    editor: self
                ) {
                    piece.position = CGPoint(x: validPos.x, y: validPos.y)
                    
                    // Visual feedback for snap
                    ghostPosition = piece.position
                    withAnimation(.easeOut(duration: 0.2)) {
                        ghostPosition = nil
                    }
                }
            }
        } else {
            // No collision, update normally
            piece.position = targetPosition
        }
        
        placedPieces[type] = piece
        
        // Update collision feedback
        collisionFeedback[type] = hasCollision
    }
    
    private func updateGroupPosition(from draggedPiece: TangramConstants.PieceType, to screenPoint: CGPoint, canvasSize: CGSize) {
        guard let draggedPieceData = placedPieces[draggedPiece] else { return }
        
        // Convert screen coordinates to grid units
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        let newPosition = CGPoint(
            x: screenPoint.x / gridUnit,
            y: (canvasSize.height - screenPoint.y) / gridUnit
        )
        
        // Calculate offset
        let offset = CGPoint(
            x: newPosition.x - draggedPieceData.position.x,
            y: newPosition.y - draggedPieceData.position.y
        )
        
        // Move all pieces in the group
        for pieceType in selectedGroup {
            if var piece = placedPieces[pieceType] {
                piece.position.x += offset.x
                piece.position.y += offset.y
                placedPieces[pieceType] = piece
            }
        }
    }
    
    private func snapPieceToGrid(_ type: TangramConstants.PieceType) {
        guard var piece = placedPieces[type] else { return }
        
        // Use smart snapping based on placement mode
        piece.position = snapToPlacement(piece.position, for: type)
        
        placedPieces[type] = piece
    }
    
    private func snapGroupToGrid(from draggedPiece: TangramConstants.PieceType) {
        // For group snapping, just use regular grid snapping
        for pieceType in selectedGroup {
            if var piece = placedPieces[pieceType] {
                piece.position = snapToGrid(piece.position)
                placedPieces[pieceType] = piece
            }
        }
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
    
    private func loadExistingPuzzle(_ id: String) {
        // TODO: Load puzzle from storage
        // This would typically fetch from your puzzle repository
        // For now, we'll just set a placeholder name
        puzzleName = "Existing Puzzle"
    }
    
    // MARK: - Placement Logic
    
    private var placementMode: PlacementMode {
        placedPieces.isEmpty ? .firstPiece : .subsequent
    }
    
    // MARK: - Connection Status
    
    private func getConnectionStatus(for pieceType: TangramConstants.PieceType) -> PlacedPieceView.ConnectionStatus {
        guard let piece = placedPieces[pieceType] else { return .none }
        
        // If it's the only piece, check if it's on a grid intersection
        if placedPieces.count == 1 {
            let isOnIntersection = isOnGridIntersection(piece.position)
            return isOnIntersection ? .validConnection : .invalidPlacement
        }
        
        // Check if this piece has valid connections to other pieces
        var hasValidConnection = false
        for (otherType, _) in placedPieces where otherType != pieceType {
            if arePiecesConnected(pieceType, otherType) {
                hasValidConnection = true
                break
            }
        }
        
        return hasValidConnection ? .validConnection : .invalidPlacement
    }
    
    private func isOnGridIntersection(_ position: CGPoint) -> Bool {
        // Check if position is on a 0.5 grid unit intersection
        let x = position.x
        let y = position.y
        let tolerance: CGFloat = 0.1
        
        let xRemainder = x.truncatingRemainder(dividingBy: 0.5)
        let yRemainder = y.truncatingRemainder(dividingBy: 0.5)
        
        return abs(xRemainder) < tolerance && abs(yRemainder) < tolerance
    }
    
    // MARK: - Group Selection
    
    private func findConnectedGroup(starting from: TangramConstants.PieceType) -> Set<TangramConstants.PieceType> {
        var group: Set<TangramConstants.PieceType> = [from]
        var toCheck: Set<TangramConstants.PieceType> = [from]
        
        while !toCheck.isEmpty {
            let current = toCheck.removeFirst()
            
            for (otherType, _) in placedPieces {
                if !group.contains(otherType) && arePiecesConnected(current, otherType) {
                    group.insert(otherType)
                    toCheck.insert(otherType)
                }
            }
        }
        
        return group
    }
    
    private func arePiecesConnected(_ type1: TangramConstants.PieceType, _ type2: TangramConstants.PieceType) -> Bool {
        guard let piece1 = placedPieces[type1],
              let piece2 = placedPieces[type2] else { return false }
        
        let vertices1 = getPieceVertices(type: type1, at: piece1.position, rotation: piece1.rotation, isFlipped: piece1.isFlipped)
        let vertices2 = getPieceVertices(type: type2, at: piece2.position, rotation: piece2.rotation, isFlipped: piece2.isFlipped)
        
        let threshold: CGFloat = 0.1
        
        // Check vertex-to-vertex connections
        for v1 in vertices1 {
            for v2 in vertices2 {
                if hypot(v1.x - v2.x, v1.y - v2.y) < threshold {
                    return true
                }
            }
        }
        
        // Check edge connections
        for i in 0..<vertices1.count {
            let edge1Start = vertices1[i]
            let edge1End = vertices1[(i + 1) % vertices1.count]
            
            for j in 0..<vertices2.count {
                let edge2Start = vertices2[j]
                let edge2End = vertices2[(j + 1) % vertices2.count]
                
                // Check if edges share points or overlap
                if edgesConnect(edge1Start, edge1End, edge2Start, edge2End, threshold: threshold) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func edgesConnect(_ e1Start: CGPoint, _ e1End: CGPoint, _ e2Start: CGPoint, _ e2End: CGPoint, threshold: CGFloat) -> Bool {
        // Check if edges share vertices
        if hypot(e1Start.x - e2Start.x, e1Start.y - e2Start.y) < threshold ||
           hypot(e1Start.x - e2End.x, e1Start.y - e2End.y) < threshold ||
           hypot(e1End.x - e2Start.x, e1End.y - e2Start.y) < threshold ||
           hypot(e1End.x - e2End.x, e1End.y - e2End.y) < threshold {
            return true
        }
        
        // Check if edges are parallel and overlapping
        let v1 = CGPoint(x: e1End.x - e1Start.x, y: e1End.y - e1Start.y)
        let v2 = CGPoint(x: e2End.x - e2Start.x, y: e2End.y - e2Start.y)
        
        let len1 = hypot(v1.x, v1.y)
        let len2 = hypot(v2.x, v2.y)
        
        if len1 > 0 && len2 > 0 {
            let n1 = CGPoint(x: v1.x / len1, y: v1.y / len1)
            let n2 = CGPoint(x: v2.x / len2, y: v2.y / len2)
            
            // Check if parallel
            let dot = abs(n1.x * n2.x + n1.y * n2.y)
            if dot > 0.99 {
                // Check distance between lines
                let dist = pointToLineDistance(e2Start, lineStart: e1Start, lineEnd: e1End)
                if dist < threshold {
                    // Check if they overlap
                    return linesOverlap(e1Start, e1End, e2Start, e2End)
                }
            }
        }
        
        return false
    }
    
    private func pointToLineDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared))
        let projection = CGPoint(x: lineStart.x + t * dx, y: lineStart.y + t * dy)
        
        return hypot(point.x - projection.x, point.y - projection.y)
    }
    
    private func linesOverlap(_ l1Start: CGPoint, _ l1End: CGPoint, _ l2Start: CGPoint, _ l2End: CGPoint) -> Bool {
        // Project all points onto the line direction
        let dir = CGPoint(x: l1End.x - l1Start.x, y: l1End.y - l1Start.y)
        let len = hypot(dir.x, dir.y)
        
        if len == 0 { return false }
        
        let n = CGPoint(x: dir.x / len, y: dir.y / len)
        
        let proj1Start: CGFloat = 0
        let proj1End: CGFloat = len
        let proj2Start = (l2Start.x - l1Start.x) * n.x + (l2Start.y - l1Start.y) * n.y
        let proj2End = (l2End.x - l1Start.x) * n.x + (l2End.y - l1Start.y) * n.y
        
        let min2 = min(proj2Start, proj2End)
        let max2 = max(proj2Start, proj2End)
        
        return max2 >= proj1Start && min2 <= proj1End
    }
    
    private func getConnectionPoints() -> [ConnectionPoint] {
        var points: [ConnectionPoint] = []
        
        for (pieceType, piece) in placedPieces {
            let vertices = getPieceVertices(type: pieceType, at: piece.position, rotation: piece.rotation, isFlipped: piece.isFlipped)
            
            // Add vertex connection points
            for vertex in vertices {
                points.append(ConnectionPoint(
                    position: vertex,
                    type: .vertex,
                    parentPieceType: pieceType
                ))
            }
            
            // Add edge connection points
            for i in 0..<vertices.count {
                let start = vertices[i]
                let end = vertices[(i + 1) % vertices.count]
                points.append(ConnectionPoint(
                    position: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2),
                    type: .edge(start: start, end: end),
                    parentPieceType: pieceType
                ))
            }
        }
        
        return points
    }
    
    // Helper method for CollisionDetector
    func getPieceVertices(_ piece: TangramPiece) -> [SIMD2<Double>] {
        let vertices = getPieceVertices(
            shape: piece.shape,
            at: CGPoint(x: piece.position.x, y: piece.position.y),
            rotation: piece.rotation,
            isFlipped: piece.isFlipped
        )
        return vertices.map { SIMD2<Double>($0.x, $0.y) }
    }
    
    private func getPieceVertices(type: TangramConstants.PieceType, at position: CGPoint, rotation: Double, isFlipped: Bool) -> [CGPoint] {
        return getPieceVertices(shape: type.shape, at: position, rotation: rotation, isFlipped: isFlipped)
    }
    
    private func getShapeSize(_ shape: TangramPiece.Shape) -> CGSize {
        switch shape {
        case .largeTriangle:
            return CGSize(width: 2, height: 2)
        case .mediumTriangle:
            return CGSize(width: TangramConstants.sqrt2, height: TangramConstants.sqrt2)
        case .smallTriangle:
            return CGSize(width: 1, height: 1)
        case .square:
            return CGSize(width: 1, height: 1)
        case .parallelogram:
            return CGSize(width: 2, height: 1)
        }
    }
    
    private func getPieceVertices(shape: TangramPiece.Shape, at position: CGPoint, rotation: Double, isFlipped: Bool) -> [CGPoint] {
        var vertices: [CGPoint] = []
        let shapeSize = getShapeSize(shape)
        
        switch shape {
        case .largeTriangle, .mediumTriangle, .smallTriangle:
            let size = shapeSize.width
            vertices = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: size, y: 0),
                CGPoint(x: 0, y: size)
            ]
        case .square:
            let size = shapeSize.width
            vertices = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: size, y: 0),
                CGPoint(x: size, y: size),
                CGPoint(x: 0, y: size)
            ]
        case .parallelogram:
            vertices = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 0),
                CGPoint(x: 2, y: 1),
                CGPoint(x: 1, y: 1)
            ]
            if isFlipped {
                vertices = vertices.map { CGPoint(x: 2 - $0.x, y: $0.y) }
            }
        }
        
        // Apply rotation and translation
        let angle = CGFloat(rotation)
        return vertices.map { vertex in
            let rotatedX = vertex.x * cos(angle) - vertex.y * sin(angle)
            let rotatedY = vertex.x * sin(angle) + vertex.y * cos(angle)
            return CGPoint(x: rotatedX + position.x, y: rotatedY + position.y)
        }
    }
    
    private func snapToPlacement(_ position: CGPoint, for pieceType: TangramConstants.PieceType) -> CGPoint {
        switch placementMode {
        case .firstPiece:
            // Snap to nearest grid intersection
            return snapToGridIntersection(position)
        case .subsequent:
            // Find nearest connection point
            let connections = getConnectionPoints()
            if let nearest = findNearestConnection(to: position, from: connections) {
                return nearest.position
            }
            return snapToGrid(position)
        }
    }
    
    private func snapToGridIntersection(_ position: CGPoint) -> CGPoint {
        // Round to nearest 0.5 grid unit (grid intersections)
        let x = round(position.x * 2) / 2
        let y = round(position.y * 2) / 2
        return CGPoint(x: x, y: y)
    }
    
    private func snapToGrid(_ position: CGPoint) -> CGPoint {
        let snap = TangramConstants.snapIncrement
        let x = round(position.x / snap) * snap
        let y = round(position.y / snap) * snap
        return CGPoint(x: x, y: y)
    }
    
    private func findNearestConnection(to position: CGPoint, from connections: [ConnectionPoint]) -> ConnectionPoint? {
        let maxDistance = TangramConstants.connectionSnapDistance
        
        // Find the closest connection point
        if let nearest = connections
            .map({ connection in (connection: connection, distance: connection.distance(to: position)) })
            .filter({ $0.distance < maxDistance })
            .min(by: { $0.distance < $1.distance }) {
            
            // For edge connections, try to find aligned edges
            if case .edge(let start, let end) = nearest.connection.type {
                // Check if we can align with this edge
                if let alignedPosition = findEdgeAlignment(position: position, edgeStart: start, edgeEnd: end, connections: connections) {
                    return ConnectionPoint(
                        position: alignedPosition,
                        type: .edge(start: start, end: end),
                        parentPieceType: nearest.connection.parentPieceType
                    )
                }
            }
            
            return nearest.connection
        }
        
        return nil
    }
    
    private func findEdgeAlignment(position: CGPoint, edgeStart: CGPoint, edgeEnd: CGPoint, connections: [ConnectionPoint]) -> CGPoint? {
        // Calculate edge direction
        let edgeVector = CGPoint(x: edgeEnd.x - edgeStart.x, y: edgeEnd.y - edgeStart.y)
        let edgeLength = hypot(edgeVector.x, edgeVector.y)
        
        guard edgeLength > 0 else { return nil }
        
        // Normalize edge vector
        let edgeDir = CGPoint(x: edgeVector.x / edgeLength, y: edgeVector.y / edgeLength)
        
        // Project position onto edge line
        let toPoint = CGPoint(x: position.x - edgeStart.x, y: position.y - edgeStart.y)
        let projection = toPoint.x * edgeDir.x + toPoint.y * edgeDir.y
        
        // Check common alignment patterns
        let alignmentThreshold: CGFloat = 0.1
        
        // Center alignment
        if abs(projection - edgeLength / 2) < alignmentThreshold {
            return CGPoint(
                x: edgeStart.x + edgeDir.x * edgeLength / 2,
                y: edgeStart.y + edgeDir.y * edgeLength / 2
            )
        }
        
        // Start alignment
        if abs(projection) < alignmentThreshold {
            return edgeStart
        }
        
        // End alignment
        if abs(projection - edgeLength) < alignmentThreshold {
            return edgeEnd
        }
        
        // Default to closest point on edge
        let t = max(0, min(1, projection / edgeLength))
        return CGPoint(
            x: edgeStart.x + edgeDir.x * edgeLength * t,
            y: edgeStart.y + edgeDir.y * edgeLength * t
        )
    }
    
    private func savePuzzle() {
        showingSaveAlert = true
    }
    
    private func performSave() {
        // Convert to TangramPuzzle format
        let pieces = TangramConstants.PieceType.allCases.compactMap { type -> TangramPiece? in
            guard let placed = placedPieces[type] else { return nil }
            var piece = TangramPiece(shape: type.shape, color: type.color)
            piece.position = placed.position
            piece.rotation = placed.rotation
            piece.isFlipped = placed.isFlipped
            return piece
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
    let isInSelectedGroup: Bool
    let connectionStatus: ConnectionStatus
    let canvasSize: CGSize
    
    enum ConnectionStatus {
        case none
        case validConnection
        case invalidPlacement
    }
    
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
            .fill(fillColor)
            .overlay(
                ImprovedShapeView(pieceType: type)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .frame(width: screenSize.width, height: screenSize.height)
            .rotationEffect(.radians(piece.rotation))
            .scaleEffect(x: piece.isFlipped ? -1 : 1, y: 1)
            .position(screenPosition)
            .allowsHitTesting(true)
    }
    
    private var fillColor: Color {
        if connectionStatus == .invalidPlacement {
            return Color(type.color).opacity(0.5)
        } else {
            return Color(type.color)
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return .blue
        } else if isInSelectedGroup {
            return .cyan
        } else if connectionStatus == .invalidPlacement {
            return .red
        } else if connectionStatus == .validConnection {
            return .green
        } else {
            return .black
        }
    }
    
    private var strokeWidth: CGFloat {
        if isSelected || isInSelectedGroup {
            return 3
        } else if connectionStatus == .invalidPlacement {
            return 2
        } else if connectionStatus == .validConnection {
            return 2
        } else {
            return 1
        }
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


struct GridLinesView: View {
    let gridUnit: CGFloat
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    
    var body: some View {
        ZStack {
            // Major grid lines (1 unit)
            Path { path in
                // Guard against zero gridUnit
                guard gridUnit > 0 else { return }
                
                // Vertical lines
                for i in 0...8 {
                    let x = CGFloat(i) * gridUnit
                    if x <= maxWidth {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: maxHeight))
                    }
                }
                
                // Horizontal lines
                for i in 0...8 {
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
                // Guard against zero gridUnit
                guard gridUnit > 0 else { return }
                
                let minorStep = gridUnit * 0.25
                guard minorStep > 0.5 else { return }  // Skip if too small
                
                // Vertical minor lines
                for i in 0...32 {  // 8 units * 4 subdivisions
                    let x = CGFloat(i) * minorStep
                    if i % 4 != 0 && x <= maxWidth {  // Skip major lines
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: maxHeight))
                    }
                }
                
                // Horizontal minor lines
                for i in 0...32 {  // 8 units * 4 subdivisions
                    let y = CGFloat(i) * minorStep
                    if i % 4 != 0 && y <= maxHeight {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: maxWidth, y: y))
                    }
                }
            }
            .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        }
    }
}


// MARK: - Preview

#Preview {
    ImprovedTangramEditor(puzzleId: nil)
}