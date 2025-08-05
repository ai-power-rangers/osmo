import SwiftUI

struct GhostPieceView: View {
    let type: TangramConstants.PieceType
    let position: CGPoint
    let rotation: Double
    let isFlipped: Bool
    let canvasSize: CGSize
    
    var body: some View {
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        let screenPosition = CGPoint(
            x: position.x * gridUnit,
            y: canvasSize.height - (position.y * gridUnit)
        )
        
        PieceShape(type: type.shape)
            .fill(Color.white.opacity(0.3))
            .overlay(
                PieceShape(type: type.shape)
                    .stroke(Color.white, lineWidth: 2)
                    .opacity(0.5)
            )
            .frame(width: type.size.width * gridUnit, height: type.size.height * gridUnit)
            .rotationEffect(.radians(rotation))
            .scaleEffect(x: isFlipped ? -1 : 1, y: 1)
            .position(screenPosition)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.2), value: position)
    }
}

struct CollisionIndicatorView: View {
    let pieces: [TangramConstants.PieceType: Bool]
    let placedPieces: [TangramConstants.PieceType: ImprovedTangramEditor.PlacedPiece]
    let canvasSize: CGSize
    
    var body: some View {
        ForEach(pieces.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { pieceType in
            if let isColliding = pieces[pieceType], 
               isColliding,
               let piece = placedPieces[pieceType] {
                CollisionPulseView(
                    type: pieceType,
                    piece: piece,
                    canvasSize: canvasSize
                )
            }
        }
    }
}

struct CollisionPulseView: View {
    let type: TangramConstants.PieceType
    let piece: ImprovedTangramEditor.PlacedPiece
    let canvasSize: CGSize
    
    @State private var isPulsing = false
    
    var body: some View {
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        let screenPosition = CGPoint(
            x: piece.position.x * gridUnit,
            y: canvasSize.height - (piece.position.y * gridUnit)
        )
        
        PieceShape(type: type.shape)
            .stroke(Color.red, lineWidth: 3)
            .frame(width: type.size.width * gridUnit, height: type.size.height * gridUnit)
            .rotationEffect(.radians(piece.rotation))
            .scaleEffect(x: piece.isFlipped ? -1 : 1, y: 1)
            .position(screenPosition)
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .opacity(isPulsing ? 0.5 : 0.8)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

struct ConnectionPointsView: View {
    let connections: [ConnectionPoint]
    let canvasSize: CGSize
    let showEdges: Bool = true
    
    var body: some View {
        let gridUnit = min(canvasSize.width, canvasSize.height) / 8.0
        
        ForEach(Array(connections.enumerated()), id: \.offset) { index, connection in
            let screenPos = CGPoint(
                x: connection.position.x * gridUnit,
                y: canvasSize.height - (connection.position.y * gridUnit)
            )
            
            switch connection.type {
            case .vertex:
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .position(screenPos)
                    .opacity(0.6)
                    
            case .edge(let start, let end):
                if showEdges {
                    Path { path in
                        let screenStart = CGPoint(
                            x: start.x * gridUnit,
                            y: canvasSize.height - (start.y * gridUnit)
                        )
                        let screenEnd = CGPoint(
                            x: end.x * gridUnit,
                            y: canvasSize.height - (end.y * gridUnit)
                        )
                        path.move(to: screenStart)
                        path.addLine(to: screenEnd)
                    }
                    .stroke(Color.green.opacity(0.3), lineWidth: 3)
                    
                    Circle()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .position(screenPos)
                }
            }
        }
    }
}

struct PieceShape: Shape {
    let type: TangramPiece.Shape
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch type {
        case .largeTriangle, .mediumTriangle, .smallTriangle:
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.closeSubpath()
            
        case .square:
            path.addRect(rect)
            
        case .parallelogram:
            let offset = rect.width / 2
            path.move(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: offset, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: offset, y: 0))
            path.closeSubpath()
        }
        
        return path
    }
}