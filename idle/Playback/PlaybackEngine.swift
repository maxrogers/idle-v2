import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// Manages all video playback via AVPlayer.
/// Works identically for both CarPlay rendering paths (CPWindow and AirPlay).
@MainActor
final class PlaybackEngine: ObservableObject {

    static let shared = PlaybackEngine()

    // MARK: - Published State

    @Published private(set) var isPlaying = false
    @Published private(set) var currentItem: VideoItem?
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isBuffering = false

    // MARK: - Player

    let player = AVPlayer()

    // MARK: - Private

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?

    private init() {
        configureAudioSession()
        configureAirPlay()
        setupRemoteCommandCenter()
        setupObservers()
        setupInterruptionHandling()
    }

    // MARK: - Public API

    func play(item: VideoItem) {
        guard let urlString = item.streamURL, let url = URL(string: urlString) else { return }

        currentItem = item
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true

        item.playedAt = Date()
        updateNowPlayingInfo()
    }

    func play(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        player.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentItem = nil
        currentTime = 0
        duration = 0
        clearNowPlayingInfo()
    }

    // MARK: - Configuration

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("[idle] Audio session configuration failed: \(error)")
        }
    }

    private func configureAirPlay() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
    }

    /// Whether video is currently being routed externally (e.g. CarPlay via AirPlay).
    var isExternalPlaybackActive: Bool {
        player.isExternalPlaybackActive
    }

    private func setupObservers() {
        // Periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                if let duration = self?.player.currentItem?.duration.seconds, duration.isFinite {
                    self?.duration = duration
                }
                self?.updateNowPlayingElapsedTime()
            }
        }

        // Rate observation for play/pause state
        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate > 0
            }
        }

        // Buffering observation
        statusObservation = player.observe(\.currentItem?.isPlaybackBufferEmpty, options: [.new]) { [weak self] _, change in
            Task { @MainActor in
                self?.isBuffering = change.newValue == true
            }
        }
    }

    // MARK: - Remote Command Center

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                guard let self else { return }
                self.seek(to: self.currentTime + event.interval)
            }
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                guard let self else { return }
                self.seek(to: max(0, self.currentTime - event.interval))
            }
            return .success
        }
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
        ]

        if let item = currentItem {
            info[MPMediaItemPropertyTitle] = item.title
            info[MPMediaItemPropertyArtist] = item.source.rawValue.capitalized
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsedTime() {
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = duration
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Interruption Handling

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt

            Task { @MainActor in
                guard let typeRaw = typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

                switch type {
                case .began:
                    self?.pause()
                case .ended:
                    if let optRaw = optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optRaw)
                        if options.contains(.shouldResume) {
                            self?.resume()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }
    }
}
