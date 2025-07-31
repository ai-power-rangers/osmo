//
//  CVTestView.swift
//  osmo
//
//  Created for Phase 3 Testing
//

import SwiftUI
import AVFoundation

enum TestMode: String, CaseIterable {
    case fingers = "Finger Detection"
    case sudoku = "Rectangle Detection"
}

struct CVTestView: View {
    @Environment(AppCoordinator.self) var coordinator
    @State private var cvService: CVServiceProtocol?
    @State private var isSessionActive = false
    @State private var lastFingerCount: Int?
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
                        CVDetectionOverlayView(
                            viewModel: overlayViewModel,
                            frameSize: UIScreen.main.bounds.size
                        )
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
                        Button(action: { coordinator.navigateToRoot() }) {
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
            // Load service when view appears
            cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
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
                if let cameraService = cvService as? CameraVisionService {
                    cameraService.debugMode = true
                    print("[CVTest] Debug mode enabled for CameraVisionService")
                    
                    // Get camera session for preview
                    await MainActor.run {
                        cameraSession = cameraService.cameraSession
                    }
                } else if let arKitService = cvService as? ARKitCVService {
                    arKitService.debugMode = true
                    print("[CVTest] Debug mode enabled for ARKitCVService")
                    // ARKit doesn't provide direct camera session access
                }
                
                // Start CV session
                try await cvService?.startSession()
                print("[CVTest] Session started successfully")
                
                // Get the camera session after starting
                if let cameraService = cvService as? CameraVisionService {
                    await MainActor.run {
                        cameraSession = cameraService.cameraSession
                    }
                }
                
                // Subscribe to events
                await subscribeToEvents()
                print("[CVTest] Event subscription active")
                
                await MainActor.run {
                    isSessionActive = true
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start: \(error.localizedDescription)"
                    print("[CVTest] Error starting session: \(error)")
                }
            }
        }
    }
    
    private func stopSession() {
        cvService?.stopSession()
        isSessionActive = false
        lastFingerCount = nil
        eventCount = 0
        rectangleDetected = false
        cameraSession = nil
        overlayViewModel.clearRectangles()
        overlayViewModel.clearHands()
    }
    
    private func subscribeToEvents() async {
        guard let cvService = cvService else { return }
        let stream = cvService.eventStream(
            gameId: "test",
            events: [] // Subscribe to all events for debugging
        )
        
        Task {
            for await event in stream {
                await MainActor.run {
                    eventCount += 1
                    
                    // Debug print
                    print("[CVTest] Received event: \(event.type)")
                    
                    switch event.type {
                    case .fingerCountDetected(let count):
                        print("[CVTest] Finger count detected: \(count)")
                        lastFingerCount = count
                        
                        // Update overlay if in finger mode
                        if testMode == .fingers, let metadata = event.metadata, let boundingBox = metadata.boundingBox {
                            // Extract chirality from metadata if available
                            let chirality: HandChirality = {
                                if let chiralityString = metadata.additionalProperties["hand_chirality"] as? String,
                                   let detectedChirality = HandChirality(rawValue: chiralityString) {
                                    return detectedChirality
                                }
                                return .unknown
                            }()
                            
                            // Check if this is for a specific hand (multiple hands case)
                            if let handId = metadata.additionalProperties["hand_id"] as? String {
                                // Multiple hands - update specific hand
                                overlayViewModel.updateSpecificHand(
                                    handId: handId,
                                    boundingBox: boundingBox,
                                    fingerCount: count,
                                    confidence: event.confidence,
                                    chirality: chirality
                                )
                            } else {
                                // Single hand - use regular update
                                overlayViewModel.updateHand(
                                    boundingBox: boundingBox,
                                    fingerCount: count,
                                    confidence: event.confidence,
                                    chirality: chirality
                                )
                            }
                        }
                        
                    case .handDetected(let handId, let chirality):
                        print("[CVTest] Hand detected: \(handId), chirality: \(chirality)")
                        
                    case .handLost(let handId):
                        print("[CVTest] Hand lost: \(handId)")
                        if testMode == .fingers {
                            overlayViewModel.clearHands()
                        }
                        
                    case .handPoseChanged(let handId, let pose):
                        print("[CVTest] Hand pose changed: \(handId) -> \(pose)")
                        
                    case .sudokuGridDetected(let gridId, let corners):
                        print("[CVTest] Rectangle detected: \(gridId), corners: \(corners.count)")
                        rectangleDetected = true
                        
                        // Update overlay if in rectangle mode
                        if testMode == .sudoku {
                            overlayViewModel.updateRectangle(corners, confidence: event.confidence)
                        }
                        
                    case .sudokuGridLost(let gridId):
                        print("[CVTest] Rectangle lost: \(gridId)")
                        rectangleDetected = false
                        if testMode == .sudoku {
                            overlayViewModel.clearRectangles()
                        }
                        
                    default:
                        print("[CVTest] Other event: \(event.type)")
                    }
                }
            }
        }
    }
}

#Preview {
    CVTestView()
}