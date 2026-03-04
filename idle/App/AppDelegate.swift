import UIKit
import CarPlay

class AppDelegate: UIResponder, UIApplicationDelegate, UIWindowSceneDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        return UISceneConfiguration(
            name: "iPhone",
            sessionRole: connectingSceneSession.role
        )
    }
}
