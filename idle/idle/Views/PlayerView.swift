import SwiftUI

/// A unified full-screen player that switches between AVPlayer (via system)
/// and WKWebView depending on the extraction result.
/// This view is presented modally when playback starts.
struct PlayerView: View {
    @Environment(PlaybackEngine.self) private var playbackEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if playbackEngine.isUsingWebView, let url = playbackEngine.webViewURL {
                WebViewPlayer(url: url)
            } else {
                AVPlayerView()
            }
        }
    }
}

// MARK: - AVPlayer container view

struct AVPlayerView: View {
    @Environment(PlaybackEngine.self) private var playbackEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // When external playback is active, show a "Playing on CarPlay" indicator
                if playbackEngine.isExternalPlaybackActive {
                    VStack(spacing: 16) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(IdleTheme.amber)

                        Text("Playing on CarPlay")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        if let title = playbackEngine.currentTitle {
                            Text(title)
                                .foregroundStyle(Color(white: 0.7))
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(IdleTheme.textTertiary)

                        if let title = playbackEngine.currentTitle {
                            Text(title)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer()

                // Transport controls
                transportControls

                Spacer(minLength: 40)
            }
            .padding()

            // Close button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }

    private var transportControls: some View {
        VStack(spacing: 16) {
            // Progress bar
            if playbackEngine.duration > 0 {
                Slider(
                    value: Binding(
                        get: { playbackEngine.progress },
                        set: { playbackEngine.seek(to: $0) }
                    ),
                    in: 0...playbackEngine.duration
                )
                .tint(IdleTheme.amber)

                HStack {
                    Text(formatTime(playbackEngine.progress))
                        .font(IdleTheme.captionFont)
                        .foregroundStyle(IdleTheme.textSecondary)
                    Spacer()
                    Text(formatTime(playbackEngine.duration))
                        .font(IdleTheme.captionFont)
                        .foregroundStyle(IdleTheme.textSecondary)
                }
            }

            // Play/pause
            HStack(spacing: 48) {
                Button {
                    playbackEngine.seek(to: max(0, playbackEngine.progress - 15))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundStyle(.white)
                }

                Button {
                    playbackEngine.toggle()
                } label: {
                    Image(systemName: playbackEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(IdleTheme.amber)
                }

                Button {
                    playbackEngine.seek(to: playbackEngine.progress + 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s % 60)
        }
        return String(format: "%d:%02d", m, s % 60)
    }
}
