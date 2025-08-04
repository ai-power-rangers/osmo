//
//  CameraVisionService.swift
//  osmo
//
//  Created for proper front camera hand detection
//

import AVFoundation
import Vision
import CoreImage
import os.log
import UIKit

// MARK: - Camera Vision Service
final class CameraVisionService: NSObject, CVServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.osmoapp", category: "cv.camera")
    private let processingQueue = DispatchQueue(label: "com.osmoapp.cv.processing", qos: .userInitiated)
    
    // Camera session
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?
    
    // Game processors
    private var activeProcessor: GameCVProcessor?
    
    // State
    private(set) var isSessionActive = false
    var debugMode = false
    
    // Service dependencies
    private weak var analyticsService: AnalyticsServiceProtocol?
    
    // Public access to camera session for preview
    var cameraSession: AVCaptureSession? {
        captureSession
    }
    
    // Tracking
    private var lastProcessedTime: TimeInterval = 0
    private var processingInterval: TimeInterval = 1.0 / 30.0 // Default 30 FPS, will adjust based on camera
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - ServiceLifecycle
    func initialize() async throws {
        logger.info("[CameraVision] Service initialized")
    }
    
    func cleanup() async {
        stopSession()
    }
    
    func setAnalyticsService(_ service: AnalyticsServiceProtocol) {
        self.analyticsService = service
        
        // Also inject into CameraPermissionManager
        CameraPermissionManager.shared.setAnalyticsService(service)
    }
    
    // MARK: - CVServiceProtocol
    func startSession() async throws {
        guard !isSessionActive else { return }
        
        do {
            try await setupCamera()
            isSessionActive = true
            
            logger.info("[CameraVision] Session started with front camera")
            
            // Analytics
            analyticsService?.logEvent("cv_session_started", parameters: [:])
        } catch {
            logger.error("[CameraVision] Failed to start session: \(error)")
            throw CVError.sessionFailure(error)
        }
    }
    
    func stopSession() {
        captureSession?.stopRunning()
        isSessionActive = false
        
        // Stop active processor
        activeProcessor?.stopProcessing()
        activeProcessor = nil
        
        logger.info("[CameraVision] Session stopped")
        
        analyticsService?.logEvent("cv_session_stopped", parameters: [:])
    }
    
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent> {
        // Set up appropriate processor based on game
        setupProcessor(for: gameId)
        
        // Return the processor's event stream if available
        if let processor = activeProcessor, processor.gameId == gameId {
            return processor.eventStream
        }
        
        // Fallback to empty stream
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    func eventStream(gameId: String, events: [CVEventType], configuration: [String: Any]) -> AsyncStream<CVEvent> {
        // Set up appropriate processor based on game with configuration
        setupProcessor(for: gameId, configuration: configuration)
        
        // Return the processor's event stream if available
        if let processor = activeProcessor, processor.gameId == gameId {
            return processor.eventStream
        }
        
        // Fallback to empty stream
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    private func setupProcessor(for gameId: String, configuration: [String: Any] = [:]) {
        // Stop existing processor if different game
        if let existing = activeProcessor, existing.gameId != gameId {
            existing.stopProcessing()
            activeProcessor = nil
        }
        
        // Create appropriate processor
        switch gameId {
        case RockPaperScissorsGameModule.gameId:
            activeProcessor = RPSHandProcessor()
        case SudokuGameModule.gameId:
            // Get grid size from configuration or default to 9x9
            let gridSizeRaw = configuration["gridSize"] as? Int ?? 9
            let gridSize: GridSize = (gridSizeRaw == 4) ? .fourByFour : .nineByNine
            activeProcessor = SudokuBoardProcessor(gridSize: gridSize)
            logger.info("[CameraVision] Created Sudoku processor with grid size: \(gridSize.displayName)")
        default:
            logger.warning("[CameraVision] No processor for game: \(gameId)")
            activeProcessor = nil
        }
        
        activeProcessor?.startProcessing()
        logger.info("[CameraVision] Set up processor for game: \(gameId)")
    }
    
    // MARK: - Camera Setup
    private func findBest60FpsFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        var bestFormat: AVCaptureDevice.Format?
        var bestResolution = 0
        
        for format in device.formats {
            // Check if format supports 60 FPS
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= 60.0 && range.minFrameRate <= 60.0 {
                    let desc = format.formatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                    let resolution = Int(dimensions.width * dimensions.height)
                    
                    // Prefer 720p (1280x720) for Vision framework performance
                    if dimensions.width == 1280 && dimensions.height == 720 {
                        logger.debug("[CameraVision] Found ideal 720p 60fps format")
                        return format // Best choice for computer vision
                    }
                    
                    // Otherwise, pick highest resolution that supports 60fps
                    if resolution > bestResolution {
                        bestResolution = resolution
                        bestFormat = format
                    }
                }
            }
        }
        
        if bestFormat != nil {
            logger.debug("[CameraVision] Found 60fps format")
        } else {
            logger.debug("[CameraVision] No 60fps format available")
        }
        
        return bestFormat
    }
    
    private func setupCamera() async throws {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Don't force a preset - we'll select format manually
        session.sessionPreset = .inputPriority
        
        // Get front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CVError.cameraUnavailable
        }
        
        currentDevice = frontCamera
        
        // Configure camera for optimal hand detection
        try frontCamera.lockForConfiguration()
        
        // Find and set 60 FPS format if available
        if let format60fps = findBest60FpsFormat(for: frontCamera) {
            // MUST set format first before frame duration
            frontCamera.activeFormat = format60fps
            
            let frameDuration = CMTime(value: 1, timescale: 60)
            frontCamera.activeVideoMinFrameDuration = frameDuration
            frontCamera.activeVideoMaxFrameDuration = frameDuration
            
            // Update processing interval to match
            processingInterval = 1.0 / 60.0
            
            let dimensions = CMVideoFormatDescriptionGetDimensions(format60fps.formatDescription)
            logger.info("[CameraVision] Configured 60 FPS at \(dimensions.width)x\(dimensions.height)")
        } else {
            // Fallback to best available frame rate on current format
            let format = frontCamera.activeFormat
            let ranges = format.videoSupportedFrameRateRanges
            if let bestRange = ranges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) {
                let targetFPS = min(30, Int32(bestRange.maxFrameRate))
                frontCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: targetFPS)
                frontCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: targetFPS)
                processingInterval = 1.0 / Double(targetFPS)
                logger.info("[CameraVision] Using fallback frame rate: \(targetFPS) FPS")
            }
        }
        
        // Disable smooth autofocus for better performance at high frame rates
        if frontCamera.isSmoothAutoFocusSupported {
            frontCamera.isSmoothAutoFocusEnabled = false
        }
        
        // Enable auto-exposure and auto-focus
        if frontCamera.isExposureModeSupported(.continuousAutoExposure) {
            frontCamera.exposureMode = .continuousAutoExposure
        }
        
        if frontCamera.isFocusModeSupported(.continuousAutoFocus) {
            frontCamera.focusMode = .continuousAutoFocus
        }
        
        frontCamera.unlockForConfiguration()
        
        // Create and configure input
        let input = try AVCaptureDeviceInput(device: frontCamera)
        
        guard session.canAddInput(input) else {
            throw CVError.detectionFailed("Cannot add camera input")
        }
        session.addInput(input)
        
        // Create and configure video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)
        
        guard session.canAddOutput(output) else {
            throw CVError.detectionFailed("Cannot add video output")
        }
        session.addOutput(output)
        
        // Configure video orientation for front camera in portrait
        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = true  // Mirror for front camera
        }
        
        // Store references
        captureSession = session
        videoOutput = output
        
        // Commit configuration and start
        session.commitConfiguration()
        
        // Start the session on a background queue
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                continuation.resume()
            }
        }
        
        logger.info("[CameraVision] Camera configured: Front camera, portrait mode, mirrored")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraVisionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle processing based on frame rate
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard currentTime - lastProcessedTime >= processingInterval else {
            return
        }
        lastProcessedTime = currentTime
        
        // Pass to active processor
        activeProcessor?.process(sampleBuffer: sampleBuffer)
    }
}