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
    // Note: CarPlay scene delegate is configured entirely via Info.plist
    // (CPTemplateApplicationSceneSessionRoleApplication → CarPlaySceneDelegate).
    // We do NOT override configurationForConnecting for CarPlay — doing so
    // causes Swift to reference the class through its Swift type metadata,
    // which can interfere with the Obj-C IMP registration we depend on.
}
