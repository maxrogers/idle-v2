import Foundation
import UIKit

/// Handles idle:// URL scheme for share extension → main app handoff.
enum URLSchemeHandler {

    /// Process an incoming idle:// URL.
    /// - Returns true if the URL was handled.
    @MainActor
    @discardableResult
    static func handle(_ url: URL, appDelegate: AppDelegate) -> Bool {
        guard url.scheme?.lowercased() == "idle" else { return false }

        switch url.host?.lowercased() {
        case "queue":
            return handleQueueAction(url, appDelegate: appDelegate)
        default:
            return false
        }
    }

    // MARK: - Queue actions

    @MainActor
    private static func handleQueueAction(_ url: URL, appDelegate: AppDelegate) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        let pathAction = url.pathComponents.dropFirst().first ?? ""

        switch pathAction {
        case "add":
            guard let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let videoURL = URL(string: urlString) else { return false }

            let title = components.queryItems?.first(where: { $0.name == "title" })?.value

            appDelegate.queueManager.addToFront(
                urlString: videoURL.absoluteString,
                title: title,
                thumbnailURLString: nil,
                sourceService: "share"
            )

            // If CarPlay is connected, play immediately
            if appDelegate.playbackEngine.isExternalPlaybackActive {
                Task {
                    let result = await ExtractionRouter.route(url: videoURL)
                    await MainActor.run {
                        switch result {
                        case .directPlay(let playURL):
                            appDelegate.playbackEngine.play(url: playURL, title: title, thumbnailURL: nil)
                        case .webView(let webURL):
                            appDelegate.playbackEngine.playViaWebView(url: webURL)
                        case .error:
                            break
                        }
                    }
                }
            }
            return true

        default:
            return false
        }
    }
}
