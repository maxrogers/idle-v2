import Foundation

/// Extracts playable video stream URLs from YouTube links.
/// Uses YouTubeKit (alexeichhorn/YouTubeKit) for on-device extraction.
final class YouTubeExtractor: Sendable {

    /// Extract streams from a YouTube URL.
    func extract(from url: URL) async throws -> [StreamInfo] {
        guard let videoID = extractVideoID(from: url) else {
            throw ExtractionError.invalidURL
        }

        // TODO: Replace with actual YouTubeKit integration once SPM package is added.
        // let yt = YouTube(videoID: videoID, methods: [.local])
        // let streams = try await yt.streams
        // return streams.filterVideoAndAudio()
        //     .filter { $0.isNativelyPlayable }
        //     .sorted { ($0.resolution ?? 0) > ($1.resolution ?? 0) }
        //     .map { StreamInfo(url: $0.url, resolution: $0.resolution) }

        // Placeholder: construct an embed URL that may work for some content
        if let streamURL = URL(string: "https://www.youtube.com/embed/\(videoID)") {
            return [StreamInfo(url: streamURL)]
        }

        throw ExtractionError.noStreamsFound
    }

    /// Extract video ID from various YouTube URL formats.
    private func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString

        // youtu.be/VIDEO_ID
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.last
        }

        // youtube.com/watch?v=VIDEO_ID
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return videoID
        }

        // youtube.com/embed/VIDEO_ID
        if urlString.contains("/embed/") {
            return url.pathComponents.last
        }

        // youtube.com/shorts/VIDEO_ID
        if urlString.contains("/shorts/") {
            return url.pathComponents.last
        }

        return nil
    }
}
