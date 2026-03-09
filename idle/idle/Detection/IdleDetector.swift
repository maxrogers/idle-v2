import Foundation
import CoreLocation
import Observation

/// Detects whether the vehicle is parked (idle) using CoreLocation speed.
/// Implementation is stubbed — will be activated in a future phase.
/// The architecture hook is here: observe `isParked` from PlaybackEngine
/// to lock/unlock video playback when this feature is enabled.
@Observable
final class IdleDetector: NSObject {

    // TODO (future phase): Lock playback above this speed threshold
    static let parkingSpeedThresholdMPS: Double = 2.24 // ~5 mph

    var isParked: Bool = true  // Default to parked (safe default)
    var isEnabled: Bool = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start() {
        guard isEnabled else { return }
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }
}

extension IdleDetector: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let speed = locations.last?.speed, speed >= 0 else { return }
        isParked = speed < Self.parkingSpeedThresholdMPS
    }
}
