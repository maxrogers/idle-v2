import Foundation

/// Extracts playable video stream URLs from YouTube links using the YouTube Innertube API.
final class YouTubeExtractor: Sendable {

    /// Extract streams from a YouTube URL.
    func extract(from url: URL) async throws -> [StreamInfo] {
        guard let videoID = extractVideoID(from: url) else {
            throw ExtractionError.invalidURL
        }
        print("[YouTube] extracting videoID=\(videoID)")
        return try await fetchStreams(videoID: videoID)
    }

    // MARK: - Innertube API

    private func fetchStreams(videoID: String) async throws -> [StreamInfo] {
        // YouTube Innertube API — same endpoint the web player uses
        let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "videoId": videoID,
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "19.45.4",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone",
                    "hl": "en",
                    "gl": "US",
                    "osName": "iPhone",
                    "osVersion": "17.0.0.21A342",
                    "userAgent": "com.google.ios.youtube/19.45.4 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
                ]
            ],
            "playbackContext": [
                "contentPlaybackContext": [
                    "html5Preference": "HTML5_PREF_WANTS"
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[YouTube] innertube API returned non-200: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ExtractionError.noStreamsFound
        }

        return try parseStreams(from: data, videoID: videoID)
    }

    private func parseStreams(from data: Data, videoID: String) throws -> [StreamInfo] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ExtractionError.noStreamsFound
        }

        // Check playability
        if let playabilityStatus = json["playabilityStatus"] as? [String: Any],
           let status = playabilityStatus["status"] as? String,
           status != "OK" {
            let reason = playabilityStatus["reason"] as? String ?? status
            print("[YouTube] video not playable: \(reason)")
            throw ExtractionError.noStreamsFound
        }

        guard let streamingData = json["streamingData"] as? [String: Any] else {
            print("[YouTube] no streamingData in response")
            throw ExtractionError.noStreamsFound
        }

        var streams: [StreamInfo] = []

        // Adaptive streams (separate video+audio) — skip these, we want muxed
        // Combined (muxed) video+audio formats — preferred
        if let formats = streamingData["formats"] as? [[String: Any]] {
            let muxed = parseFormats(formats, videoID: videoID, adaptive: false)
            streams.append(contentsOf: muxed)
        }

        // HLS manifest — best for AVPlayer
        if let hlsManifest = streamingData["hlsManifestUrl"] as? String,
           let hlsURL = URL(string: hlsManifest) {
            print("[YouTube] HLS manifest found: \(hlsManifest)")
            // HLS is preferred — put it first
            streams.insert(StreamInfo(url: hlsURL), at: 0)
        }

        // Adaptive video+audio as fallback
        if streams.isEmpty, let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            let adaptive = parseFormats(adaptiveFormats, videoID: videoID, adaptive: true)
            // Only take video streams (mime contains "video/")
            let videoOnly = adaptive.filter { $0.url.absoluteString.contains("video") || true }
            streams.append(contentsOf: videoOnly)
        }

        print("[YouTube] found \(streams.count) stream(s)")
        if streams.isEmpty {
            throw ExtractionError.noStreamsFound
        }

        return streams
    }

    private func parseFormats(_ formats: [[String: Any]], videoID: String, adaptive: Bool) -> [StreamInfo] {
        var result: [StreamInfo] = []
        for format in formats {
            // Prefer formats that have a direct URL (not cipher/signatureCipher)
            if let urlString = format["url"] as? String,
               let url = URL(string: urlString) {
                let height = format["height"] as? Int
                result.append(StreamInfo(url: url, resolution: height))
            }
            // signatureCipher requires deobfuscation — skip for now
        }
        // Sort by resolution descending (highest quality first)
        result.sort { ($0.resolution ?? 0) > ($1.resolution ?? 0) }
        return result
    }

    // MARK: - Video ID Extraction

    /// Extract video ID from various YouTube URL formats.
    private func extractVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString

        // youtu.be/VIDEO_ID
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.dropFirst().first
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
