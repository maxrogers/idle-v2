import CoreMotion
import Foundation

/// Detects whether the vehicle is stationary (idle) using the device's motion sensors.
/// Mirrors iOS 26.4's approach of using accelerometer data rather than vehicle data.
@MainActor
final class IdleDetector: ObservableObject {

    static let shared = IdleDetector()

    @Published private(set) var isIdle = true
    @Published private(set) var confidence: Double = 1.0

    private let activityManager = CMMotionActivityManager()
    private let motionManager = CMMotionManager()
    private var confirmationTask: Task<Void, Never>?

    /// Seconds of stationary activity required before confirming idle state.
    private let confirmationSeconds: Double = 3.0

    private init() {
        // Defer motion monitoring so it doesn't block app launch.
        // isIdle defaults to true so playback is allowed immediately.
        Task { @MainActor in
            self.startMonitoring()
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        let t = Date()
        print("[idle] ⏱ IdleDetector.startMonitoring")
        guard CMMotionActivityManager.isActivityAvailable() else {
            // Fallback to accelerometer (or no-op on simulator where neither is available)
            startAccelerometerFallback()
            print("[idle] ⏱ IdleDetector ready (accelerometer fallback) \(Date().timeIntervalSince(t)*1000)ms")
            return
        }

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            Task { @MainActor in
                self?.handleActivity(activity)
            }
        }
        print("[idle] ⏱ IdleDetector ready (activity manager) \(Date().timeIntervalSince(t)*1000)ms")
    }

    private func handleActivity(_ activity: CMMotionActivity) {
        if activity.stationary {
            // Stationary detected — start confirmation timer
            startConfirmation()
        } else if activity.automotive || activity.cycling || activity.running || activity.walking {
            // Motion detected — immediately block video
            cancelConfirmation()
            isIdle = false
            confidence = 0.0
        }
    }

    private func startConfirmation() {
        // Don't restart if already confirming
        guard confirmationTask == nil else { return }

        confirmationTask = Task { @MainActor in
            // Wait for confirmation period
            try? await Task.sleep(for: .seconds(confirmationSeconds))
            guard !Task.isCancelled else { return }

            isIdle = true
            confidence = 1.0
            confirmationTask = nil
        }
    }

    private func cancelConfirmation() {
        confirmationTask?.cancel()
        confirmationTask = nil
    }

    // MARK: - Accelerometer Fallback

    private func startAccelerometerFallback() {
        guard motionManager.isAccelerometerAvailable else {
            // No sensors available — default to idle (allow playback)
            isIdle = true
            return
        }

        motionManager.accelerometerUpdateInterval = 0.5
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let data = data else { return }
            Task { @MainActor in
                self?.handleAccelerometer(data)
            }
        }
    }

    private func handleAccelerometer(_ data: CMAccelerometerData) {
        // Calculate total acceleration magnitude (excluding gravity ~1.0)
        let magnitude = sqrt(
            data.acceleration.x * data.acceleration.x +
            data.acceleration.y * data.acceleration.y +
            data.acceleration.z * data.acceleration.z
        )

        // Threshold: significant motion above normal gravity variation
        let threshold = 1.05
        if magnitude > threshold {
            isIdle = false
            confidence = 0.0
            cancelConfirmation()
        } else {
            startConfirmation()
        }
    }

    func stopMonitoring() {
        activityManager.stopActivityUpdates()
        motionManager.stopAccelerometerUpdates()
        confirmationTask?.cancel()
    }
}
