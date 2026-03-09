import SwiftUI
import CarPlay

/// The core protocol every service plugin must conform to.
/// Adding a new service (YouTube, Netflix, etc.) requires only a new type
/// conforming to this protocol — no core app changes needed.
@MainActor
protocol VideoServicePlugin: AnyObject, Identifiable {
    var id: String { get }
    var displayName: String { get }
    var iconSystemName: String { get }
    var isAuthenticated: Bool { get }

    /// View shown on iPhone to authenticate / set up the service.
    /// Returns nil if no authentication is needed.
    func authenticationView() -> AnyView?

    /// Full browsing view shown on iPhone for this service.
    func browseView() -> AnyView

    /// Root CarPlay template for this service's tab.
    func carPlayTab(interfaceController: CPInterfaceController) -> CPTemplate

    /// Resolves a playback URL for a given item identifier.
    func playbackURL(for itemID: String) async throws -> URL
}
