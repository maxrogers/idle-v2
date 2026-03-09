import UIKit
import CarPlay

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Shared Singletons
    // These are created once and outlive all scenes — both iPhone and CarPlay scenes
    // access state through these shared objects.
    let serviceRegistry = ServiceRegistry()
    let queueManager = QueueManager()
    let playbackEngine = PlaybackEngine()

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay",
                sessionRole: .carTemplateApplication
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        return UISceneConfiguration(
            name: "Default",
            sessionRole: connectingSceneSession.role
        )
    }
}
