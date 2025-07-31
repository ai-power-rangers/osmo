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
                // Start CV session
                try await cvService?.startSession()
                
                // Subscribe to events
                await subscribeToEvents()
                
                await MainActor.run {
                    isSessionActive = true
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to start: \(error.localizedDescription)"
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
            events: [.fingerCountDetected(count: 0)]
        )
        
        Task {
            for await event in stream {
                await MainActor.run {
                    eventCount += 1
                    
                    if case .fingerCountDetected(let count) = event.type {
                        withAnimation(.spring()) {
                            lastFingerCount = count
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CVTestView()
}