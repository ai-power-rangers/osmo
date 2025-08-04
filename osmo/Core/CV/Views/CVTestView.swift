//
//  CVTestView.swift
//  osmo
//
//  Created for Phase 3 Testing
//

import SwiftUI
import AVFoundation
import os.log

enum TestMode: String, CaseIterable {
    case fingers = "Finger Detection"
    case rectangle = "Rectangle Detection"
}

struct CVTestView: View {

    // Use GameKit.cv directly instead of environment
    @State private var isSessionActive = false
    @State private var lastFingerCount: Int?
    
    private let logger = Logger(subsystem: "com.osmoapp", category: "CVTest")
    @State private var eventCount = 0
    @State private var permissionStatus = CameraPermissionManager.shared.status
    @State private var errorMessage: String?
    @State private var rectangleDetected = false
    @State private var testMode: TestMode = .fingers
    @State private var overlayViewModel = CVOverlayViewModel()
    @State private var cameraSession: AVCaptureSession?
    
    var body: some View {
        ZStack {
            // Camera Preview Layer
            if isSessionActive, let session = cameraSession {
                CameraPreviewView(session: session)
                    .ignoresSafeArea()
                    .overlay(
                        GeometryReader { geometry in
                            CVDetectionOverlayView(
                                viewModel: overlayViewModel,
                                frameSize: geometry.size
                            )
                        }
                    )
            } else {
                // Background when no camera
                Color.black.ignoresSafeArea()
            }
            
            // UI Overlay
            VStack(spacing: 0) {
                // Top Controls without background
                VStack(spacing: 12) {
                    // Navigation bar
                    HStack {
                        // Back button with blur background
                        Button(action: { /* Navigation handled by NavigationStack */ }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 17))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        // Status indicator with blur background
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isSessionActive ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(isSessionActive ? "Active" : "Inactive")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 16)
                    
                    // Mode Selector tabs
                    HStack(spacing: 12) {
                        ForEach(TestMode.allCases, id: \.self) { mode in
                            Button(action: {
                                testMode = mode
                                // Clear overlays when switching modes
                                overlayViewModel.clearRectangles()
                                overlayViewModel.clearHands()
                            }) {
                                Text(mode.rawValue)
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(testMode == mode ? Color.blue : Color.white.opacity(0.9))
                                    .foregroundColor(testMode == mode ? .white : .black)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top) // Safe area padding
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 15) {
                    
                    // Main control button
                    if permissionStatus.canUseCamera {
                        Button(action: toggleSession) {
                            Label(
                                isSessionActive ? "Stop Session" : "Start Session",
                                systemImage: isSessionActive ? "stop.circle.fill" : "play.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                    } else {
                        Button("Request Camera Permission") {
                            Task {
                                await requestPermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true) // Hide default navigation bar
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    private var permissionStatusText: String {
        switch permissionStatus {
        case .notDetermined: return "Not Determined"
        case .authorized: return "Authorized ✓"
        case .denied: return "Denied ✗"
        case .restricted: return "Restricted"
        }
    }
    
    private func checkPermissionStatus() {
        CameraPermissionManager.shared.checkCurrentStatus()
        permissionStatus = CameraPermissionManager.shared.status
    }
    
    private func requestPermission() async {
        let status = await CameraPermissionManager.shared.requestPermission()
        permissionStatus = status
    }
    
    private func toggleSession() {
        if isSessionActive {
            stopSession()
        } else {
            startSession()
        }
    }
    
    private func startSession() {
        Task {
            do {
                // Enable debug mode for more logging
                if let cameraService = GameKit.cv as? CameraVisionService {
                    cameraService.debugMode = true
                    logger.info("[CVTest] Debug mode enabled for CameraVisionService")
                    
                    // Get camera session for preview
                    await MainActor.run {
                        cameraSession = cameraService.cameraSession
                    }
                } else if let arKitService = GameKit.cv as? ARKitCVService {
                    arKitService.debugMode = true
                    logger.info("[CVTest] Debug mode enabled for ARKitCVService")
                    // ARKit doesn't provide direct camera session access
                }
                
                // Start CV session
                try await GameKit.cv.startSession()
                logger.info("[CVTest] Session started successfully")
                
                // Get the camera session after starting
                if let cameraService = GameKit.cv as? CameraVisionService {
                    await MainActor.run {
                        cameraSession = cameraService.cameraSession
                    }
                }
                
                // Subscribe to events
                await subscribeToEvents()
                logger.info("[CVTest] Event subscription active")
                
                await MainActor.run {
                    isSessionActive = true
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start: \(error.localizedDescription)"
                    logger.error("[CVTest] Error starting session: \(error)")
                }
            }
        }
    }
    
    private func stopSession() {
        GameKit.cv.stopSession()
        isSessionActive = false
        lastFingerCount = nil
        eventCount = 0
        rectangleDetected = false
        cameraSession = nil
        overlayViewModel.clearRectangles()
        overlayViewModel.clearHands()
    }
    
    private func subscribeToEvents() async {
        let stream = GameKit.cv.eventStream(for: "test")
        
        for await event in stream {
                    eventCount += 1
                    
                    // Debug print
                    // Commented out due to complex type interpolation
                    // logger.debug("[CVTest] Received event")
                    
                    // Simplified event handling for migration
                    switch event {
                    case .fingerDetected(let count):
                        logger.info("[CVTest] Finger count detected: \(count)")
                        lastFingerCount = count
                    case .pieceDetected(let piece):
                        logger.info("[CVTest] Piece detected")
                    case .rectangleDetected(let rect):
                        logger.info("[CVTest] Rectangle detected")
                        rectangleDetected = true
                    case .error(let error):
                        logger.error("[CVTest] Error: \(error)")
                    }
        }
    }
}

#Preview {
    CVTestView()
}