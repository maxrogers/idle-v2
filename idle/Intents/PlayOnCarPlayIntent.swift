import AppIntents
import Foundation

/// App Intent for "Hey Siri, play this on CarPlay" workflows.
/// Also powers the `idle://play?url=...` URL scheme.
struct PlayOnCarPlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Play on CarPlay"
    static let description = IntentDescription("Send a video URL to play on your CarPlay display.")

    @Parameter(title: "Video URL")
    var url: String

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$url) on CarPlay")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let item = QueueManager.shared.addFromURL(url, title: "From Siri")

        // Attempt extraction
        do {
            let streams = try await ExtractionRouter.shared.extract(from: url)
            if let best = streams.first {
                QueueManager.shared.markAsReady(item, streamURL: best.url.absoluteString)

                if CarPlaySceneDelegate.isConnected {
                    PlaybackEngine.shared.play(item: item)
                    QueueManager.shared.markAsPlayed(item)
                    return .result(dialog: "Playing on CarPlay now.")
                } else {
                    return .result(dialog: "Video queued. It will play when CarPlay connects.")
                }
            }
        } catch {
            QueueManager.shared.markAsFailed(item)
        }

        return .result(dialog: "Couldn't play that video. Try a different link.")
    }
}

/// Shortcuts provider to expose the intent.
struct idleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayOnCarPlayIntent(),
            phrases: [
                "Play video on CarPlay with \(.applicationName)",
                "Send video to \(.applicationName)",
                "Play this on my car screen with \(.applicationName)"
            ],
            shortTitle: "Play on CarPlay",
            systemImageName: "play.rectangle.on.rectangle"
        )
    }
}
