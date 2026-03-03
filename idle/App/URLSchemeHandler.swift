import Foundation
import SwiftUI

/// Handles `idle://play?url=...` deep links from Shortcuts, other apps, etc.
@MainActor
final class URLSchemeHandler {

    static let shared = URLSchemeHandler()

    private init() {}

    /// Handle an incoming URL.
    /// Returns true if the URL was handled.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "idle" else { return false }

        switch url.host {
        case "play":
            return handlePlay(url: url)
        default:
            return false
        }
    }

    private func handlePlay(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let videoURLString = components.queryItems?.first(where: { $0.name == "url" })?.value else {
            return false
        }

        let title = components.queryItems?.first(where: { $0.name == "title" })?.value

        let item = QueueManager.shared.addFromURL(videoURLString, title: title)

        Task { @MainActor in
            do {
                let streams = try await ExtractionRouter.shared.extract(from: videoURLString)
                if let best = streams.first {
                    QueueManager.shared.markAsReady(item, streamURL: best.url.absoluteString)

                    if CarPlaySceneDelegate.isConnected {
                        PlaybackEngine.shared.play(item: item)
                        QueueManager.shared.markAsPlayed(item)
                    }
                }
            } catch {
                QueueManager.shared.markAsFailed(item)
            }
        }

        return true
    }
}
