//
//  CVService.swift
//  osmo
//
//  Simple computer vision service for GameKit
//

import AVFoundation
import Vision
import SwiftUI

@MainActor
public final class CVService: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastDetectionTime = Date()
    private let detectionInterval: TimeInterval = 0.1 // Detect every 100ms
    
    public override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              let session = captureSession else {
            print("[CV] Failed to setup camera")
            return
        }
        
        session.addInput(input)
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cv.queue"))
        
        if let output = videoOutput {
            session.addOutput(output)
        }
    }
    
    // MARK: - Public API
    
    public func startDetection() {
        captureSession?.startRunning()
    }
    
    public func stopDetection() {
        captureSession?.stopRunning()
    }
    
    public func startSession() async throws {
        captureSession?.startRunning()
    }
    
    public func stopSession() {
        captureSession?.stopRunning()
    }
    
    public func eventStream(for game: String = "default") -> AsyncStream<CVEvent> {
        AsyncStream { continuation in
            // Simple event stream
            continuation.finish()
        }
    }
    
    public func createPreviewLayer() -> CALayer? {
        guard let session = captureSession else { return nil }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }
    
    // MARK: - Detection Results
    
    public enum CVEvent {
        case fingerDetected(count: Int)
        case pieceDetected(DetectedPiece)
        case rectangleDetected(CGRect)
        case error(Error)
    }
    
    public struct DetectionResult {
        let pieces: [DetectedPiece]
        let timestamp: Date
    }
    
    public struct DetectedPiece {
        let id: UUID = UUID()
        let bounds: CGRect
        let center: CGPoint
        let rotation: Double
        let confidence: Float
        let color: UIColor
    }
    
    // Callback for detection results
    public var onDetection: ((DetectionResult) -> Void)?
    
    // MARK: - Simple Shape Detection
    
    private func detectShapes(in image: CIImage) {
        // Simple shape detection logic
        // This is a placeholder - real implementation would use Vision framework
        
        let result = DetectionResult(
            pieces: [],
            timestamp: Date()
        )
        
        Task { @MainActor in
            onDetection?(result)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CVService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                            didOutput sampleBuffer: CMSampleBuffer,
                            from connection: AVCaptureConnection) {
        
        // Throttle detection
        guard Date().timeIntervalSince(lastDetectionTime) > detectionInterval else { return }
        lastDetectionTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        detectShapes(in: ciImage)
    }
}