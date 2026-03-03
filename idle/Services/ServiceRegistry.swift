import Foundation

/// Central registry of all available video services.
/// CarPlay tabs and iPhone service list are driven by this registry.
@MainActor
final class ServiceRegistry: ObservableObject {

    static let shared = ServiceRegistry()

    @Published private(set) var services: [VideoService] = []

    /// Only services that are currently authenticated.
    var authenticatedServices: [VideoService] {
        services.filter { $0.isAuthenticated }
    }

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        services = [
            PlexService(),
            YouTubeService()
        ]
    }

    func service(byID id: String) -> VideoService? {
        services.first { $0.id == id }
    }
}
