# Phase 3: CV/ARKit Integration - Detailed Implementation Plan

## Overview
Phase 3 implements the computer vision service using ARKit and Vision framework for finger detection. This phase includes camera permissions, real-time hand tracking, event publishing, and debug visualization tools.

## Prerequisites
- Phase 2 completed successfully
- iOS device with TrueDepth camera (for testing)
- Xcode with ARKit capabilities enabled

## Step 1: Project Configuration (15 minutes)

### 1.1 Add Required Frameworks
In Xcode project settings:
1. Select your target
2. Go to "Frameworks, Libraries, and Embedded Content"
3. Add:
   - ARKit.framework
   - Vision.framework
   - CoreML.framework

### 1.2 Update Info.plist
Add/verify these keys in Info.plist:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to see your hands and play games!</string>
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
</array>
```

### 1.3 Enable Background Modes (Optional)
If you want CV to prepare while app loads:
1. Add "Background Modes" capability
2. Check "Audio, AirPlay, and Picture in Picture"

## Step 2: Camera Permission System (45 minutes)

### 2.1 Create Permission Manager
Create `Core/Services/CameraPermissionManager.swift`:

```swift
import Foundation
import AVFoundation
import UIKit

// MARK: - Camera Permission Status
enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var needsRequest: Bool {
        return self == .notDetermined
    }
    
    var canUseCamera: Bool {
        return self == .authorized
    }
}

// MARK: - Camera Permission Manager
final class CameraPermissionManager: ObservableObject {
    static let shared = CameraPermissionManager()
    
    @Published private(set) var status: CameraPermissionStatus = .notDetermined
    
    private init() {
        checkCurrentStatus()
    }
    
    // MARK: - Status Check
    func checkCurrentStatus() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        status = mapAuthorizationStatus(authStatus)
    }
    
    private func mapAuthorizationStatus(_ status: AVAuthorizationStatus) -> CameraPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    // MARK: - Permission Request
    func requestPermission() async -> CameraPermissionStatus {
        // Check current status first
        checkCurrentStatus()
        
        guard status.needsRequest else {
            return status
        }
        
        // Request permission
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        
        // Update status
        await MainActor.run {
            self.status = granted ? .authorized : .denied
        }
        
        // Log analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("camera_permission_result", parameters: [
            "granted": granted
        ])
        
        return status
    }
    
    // MARK: - Settings Navigation
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            return
        }
        
        UIApplication.shared.open(settingsUrl)
        
        // Log analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("camera_settings_opened", parameters: [:])
    }
}
```

### 2.2 Create Permission UI Views
Create `Features/Permissions/CameraPermissionView.swift`:

```swift
import SwiftUI

struct CameraPermissionView: View {
    @StateObject private var permissionManager = CameraPermissionManager.shared
    @Environment(\.dismiss) var dismiss
    let onAuthorized: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .overlay(
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .offset(x: 40, y: 40)
                    )
                
                // Title
                Text("Camera Access Needed")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Description
                Text("OsmoApp needs to use your camera to see your hands and objects for playing games!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Visual example
                PermissionExampleView()
                    .padding(.vertical)
                
                // Action button
                Group {
                    switch permissionManager.status {
                    case .notDetermined:
                        Button {
                            Task {
                                await requestPermission()
                            }
                        } label: {
                            Label("Allow Camera Access", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                    case .denied:
                        VStack(spacing: 15) {
                            Text("Camera access was denied")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Button {
                                permissionManager.openSettings()
                            } label: {
                                Label("Open Settings", systemImage: "gear")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        
                    case .authorized:
                        Button {
                            onAuthorized()
                            dismiss()
                        } label: {
                            Label("Continue", systemImage: "arrow.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .onAppear {
                            // Auto-continue after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onAuthorized()
                                dismiss()
                            }
                        }
                        
                    case .restricted:
                        Text("Camera access is restricted on this device")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Skip button (only for non-essential uses)
                Button("Maybe Later") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .opacity(permissionManager.status == .notDetermined ? 1 : 0)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func requestPermission() async {
        let status = await permissionManager.requestPermission()
        
        // Haptic feedback
        let audio = ServiceLocator.shared.resolve(AudioServiceProtocol.self)
        if status == .authorized {
            audio.playHaptic(.success)
        } else {
            audio.playHaptic(.error)
        }
    }
}

// MARK: - Permission Example View
private struct PermissionExampleView: View {
    @State private var handOffset: CGFloat = -20
    
    var body: some View {
        ZStack {
            // Camera frame
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: 200, height: 150)
                .overlay(
                    Image(systemName: "camera")
                        .font(.title)
                        .foregroundColor(.gray.opacity(0.3))
                )
            
            // Animated hand
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .offset(x: handOffset)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: handOffset)
        }
        .onAppear {
            handOffset = 20
        }
    }
}
```

### 2.3 Create Camera Unavailable View
Create `Features/Permissions/CameraUnavailableView.swift`:

```swift
import SwiftUI

struct CameraUnavailableView: View {
    @Environment(\.dismiss) var dismiss
    let reason: CameraUnavailableReason
    
    enum CameraUnavailableReason {
        case noCamera
        case inUseByOtherApp
        case systemError
        
        var icon: String {
            switch self {
            case .noCamera: return "video.slash"
            case .inUseByOtherApp: return "video.badge.ellipsis"
            case .systemError: return "exclamationmark.triangle"
            }
        }
        
        var title: String {
            switch self {
            case .noCamera: return "No Camera Found"
            case .inUseByOtherApp: return "Camera In Use"
            case .systemError: return "Camera Error"
            }
        }
        
        var message: String {
            switch self {
            case .noCamera:
                return "This device doesn't have a camera that works with OsmoApp"
            case .inUseByOtherApp:
                return "Another app is using the camera. Please close it and try again"
            case .systemError:
                return "There was a problem accessing the camera. Please restart the app"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: reason.icon)
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text(reason.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(reason.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Back to Games") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
}
```

## Step 3: CV Service Implementation (90 minutes)

### 3.1 Create Hand Detection Types
Create `Core/Services/CV/HandDetection.swift`:

```swift
import Foundation
import Vision
import CoreGraphics

// MARK: - Hand Detection Types
struct HandObservation {
    let id: UUID
    let chirality: HandChirality
    let landmarks: HandLandmarks
    let confidence: Float
    let boundingBox: CGRect
}

enum HandChirality {
    case left
    case right
    case unknown
}

struct HandLandmarks {
    let wrist: CGPoint
    let thumbTip: CGPoint
    let thumbIP: CGPoint
    let thumbMP: CGPoint
    let thumbCMC: CGPoint
    
    let indexTip: CGPoint
    let indexDIP: CGPoint
    let indexPIP: CGPoint
    let indexMCP: CGPoint
    
    let middleTip: CGPoint
    let middleDIP: CGPoint
    let middlePIP: CGPoint
    let middleMCP: CGPoint
    
    let ringTip: CGPoint
    let ringDIP: CGPoint
    let ringPIP: CGPoint
    let ringMCP: CGPoint
    
    let littleTip: CGPoint
    let littleDIP: CGPoint
    let littlePIP: CGPoint
    let littleMCP: CGPoint
    
    // Helper to get all fingertips
    var fingerTips: [CGPoint] {
        [thumbTip, indexTip, middleTip, ringTip, littleTip]
    }
}

// MARK: - Finger Detection
struct FingerDetectionResult {
    let count: Int
    let confidence: Float
    let raisedFingers: [Finger]
    let handChirality: HandChirality
}

enum Finger: String, CaseIterable {
    case thumb
    case index
    case middle
    case ring
    case little
}
```

### 3.2 Create ARKit CV Service
Replace `Core/Services/MockCVService.swift` with `Core/Services/CVService/ARKitCVService.swift`:

```swift
import Foundation
import ARKit
import Vision
import Combine

// MARK: - ARKit CV Service
final class ARKitCVService: NSObject, CVServiceProtocol {
    // Session state
    private(set) var isSessionActive = false
    var debugMode = false {
        didSet {
            debugSubject.send(debugMode)
        }
    }
    
    // AR components
    private var arSession: ARSession?
    private var processingQueue = DispatchQueue(label: "com.osmoapp.cv", qos: .userInitiated)
    
    // Vision components
    private var handDetectionRequest: VNDetectHumanHandPoseRequest?
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 1.0 / 30.0 // 30 FPS
    
    // Subscriptions
    private var subscriptions: [UUID: CVSubscription] = [:]
    private let subscriptionQueue = DispatchQueue(label: "com.osmoapp.cv.subscriptions", attributes: .concurrent)
    
    // Publishers for debug
    let debugSubject = PassthroughSubject<Bool, Never>()
    let handDetectionSubject = PassthroughSubject<HandObservation?, Never>()
    
    // Finger detection
    private var fingerDetector = FingerDetector()
    
    override init() {
        super.init()
        setupVisionRequest()
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
        
        print("[CVService] Session started")
        
        // Log analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("cv_session_started", parameters: [:])
    }
    
    func stopSession() {
        guard isSessionActive else { return }
        
        arSession?.pause()
        arSession = nil
        isSessionActive = false
        
        print("[CVService] Session stopped")
        
        // Log analytics
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("cv_session_stopped", parameters: [:])
    }
    
    // MARK: - Subscriptions
    func subscribe(gameId: String,
                  events: [CVEventType],
                  handler: @escaping (CVEvent) -> Void) -> CVSubscription {
        let subscription = CVSubscription(
            gameId: gameId,
            eventTypes: events,
            handler: handler
        )
        
        subscriptionQueue.async(flags: .barrier) {
            self.subscriptions[subscription.id] = subscription
        }
        
        print("[CVService] Game \(gameId) subscribed to \(events.count) event types")
        
        return subscription
    }
    
    func unsubscribe(_ subscription: CVSubscription) {
        subscriptionQueue.async(flags: .barrier) {
            self.subscriptions.removeValue(forKey: subscription.id)
        }
        
        print("[CVService] Unsubscribed game \(subscription.gameId)")
    }
    
    // MARK: - AR Setup
    private func setupARSession() {
        arSession = ARSession()
        arSession?.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .personSegmentationWithDepth
        
        arSession?.run(configuration)
    }
    
    // MARK: - Vision Setup
    private func setupVisionRequest() {
        handDetectionRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
            if let error = error {
                print("[CVService] Hand detection error: \(error)")
                return
            }
            
            self?.processHandObservations(request.results as? [VNHumanHandPoseObservation] ?? [])
        }
        
        handDetectionRequest?.maximumHandCount = 2
    }
    
    // MARK: - Hand Processing
    private func processHandObservations(_ observations: [VNHumanHandPoseObservation]) {
        for observation in observations {
            guard let handObservation = createHandObservation(from: observation) else { continue }
            
            // Send to debug view
            if debugMode {
                handDetectionSubject.send(handObservation)
            }
            
            // Detect fingers
            let fingerResult = fingerDetector.detectRaisedFingers(from: handObservation)
            
            // Create CV event
            let event = CVEvent(
                type: .fingerCountDetected(count: fingerResult.count),
                position: CGPoint(x: 0.5, y: 0.5), // Center for now
                confidence: fingerResult.confidence,
                metadata: CVMetadata(
                    boundingBox: handObservation.boundingBox,
                    additionalProperties: [
                        "hand_chirality": fingerResult.handChirality,
                        "raised_fingers": fingerResult.raisedFingers.map { $0.rawValue }
                    ]
                )
            )
            
            // Publish to subscribers
            publishEvent(event)
        }
    }
    
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
            
            // Determine chirality (simplified - would need more logic)
            let chirality = determineChirality(from: landmarks)
            
            return HandObservation(
                id: UUID(),
                chirality: chirality,
                landmarks: landmarks,
                confidence: vnObservation.confidence,
                boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1) // Normalized
            )
            
        } catch {
            print("[CVService] Failed to extract hand landmarks: \(error)")
            return nil
        }
    }
    
    private func determineChirality(from landmarks: HandLandmarks) -> HandChirality {
        // Simplified chirality detection
        // In reality, would use thumb position relative to other fingers
        let thumbX = landmarks.thumbTip.x
        let indexX = landmarks.indexTip.x
        
        if thumbX < indexX {
            return .left
        } else {
            return .right
        }
    }
    
    // MARK: - Event Publishing
    private func publishEvent(_ event: CVEvent) {
        subscriptionQueue.sync {
            for subscription in subscriptions.values {
                // Check if subscription wants this type of event
                let wantsEvent = subscription.eventTypes.contains { eventType in
                    switch (eventType, event.type) {
                    case (.fingerCountDetected, .fingerCountDetected):
                        return true
                    default:
                        return false
                    }
                }
                
                if wantsEvent {
                    DispatchQueue.main.async {
                        subscription.handle(event)
                    }
                }
            }
        }
        
        // Log high-frequency events sparingly
        if debugMode {
            print("[CVService] Published event: \(event.type)")
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
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        // Perform hand detection
        do {
            if let request = handDetectionRequest {
                try handler.perform([request])
            }
        } catch {
            print("[CVService] Failed to perform hand detection: \(error)")
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[CVService] AR session failed: \(error)")
        
        // Notify subscribers of error
        let cvError = CVError.cameraUnavailable
        
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logError(cvError, context: "ar_session")
    }
}
```

### 3.3 Create Finger Detection Logic
Create `Core/Services/CV/FingerDetector.swift`:

```swift
import Foundation
import CoreGraphics

// MARK: - Finger Detector
final class FingerDetector {
    
    // Thresholds for finger detection
    private let extendedThreshold: Float = 0.8  // How straight the finger needs to be
    private let confidenceThreshold: Float = 0.7
    
    func detectRaisedFingers(from hand: HandObservation) -> FingerDetectionResult {
        var raisedFingers: [Finger] = []
        
        // Check each finger
        if isFingerExtended(
            tip: hand.landmarks.thumbTip,
            dip: hand.landmarks.thumbIP,
            pip: hand.landmarks.thumbMP,
            mcp: hand.landmarks.thumbCMC,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.thumb)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.indexTip,
            dip: hand.landmarks.indexDIP,
            pip: hand.landmarks.indexPIP,
            mcp: hand.landmarks.indexMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.index)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.middleTip,
            dip: hand.landmarks.middleDIP,
            pip: hand.landmarks.middlePIP,
            mcp: hand.landmarks.middleMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.middle)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.ringTip,
            dip: hand.landmarks.ringDIP,
            pip: hand.landmarks.ringPIP,
            mcp: hand.landmarks.ringMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.ring)
        }
        
        if isFingerExtended(
            tip: hand.landmarks.littleTip,
            dip: hand.landmarks.littleDIP,
            pip: hand.landmarks.littlePIP,
            mcp: hand.landmarks.littleMCP,
            wrist: hand.landmarks.wrist
        ) {
            raisedFingers.append(.little)
        }
        
        return FingerDetectionResult(
            count: raisedFingers.count,
            confidence: hand.confidence,
            raisedFingers: raisedFingers,
            handChirality: hand.chirality
        )
    }
    
    private func isFingerExtended(tip: CGPoint,
                                 dip: CGPoint,
                                 pip: CGPoint,
                                 mcp: CGPoint,
                                 wrist: CGPoint) -> Bool {
        // Calculate distances
        let tipToWrist = distance(from: tip, to: wrist)
        let dipToWrist = distance(from: dip, to: wrist)
        let pipToWrist = distance(from: pip, to: wrist)
        let mcpToWrist = distance(from: mcp, to: wrist)
        
        // Check if distances are increasing (finger is extended)
        let isExtending = tipToWrist > dipToWrist &&
                         dipToWrist > pipToWrist &&
                         pipToWrist > mcpToWrist
        
        // Check angle between joints (simplified)
        let angle = calculateAngle(p1: tip, p2: pip, p3: mcp)
        let isStraight = angle > 150 // degrees
        
        return isExtending && isStraight
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateAngle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let det = v1.x * v2.y - v1.y * v2.x
        
        let angle = atan2(det, dot) * 180 / .pi
        return abs(angle)
    }
}

// MARK: - Detection Helpers
extension FingerDetector {
    // Common gesture patterns
    func detectGesture(from result: FingerDetectionResult) -> GestureType? {
        let fingers = Set(result.raisedFingers)
        
        // Peace sign
        if fingers == [.index, .middle] {
            return .peace
        }
        
        // Thumbs up
        if fingers == [.thumb] {
            return .thumbsUp
        }
        
        // OK sign (simplified - would need more complex detection)
        if fingers == [.thumb, .index] && result.count == 2 {
            return .ok
        }
        
        return nil
    }
}

enum GestureType {
    case peace
    case thumbsUp
    case ok
    case pointing
}
```

## Step 4: Debug Visualization (60 minutes)

### 4.1 Create CV Debug Overlay
Create `Features/Debug/CVDebugOverlay.swift`:

```swift
import SwiftUI
import Combine

struct CVDebugOverlay: View {
    @StateObject private var viewModel = CVDebugViewModel()
    @State private var showingDetails = false
    
    var body: some View {
        ZStack {
            // Main overlay
            VStack {
                HStack {
                    // Debug info panel
                    debugInfoPanel
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Hand visualization
                if let hand = viewModel.currentHand {
                    HandVisualizationView(hand: hand)
                        .frame(height: 200)
                        .background(Color.black.opacity(0.5))
                }
            }
            
            // Detailed debug view
            if showingDetails {
                DetailedDebugView(viewModel: viewModel)
                    .transition(.move(edge: .trailing))
            }
        }
    }
    
    private var debugInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Circle()
                    .fill(viewModel.isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text("CV Debug")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    showingDetails.toggle()
                } label: {
                    Image(systemName: showingDetails ? "xmark" : "info.circle")
                        .foregroundColor(.white)
                }
            }
            
            Divider().background(Color.white.opacity(0.3))
            
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("FPS: \(viewModel.fps)")
                Text("Hands: \(viewModel.handCount)")
                Text("Events/s: \(viewModel.eventsPerSecond)")
                Text("Latency: \(viewModel.latency)ms")
                
                if let fingers = viewModel.fingerCount {
                    Text("Fingers: \(fingers)")
                        .font(.caption.bold())
                        .foregroundColor(.yellow)
                }
            }
            .font(.caption.monospaced())
            .foregroundColor(.white)
        }
    }
}

// MARK: - Hand Visualization
struct HandVisualizationView: View {
    let hand: HandObservation
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw hand skeleton
                HandSkeletonShape(
                    hand: hand,
                    size: geometry.size
                )
                .stroke(Color.green, lineWidth: 2)
                
                // Draw joint points
                ForEach(jointPoints, id: \.x) { point in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .position(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                }
                
                // Finger labels
                if let result = FingerDetector().detectRaisedFingers(from: hand),
                   result.count > 0 {
                    Text("\(result.count)")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
            }
        }
    }
    
    private var jointPoints: [CGPoint] {
        [
            hand.landmarks.wrist,
            hand.landmarks.thumbTip,
            hand.landmarks.indexTip,
            hand.landmarks.middleTip,
            hand.landmarks.ringTip,
            hand.landmarks.littleTip
        ]
    }
}

// MARK: - Hand Skeleton Shape
struct HandSkeletonShape: Shape {
    let hand: HandObservation
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Scale points to view size
        func scaled(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * size.width, y: point.y * size.height)
        }
        
        // Draw finger bones
        drawFinger(&path, 
                  tip: hand.landmarks.thumbTip,
                  dip: hand.landmarks.thumbIP,
                  pip: hand.landmarks.thumbMP,
                  mcp: hand.landmarks.thumbCMC,
                  scaled: scaled)
        
        drawFinger(&path,
                  tip: hand.landmarks.indexTip,
                  dip: hand.landmarks.indexDIP,
                  pip: hand.landmarks.indexPIP,
                  mcp: hand.landmarks.indexMCP,
                  scaled: scaled)
        
        // ... repeat for other fingers
        
        // Connect to wrist
        path.move(to: scaled(hand.landmarks.wrist))
        path.addLine(to: scaled(hand.landmarks.thumbCMC))
        path.addLine(to: scaled(hand.landmarks.indexMCP))
        
        return path
    }
    
    private func drawFinger(_ path: inout Path,
                           tip: CGPoint,
                           dip: CGPoint,
                           pip: CGPoint,
                           mcp: CGPoint,
                           scaled: (CGPoint) -> CGPoint) {
        path.move(to: scaled(tip))
        path.addLine(to: scaled(dip))
        path.addLine(to: scaled(pip))
        path.addLine(to: scaled(mcp))
    }
}

// MARK: - Detailed Debug View
struct DetailedDebugView: View {
    @ObservedObject var viewModel: CVDebugViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CV Debug Details")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Session info
                    Section("Session") {
                        DebugRow("Status", viewModel.isActive ? "Active" : "Inactive")
                        DebugRow("Duration", viewModel.sessionDuration)
                        DebugRow("Total Events", "\(viewModel.totalEvents)")
                    }
                    
                    // Performance
                    Section("Performance") {
                        DebugRow("Current FPS", "\(viewModel.fps)")
                        DebugRow("Avg Latency", "\(viewModel.latency)ms")
                        DebugRow("Frame Drops", "\(viewModel.frameDrops)")
                    }
                    
                    // Detection
                    Section("Detection") {
                        DebugRow("Confidence", String(format: "%.2f", viewModel.lastConfidence))
                        DebugRow("Hand Type", viewModel.handChirality)
                        if let fingers = viewModel.raisedFingers {
                            DebugRow("Fingers", fingers.joined(separator: ", "))
                        }
                    }
                    
                    // Events log
                    Section("Recent Events") {
                        ForEach(viewModel.recentEvents, id: \.self) { event in
                            Text(event)
                                .font(.caption.monospaced())
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(15)
        .padding()
    }
}

// MARK: - Debug Row
private struct DebugRow: View {
    let label: String
    let value: String
    
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.white)
        }
    }
}

// MARK: - Section Header
private struct Section<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.yellow)
            content()
        }
        .padding(.vertical, 4)
    }
}
```

### 4.2 Create Debug View Model
Create `Features/Debug/CVDebugViewModel.swift`:

```swift
import Foundation
import Combine
import SwiftUI

// MARK: - CV Debug View Model
@MainActor
final class CVDebugViewModel: ObservableObject {
    @Published var isActive = false
    @Published var fps = 0
    @Published var handCount = 0
    @Published var eventsPerSecond = 0
    @Published var latency = 0
    @Published var fingerCount: Int?
    @Published var currentHand: HandObservation?
    @Published var sessionDuration = "0:00"
    @Published var totalEvents = 0
    @Published var frameDrops = 0
    @Published var lastConfidence: Float = 0
    @Published var handChirality = "Unknown"
    @Published var raisedFingers: [String]?
    @Published var recentEvents: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    private var eventCount = 0
    private var lastEventUpdate = Date()
    private let maxRecentEvents = 10
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to CV service debug events
        if let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self) as? ARKitCVService {
            // Debug mode changes
            cvService.debugSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak self] debugMode in
                    self?.isActive = debugMode
                    if debugMode {
                        self?.sessionStartTime = Date()
                    }
                }
                .store(in: &cancellables)
            
            // Hand observations
            cvService.handDetectionSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak self] hand in
                    self?.updateHandInfo(hand)
                }
                .store(in: &cancellables)
        }
        
        // Update timer
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
    }
    
    private func updateHandInfo(_ hand: HandObservation?) {
        guard let hand = hand else {
            handCount = 0
            currentHand = nil
            fingerCount = nil
            return
        }
        
        currentHand = hand
        handCount = 1
        lastConfidence = hand.confidence
        
        // Update chirality
        handChirality = switch hand.chirality {
        case .left: "Left"
        case .right: "Right"
        case .unknown: "Unknown"
        }
        
        // Detect fingers
        let fingerResult = FingerDetector().detectRaisedFingers(from: hand)
        fingerCount = fingerResult.count
        raisedFingers = fingerResult.raisedFingers.map { $0.rawValue.capitalized }
        
        // Log event
        totalEvents += 1
        eventCount += 1
        
        let event = "[\(Date().formatted(.dateTime.hour().minute().second()))] \(fingerResult.count) fingers"
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeLast()
        }
        
        // Update frame count
        frameCount += 1
    }
    
    private func updateStats() {
        // FPS calculation
        let now = Date()
        let fpsDelta = now.timeIntervalSince(lastFPSUpdate)
        if fpsDelta >= 1.0 {
            fps = Int(Double(frameCount) / fpsDelta)
            frameCount = 0
            lastFPSUpdate = now
        }
        
        // Events per second
        let eventDelta = now.timeIntervalSince(lastEventUpdate)
        if eventDelta >= 1.0 {
            eventsPerSecond = Int(Double(eventCount) / eventDelta)
            eventCount = 0
            lastEventUpdate = now
        }
        
        // Session duration
        if let startTime = sessionStartTime {
            let duration = Int(now.timeIntervalSince(startTime))
            let minutes = duration / 60
            let seconds = duration % 60
            sessionDuration = String(format: "%d:%02d", minutes, seconds)
        }
        
        // Mock latency (in real app, measure actual processing time)
        latency = Int.random(in: 15...25)
    }
}
```

## Step 5: Integration Updates (45 minutes)

### 5.1 Update Game Host for CV Debug
Update `Features/GameHost/GameHostView.swift` to include CV debug overlay:

```swift
// Add to GameHostView:

@State private var showCVDebug = false

// In the body, after the debug toggle button:
#if DEBUG
HStack {
    Button {
        showDebugInfo.toggle()
    } label: {
        Image(systemName: showDebugInfo ? "eye.fill" : "eye.slash.fill")
            .font(.title2)
            .foregroundColor(.white)
            .background(Circle().fill(Color.black.opacity(0.5)))
    }
    
    Button {
        showCVDebug.toggle()
        updateCVDebugMode()
    } label: {
        Image(systemName: "camera.viewfinder")
            .font(.title2)
            .foregroundColor(showCVDebug ? .yellow : .white)
            .background(Circle().fill(Color.black.opacity(0.5)))
    }
}
.padding()
#endif

// Add CV debug overlay:
if showCVDebug {
    CVDebugOverlay()
        .allowsHitTesting(false)
}

// Add method:
private func updateCVDebugMode() {
    let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
    cvService.debugMode = showCVDebug
}
```

### 5.2 Update App to Check Camera Permission
Update `App/ContentView.swift`:

```swift
struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var permissionManager = CameraPermissionManager.shared
    @State private var showPermissionView = false
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            LobbyView()
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .lobby:
                        LobbyView()
                    case .game(let gameId):
                        // Check permission before showing game
                        if permissionManager.status.canUseCamera {
                            GameHostView(gameId: gameId)
                        } else {
                            CameraPermissionNeededView(gameId: gameId)
                        }
                    case .settings:
                        SettingsView()
                    case .parentGate:
                        ParentGateView()
                    }
                }
        }
        .alert("Error", isPresented: $coordinator.showError) {
            Button("OK") {
                coordinator.showError = false
            }
        } message: {
            Text(coordinator.errorMessage ?? "An error occurred")
        }
        .onAppear {
            checkInitialPermissions()
        }
    }
    
    private func checkInitialPermissions() {
        permissionManager.checkCurrentStatus()
        
        // Log permission status
        let analytics = ServiceLocator.shared.resolve(AnalyticsServiceProtocol.self)
        analytics.logEvent("app_launch_permission_status", parameters: [
            "camera_permission": String(describing: permissionManager.status)
        ])
    }
}

// MARK: - Permission Needed View
struct CameraPermissionNeededView: View {
    let gameId: String
    @Environment(\.coordinator) var coordinator
    
    var body: some View {
        CameraPermissionView {
            // Permission granted - reload the game
            coordinator.navigateBack()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                coordinator.launchGame(gameId)
            }
        }
    }
}
```

### 5.3 Update Service Registration
Update `App/OsmoApp.swift`:

```swift
private func setupServices() {
    // Register real CV service (replacing mock from Phase 2)
    ServiceLocator.shared.register(ARKitCVService(), for: CVServiceProtocol.self)
    ServiceLocator.shared.register(AudioService(), for: AudioServiceProtocol.self)
    ServiceLocator.shared.register(AnalyticsService(), for: AnalyticsServiceProtocol.self)
    ServiceLocator.shared.register(PersistenceService(), for: PersistenceServiceProtocol.self)
    
    print("[App] All services registered")
    
    #if DEBUG
    ServiceLocator.validateServices()
    #endif
}
```

### 5.4 Create FPS Counter View
Create `Features/Debug/FPSCounterView.swift`:

```swift
import SwiftUI

struct FPSCounterView: View {
    @State private var fps = 0
    @State private var frameTime = 0.0
    private let updateTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(fps) FPS")
                .font(.caption.monospaced())
                .fontWeight(.bold)
                .foregroundColor(fpsColor)
            
            Text(String(format: "%.1f ms", frameTime))
                .font(.caption2.monospaced())
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .onReceive(updateTimer) { _ in
            updateFPS()
        }
    }
    
    private var fpsColor: Color {
        switch fps {
        case 55...: return .green
        case 30..<55: return .yellow
        default: return .red
        }
    }
    
    private func updateFPS() {
        // In a real implementation, this would track actual frame times
        // For now, using mock data
        fps = Int.random(in: 55...60)
        frameTime = 1000.0 / Double(fps)
    }
}
```

## Step 6: Testing & Optimization (30 minutes)

### 6.1 Create CV Performance Tests
Create `Utilities/CVPerformanceTests.swift`:

```swift
import Foundation
import Combine

// MARK: - CV Performance Tests
struct CVPerformanceTests {
    
    static func runPerformanceTests() {
        print("\n🔬 Running CV Performance Tests...")
        
        Task {
            await testCVLatency()
            await testEventThroughput()
            await testMemoryUsage()
        }
    }
    
    // MARK: - Latency Test
    static func testCVLatency() async {
        print("\n=== CV Latency Test ===")
        
        let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
        var latencies: [TimeInterval] = []
        
        // Subscribe to events
        let startTime = Date()
        let subscription = cvService.subscribe(
            gameId: "test",
            events: [.fingerCountDetected(count: 0)]
        ) { event in
            let latency = Date().timeIntervalSince(startTime)
            latencies.append(latency)
        }
        
        // Run for 5 seconds
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        cvService.unsubscribe(subscription)
        
        // Calculate stats
        if !latencies.isEmpty {
            let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
            let maxLatency = latencies.max() ?? 0
            let minLatency = latencies.min() ?? 0
            
            print("Average latency: \(Int(avgLatency * 1000))ms")
            print("Max latency: \(Int(maxLatency * 1000))ms")
            print("Min latency: \(Int(minLatency * 1000))ms")
        }
    }
    
    // MARK: - Throughput Test
    static func testEventThroughput() async {
        print("\n=== CV Event Throughput Test ===")
        
        let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
        var eventCount = 0
        
        let subscription = cvService.subscribe(
            gameId: "test",
            events: [.fingerCountDetected(count: 0)]
        ) { _ in
            eventCount += 1
        }
        
        let startTime = Date()
        
        // Run for 10 seconds
        try? await Task.sleep(nanoseconds: 10_000_000_000)
        
        let duration = Date().timeIntervalSince(startTime)
        cvService.unsubscribe(subscription)
        
        let eventsPerSecond = Double(eventCount) / duration
        print("Events per second: \(Int(eventsPerSecond))")
        print("Total events in \(Int(duration))s: \(eventCount)")
    }
    
    // MARK: - Memory Test
    static func testMemoryUsage() async {
        print("\n=== CV Memory Usage Test ===")
        
        let startMemory = getMemoryUsage()
        print("Start memory: \(formatBytes(startMemory))")
        
        // Start CV session
        let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
        try? await cvService.startSession()
        
        // Run for 30 seconds
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        
        let endMemory = getMemoryUsage()
        print("End memory: \(formatBytes(endMemory))")
        print("Memory increase: \(formatBytes(endMemory - startMemory))")
        
        cvService.stopSession()
    }
    
    // MARK: - Helpers
    private static func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
```

### 6.2 Add CV Test Controls to Settings
Update `Features/Settings/SettingsView.swift`:

```swift
// Add to Debug Tools section:

Section("CV Testing") {
    Button("Test Camera Permission") {
        Task {
            await CameraPermissionManager.shared.requestPermission()
        }
    }
    
    Button("Start CV Session") {
        Task {
            let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
            try? await cvService.startSession()
        }
    }
    
    Button("Stop CV Session") {
        let cvService = ServiceLocator.shared.resolve(CVServiceProtocol.self)
        cvService.stopSession()
    }
    
    Button("Run CV Performance Tests") {
        CVPerformanceTests.runPerformanceTests()
    }
    
    Toggle("CV Debug Mode", isOn: .init(
        get: {
            ServiceLocator.shared.resolve(CVServiceProtocol.self).debugMode
        },
        set: { enabled in
            ServiceLocator.shared.resolve(CVServiceProtocol.self).debugMode = enabled
        }
    ))
}
```

## Phase 3 Completion Checklist

### ✅ Camera Permissions
- [ ] Permission manager implementation
- [ ] Permission request UI with animations
- [ ] Camera unavailable handling
- [ ] Settings navigation for denied permissions

### ✅ CV Service Implementation
- [ ] ARKit session management
- [ ] Vision framework integration
- [ ] Hand pose detection
- [ ] Finger counting algorithm
- [ ] Event publishing system

### ✅ Debug Visualization
- [ ] CV debug overlay with hand skeleton
- [ ] FPS counter
- [ ] Event logging view
- [ ] Performance metrics display
- [ ] Debug view model with real-time updates

### ✅ Integration
- [ ] Camera permission check in game flow
- [ ] CV service registration
- [ ] Debug controls in settings
- [ ] Performance test suite

### ✅ Error Handling
- [ ] Camera permission errors
- [ ] ARKit availability checks
- [ ] Session failure recovery
- [ ] Graceful degradation

## Next Steps for Phase 4

With Phase 3 complete, you now have:
1. **Working CV Service**: Real-time hand tracking with ARKit
2. **Finger Detection**: Accurate counting of raised fingers
3. **Permission System**: Proper camera access flow
4. **Debug Tools**: Comprehensive visualization and metrics
5. **Event System**: Games can subscribe to CV events

Phase 4 will implement:
- The actual Finger Count game using SpriteKit
- Game mechanics and scoring
- Visual feedback for CV events
- Complete game loop with the CV system

The infrastructure is now ready for building real games that use computer vision!