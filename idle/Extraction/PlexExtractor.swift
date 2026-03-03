import Foundation

/// Extracts playable video stream URLs from Plex links.
/// Uses the Plex API with X-Plex-Token for direct stream access.
final class PlexExtractor: Sendable {

    /// Extract streams from a Plex URL.
    func extract(from url: URL) async throws -> [StreamInfo] {
        // Check if this is already a direct stream URL with token
        if url.absoluteString.contains("X-Plex-Token") {
            return [StreamInfo(url: url)]
        }

        // Try to parse Plex web app URLs: app.plex.tv/desktop#!/server/.../details?key=...
        guard let metadataKey = extractMetadataKey(from: url) else {
            throw ExtractionError.extractionFailed("Could not parse Plex URL")
        }

        // Need a server URL and token to construct a direct stream URL
        guard let config = PlexService.loadStoredConfig() else {
            throw ExtractionError.extractionFailed("Plex server not configured. Add your server in Settings.")
        }

        let streamURL = "\(config.serverURL)/library/metadata/\(metadataKey)/file?X-Plex-Token=\(config.token)"
        guard let url = URL(string: streamURL) else {
            throw ExtractionError.extractionFailed("Invalid Plex stream URL")
        }

        return [StreamInfo(url: url)]
    }

    private func extractMetadataKey(from url: URL) -> String? {
        // Parse various Plex URL formats
        let urlString = url.absoluteString

        // app.plex.tv URLs contain metadata key in the path
        if let range = urlString.range(of: "key=%2Flibrary%2Fmetadata%2F") {
            let start = range.upperBound
            let remaining = String(urlString[start...])
            return remaining.components(separatedBy: CharacterSet(charactersIn: "&%")).first
        }

        // Direct API URLs: /library/metadata/12345
        if urlString.contains("/library/metadata/") {
            let components = url.pathComponents
            if let idx = components.firstIndex(of: "metadata"), idx + 1 < components.count {
                return components[idx + 1]
            }
        }

        return nil
    }
}
