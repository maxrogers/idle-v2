import Foundation
import MediaPlayer

enum NowPlayingManager {

    static func update(title: String?, duration: Double?, thumbnailURL: URL?) {
        var info: [String: Any] = [
            MPMediaItemPropertyMediaType: MPMediaType.anyVideo.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        if let title { info[MPMediaItemPropertyTitle] = title }
        if let duration { info[MPMediaItemPropertyPlaybackDuration] = duration }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork asynchronously if a URL is provided
        if let url = thumbnailURL {
            Task {
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    current[MPMediaItemPropertyArtwork] = artwork
                    await MainActor.run {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                }
            }
        }
    }

    static func updateProgress(elapsed: Double, duration: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    static func setPlaybackRate(_ rate: Float) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    static func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
