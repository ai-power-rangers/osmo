//
//  GameCVProcessor.swift
//  osmo
//
//  Protocol for game-specific computer vision processing
//

import Foundation
import AVFoundation
import Vision
import CoreImage

// MARK: - Game CV Processor Protocol

protocol GameCVProcessor: AnyObject {
    var gameId: String { get }
    var eventStream: AsyncStream<CVEvent> { get }
    
    func startProcessing()
    func stopProcessing()
    func process(sampleBuffer: CMSampleBuffer)
}

// MARK: - Base Implementation

class BaseGameCVProcessor: GameCVProcessor {
    let gameId: String
    private var eventContinuation: AsyncStream<CVEvent>.Continuation?
    
    var eventStream: AsyncStream<CVEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
    
    init(gameId: String) {
        self.gameId = gameId
    }
    
    func startProcessing() {
        // Override in subclasses
    }
    
    func stopProcessing() {
        eventContinuation?.finish()
        eventContinuation = nil
    }
    
    func process(sampleBuffer: CMSampleBuffer) {
        // Override in subclasses
    }
    
    // MARK: - Helper Methods
    
    func emit(event: CVEvent) {
        eventContinuation?.yield(event)
    }
    
    func createCIImage(from sampleBuffer: CMSampleBuffer) -> CIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        return CIImage(cvPixelBuffer: imageBuffer)
    }
}