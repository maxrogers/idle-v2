import CarPlay
import UIKit
import os.log

private let log = Logger(subsystem: "com.steverogers.idle", category: "CarPlayDelegate")

/// Swift-side logic called from the Obj-C CarPlaySceneDelegate.
/// Keeping this in Swift lets us use Swift types (CarPlayTabManager, AppDelegate, etc.)
/// while the Obj-C delegate provides plain IMPs that the CarPlay runtime can find.
@objc public final class CarPlayBridge: NSObject {

    private static var tabManager: CarPlayTabManager?

    @objc public static func didConnect(
        withInterfaceController interfaceController: CPInterfaceController,
        delegate: NSObject
    ) {
        log.info("CarPlay: didConnect — setting up on MainActor")
        Task { @MainActor in
            log.info("CarPlay: MainActor setup start")
            interfaceController.delegate = delegate as? CPInterfaceControllerDelegate

            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                log.error("CarPlay: AppDelegate not found")
                return
            }

            let manager = CarPlayTabManager(
                interfaceController: interfaceController,
                serviceRegistry: appDelegate.serviceRegistry,
                queueManager: appDelegate.queueManager,
                playbackEngine: appDelegate.playbackEngine
            )
            tabManager = manager
            manager.buildAndSetRoot()
            log.info("CarPlay: tab manager built successfully")

            NotificationCenter.default.post(name: .carPlayDidConnect, object: nil)
        }
    }

    @objc public static func didDisconnect() {
        log.info("CarPlay: didDisconnect")
        Task { @MainActor in
            tabManager = nil
            NotificationCenter.default.post(name: .carPlayDidDisconnect, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let carPlayDidConnect = Notification.Name("carPlayDidConnect")
    static let carPlayDidDisconnect = Notification.Name("carPlayDidDisconnect")
    static let carPlayRebuildTabs = Notification.Name("carPlayRebuildTabs")
}
