import Foundation

enum ExtractionResult {
    case directPlay(URL)
    case webView(URL)
    case error(String)
}

enum ExtractionRouter {

    static func route(url: URL) async -> ExtractionResult {
        if YouTubeExtractor.isYouTubeURL(url) {
            if let normalized = YouTubeExtractor.normalizeURL(url) {
                return .webView(normalized)
            }
            return .webView(url)
        }

        // Try direct play for everything else
        return await GenericExtractor.extract(url: url)
    }
}
