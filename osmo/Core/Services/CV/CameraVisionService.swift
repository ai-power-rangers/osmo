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
    private let continuationQueue = DispatchQueue(label: "com.osmoapp.cv.continuations", attributes: .concurrent)
    
    // Camera session
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var currentDevice: AVCaptureDevice?
    
    // Vision
    private var handDetectionRequest: VNDetectHumanHandPoseRequest?
    private var rectangleDetectionRequest: VNDetectRectanglesRequest?
    private var sequenceHandler: VNSequenceRequestHandler?
    
    // State
    private(set) var isSessionActive = false
    private var eventContinuations: [String: AsyncStream<CVEvent>.Continuation] = [:]
    var debugMode = false
    
    // Tracking
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 1.0 / 30.0 // 30 FPS
    private var fingerDetector = FingerDetector()
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupVisionRequests()
        sequenceHandler = VNSequenceRequestHandler()
    }
    
    // MARK: - ServiceLifecycle
    func initialize() async throws {
        logger.info("[CameraVision] Service initialized")
    }
    
    // MARK: - CVServiceProtocol
    func startSession() async throws {
        guard !isSessionActive else { return }
        
        do {
            try await setupCamera()
            isSessionActive = true
            
            logger.info("[CameraVision] Session started with front camera")
            
            // Analytics
            let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
            analytics.logEvent("cv_session_started", parameters: [:])
        } catch {
            logger.error("[CameraVision] Failed to start session: \(error)")
            throw CVError.sessionFailure(error)
        }
    }
    
    func stopSession() {
        captureSession?.stopRunning()
        isSessionActive = false
        
        logger.info("[CameraVision] Session stopped")
        
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("cv_session_stopped", parameters: [:])
    }
    
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent> {
        AsyncStream { continuation in
            continuationQueue.async(flags: .barrier) {
                self.eventContinuations[gameId] = continuation
            }
            
            logger.info("[CameraVision] Game \(gameId) subscribed to event stream")
            
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self = self else { return }
                self.continuationQueue.async(flags: .barrier) {
                    self.eventContinuations.removeValue(forKey: gameId)
                }
                self.logger.info("[CameraVision] Game \(gameId) stream terminated")
            }
        }
    }
    
    // MARK: - Camera Setup
    private func setupCamera() async throws {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Use high quality for better hand detection
        session.sessionPreset = .high
        
        // Get front camera
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CVError.cameraNotAvailable
        }
        
        currentDevice = frontCamera
        
        // Configure camera for optimal hand detection
        try frontCamera.lockForConfiguration()
        
        // Set frame rate for smooth detection
        frontCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        frontCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        
        // Enable auto-exposure and auto-focus
        if frontCamera.isExposureModeSupported(.continuousAutoExposure) {
            frontCamera.exposureMode = .continuousAutoExposure
        }
        
        if frontCamera.isFocusModeSupported(.continuousAutoFocus) {
            frontCamera.focusMode = .continuousAutoFocus
        }
        
        frontCamera.unlockForConfiguration()
        
        // Add camera input
        let input = try AVCaptureDeviceInput(device: frontCamera)
        guard session.canAddInput(input) else {
            throw CVError.cameraConfigurationFailed
        }
        session.addInput(input)
        
        // Setup video output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        
        guard session.canAddOutput(output) else {
            throw CVError.cameraConfigurationFailed
        }
        session.addOutput(output)
        
        videoOutput = output
        
        // Set video orientation for front camera
        if let connection = output.connection(with: .video) {
            connection.isVideoMirrored = true // Mirror for selfie mode
            // Use rotation angle for iOS 17+
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90.0
            }
        }
        
        session.commitConfiguration()
        
        // Start capture session
        captureSession = session
        
        await MainActor.run {
            session.startRunning()
        }
        
        logger.info("[CameraVision] Camera configured: Front camera, portrait mode, mirrored")
    }
    
    // MARK: - Vision Setup
    private func setupVisionRequests() {
        // Hand detection request
        handDetectionRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
            if let error = error {
                self?.logger.error("[CameraVision] Hand detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanHandPoseObservation] else {
                if self?.debugMode ?? false {
                    self?.logger.info("[CameraVision] No hand pose observations in results")
                }
                return
            }
            
            self?.processHandObservations(observations)
        }
        
        // Configure for best accuracy
        handDetectionRequest?.maximumHandCount = 2
        
        // Rectangle detection for sudoku
        rectangleDetectionRequest = VNDetectRectanglesRequest { [weak self] request, error in
            if let error = error {
                self?.logger.error("[CameraVision] Rectangle detection error: \(error)")
                return
            }
            
            self?.processRectangleObservations(request.results as? [VNRectangleObservation] ?? [])
        }
        
        rectangleDetectionRequest?.minimumAspectRatio = 0.5
        rectangleDetectionRequest?.maximumAspectRatio = 2.0
        rectangleDetectionRequest?.minimumSize = 0.2
        rectangleDetectionRequest?.maximumObservations = 1
    }
    
    // MARK: - Event Publishing
    private func publishEvent(_ event: CVEvent) {
        continuationQueue.sync {
            for continuation in eventContinuations.values {
                continuation.yield(event)
            }
        }
        
        if debugMode {
            logger.debug("[CameraVision] Published event: \(String(describing: event.type))")
        }
    }
    
    // MARK: - Hand Processing
    private func processHandObservations(_ observations: [VNHumanHandPoseObservation]) {
        if debugMode {
            logger.info("[CameraVision] Processing \(observations.count) hand observations")
        }
        
        for observation in observations {
            guard let handObservation = createHandObservation(from: observation) else {
                if debugMode {
                    logger.info("[CameraVision] Failed to create hand observation")
                }
                continue
            }
            
            // Track hand
            if !trackedHands.keys.contains(handObservation.id) {
                trackedHands[handObservation.id] = handObservation
                publishEvent(CVEvent(
                    type: .handDetected(handId: handObservation.id, chirality: handObservation.chirality)
                ))
            }
            
            // Detect fingers
            let fingerResult = fingerDetector.detectRaisedFingers(from: handObservation)
            
            if debugMode {
                logger.info("[CameraVision] Finger detection result: count=\(fingerResult.count), confidence=\(fingerResult.confidence)")
            }
            
            // Publish finger count event
            publishEvent(CVEvent(
                type: .fingerCountDetected(count: fingerResult.count),
                position: CGPoint(x: 0.5, y: 0.5),
                confidence: fingerResult.confidence,
                metadata: CVMetadata(
                    boundingBox: handObservation.boundingBox,
                    additionalProperties: [
                        "hand_chirality": fingerResult.handChirality.rawValue,
                        "raised_fingers": fingerResult.raisedFingers.map { $0.rawValue }
                    ]
                )
            ))
        }
    }
    
    private var trackedHands: [UUID: HandObservation] = [:]
    
    private func createHandObservation(from vnObservation: VNHumanHandPoseObservation) -> HandObservation? {
        do {
            // Extract all landmarks
            let landmarks = try HandLandmarks(
                wrist: vnObservation.recognizedPoint(.wrist).location,
                thumbTip: vnObservation.recognizedPoint(.thumbTip).location,
                thumbIP: vnObservation.recognizedPoint(.thumbIP).location,
                thumbMP: vnObservation.recognizedPoint(.thumbMP).location,
                thumbCMC: vnObservation.recognizedPoint(.thumbCMC).location,
                indexTip: vnObservation.recognizedPoint(.indexTip).location,
                indexDIP: vnObservation.recognizedPoint(.indexDIP).location,
                indexPIP: vnObservation.recognizedPoint(.indexPIP).location,
                indexMCP: vnObservation.recognizedPoint(.indexMCP).location,
                middleTip: vnObservation.recognizedPoint(.middleTip).location,
                middleDIP: vnObservation.recognizedPoint(.middleDIP).location,
                middlePIP: vnObservation.recognizedPoint(.middlePIP).location,
                middleMCP: vnObservation.recognizedPoint(.middleMCP).location,
                ringTip: vnObservation.recognizedPoint(.ringTip).location,
                ringDIP: vnObservation.recognizedPoint(.ringDIP).location,
                ringPIP: vnObservation.recognizedPoint(.ringPIP).location,
                ringMCP: vnObservation.recognizedPoint(.ringMCP).location,
                littleTip: vnObservation.recognizedPoint(.littleTip).location,
                littleDIP: vnObservation.recognizedPoint(.littleDIP).location,
                littlePIP: vnObservation.recognizedPoint(.littlePIP).location,
                littleMCP: vnObservation.recognizedPoint(.littleMCP).location
            )
            
            // Determine chirality based on thumb position relative to wrist
            let chirality = determineChirality(landmarks: landmarks)
            
            // Calculate bounding box from landmarks
            let boundingBox = calculateBoundingBox(from: landmarks)
            
            return HandObservation(
                id: UUID(),
                chirality: chirality,
                landmarks: landmarks,
                confidence: vnObservation.confidence,
                boundingBox: boundingBox
            )
        } catch {
            logger.error("[CameraVision] Failed to extract hand landmarks: \(error)")
            return nil
        }
    }
    
    private func determineChirality(landmarks: HandLandmarks) -> HandChirality {
        // Simple heuristic: check if thumb is on left or right of wrist
        if landmarks.thumbCMC.x < landmarks.wrist.x {
            return .left
        } else {
            return .right
        }
    }
    
    private func calculateBoundingBox(from landmarks: HandLandmarks) -> CGRect {
        // Get all landmark points
        let allPoints = [
            landmarks.wrist,
            landmarks.thumbTip, landmarks.thumbIP, landmarks.thumbMP, landmarks.thumbCMC,
            landmarks.indexTip, landmarks.indexDIP, landmarks.indexPIP, landmarks.indexMCP,
            landmarks.middleTip, landmarks.middleDIP, landmarks.middlePIP, landmarks.middleMCP,
            landmarks.ringTip, landmarks.ringDIP, landmarks.ringPIP, landmarks.ringMCP,
            landmarks.littleTip, landmarks.littleDIP, landmarks.littlePIP, landmarks.littleMCP
        ]
        
        // Find min/max coordinates
        let xCoords = allPoints.map { $0.x }
        let yCoords = allPoints.map { $0.y }
        
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 1
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 1
        
        // Add small padding
        let padding: CGFloat = 0.05
        let x = max(0, minX - padding)
        let y = max(0, minY - padding)
        let width = min(1 - x, (maxX - minX) + 2 * padding)
        let height = min(1 - y, (maxY - minY) + 2 * padding)
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Rectangle Processing
    private var trackedRectangles: [UUID: RectangleObservation] = [:]
    
    private func processRectangleObservations(_ observations: [VNRectangleObservation]) {
        // Similar to ARKitCVService implementation
        for observation in observations {
            let corners = [
                observation.topLeft,
                observation.topRight,
                observation.bottomRight,
                observation.bottomLeft
            ]
            
            let rectangleObs = RectangleObservation(
                id: UUID(),
                corners: corners,
                confidence: observation.confidence,
                boundingBox: observation.boundingBox
            )
            
            if rectangleObs.confidence > 0.7 {
                trackedRectangles[rectangleObs.id] = rectangleObs
                publishEvent(CVEvent(
                    type: .sudokuGridDetected(gridId: rectangleObs.id, corners: corners),
                    confidence: rectangleObs.confidence
                ))
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraVisionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle processing
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessedTime >= processingInterval else { return }
        lastProcessedTime = currentTime
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Process the frame
        processFrame(pixelBuffer: pixelBuffer)
    }
    
    private func processFrame(pixelBuffer: CVPixelBuffer) {
        var requests: [VNRequest] = []
        
        if let handRequest = handDetectionRequest {
            requests.append(handRequest)
        }
        
        if let rectangleRequest = rectangleDetectionRequest {
            requests.append(rectangleRequest)
        }
        
        do {
            try sequenceHandler?.perform(requests, on: pixelBuffer)
        } catch {
            logger.error("[CameraVision] Failed to perform vision requests: \(error)")
        }
    }
}

// MARK: - CVError Extension
extension CVError {
    static let cameraNotAvailable = CVError.sessionFailure(NSError(domain: "CameraVision", code: 1, userInfo: [NSLocalizedDescriptionKey: "Front camera not available"]))
    static let cameraConfigurationFailed = CVError.sessionFailure(NSError(domain: "CameraVision", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to configure camera"]))
}