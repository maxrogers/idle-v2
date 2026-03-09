import Foundation

enum GenericExtractor {

    private static let videoMIMETypes: Set<String> = [
        "video/mp4", "video/quicktime", "video/x-m4v", "video/mpeg",
        "video/ogg", "video/webm", "video/x-msvideo", "video/x-matroska",
        "application/x-mpegURL",  // HLS
        "application/dash+xml"    // DASH
    ]

    /// Attempts direct playback. Does a HEAD request to check content-type.
    static func extract(url: URL) async -> ExtractionResult {
        // For URLs that look like direct video files, pass through immediately
        let pathExt = url.pathExtension.lowercased()
        if ["mp4", "m4v", "mov", "mkv", "avi", "mpg", "mpeg", "m3u8", "webm"].contains(pathExt) {
            return .directPlay(url)
        }

        // For unknown URLs, try a HEAD request
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            let baseType = contentType.split(separator: ";").first.map(String.init)?.trimmingCharacters(in: .whitespaces)
            if let baseType, videoMIMETypes.contains(baseType) {
                return .directPlay(url)
            }
        }

        // Default: attempt direct play and let AVPlayer decide
        return .directPlay(url)
    }
}
