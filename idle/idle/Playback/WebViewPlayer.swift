import SwiftUI
import WebKit

/// Full-screen WKWebView player for YouTube URLs.
/// Loads the official YouTube web player, injects JS to auto-play
/// and activate theater mode, and overlays transport controls.
struct WebViewPlayer: View {
    let url: URL
    @Environment(PlaybackEngine.self) private var playbackEngine
    @Environment(\.dismiss) private var dismiss

    @State private var webView = WKWebView()
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var controlsTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebViewRepresentable(url: url, webView: webView)
                .ignoresSafeArea()
                .onTapGesture { toggleControls() }

            // Transport controls overlay
            if showControls {
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding()

                    Spacer()

                    // Bottom controls
                    HStack(spacing: 40) {
                        Button {
                            seekBack()
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title)
                                .foregroundStyle(.white)
                        }

                        Button {
                            togglePlayPause()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(IdleTheme.amber)
                        }

                        Button {
                            seekForward()
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.bottom, 40)
                    .background(
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showControls)
            }
        }
        .statusBarHidden()
        .onAppear { scheduleControlsHide() }
        .onDisappear { controlsTimer?.invalidate() }
    }

    // MARK: - Controls

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { scheduleControlsHide() }
    }

    private func scheduleControlsHide() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation { showControls = false }
            }
        }
    }

    private func togglePlayPause() {
        let js = isPlaying
            ? "document.querySelector('video')?.pause();"
            : "document.querySelector('video')?.play();"
        webView.evaluateJavaScript(js)
        isPlaying.toggle()
        resetControlsTimer()
    }

    private func seekBack() {
        webView.evaluateJavaScript("document.querySelector('video').currentTime -= 15;")
        resetControlsTimer()
    }

    private func seekForward() {
        webView.evaluateJavaScript("document.querySelector('video').currentTime += 15;")
        resetControlsTimer()
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        scheduleControlsHide()
    }
}

// MARK: - WKWebView Representable

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Allow loading the same webView instance with updated config
        let wkView = webView
        wkView.navigationDelegate = context.coordinator
        wkView.scrollView.isScrollEnabled = false
        wkView.backgroundColor = .black
        wkView.scrollView.backgroundColor = .black
        wkView.isOpaque = false

        let request = URLRequest(url: url)
        wkView.load(request)
        return wkView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject JS: auto-play, theater mode, fullscreen
            let js = """
            (function() {
                var video = document.querySelector('video');
                if (video) {
                    video.play();
                }
                // Theater mode button
                var theaterBtn = document.querySelector('.ytp-size-button');
                if (theaterBtn) { theaterBtn.click(); }
                // Hide YouTube header/footer for cleaner experience
                var header = document.querySelector('#masthead-container');
                if (header) header.style.display = 'none';
                var guide = document.querySelector('#guide-inner-content');
                if (guide) guide.style.display = 'none';
            })();
            """
            webView.evaluateJavaScript(js)
        }
    }
}

#Preview {
    WebViewPlayer(url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)
        .environment(PlaybackEngine())
}
