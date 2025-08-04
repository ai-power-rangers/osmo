//
//  ServiceBoundary.swift
//  osmo
//
//  Error boundary views for service initialization
//

import SwiftUI

/// A view that ensures services are initialized before showing content
struct ServiceBoundary<Content: View>: View {
    @Environment(ServiceContainer.self) private var services
    let content: () -> Content
    
    var body: some View {
        Group {
            if services.isInitialized {
                content()
                    .injectServices(from: services)
            } else if let error = services.initializationError {
                ServiceErrorView(error: error)
            } else {
                ServiceLoadingView(progress: services.initializationProgress)
            }
        }
    }
}

/// Loading view shown during service initialization
struct ServiceLoadingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 30) {
            // App logo or icon
            Image(systemName: "cube.box.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .symbolEffect(.pulse)
            
            VStack(spacing: 10) {
                Text("Initializing Services")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if progress > 0 {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                        .tint(.accentColor)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Error view shown when service initialization fails
struct ServiceErrorView: View {
    let error: Error
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 10) {
                Text("Service Initialization Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 15) {
                Button {
                    // Attempt to reinitialize
                    Task {
                        await reinitializeServices()
                    }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                
                #if DEBUG
                Button {
                    // Show detailed error info
                    showDetailedError()
                } label: {
                    Text("Show Details")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                #endif
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func reinitializeServices() async {
        // This would be implemented to retry initialization
        // For now, just close the app
        fatalError("Service reinitialization not implemented")
    }
    
    private func showDetailedError() {
        print("=== Service Initialization Error ===")
        print(error)
        if let nsError = error as NSError? {
            print("Domain: \(nsError.domain)")
            print("Code: \(nsError.code)")
            print("UserInfo: \(nsError.userInfo)")
        }
        print("===================================")
    }
}

/// A view modifier that adds service boundary protection
struct ServiceBoundaryModifier: ViewModifier {
    func body(content: Content) -> some View {
        ServiceBoundary {
            content
        }
    }
}

extension View {
    /// Wrap view in service boundary protection
    func serviceBoundary() -> some View {
        modifier(ServiceBoundaryModifier())
    }
}