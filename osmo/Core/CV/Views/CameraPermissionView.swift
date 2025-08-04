//
//  CameraPermissionView.swift
//  osmo
//
//  Created by Phase 3 Implementation
//

import SwiftUI

struct CameraPermissionView: View {
    @State private var permissionManager = CameraPermissionManager.shared
    @Environment(\.dismiss) var dismiss
    // Use GameKit.audio directly
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
                Text("Osmo needs to use your camera to see your hands and objects for playing games!")
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
                                // We'll handle opening settings through the coordinator
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
        if status == .authorized {
            GameKit.haptics.notification(.success)
        } else {
            GameKit.haptics.notification(.error)
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