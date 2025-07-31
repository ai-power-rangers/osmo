//
//  CVTestView.swift
//  osmo
//
//  Created for Phase 3 Testing
//

import SwiftUI

struct CVTestView: View {
    @Environment(AppCoordinator.self) var coordinator
    @State private var cvService: CVServiceProtocol?
    @State private var isSessionActive = false
    @State private var lastFingerCount: Int?
    @State private var eventCount = 0
    @State private var permissionStatus = CameraPermissionManager.shared.status
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            // Status Section
            VStack(spacing: 10) {
                Text("CV Test View")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack {
                    Circle()
                        .fill(isSessionActive ? Color.green : Color.red)
                        .frame(width: 20, height: 20)
                    Text(isSessionActive ? "Session Active" : "Session Inactive")
                        .font(.headline)
                }
                
                Text("Permission: \(permissionStatusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Detection Results
            VStack(spacing: 20) {
                if let count = lastFingerCount {
                    VStack {
                        Text("\(count)")
                            .font(.system(size: 120, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text("Fingers Detected")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale)
                } else {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.3))
                }
                
                Text("Events: \(eventCount)")
                    .font(.caption)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Controls
            VStack(spacing: 15) {
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
                    .disabled(isSessionActive && (cvService?.isSessionActive ?? false))
                } else {
                    Button("Request Camera Permission") {
                        Task {
                            await requestPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Button("Back to Lobby") {
                    coordinator.navigateToRoot()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
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
                if let arKitService = cvService as? ARKitCVService {
                    arKitService.debugMode = true
                    print("[CVTest] Debug mode enabled")
                }
                
                // Start CV session
                try await cvService?.startSession()
                print("[CVTest] Session started successfully")
                
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
                        withAnimation(.spring()) {
                            lastFingerCount = count
                        }
                    case .handDetected(let handId, let chirality):
                        print("[CVTest] Hand detected: \(handId), chirality: \(chirality)")
                    case .handLost(let handId):
                        print("[CVTest] Hand lost: \(handId)")
                    case .handPoseChanged(let handId, let pose):
                        print("[CVTest] Hand pose changed: \(handId) -> \(pose)")
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