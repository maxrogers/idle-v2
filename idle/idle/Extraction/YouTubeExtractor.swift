import Foundation

enum YouTubeExtractor {

    static func isYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "youtube.com" || host == "www.youtube.com"
            || host == "youtu.be" || host == "m.youtube.com"
            || host == "music.youtube.com"
    }

    /// Normalizes short/mobile/shorts URLs to standard youtube.com/watch?v= format.
    static func normalizeURL(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }

        // youtu.be/VIDEO_ID
        if host == "youtu.be" {
            let videoID = url.lastPathComponent
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        // Normalize to desktop
        components.host = "www.youtube.com"

        // /shorts/VIDEO_ID -> /watch?v=VIDEO_ID
        if url.pathComponents.contains("shorts") {
            let videoID = url.lastPathComponent
            components.path = "/watch"
            components.queryItems = [URLQueryItem(name: "v", value: videoID)]
        }

        return components.url
    }
}
