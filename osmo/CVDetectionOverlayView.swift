//
//  CVDetectionOverlayView.swift
//  osmo
//
//  Overlay view for visualizing CV detections (rectangles, hands, etc.)
//

import SwiftUI
import Vision

// MARK: - Detection Data Models
struct DetectedRectangle: Identifiable {
    let id = UUID()
    let corners: [CGPoint] // Normalized Vision coordinates
    let confidence: Float
    let timestamp: Date = Date()
}

struct DetectedHand: Identifiable {
    let id: UUID
    let boundingBox: CGRect // Normalized coordinates
    let fingerCount: Int
    let confidence: Float
    let chirality: HandChirality
    
    init(id: UUID = UUID(), boundingBox: CGRect, fingerCount: Int, confidence: Float, chirality: HandChirality) {
        self.id = id
        self.boundingBox = boundingBox
        self.fingerCount = fingerCount
        self.confidence = confidence
        self.chirality = chirality
    }
}

// MARK: - Overlay View Model
@Observable
class CVOverlayViewModel {
    var detectedRectangles: [DetectedRectangle] = []
    var detectedHands: [DetectedHand] = []
    var showDebugInfo = false
    var lastUpdateTime = Date()
    
    func updateRectangle(_ corners: [CGPoint], confidence: Float) {
        // Keep only the most recent detection
        detectedRectangles = [DetectedRectangle(corners: corners, confidence: confidence)]
        lastUpdateTime = Date()
    }
    
    func clearRectangles() {
        detectedRectangles.removeAll()
    }
    
    func updateHand(boundingBox: CGRect, fingerCount: Int, confidence: Float, chirality: HandChirality) {
        // Single hand mode - replace all hands
        detectedHands = [DetectedHand(
            boundingBox: boundingBox,
            fingerCount: fingerCount,
            confidence: confidence,
            chirality: chirality
        )]
        lastUpdateTime = Date()
    }
    
    func updateSpecificHand(handId: String, boundingBox: CGRect, fingerCount: Int, confidence: Float, chirality: HandChirality) {
        // Multiple hands mode - update or add specific hand
        let newHand = DetectedHand(
            id: UUID(uuidString: handId) ?? UUID(),
            boundingBox: boundingBox,
            fingerCount: fingerCount,
            confidence: confidence,
            chirality: chirality
        )
        
        // Remove old instance of this hand if it exists
        detectedHands.removeAll { $0.id == newHand.id }
        
        // Add updated hand
        detectedHands.append(newHand)
        
        // Keep only the 2 most recent hands to avoid clutter
        if detectedHands.count > 2 {
            detectedHands = Array(detectedHands.suffix(2))
        }
        
        lastUpdateTime = Date()
    }
    
    func clearHands() {
        detectedHands.removeAll()
    }
}

// MARK: - Overlay View
struct CVDetectionOverlayView: View {
    @Bindable var viewModel: CVOverlayViewModel
    let frameSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Rectangle detections
                ForEach(viewModel.detectedRectangles) { rectangle in
                    RectangleOverlay(
                        corners: rectangle.corners,
                        confidence: rectangle.confidence,
                        geometry: geometry
                    )
                }
                
                // Hand detections
                ForEach(viewModel.detectedHands) { hand in
                    HandOverlay(
                        hand: hand,
                        geometry: geometry
                    )
                }
                
                // Debug info
                if viewModel.showDebugInfo {
                    VStack {
                        HStack {
                            DebugInfoView(
                                rectangleCount: viewModel.detectedRectangles.count,
                                handCount: viewModel.detectedHands.count,
                                lastUpdate: viewModel.lastUpdateTime
                            )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Rectangle Overlay
struct RectangleOverlay: View {
    let corners: [CGPoint]
    let confidence: Float
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Fill with light green overlay
            Path { path in
                guard corners.count == 4 else { return }
                
                // Convert normalized coordinates to screen coordinates with expansion
                let screenCorners = expandedCorners(from: corners, in: geometry.size)
                
                // Draw filled rectangle
                path.move(to: screenCorners[0])
                for i in 1..<4 {
                    path.addLine(to: screenCorners[i])
                }
                path.closeSubpath()
            }
            .fill(Color.green.opacity(0.3)) // Light green fill
            
            // Optional: Add subtle border
            Path { path in
                guard corners.count == 4 else { return }
                
                let screenCorners = expandedCorners(from: corners, in: geometry.size)
                
                path.move(to: screenCorners[0])
                for i in 1..<4 {
                    path.addLine(to: screenCorners[i])
                }
                path.closeSubpath()
            }
            .stroke(Color.green.opacity(0.6), lineWidth: 2)
            
            // Confidence badge in center
            if let centerPoint = calculateCenter(from: corners) {
                Text("\(Int(confidence * 100))%")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(12)
                    .position(
                        x: centerPoint.x * geometry.size.width,
                        y: (1 - centerPoint.y) * geometry.size.height
                    )
            }
        }
    }
    
    private func calculateCenter(from corners: [CGPoint]) -> CGPoint? {
        guard corners.count == 4 else { return nil }
        let sumX = corners.reduce(0) { $0 + $1.x }
        let sumY = corners.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / 4, y: sumY / 4)
    }
    
    private func expandedCorners(from corners: [CGPoint], in size: CGSize) -> [CGPoint] {
        guard corners.count == 4 else { return [] }
        
        // Calculate center
        let centerX = corners.reduce(0) { $0 + $1.x } / 4
        let centerY = corners.reduce(0) { $0 + $1.y } / 4
        let center = CGPoint(x: centerX, y: centerY)
        
        // Expand each corner away from center by 8% to ensure coverage without overdoing bottom
        let expansionFactor: CGFloat = 1.08
        
        return corners.enumerated().map { index, corner in
            // Vector from center to corner
            let dx = corner.x - center.x
            let dy = corner.y - center.y
            
            // Expanded position with general expansion
            var expandedX = center.x + dx * expansionFactor
            var expandedY = center.y + dy * expansionFactor
            
            // Additional edge expansion - uniform small amount
            let edgeExpansion: CGFloat = 0.01
            
            // Top corners (indices 0, 1)
            if index <= 1 {
                expandedY = min(expandedY + edgeExpansion, 1.0)
            }
            // Bottom corners (indices 2, 3) - same small expansion as others
            else {
                expandedY = max(expandedY - edgeExpansion, 0.0)
            }
            
            // Left corners (indices 0, 3)
            if index == 0 || index == 3 {
                expandedX = max(expandedX - edgeExpansion, 0.0)
            }
            // Right corners (indices 1, 2)
            else {
                expandedX = min(expandedX + edgeExpansion, 1.0)
            }
            
            // Convert to screen coordinates
            return CGPoint(
                x: expandedX * size.width,
                y: (1 - expandedY) * size.height
            )
        }
    }
}

// MARK: - Hand Overlay
struct HandOverlay: View {
    let hand: DetectedHand
    let geometry: GeometryProxy
    
    var body: some View {
        let rect = CGRect(
            x: hand.boundingBox.minX * geometry.size.width,
            y: (1 - hand.boundingBox.maxY) * geometry.size.height,
            width: hand.boundingBox.width * geometry.size.width,
            height: hand.boundingBox.height * geometry.size.height
        )
        
        Rectangle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .overlay(
                Text("\(hand.fingerCount)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(6)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(8)
                    .position(x: rect.midX, y: rect.minY - 20)
            )
    }
}

// MARK: - Debug Info View
struct DebugInfoView: View {
    let rectangleCount: Int
    let handCount: Int
    let lastUpdate: Date
    
    @State private var fps: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CV Debug Info")
                .font(.caption)
                .fontWeight(.bold)
            
            Text("Rectangles: \(rectangleCount)")
                .font(.caption2)
            
            Text("Hands: \(handCount)")
                .font(.caption2)
            
            Text("FPS: ~\(fps)")
                .font(.caption2)
                .onAppear {
                    startFPSTimer()
                }
                .onDisappear {
                    timer?.invalidate()
                }
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    private func startFPSTimer() {
        var lastTime = Date()
        var frameCount = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let now = Date()
            if now.timeIntervalSince(lastUpdate) < 0.1 {
                frameCount += 1
            }
            
            if now.timeIntervalSince(lastTime) >= 1.0 {
                fps = frameCount
                frameCount = 0
                lastTime = now
            }
        }
    }
}