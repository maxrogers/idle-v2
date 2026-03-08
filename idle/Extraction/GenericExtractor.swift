import Foundation
import WebKit

/// Extracts video URLs from arbitrary webpages using a combination of:
/// 1. OEmbed/OpenGraph metadata parsing
/// 2. Headless WKWebView + JavaScript injection to find <video> elements
final class GenericExtractor: Sendable {

    /// Extract streams from a generic URL.
    func extract(from url: URL) async throws -> [StreamInfo] {
        // Step 1: Try OEmbed/OpenGraph metadata
        if let streams = try? await extractFromMetadata(url: url), !streams.isEmpty {
            return streams
        }

        // Step 2: Try headless WebView extraction
        let webViewStreams = try? await extractFromWebViewOnMain(url: url)
        if let streams = webViewStreams, !streams.isEmpty {
            return streams
        }

        throw ExtractionError.noStreamsFound
    }

    @MainActor
    private func extractFromWebViewOnMain(url: URL) async throws -> [StreamInfo] {
        try await extractFromWebView(url: url)
    }

    // MARK: - Metadata Extraction

    private func extractFromMetadata(url: URL) async throws -> [StreamInfo] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }

        // Use the final response URL as base for resolving relative links
        let baseURL = (response as? HTTPURLResponse).flatMap { _ in response.url } ?? url

        var streams: [StreamInfo] = []

        // OpenGraph video meta tags
        let ogPatterns = [
            "og:video:url",
            "og:video:secure_url",
            "og:video",
            "twitter:player:stream"
        ]

        for pattern in ogPatterns {
            if let videoURL = extractMetaContent(html: html, property: pattern),
               let resolved = resolveURL(videoURL, base: baseURL),
               isVideoURL(videoURL) {
                streams.append(StreamInfo(url: resolved))
            }
        }

        // JSON-LD VideoObject
        if let videoURL = extractJSONLDVideo(html: html),
           let resolved = resolveURL(videoURL, base: baseURL) {
            streams.append(StreamInfo(url: resolved))
        }

        // <video src="..."> and <source src="..."> tags
        streams += extractVideoTags(html: html, base: baseURL)

        // <a href="..."> links pointing directly to video files
        streams += extractVideoLinks(html: html, base: baseURL)

        return streams
    }

    private func resolveURL(_ urlString: String, base: URL) -> URL? {
        if let absolute = URL(string: urlString), absolute.scheme != nil {
            return absolute
        }
        return URL(string: urlString, relativeTo: base)?.absoluteURL
    }

    private func extractVideoTags(html: String, base: URL) -> [StreamInfo] {
        // Match <video src="..."> and <source src="...">
        let pattern = "<(?:video|source)[^>]+src=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match -> StreamInfo? in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            let src = String(html[r])
            guard let url = resolveURL(src, base: base) else { return nil }
            return StreamInfo(url: url)
        }
    }

    private func extractVideoLinks(html: String, base: URL) -> [StreamInfo] {
        // Match <a href="...video-extension...">
        let pattern = "<a[^>]+href=[\"']([^\"']+\\.(?:mp4|m4v|mov|webm|m3u8|mpd)[^\"']*)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        return matches.compactMap { match -> StreamInfo? in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            let href = String(html[r])
            guard let url = resolveURL(href, base: base) else { return nil }
            return StreamInfo(url: url)
        }
    }

    private func extractMetaContent(html: String, property: String) -> String? {
        // Match: <meta property="og:video" content="URL" />
        let pattern = "<meta[^>]*(?:property|name)=\"\(property)\"[^>]*content=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else { return nil }
        guard let contentRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[contentRange])
    }

    private func extractJSONLDVideo(html: String) -> String? {
        // Look for JSON-LD with @type: VideoObject
        let pattern = "\"contentUrl\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else { return nil }
        guard let urlRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[urlRange])
    }

    private func isVideoURL(_ url: String) -> Bool {
        let videoExtensions = ["mp4", "m4v", "mov", "webm", "m3u8", "mpd"]
        return videoExtensions.contains(where: { url.lowercased().contains($0) })
    }

    // MARK: - WebView Extraction

    @MainActor
    private func extractFromWebView(url: URL) async throws -> [StreamInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []

            let webView = WKWebView(frame: .zero, configuration: config)
            let delegate = WebViewExtractionDelegate(continuation: continuation)
            webView.navigationDelegate = delegate

            // Prevent the webview from being deallocated
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            objc_setAssociatedObject(delegate, "webview", webView, .OBJC_ASSOCIATION_RETAIN)

            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - WebView Delegate

@MainActor
private final class WebViewExtractionDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<[StreamInfo], Error>?
    private var hasCompleted = false

    init(continuation: CheckedContinuation<[StreamInfo], Error>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        // Wait briefly for dynamic content to load
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !self.hasCompleted else { return }

            let js = """
            (function() {
                var videos = document.querySelectorAll('video');
                var sources = [];
                videos.forEach(function(v) {
                    if (v.src) sources.push(v.src);
                    if (v.currentSrc) sources.push(v.currentSrc);
                    v.querySelectorAll('source').forEach(function(s) {
                        if (s.src) sources.push(s.src);
                    });
                });
                return JSON.stringify([...new Set(sources)]);
            })()
            """

            do {
                let result = try await webView.evaluateJavaScript(js)
                if let jsonString = result as? String,
                   let data = jsonString.data(using: .utf8),
                   let urls = try? JSONDecoder().decode([String].self, from: data) {
                    let streams = urls.compactMap { URL(string: $0) }.map { StreamInfo(url: $0) }
                    self.complete(with: .success(streams))
                } else {
                    self.complete(with: .success([]))
                }
            } catch {
                self.complete(with: .success([]))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(with: .failure(ExtractionError.extractionFailed(error.localizedDescription)))
    }

    private func complete(with result: Result<[StreamInfo], Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        switch result {
        case .success(let streams):
            continuation?.resume(returning: streams)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}
