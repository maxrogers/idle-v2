import Foundation
import AVFoundation
import Observation
import MediaPlayer

@Observable
final class PlaybackEngine: NSObject, @unchecked Sendable {

    // MARK: - State
    var isPlaying: Bool = false
    var isExternalPlaybackActive: Bool = false
    var currentTitle: String?
    var currentURL: URL?
    var progress: Double = 0
    var duration: Double = 0
    var isUsingWebView: Bool = false
    var webViewURL: URL?

    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playerItemObserver: NSKeyValueObservation?
    private var externalPlaybackObserver: NSKeyValueObservation?

    override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
    }

    // MARK: - Playback Control

    func play(url: URL, title: String?, thumbnailURL: URL?) {
        stopCurrentPlayback()

        currentURL = url
        currentTitle = title
        isUsingWebView = false
        webViewURL = nil

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.allowsExternalPlayback = true
        newPlayer.usesExternalPlaybackWhileExternalScreenIsActive = true
        newPlayer.externalPlaybackVideoGravity = .resizeAspect
        newPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible

        externalPlaybackObserver = newPlayer.observe(\.isExternalPlaybackActive, options: [.new]) { [weak self] player, _ in
            let isActive = player.isExternalPlaybackActive
            Task { @MainActor [weak self] in
                self?.isExternalPlaybackActive = isActive
            }
        }

        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.progress = time.seconds
            if let d = newPlayer.currentItem?.duration.seconds, d.isFinite {
                self?.duration = d
            }
        }

        player = newPlayer
        newPlayer.play()
        isPlaying = true

        NowPlayingManager.update(title: title, duration: nil, thumbnailURL: thumbnailURL)
    }

    func playViaWebView(url: URL) {
        stopCurrentPlayback()
        isUsingWebView = true
        webViewURL = url
        currentURL = url
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
        NowPlayingManager.setPlaybackRate(0)
    }

    func resume() {
        player?.play()
        isPlaying = true
        NowPlayingManager.setPlaybackRate(1)
    }

    func stop() {
        stopCurrentPlayback()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }

    func toggle() {
        if isPlaying { pause() } else { resume() }
    }

    // MARK: - Private Helpers

    private func stopCurrentPlayback() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        timeObserver = nil
        externalPlaybackObserver = nil
        playerItemObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        isUsingWebView = false
        webViewURL = nil
        progress = 0
        duration = 0
        isExternalPlaybackActive = false
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[PlaybackEngine] Audio session error: \(error)")
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggle()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: e.positionTime)
            }
            return .success
        }
    }
}
