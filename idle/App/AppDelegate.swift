import UIKit

/// AppDelegate serves as the iPhone window scene delegate.
/// Having a concrete UISceneDelegateClassName in Info.plist prevents
/// SwiftUI's internal AppSceneDelegate from entering infinite recursion.
class AppDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate {
    var window: UIWindow?
}
