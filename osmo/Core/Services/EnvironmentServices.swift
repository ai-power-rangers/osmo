//
//  EnvironmentServices.swift
//  osmo
//
//  SwiftUI Environment keys for service injection
//

import SwiftUI

// MARK: - Service Container Environment Key

private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer? = nil
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainer? {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - Individual Service Environment Keys

private struct PersistenceServiceKey: EnvironmentKey {
    static let defaultValue: PersistenceServiceProtocol? = nil
}

private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsServiceProtocol? = nil
}

private struct AudioServiceKey: EnvironmentKey {
    static let defaultValue: AudioServiceProtocol? = nil
}

private struct CVServiceKey: EnvironmentKey {
    static let defaultValue: CVServiceProtocol? = nil
}

private struct GridEditorServiceKey: EnvironmentKey {
    static let defaultValue: GridEditorServiceProtocol? = nil
}

// MARK: - Environment Value Extensions

extension EnvironmentValues {
    var persistenceService: PersistenceServiceProtocol? {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
    
    var analyticsService: AnalyticsServiceProtocol? {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
    
    var audioService: AudioServiceProtocol? {
        get { self[AudioServiceKey.self] }
        set { self[AudioServiceKey.self] = newValue }
    }
    
    var cvService: CVServiceProtocol? {
        get { self[CVServiceKey.self] }
        set { self[CVServiceKey.self] = newValue }
    }
    
    var gridEditorService: GridEditorServiceProtocol? {
        get { self[GridEditorServiceKey.self] }
        set { self[GridEditorServiceKey.self] = newValue }
    }
}

// MARK: - View Modifiers for Service Injection

extension View {
    /// Inject all services from a service container
    func injectServices(from container: ServiceContainer) -> some View {
        self
            .environment(\.serviceContainer, container)
            .environment(\.persistenceService, container.persistence)
            .environment(\.analyticsService, container.analytics)
            .environment(\.audioService, container.audio)
            .environment(\.cvService, container.cv)
            .environment(\.gridEditorService, container.gridEditor)
    }
    
    /// Inject individual service
    func inject<Service>(_ keyPath: WritableKeyPath<EnvironmentValues, Service?>, _ service: Service?) -> some View {
        environment(keyPath, service)
    }
}

// MARK: - Service Requirement View Modifier

struct RequireService<Service, Content: View>: View {
    let service: Service?
    let content: (Service) -> Content
    let serviceName: String
    
    init(
        _ service: Service?,
        serviceName: String,
        @ViewBuilder content: @escaping (Service) -> Content
    ) {
        self.service = service
        self.serviceName = serviceName
        self.content = content
    }
    
    var body: some View {
        if let service = service {
            content(service)
        } else {
            ServiceUnavailableView(serviceName: serviceName)
        }
    }
}

// MARK: - Service Unavailable View

struct ServiceUnavailableView: View {
    let serviceName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Service Unavailable")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("\(serviceName) service is not available.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Please restart the app or contact support if the problem persists.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Convenience Service Access

extension View {
    /// Require persistence service or show error
    func requirePersistence<Content: View>(
        @ViewBuilder content: @escaping (PersistenceServiceProtocol) -> Content
    ) -> some View {
        WithService(\.persistenceService, serviceName: "Persistence", content: content)
    }
    
    /// Require analytics service or show error
    func requireAnalytics<Content: View>(
        @ViewBuilder content: @escaping (AnalyticsServiceProtocol) -> Content
    ) -> some View {
        WithService(\.analyticsService, serviceName: "Analytics", content: content)
    }
    
    /// Require audio service or show error
    func requireAudio<Content: View>(
        @ViewBuilder content: @escaping (AudioServiceProtocol) -> Content
    ) -> some View {
        WithService(\.audioService, serviceName: "Audio", content: content)
    }
    
    /// Require CV service or show error
    func requireCV<Content: View>(
        @ViewBuilder content: @escaping (CVServiceProtocol) -> Content
    ) -> some View {
        WithService(\.cvService, serviceName: "Computer Vision", content: content)
    }
    
    /// Require grid editor service or show error
    func requireGridEditor<Content: View>(
        @ViewBuilder content: @escaping (GridEditorServiceProtocol) -> Content
    ) -> some View {
        WithService(\.gridEditorService, serviceName: "Grid Editor", content: content)
    }
}

// MARK: - Generic Service Wrapper

private struct WithService<Service, Content: View>: View {
    @Environment var service: Service?
    let serviceName: String
    let content: (Service) -> Content
    
    init(
        _ keyPath: KeyPath<EnvironmentValues, Service?>,
        serviceName: String,
        @ViewBuilder content: @escaping (Service) -> Content
    ) {
        self._service = Environment(keyPath)
        self.serviceName = serviceName
        self.content = content
    }
    
    var body: some View {
        RequireService(service, serviceName: serviceName, content: content)
    }
}