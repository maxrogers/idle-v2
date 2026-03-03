import AVFoundation
import UIKit

/// Renders video on the CarPlay display via AVPlayerLayer.
/// Used as the rootViewController of CPWindow (Path A — navigation entitlement).
final class CarPlayVideoViewController: UIViewController {

    private var playerLayer: AVPlayerLayer?

    /// User's preferred aspect ratio mode.
    enum AspectMode: String {
        case fill       // Crop to fill (default)
        case fit        // Letterbox/pillarbox
    }

    var aspectMode: AspectMode = .fill {
        didSet { updateAspectRatio() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    // MARK: - Public API

    func attachPlayer(_ player: AVPlayer) {
        // Remove existing layer if any
        playerLayer?.removeFromSuperlayer()

        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.videoGravity = gravityForMode(aspectMode)
        view.layer.addSublayer(layer)
        self.playerLayer = layer
    }

    // MARK: - Aspect Ratio

    private func updateAspectRatio() {
        playerLayer?.videoGravity = gravityForMode(aspectMode)
    }

    private func gravityForMode(_ mode: AspectMode) -> AVLayerVideoGravity {
        switch mode {
        case .fill: return .resizeAspectFill
        case .fit:  return .resizeAspect
        }
    }
}
