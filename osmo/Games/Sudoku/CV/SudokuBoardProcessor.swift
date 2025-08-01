//
//  SudokuBoardProcessor.swift
//  osmo
//
//  Board and text detection processor for Sudoku
//

import Foundation
import Vision
import AVFoundation
import CoreGraphics
import CoreImage

final class SudokuBoardProcessor: BaseGameCVProcessor {
    
    // MARK: - Properties
    
    private var rectangleRequest: VNDetectRectanglesRequest?
    private var textRequest: VNRecognizeTextRequest?
    private let requestHandler = VNSequenceRequestHandler()
    
    private var boardDetector: SudokuBoardDetector
    private var numberRecognizer: SudokuNumberRecognizer
    private let gridSize: GridSize
    
    private var lastDetectedBoard: BoardDetection?
    private var isProcessingText = false
    private var currentProcessingPosition: Position?
    
    // MARK: - Initialization
    
    init(gridSize: GridSize) {
        self.gridSize = gridSize
        self.boardDetector = SudokuBoardDetector(gridSize: gridSize)
        self.numberRecognizer = SudokuNumberRecognizer(gridSize: gridSize)
        super.init(gameId: SudokuGameModule.gameId)
        setupVisionRequests()
    }
    
    // MARK: - Setup
    
    private func setupVisionRequests() {
        // Rectangle detection for board
        rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
            if let error = error {
                print("[SudokuProcessor] Rectangle detection error: \(error)")
                return
            }
            
            guard let results = request.results as? [VNRectangleObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                self?.processRectangleObservations(results)
            }
        }
        
        rectangleRequest?.minimumAspectRatio = 0.4  // More flexible for angled boards
        rectangleRequest?.maximumAspectRatio = 2.5  // Allow more perspective distortion
        rectangleRequest?.minimumSize = 0.2  // Board can be smaller (20% of frame)
        rectangleRequest?.maximumObservations = 3  // Detect multiple to choose best
        rectangleRequest?.minimumConfidence = 0.5  // Lower confidence threshold
        
        // Text recognition for numbers
        textRequest = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                print("[SudokuProcessor] Text recognition error: \(error)")
                return
            }
            
            guard let results = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                self?.processTextObservations(results)
            }
        }
        
        textRequest?.recognitionLevel = .accurate
        textRequest?.recognitionLanguages = ["en-US"]
        textRequest?.usesLanguageCorrection = false
    }
    
    // MARK: - Processing
    
    override func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Always try to detect rectangles
        if let rectangleRequest = rectangleRequest {
            do {
                try requestHandler.perform([rectangleRequest], on: pixelBuffer)
            } catch {
                print("[SudokuProcessor] Failed to perform rectangle detection: \(error)")
            }
        }
        
        // Only process text if we have a board and aren't already processing
        if lastDetectedBoard != nil && !isProcessingText {
            processTextInBoard(pixelBuffer: pixelBuffer)
        }
    }
    
    // MARK: - Rectangle Processing
    
    private func processRectangleObservations(_ observations: [VNRectangleObservation]) {
        // Find the best rectangle (largest and most confident)
        let bestObservation = observations
            .sorted { first, second in
                // Calculate area approximation (using bounding box)
                let firstArea = abs((first.topRight.x - first.topLeft.x) * (first.bottomLeft.y - first.topLeft.y))
                let secondArea = abs((second.topRight.x - second.topLeft.x) * (second.bottomLeft.y - second.topLeft.y))
                
                // Prefer larger area with higher confidence
                let firstScore = firstArea * CGFloat(first.confidence)
                let secondScore = secondArea * CGFloat(second.confidence)
                
                return firstScore > secondScore
            }
            .first
        
        if let observation = bestObservation {
            // Convert to screen coordinates
            let rectangle = CVRectangle(
                topLeft: convertPoint(observation.topLeft),
                topRight: convertPoint(observation.topRight),
                bottomLeft: convertPoint(observation.bottomLeft),
                bottomRight: convertPoint(observation.bottomRight),
                confidence: observation.confidence
            )
            
            // Process through board detector
            if let boardDetection = boardDetector.processQuadrilateral(rectangle) {
                lastDetectedBoard = boardDetection
                
                // Emit rectangle detected event with all detected rectangles for debugging
                let allRectangles = observations.map { obs in
                    CVRectangle(
                        topLeft: convertPoint(obs.topLeft),
                        topRight: convertPoint(obs.topRight),
                        bottomLeft: convertPoint(obs.bottomLeft),
                        bottomRight: convertPoint(obs.bottomRight),
                        confidence: obs.confidence
                    )
                }
                
                let event = CVEvent(
                    type: .rectangleDetected(rectangles: allRectangles),
                    confidence: boardDetection.confidence
                )
                emit(event: event)
                
                print("[SudokuProcessor] Board detected with confidence: \(boardDetection.confidence)")
            }
        } else {
            // No board detected
            lastDetectedBoard = nil
            let event = CVEvent(type: .rectangleLost, confidence: 1.0)
            emit(event: event)
        }
    }
    
    // MARK: - Text Processing
    
    private func processTextInBoard(pixelBuffer: CVPixelBuffer) {
        guard let board = lastDetectedBoard,
              let textRequest = textRequest else {
            return
        }
        
        isProcessingText = true
        
        // Create a task to process text detection
        Task {
            defer { isProcessingText = false }
            
            // Convert pixel buffer to CIImage for processing
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // For each cell in the grid, check for text
            let dimension = gridSize.rawValue
            
            for row in 0..<dimension {
                for col in 0..<dimension {
                    let position = Position(row: row, col: col)
                    
                    // Get cell bounds in normalized coordinates
                    let cellBounds = getCellBounds(for: position, in: board)
                    
                    // Extract and rotate cell region for upside-down text
                    if let cellImage = extractAndRotateCellImage(from: ciImage, bounds: cellBounds) {
                        // Store current position for text processing callback
                        currentProcessingPosition = position
                        
                        // Create new request handler for rotated image
                        let rotatedHandler = VNImageRequestHandler(ciImage: cellImage, options: [:])
                        
                        do {
                            try rotatedHandler.perform([textRequest])
                        } catch {
                            print("[SudokuProcessor] Failed to perform text recognition: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func extractAndRotateCellImage(from ciImage: CIImage, bounds: CGRect) -> CIImage? {
        // Extract cell region
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        
        let cellRect = CGRect(
            x: bounds.origin.x * width,
            y: bounds.origin.y * height,
            width: bounds.width * width,
            height: bounds.height * height
        )
        
        let cropped = ciImage.cropped(to: cellRect)
        
        // Rotate 180 degrees for upside-down text
        let rotated = cropped.transformed(by: CGAffineTransform(rotationAngle: .pi))
        
        // Translate back to positive coordinates
        let transformed = rotated.transformed(by: CGAffineTransform(translationX: cellRect.width, y: cellRect.height))
        
        return transformed
    }
    
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) {
        guard let position = currentProcessingPosition else { return }
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            
            // Validate it's a number
            if let number = Int(text), number >= 1 && number <= gridSize.maxNumber {
                // Convert bounding box to screen coordinates
                let boundingBox = CGRect(
                    x: observation.boundingBox.origin.x,
                    y: 1 - observation.boundingBox.origin.y - observation.boundingBox.height,
                    width: observation.boundingBox.width,
                    height: observation.boundingBox.height
                )
                
                // Emit text detected event with position metadata
                let event = CVEvent(
                    type: .textDetected(text: text, boundingBox: boundingBox),
                    confidence: confidence,
                    metadata: CVMetadata(
                        additionalProperties: [
                            "position_row": position.row,
                            "position_col": position.col
                        ]
                    )
                )
                emit(event: event)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertPoint(_ point: CGPoint) -> CGPoint {
        // Convert from Vision coordinates (bottom-left origin) to UIKit (top-left origin)
        return CGPoint(x: point.x, y: 1 - point.y)
    }
    
    private func getCellBounds(for position: Position, in board: BoardDetection) -> CGRect {
        let dimension = CGFloat(gridSize.rawValue)
        let cellSize = 1.0 / dimension
        
        // Calculate normalized bounds for this cell
        let x = CGFloat(position.col) * cellSize
        let y = CGFloat(position.row) * cellSize
        
        return CGRect(x: x, y: y, width: cellSize, height: cellSize)
    }
}