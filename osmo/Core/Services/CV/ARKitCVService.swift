//
//  ARKitCVService.swift
//  osmo
//
//  Created by Phase 3 Implementation
//

import Foundation
import ARKit
import Vision
import Observation
import os.log

// MARK: - ARKit CV Service
@Observable
final class ARKitCVService: NSObject, CVServiceProtocol, ServiceLifecycle, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.osmoapp", category: "cv")
    
    // Session state
    private(set) var isSessionActive = false
    var debugMode = false
    
    // AR components
    private var arSession: ARSession?
    private let processingQueue = DispatchQueue(label: "com.osmoapp.cv", qos: .userInitiated)
    
    // Vision components
    private var handDetectionRequest: VNDetectHumanHandPoseRequest?
    private var rectangleDetectionRequest: VNDetectRectanglesRequest?
    private var textRecognitionRequest: VNRecognizeTextRequest?
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 1.0 / 30.0 // 30 FPS
    
    // Event continuations
    private var eventContinuations: [String: AsyncStream<CVEvent>.Continuation] = [:]
    private let continuationQueue = DispatchQueue(label: "com.osmoapp.cv.continuations", attributes: .concurrent)
    
    // Tracking
    private var trackedHands: [UUID: HandObservation] = [:]
    private var trackedRectangles: [UUID: RectangleObservation] = [:]
    
    // Finger detection
    private let fingerDetector = FingerDetector()
    
    // Service dependencies
    private weak var analyticsService: AnalyticsServiceProtocol?
    
    override init() {
        super.init()
        setupVisionRequests()
    }
    
    // MARK: - ServiceLifecycle
    func initialize() async throws {
        logger.info("[ARKitCV] Service initialized")
        // ARKit service has no dependencies to initialize
    }
    
    func cleanup() async {
        stopSession()
    }
    
    func setAnalyticsService(_ service: AnalyticsServiceProtocol) {
        self.analyticsService = service
    }
    
    // MARK: - Session Management
    func startSession() async throws {
        guard !isSessionActive else { return }
        
        // Check camera permission
        let permissionManager = CameraPermissionManager.shared
        permissionManager.checkCurrentStatus()
        
        guard permissionManager.status.canUseCamera else {
            throw CVError.cameraPermissionDenied
        }
        
        // Check AR support
        guard ARWorldTrackingConfiguration.isSupported else {
            throw CVError.cameraUnavailable
        }
        
        // Start AR session
        await MainActor.run {
            setupARSession()
        }
        
        isSessionActive = true
        logger.info("[CVService] Session started")
        
        // Log analytics
        analyticsService?.logEvent("cv_session_started", parameters: [:])
    }
    
    func stopSession() {
        guard isSessionActive else { return }
        
        arSession?.pause()
        arSession = nil
        isSessionActive = false
        
        // Clear tracking
        trackedHands.removeAll()
        trackedRectangles.removeAll()
        
        // End all streams
        continuationQueue.async(flags: .barrier) {
            self.eventContinuations.values.forEach { $0.finish() }
            self.eventContinuations.removeAll()
        }
        
        logger.info("[CVService] Session stopped")
        
        // Log analytics
        analyticsService?.logEvent("cv_session_stopped", parameters: [:])
    }
    
    // MARK: - Event Stream
    func eventStream(gameId: String, events: [CVEventType]) -> AsyncStream<CVEvent> {
        AsyncStream { continuation in
            continuationQueue.async(flags: .barrier) {
                self.eventContinuations[gameId] = continuation
            }
            
            logger.info("[CVService] Game \(gameId) subscribed to event stream")
            
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self = self else { return }
                self.continuationQueue.async(flags: .barrier) {
                    self.eventContinuations.removeValue(forKey: gameId)
                }
                self.logger.info("[CVService] Game \(gameId) stream terminated")
            }
        }
    }
    
    func eventStream(gameId: String, events: [CVEventType], configuration: [String: Any]) -> AsyncStream<CVEvent> {
        // For ARKit, we just use the regular event stream (configuration not needed yet)
        return eventStream(gameId: gameId, events: events)
    }
    
    // MARK: - AR Setup
    private func setupARSession() {
        arSession = ARSession()
        arSession?.delegate = self
        
        // Use face tracking configuration for front camera
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            configuration.isWorldTrackingEnabled = false
            
            logger.info("[CVService] Starting AR session with face tracking configuration (front camera)")
            arSession?.run(configuration)
        } else {
            // Fallback to world tracking but it will use back camera
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = []
            
            logger.info("[CVService] WARNING: Face tracking not supported, falling back to world tracking (back camera)")
            arSession?.run(configuration)
        }
    }
    
    // MARK: - Vision Setup
    private func setupVisionRequests() {
        // Hand detection request
        handDetectionRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
            if let error = error {
                self?.logger.error("[CVService] Hand detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanHandPoseObservation] else {
                if self?.debugMode ?? false {
                    self?.logger.info("[CVService] No hand pose observations in results")
                }
                return
            }
            
            self?.processHandObservations(observations)
        }
        handDetectionRequest?.maximumHandCount = 2
        
        // Rectangle detection request (for sudoku grids)
        rectangleDetectionRequest = VNDetectRectanglesRequest { [weak self] request, error in
            if let error = error {
                self?.logger.error("[CVService] Rectangle detection error: \(error)")
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
        
        // Text recognition request (for sudoku digits)
        textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                self?.logger.error("[CVService] Text recognition error: \(error)")
                return
            }
            
            self?.processTextObservations(request.results as? [VNRecognizedTextObservation] ?? [])
        }
        textRecognitionRequest?.recognitionLevel = .accurate
        textRecognitionRequest?.usesLanguageCorrection = false
    }
    
    // MARK: - Hand Processing
    private func processHandObservations(_ observations: [VNHumanHandPoseObservation]) {
        if debugMode {
            logger.info("[CVService] Processing \(observations.count) hand observations")
        }
        
        for observation in observations {
            guard let handObservation = createHandObservation(from: observation) else {
                if debugMode {
                    logger.info("[CVService] Failed to create hand observation")
                }
                continue
            }
            
            // Check if this is a new hand or existing one
            let isNewHand = !trackedHands.values.contains { existingHand in
                distance(from: existingHand.boundingBox.center, to: handObservation.boundingBox.center) < 0.1
            }
            
            if isNewHand {
                // New hand detected
                trackedHands[handObservation.id] = handObservation
                publishEvent(CVEvent(
                    type: .handDetected(handId: handObservation.id, chirality: handObservation.chirality),
                    confidence: handObservation.confidence
                ))
            }
            
            // Detect fingers
            let fingerResult = fingerDetector.detectRaisedFingers(from: handObservation)
            
            if debugMode {
                logger.info("[CVService] Finger detection result: count=\(fingerResult.count), confidence=\(fingerResult.confidence)")
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
            
            // Detect pose changes
            if let pose = detectHandPose(from: fingerResult) {
                publishEvent(CVEvent(
                    type: .handPoseChanged(handId: handObservation.id, pose: pose),
                    confidence: fingerResult.confidence
                ))
            }
        }
        
        // Check for lost hands
        let currentHandIds = Set(observations.compactMap { obs in
            trackedHands.values.first { hand in
                if let handObs = createHandObservation(from: obs) {
                    return distance(from: hand.boundingBox.center, to: handObs.boundingBox.center) < 0.1
                }
                return false
            }?.id
        })
        
        let lostHandIds = Set(trackedHands.keys).subtracting(currentHandIds)
        for handId in lostHandIds {
            trackedHands.removeValue(forKey: handId)
            publishEvent(CVEvent(type: .handLost(handId: handId)))
        }
    }
    
    // MARK: - Rectangle Processing (for Sudoku)
    private func processRectangleObservations(_ observations: [VNRectangleObservation]) {
        for observation in observations {
            let corners = [
                observation.topLeft,
                observation.topRight,
                observation.bottomRight,
                observation.bottomLeft
            ]
            
            // Additional filtering for square-like shapes
            let width = abs(observation.topRight.x - observation.topLeft.x)
            let height = abs(observation.topLeft.y - observation.bottomLeft.y)
            let aspectRatio = width > 0 ? height / width : 0
            
            // Check if it's a reasonable rectangle (books, papers, etc.)
            guard aspectRatio > 0.5 && aspectRatio < 2.0 else {
                if debugMode {
                    logger.info("[ARKitCV] Rejected rectangle: aspect ratio \(aspectRatio) out of range")
                }
                continue
            }
            
            // Check minimum area (at least 2% of frame for smaller objects)
            let area = observation.boundingBox.width * observation.boundingBox.height
            guard area > 0.02 else {
                if debugMode {
                    logger.info("[ARKitCV] Rejected rectangle: area \(area) too small")
                }
                continue
            }
            
            let rectangleObs = RectangleObservation(
                id: UUID(),
                corners: corners,
                confidence: observation.confidence,
                boundingBox: observation.boundingBox
            )
            
            // Check if this is a new grid
            let isNewGrid = !trackedRectangles.values.contains { rect in
                distance(from: rect.boundingBox.center, to: rectangleObs.boundingBox.center) < 0.05
            }
            
            if isNewGrid && rectangleObs.confidence > 0.4 {
                trackedRectangles[rectangleObs.id] = rectangleObs
                publishEvent(CVEvent(
                    type: .sudokuGridDetected(gridId: rectangleObs.id, corners: corners),
                    confidence: rectangleObs.confidence
                ))
            }
        }
        
        // Check for lost grids
        if observations.isEmpty && !trackedRectangles.isEmpty {
            for (gridId, _) in trackedRectangles {
                publishEvent(CVEvent(type: .sudokuGridLost(gridId: gridId)))
            }
            trackedRectangles.removeAll()
        }
    }
    
    // MARK: - Text Processing (for Sudoku digits)
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) {
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first,
                  let digit = Int(topCandidate.string),
                  (1...9).contains(digit) else { continue }
            
            // Find which grid and cell this digit belongs to
            if let (gridId, row, col) = findGridCell(for: observation.boundingBox) {
                publishEvent(CVEvent(
                    type: .sudokuCellWritten(gridId: gridId, row: row, col: col, digit: digit),
                    confidence: topCandidate.confidence
                ))
            }
        }
    }
    
    // MARK: - Helper Methods
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
            
            // Determine chirality
            let chirality = determineChirality(from: landmarks)
            
            return HandObservation(
                id: UUID(),
                chirality: chirality,
                landmarks: landmarks,
                confidence: vnObservation.confidence,
                boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1) // Normalized
            )
            
        } catch {
            logger.error("[CVService] Failed to extract hand landmarks: \(error)")
            return nil
        }
    }
    
    private func determineChirality(from landmarks: HandLandmarks) -> HandChirality {
        // Simplified chirality detection based on thumb position
        let thumbX = landmarks.thumbTip.x
        let indexX = landmarks.indexTip.x
        
        if thumbX < indexX {
            return .left
        } else {
            return .right
        }
    }
    
    private func detectHandPose(from result: FingerDetectionResult) -> HandPose? {
        let fingers = Set(result.raisedFingers)
        
        if fingers.isEmpty {
            return .closed
        } else if fingers.count == 5 {
            return .open
        } else if fingers == [.index, .middle] {
            return .peace
        } else if fingers == [.thumb] {
            return .thumbsUp
        } else if fingers == [.index] {
            return .pointing
        }
        
        return nil
    }
    
    private func findGridCell(for boundingBox: CGRect) -> (gridId: UUID, row: Int, col: Int)? {
        // This would map the text location to a specific sudoku grid cell
        // For now, returning nil as this requires grid subdivision logic
        return nil
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Event Publishing
    private func publishEvent(_ event: CVEvent) {
        continuationQueue.sync {
            for continuation in eventContinuations.values {
                continuation.yield(event)
            }
        }
        
        if debugMode {
            logger.debug("[CVService] Published event: \(String(describing: event.type))")
        }
    }
}

// MARK: - ARSessionDelegate
extension ARKitCVService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Throttle processing
        let currentTime = frame.timestamp
        guard currentTime - lastProcessedTime >= processingInterval else { return }
        lastProcessedTime = currentTime
        
        // Process frame on background queue
        processingQueue.async { [weak self] in
            self?.processFrame(frame)
        }
    }
    
    private func processFrame(_ frame: ARFrame) {
        // Convert ARFrame to CVPixelBuffer
        let pixelBuffer = frame.capturedImage
        
        // Create Vision request handler
        // For ARKit with front camera in portrait mode, we need .up
        // ARKit already handles the orientation transforms
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        // Perform all requests
        var requests: [VNRequest] = []
        
        if let handRequest = handDetectionRequest {
            requests.append(handRequest)
        }
        
        if let rectangleRequest = rectangleDetectionRequest {
            requests.append(rectangleRequest)
        }
        
        if let textRequest = textRecognitionRequest,
           !trackedRectangles.isEmpty {
            requests.append(textRequest)
        }
        
        do {
            try handler.perform(requests)
        } catch {
            logger.error("[CVService] Failed to perform vision requests: \(error)")
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        logger.error("[CVService] AR session failed: \(error)")
        
        let cvError = CVError.sessionFailure(error)
        analyticsService?.logError(cvError, context: "ar_session")
    }
}

// MARK: - CGRect Extension
private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}