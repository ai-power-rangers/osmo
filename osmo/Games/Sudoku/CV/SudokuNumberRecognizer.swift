//
//  SudokuNumberRecognizer.swift
//  osmo
//
//  Number recognition for Sudoku tiles with 180° rotation handling
//

import Foundation
import CoreGraphics
import Vision
import CoreImage

final class SudokuNumberRecognizer {
    
    // MARK: - Properties
    
    private let gridSize: GridSize
    private var textRecognitionRequest: VNRecognizeTextRequest?
    private let confidenceThreshold: Float = 0.6
    
    // Temporal consistency tracking
    private var detectionHistory: [Position: [Int?]] = [:]
    private let historySize = 5
    
    // MARK: - Initialization
    
    init(gridSize: GridSize) {
        self.gridSize = gridSize
        setupTextRecognition()
    }
    
    // MARK: - Setup
    
    private func setupTextRecognition() {
        textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                print("[Sudoku] Text recognition error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            self?.processTextObservations(observations)
        }
        
        // Configure for single digit recognition
        textRecognitionRequest?.recognitionLevel = .accurate
        textRecognitionRequest?.recognitionLanguages = ["en-US"]
        textRecognitionRequest?.usesLanguageCorrection = false
    }
    
    // MARK: - Public Methods
    
    func recognizeNumber(in image: CGImage, at cellBounds: CGRect) -> TileDetection? {
        // Rotate image 180° for upside-down view
        guard let rotatedImage = rotateImage(image, by: 180) else { return nil }
        
        // Create request handler
        let handler = VNImageRequestHandler(cgImage: rotatedImage, options: [:])
        
        // Perform recognition
        do {
            try handler.perform([textRecognitionRequest].compactMap { $0 })
        } catch {
            print("[Sudoku] Failed to perform text recognition: \(error)")
            return nil
        }
        
        // Process results would be handled in the completion handler
        // For this simplified version, return nil
        return nil
    }
    
    func processDetectedText(_ text: String, at position: Position, confidence: Float) -> Int? {
        // Validate text is a single digit in valid range
        guard let number = Int(text),
              number >= 1 && number <= gridSize.maxNumber else {
            return nil
        }
        
        // Add to history for temporal consistency
        updateDetectionHistory(number: number, at: position)
        
        // Get stable detection
        return getStableNumber(at: position)
    }
    
    // MARK: - Private Methods
    
    private func rotateImage(_ image: CGImage, by degrees: CGFloat) -> CGImage? {
        let radians = degrees * .pi / 180
        
        let width = image.width
        let height = image.height
        
        // Create context
        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else {
            return nil
        }
        
        // Apply rotation
        context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        context.rotate(by: radians)
        context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
        
        // Draw image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) {
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // Process if confidence is high enough
            if confidence >= confidenceThreshold {
                // Would emit detection event here
                print("[Sudoku] Detected text: \(text) with confidence: \(confidence)")
            }
        }
    }
    
    private func updateDetectionHistory(number: Int, at position: Position) {
        if detectionHistory[position] == nil {
            detectionHistory[position] = []
        }
        
        detectionHistory[position]?.append(number)
        
        // Keep only recent detections
        if let count = detectionHistory[position]?.count, count > historySize {
            detectionHistory[position]?.removeFirst()
        }
    }
    
    private func getStableNumber(at position: Position) -> Int? {
        guard let history = detectionHistory[position],
              history.count >= 3 else {
            return nil
        }
        
        // Count occurrences
        var counts: [Int: Int] = [:]
        for num in history.compactMap({ $0 }) {
            counts[num, default: 0] += 1
        }
        
        // Return most frequent if it appears in majority
        if let (number, count) = counts.max(by: { $0.value < $1.value }),
           count >= history.count / 2 {
            return number
        }
        
        return nil
    }
    
    // MARK: - Cell Detection
    
    func detectTilePresence(in cellImage: CGImage) -> Bool {
        // Simple detection based on contrast
        // In production, would use more sophisticated detection
        
        guard let pixelData = cellImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return false
        }
        
        let width = cellImage.width
        let height = cellImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cellImage.bytesPerRow
        
        var totalBrightness: Int = 0
        let sampleSize = 10  // Sample every 10th pixel for efficiency
        
        for y in stride(from: 0, to: height, by: sampleSize) {
            for x in stride(from: 0, to: width, by: sampleSize) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                
                // Calculate brightness
                let brightness = (Int(r) + Int(g) + Int(b)) / 3
                totalBrightness += brightness
            }
        }
        
        let avgBrightness = totalBrightness / ((width / sampleSize) * (height / sampleSize))
        
        // If average brightness is above threshold, likely a tile is present
        return avgBrightness > 128  // Threshold for tile detection
    }
}

// MARK: - Helper Extensions

extension SudokuNumberRecognizer {
    
    struct RecognitionResult {
        let number: Int
        let confidence: Float
        let boundingBox: CGRect
    }
    
    func recognizeAllNumbers(in boardImage: CGImage, with boardDetection: BoardDetection) -> [Position: RecognitionResult] {
        var results: [Position: RecognitionResult] = [:]
        
        let dimension = gridSize.rawValue
        let cellWidth = boardImage.width / dimension
        let cellHeight = boardImage.height / dimension
        
        for row in 0..<dimension {
            for col in 0..<dimension {
                let position = Position(row: row, col: col)
                
                // Extract cell region
                let cellRect = CGRect(
                    x: col * cellWidth,
                    y: row * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                
                guard let cellImage = boardImage.cropping(to: cellRect) else { continue }
                
                // Check if tile is present
                if detectTilePresence(in: cellImage) {
                    // Recognize number
                    if let detection = recognizeNumber(in: cellImage, at: cellRect) {
                        if let number = processDetectedText(
                            "\(detection.number ?? 0)",
                            at: position,
                            confidence: detection.confidence
                        ) {
                            results[position] = RecognitionResult(
                                number: number,
                                confidence: detection.confidence,
                                boundingBox: cellRect
                            )
                        }
                    }
                }
            }
        }
        
        return results
    }
}