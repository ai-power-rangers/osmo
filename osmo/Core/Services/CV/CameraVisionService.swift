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
    
    // Public access to camera session for preview
    var cameraSession: AVCaptureSession? {
        captureSession
    }
    
    // Tracking
    private var lastProcessedTime: TimeInterval = 0
    private var processingInterval: TimeInterval = 1.0 / 30.0 // Default 30 FPS, will adjust based on camera
    private var fingerDetector = FingerDetector()
    
    // Smoothing
    private var recentFingerCounts: [Int] = []
    private let smoothingWindowSize = 3
    private var lastPublishedCount: Int = 0
    
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
            throw CVError.cameraNotAvailable
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
        
        // Parameters for rectangle detection - more permissive for smaller objects
        rectangleDetectionRequest?.minimumAspectRatio = 0.5  // Allow more rectangular shapes
        rectangleDetectionRequest?.maximumAspectRatio = 2.0  // Allow more rectangular shapes
        rectangleDetectionRequest?.minimumSize = 0.05  // Much smaller minimum size (5% of frame)
        rectangleDetectionRequest?.maximumObservations = 1
        rectangleDetectionRequest?.minimumConfidence = 0.4  // Lower confidence for initial detection
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
        
        // Create hand observations
        var currentHands: [HandObservation] = []
        for observation in observations {
            guard let handObservation = createHandObservation(from: observation) else {
                if debugMode {
                    logger.info("[CameraVision] Failed to create hand observation")
                }
                continue
            }
            currentHands.append(handObservation)
        }
        
        // Match current hands to tracked hands
        var matchedHands: [(tracked: HandObservation, current: HandObservation)] = []
        var unmatchedCurrentHands = currentHands
        var unmatchedTrackedIds = Set(trackedHands.keys)
        
        // Find best matches based on position
        for currentHand in currentHands {
            var bestMatch: (id: UUID, distance: CGFloat)?
            
            for (trackedId, trackedHand) in trackedHands {
                let dist = distance(from: trackedHand.boundingBox.center, to: currentHand.boundingBox.center)
                // Match if hand moved less than 20% of screen
                if dist < 0.2 {
                    if bestMatch == nil || dist < bestMatch!.distance {
                        bestMatch = (trackedId, dist)
                    }
                }
            }
            
            if let match = bestMatch {
                // Update tracked hand with new observation but keep same ID
                var updatedHand = currentHand
                updatedHand.id = match.id
                matchedHands.append((trackedHands[match.id]!, updatedHand))
                unmatchedTrackedIds.remove(match.id)
                unmatchedCurrentHands.removeAll { $0.id == currentHand.id }
            }
        }
        
        // Handle new hands
        for newHand in unmatchedCurrentHands {
            let id = UUID()
            var handWithId = newHand
            handWithId.id = id
            trackedHands[id] = handWithId
            publishEvent(CVEvent(
                type: .handDetected(handId: id, chirality: handWithId.chirality)
            ))
        }
        
        // Handle lost hands
        for lostId in unmatchedTrackedIds {
            trackedHands.removeValue(forKey: lostId)
            publishEvent(CVEvent(type: .handLost(handId: lostId)))
        }
        
        // Update tracked hands and process fingers for each hand
        for (_, updatedHand) in matchedHands {
            trackedHands[updatedHand.id] = updatedHand
        }
        
        // Process finger detection for all current hands
        if !trackedHands.isEmpty {
            // For multiple hands, show total finger count
            var totalFingerCount = 0
            var avgConfidence: Float = 0
            var handResults: [(HandObservation, FingerDetectionResult)] = []
            
            for (_, hand) in trackedHands {
                let fingerResult = fingerDetector.detectRaisedFingers(from: hand)
                handResults.append((hand, fingerResult))
                totalFingerCount += fingerResult.count
                avgConfidence += fingerResult.confidence
            }
            
            avgConfidence /= Float(trackedHands.count)
            
            // For single hand, show individual result with smoothing
            if trackedHands.count == 1, let (hand, fingerResult) = handResults.first {
                let smoothedCount = smoothFingerCount(fingerResult.count)
                let handOpenness = fingerDetector.calculateHandOpenness(from: hand)
                
                // Always publish to update position even if count hasn't changed
                publishEvent(CVEvent(
                    type: .fingerCountDetected(count: smoothedCount),
                    position: hand.boundingBox.center,
                    confidence: fingerResult.confidence,
                    metadata: CVMetadata(
                        boundingBox: hand.boundingBox,
                        additionalProperties: [
                            "hand_chirality": fingerResult.handChirality.rawValue,
                            "raised_fingers": fingerResult.raisedFingers.map { $0.rawValue },
                            "hand_openness": handOpenness
                        ]
                    )
                ))
                lastPublishedCount = smoothedCount
            } else if trackedHands.count > 1 {
                // For multiple hands, show each hand separately without smoothing
                for (hand, fingerResult) in handResults {
                    let handOpenness = fingerDetector.calculateHandOpenness(from: hand)
                    publishEvent(CVEvent(
                        type: .fingerCountDetected(count: fingerResult.count),
                        position: hand.boundingBox.center,
                        confidence: fingerResult.confidence,
                        metadata: CVMetadata(
                            boundingBox: hand.boundingBox,
                            additionalProperties: [
                                "hand_chirality": fingerResult.handChirality.rawValue,
                                "raised_fingers": fingerResult.raisedFingers.map { $0.rawValue },
                                "hand_id": hand.id.uuidString,
                                "hand_openness": handOpenness
                            ]
                        )
                    ))
                }
                // Clear smoothing for multiple hands
                recentFingerCounts.removeAll()
            }
        } else {
            // No hands detected
            lastPublishedCount = 0
            recentFingerCounts.removeAll()
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
        // For front camera (mirrored), check thumb position relative to index finger
        // In a mirrored view:
        // - Right hand: thumb is to the left of index finger
        // - Left hand: thumb is to the right of index finger
        let thumbX = landmarks.thumbCMC.x
        let indexX = landmarks.indexMCP.x
        
        // Since the camera is mirrored, we need to invert the logic
        if thumbX < indexX {
            return .right  // Thumb on left side in mirrored view = right hand
        } else {
            return .left   // Thumb on right side in mirrored view = left hand
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
    
    // MARK: - Smoothing
    private func smoothFingerCount(_ newCount: Int) -> Int {
        // Add to recent counts
        recentFingerCounts.append(newCount)
        
        // Keep only recent values
        if recentFingerCounts.count > smoothingWindowSize {
            recentFingerCounts.removeFirst()
        }
        
        // Use mode (most frequent value) for stability
        let countFrequency = Dictionary(recentFingerCounts.map { ($0, 1) }, uniquingKeysWith: +)
        let mode = countFrequency.max(by: { $0.value < $1.value })?.key ?? newCount
        
        return mode
    }
    
    // MARK: - Rectangle Processing
    private var trackedRectangles: [UUID: RectangleObservation] = [:]
    private var rectangleDetectionHistory: [Date] = []
    private var lastRectanglePublishTime: Date = Date()
    private var stableRectangleId: UUID?
    
    private func processRectangleObservations(_ observations: [VNRectangleObservation]) {
        if debugMode && !observations.isEmpty {
            logger.info("[CameraVision] Processing \(observations.count) rectangle observations")
        }
        
        for observation in observations {
            let corners = [
                observation.topLeft,
                observation.topRight,
                observation.bottomRight,
                observation.bottomLeft
            ]
            
            // Validate it's actually a rectangle (not a parallelogram)
            let topWidth = abs(observation.topRight.x - observation.topLeft.x)
            let bottomWidth = abs(observation.bottomRight.x - observation.bottomLeft.x)
            let leftHeight = abs(observation.topLeft.y - observation.bottomLeft.y)
            let rightHeight = abs(observation.topRight.y - observation.bottomRight.y)
            
            // Check if opposite sides are roughly equal (within 10% tolerance)
            let widthRatio = min(topWidth, bottomWidth) / max(topWidth, bottomWidth)
            let heightRatio = min(leftHeight, rightHeight) / max(leftHeight, rightHeight)
            
            guard widthRatio > 0.9 && heightRatio > 0.9 else {
                if debugMode {
                    logger.info("[CameraVision] Rejected parallelogram: width ratio \(widthRatio), height ratio \(heightRatio)")
                }
                continue
            }
            
            // Check angles are roughly 90 degrees
            let topLeftAngle = angleAtCorner(p1: observation.bottomLeft, corner: observation.topLeft, p2: observation.topRight)
            let topRightAngle = angleAtCorner(p1: observation.topLeft, corner: observation.topRight, p2: observation.bottomRight)
            
            // Angles should be close to 90 degrees (within 15 degree tolerance)
            guard abs(topLeftAngle - 90) < 15 && abs(topRightAngle - 90) < 15 else {
                if debugMode {
                    logger.info("[CameraVision] Rejected non-rectangle: angles \(topLeftAngle)°, \(topRightAngle)°")
                }
                continue
            }
            
            // Check aspect ratio
            let aspectRatio = topWidth > 0 ? leftHeight / topWidth : 0
            guard aspectRatio > 0.4 && aspectRatio < 2.5 else {
                if debugMode {
                    logger.info("[CameraVision] Rejected rectangle: aspect ratio \(aspectRatio) out of range")
                }
                continue
            }
            
            // Check minimum area (at least 2% of frame for smaller objects)
            let area = observation.boundingBox.width * observation.boundingBox.height
            guard area > 0.02 else {
                if debugMode {
                    logger.info("[CameraVision] Rejected rectangle: area \(area) too small")
                }
                continue
            }
            
            let rectangleObs = RectangleObservation(
                id: UUID(),
                corners: corners,
                confidence: observation.confidence,
                boundingBox: observation.boundingBox
            )
            
            if debugMode {
                logger.info("[CameraVision] Rectangle candidate: confidence=\(rectangleObs.confidence), aspectRatio=\(aspectRatio), area=\(area)")
            }
            
            // Lower confidence threshold for better detection
            if rectangleObs.confidence > 0.4 {
                // Track detection history
                let now = Date()
                rectangleDetectionHistory.append(now)
                
                // Remove old detections (older than 0.5 seconds)
                rectangleDetectionHistory.removeAll { now.timeIntervalSince($0) > 0.5 }
                
                // Find matching existing rectangle
                let matchingRectangle = trackedRectangles.values.first { existing in
                    let centerDistance = distance(from: existing.boundingBox.center, to: rectangleObs.boundingBox.center)
                    return centerDistance < 0.1 // 10% movement threshold
                }
                
                if let existing = matchingRectangle {
                    // Update existing rectangle
                    trackedRectangles[existing.id] = rectangleObs
                    
                    // Only publish updates every 100ms to reduce flicker
                    if now.timeIntervalSince(lastRectanglePublishTime) > 0.1 {
                        lastRectanglePublishTime = now
                        publishEvent(CVEvent(
                            type: .sudokuGridDetected(gridId: existing.id, corners: corners),
                            confidence: rectangleObs.confidence,
                            metadata: CVMetadata(
                                boundingBox: observation.boundingBox,
                                additionalProperties: [
                                    "corners": corners.map { ["x": $0.x, "y": $0.y] },
                                    "aspectRatio": aspectRatio,
                                    "area": area
                                ]
                            )
                        ))
                    }
                } else if rectangleDetectionHistory.count >= 3 {
                    // Need at least 3 detections in 0.5 seconds to consider it stable
                    let newId = UUID()
                    trackedRectangles[newId] = rectangleObs
                    stableRectangleId = newId
                    
                    publishEvent(CVEvent(
                        type: .sudokuGridDetected(gridId: newId, corners: corners),
                        confidence: rectangleObs.confidence,
                        metadata: CVMetadata(
                            boundingBox: observation.boundingBox,
                            additionalProperties: [
                                "corners": corners.map { ["x": $0.x, "y": $0.y] },
                                "aspectRatio": aspectRatio,
                                "area": area
                            ]
                        )
                    ))
                }
            }
        }
        
        // Check for lost rectangles with hysteresis
        if observations.isEmpty {
            let now = Date()
            // Only clear if no detections for 0.3 seconds
            if rectangleDetectionHistory.isEmpty || now.timeIntervalSince(rectangleDetectionHistory.last!) > 0.3 {
                if !trackedRectangles.isEmpty {
                    for (gridId, _) in trackedRectangles {
                        publishEvent(CVEvent(type: .sudokuGridLost(gridId: gridId)))
                    }
                    trackedRectangles.removeAll()
                    stableRectangleId = nil
                }
            }
        }
    }
    
    // Helper function for center calculation
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // Helper function to calculate angle at a corner
    private func angleAtCorner(p1: CGPoint, corner: CGPoint, p2: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - corner.x, y: p1.y - corner.y)
        let v2 = CGPoint(x: p2.x - corner.x, y: p2.y - corner.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let det = v1.x * v2.y - v1.y * v2.x
        
        let angle = atan2(det, dot) * 180 / .pi
        return abs(angle)
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

// MARK: - CGRect Extension
private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}