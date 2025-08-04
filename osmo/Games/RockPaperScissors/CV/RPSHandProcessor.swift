//
//  RPSHandProcessor.swift
//  osmo
//
//  Hand detection processor for Rock Paper Scissors
//

import Foundation
import Vision
import AVFoundation
import CoreGraphics

final class RPSHandProcessor: BaseGameCVProcessor {
    
    // MARK: - Properties
    
    private var handDetectionRequest: VNDetectHumanHandPoseRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    private var fingerDetector = FingerDetector()
    private var currentHandId = UUID()
    
    // Gesture smoothing
    private let gestureSmoother = GestureSmoother()
    private let transitionValidator = GestureTransitionValidator()
    
    // Hand tracking state
    private var lastHandDetectionTime: TimeInterval = 0
    private var handLostTimer: Timer?
    
    // MARK: - Initialization
    
    override init(gameId: String = RockPaperScissorsGameModule.gameId) {
        super.init(gameId: gameId)
        setupHandDetection()
    }
    
    // MARK: - Setup
    
    private func setupHandDetection() {
        handDetectionRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
            if let error = error {
                print("[RPSHandProcessor] Hand detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanHandPoseObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                self?.processHandObservations(observations)
            }
        }
        
        handDetectionRequest?.maximumHandCount = 1
    }
    
    // MARK: - Processing
    
    override func process(sampleBuffer: CMSampleBuffer) {
        guard let request = handDetectionRequest,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("[RPSHandProcessor] Failed to perform hand detection: \(error)")
        }
    }
    
    private func processHandObservations(_ observations: [VNHumanHandPoseObservation]) {
        let currentTime = Date().timeIntervalSince1970
        
        if let observation = observations.first {
            lastHandDetectionTime = currentTime
            
            // Cancel hand lost timer if running
            handLostTimer?.invalidate()
            handLostTimer = nil
            
            // Convert to our hand observation format
            let handObservation = HandObservation(
                id: currentHandId,
                chirality: detectChirality(from: observation),
                landmarks: extractLandmarks(from: observation),
                confidence: observation.confidence,
                boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)  // Normalized bounds
            )
            
            // Detect finger count
            let fingerResult = fingerDetector.detectRaisedFingers(from: handObservation)
            
            // Calculate hand openness
            let handOpenness = fingerDetector.calculateHandOpenness(from: handObservation)
            
            // Create hand metrics for gesture inference
            let metrics = HandMetrics(
                fingerCount: fingerResult.count,
                handOpenness: handOpenness,
                stability: fingerResult.confidence,
                position: CGPoint(x: 0.5, y: 0.5)
            )
            
            // Get inferred gesture and its confidence
            let inferredGesture = metrics.inferredPose
            let gestureConfidence = metrics.gestureConfidence * fingerResult.confidence
            
            // Apply temporal smoothing
            let smoothedResult = gestureSmoother.addObservation(
                gesture: inferredGesture,
                confidence: gestureConfidence
            )
            
            // Validate gesture transition
            let validatedGesture = transitionValidator.getValidatedGesture(
                newGesture: smoothedResult.gesture,
                confidence: smoothedResult.confidence
            )
            
            // Emit enhanced finger count event with gesture info
            let fingerEvent = CVEvent(
                type: .fingerCountDetected(count: fingerResult.count),
                position: CGPoint(x: 0.5, y: 0.5),
                confidence: smoothedResult.confidence,
                metadata: CVMetadata(
                    additionalProperties: [
                        "hand_openness": handOpenness,
                        "hand_chirality": fingerResult.handChirality.rawValue,
                        "inferred_gesture": validatedGesture.rawValue,
                        "raw_gesture": inferredGesture.rawValue,
                        "gesture_confidence": gestureConfidence,
                        "smoothed_confidence": smoothedResult.confidence
                    ]
                )
            )
            
            emit(event: fingerEvent)
            
            // Emit hand detected event if new
            let handEvent = CVEvent(
                type: .handDetected(handId: currentHandId, chirality: fingerResult.handChirality),
                confidence: observation.confidence
            )
            emit(event: handEvent)
            
            // Debug logging
            print("[RPSProcessor] Gesture: \(validatedGesture) (raw: \(inferredGesture)), Fingers: \(fingerResult.count), Openness: \(String(format: "%.2f", handOpenness)), Confidence: \(String(format: "%.2f", smoothedResult.confidence))")
            
        } else {
            // No hands detected - use timer to avoid flickering
            if handLostTimer == nil && currentTime - lastHandDetectionTime > 0.1 {
                handLostTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.handleHandLost()
                    }
                }
            }
        }
    }
    
    private func handleHandLost() {
        // Reset smoothing
        gestureSmoother.reset()
        transitionValidator.reset()
        
        // Emit hand lost event
        let lostEvent = CVEvent(
            type: .handLost(handId: currentHandId),
            confidence: 1.0
        )
        emit(event: lostEvent)
        
        // Generate new ID for next detection
        currentHandId = UUID()
    }
    
    // MARK: - Helper Methods
    
    private func extractLandmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks {
        // Extract all landmarks
        let landmarks = HandLandmarks(
            wrist: extractPoint(for: .wrist, from: observation) ?? .zero,
            thumbTip: extractPoint(for: .thumbTip, from: observation) ?? .zero,
            thumbIP: extractPoint(for: .thumbIP, from: observation) ?? .zero,
            thumbMP: extractPoint(for: .thumbMP, from: observation) ?? .zero,
            thumbCMC: extractPoint(for: .thumbCMC, from: observation) ?? .zero,
            indexTip: extractPoint(for: .indexTip, from: observation) ?? .zero,
            indexDIP: extractPoint(for: .indexDIP, from: observation) ?? .zero,
            indexPIP: extractPoint(for: .indexPIP, from: observation) ?? .zero,
            indexMCP: extractPoint(for: .indexMCP, from: observation) ?? .zero,
            middleTip: extractPoint(for: .middleTip, from: observation) ?? .zero,
            middleDIP: extractPoint(for: .middleDIP, from: observation) ?? .zero,
            middlePIP: extractPoint(for: .middlePIP, from: observation) ?? .zero,
            middleMCP: extractPoint(for: .middleMCP, from: observation) ?? .zero,
            ringTip: extractPoint(for: .ringTip, from: observation) ?? .zero,
            ringDIP: extractPoint(for: .ringDIP, from: observation) ?? .zero,
            ringPIP: extractPoint(for: .ringPIP, from: observation) ?? .zero,
            ringMCP: extractPoint(for: .ringMCP, from: observation) ?? .zero,
            littleTip: extractPoint(for: .littleTip, from: observation) ?? .zero,
            littleDIP: extractPoint(for: .littleDIP, from: observation) ?? .zero,
            littlePIP: extractPoint(for: .littlePIP, from: observation) ?? .zero,
            littleMCP: extractPoint(for: .littleMCP, from: observation) ?? .zero
        )
        
        return landmarks
    }
    
    private func extractPoint(for jointName: VNHumanHandPoseObservation.JointName, from observation: VNHumanHandPoseObservation) -> CGPoint? {
        guard let point = try? observation.recognizedPoint(jointName) else {
            return nil
        }
        
        // Convert from Vision coordinates (bottom-left origin) to UIKit (top-left origin)
        return CGPoint(x: point.location.x, y: 1 - point.location.y)
    }
    
    private func detectChirality(from observation: VNHumanHandPoseObservation) -> HandChirality {
        // Simple chirality detection based on thumb position
        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let indexMCP = try? observation.recognizedPoint(.indexMCP),
              let littleMCP = try? observation.recognizedPoint(.littleMCP) else {
            return .unknown
        }
        
        // If thumb is to the left of the hand center, it's likely a right hand
        let handCenterX = (indexMCP.location.x + littleMCP.location.x) / 2
        
        if thumbTip.location.x < handCenterX {
            return .right
        } else {
            return .left
        }
    }
}