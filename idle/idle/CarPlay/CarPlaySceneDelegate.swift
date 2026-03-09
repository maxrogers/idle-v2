import CarPlay
import UIKit
import os.log

private let log = Logger(subsystem: "com.steverogers.idle", category: "CarPlayDelegate")

// MARK: - CarPlaySceneDelegate
//
// CRITICAL NOTES on actor isolation and Obj-C interop:
//
// 1. SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor makes all classes implicitly @MainActor.
//    CPTemplateApplicationSceneDelegate is an Obj-C protocol. The CarPlay runtime calls
//    the lifecycle selectors synchronously before the main runloop is ready for actor-
//    isolated dispatch, so any Swift actor wrapper around the IMP causes the selector
//    lookup to fail: "Application does not implement CarPlay template application
//    lifecycle methods in its scene delegate."
//
// 2. Fix (two-part):
//    a) Mark stored properties `nonisolated(unsafe)` — this removes MainActor isolation
//       from the *class*, so Swift no longer wraps the Obj-C IMPs in an actor check.
//    b) Mark every protocol method `nonisolated` so the bare IMP is registered.
//    Then dispatch to @MainActor explicitly inside each method body.
//
// 3. UISceneDelegateClassName in Info.plist must be "idle.CarPlaySceneDelegate".
//    AppDelegate.configurationForConnecting also sets delegateClass programmatically
//    as a belt-and-suspenders measure.

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    // nonisolated(unsafe) removes @MainActor from these stored properties, which in turn
    // removes the actor isolation from the class itself. Without this, Swift generates
    // actor-executor-checked IMPs for all Obj-C protocol methods, causing the CarPlay
    // runtime's selector lookup to fail even when the methods are marked `nonisolated`.
    nonisolated(unsafe) var interfaceController: CPInterfaceController?
    nonisolated(unsafe) private var tabManager: CarPlayTabManager?

    // MARK: - CPTemplateApplicationSceneDelegate

    nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        log.info("CarPlay: templateApplicationScene didConnect — dispatching to MainActor")
        Task { @MainActor in
            log.info("CarPlay: MainActor setup start")
            self.interfaceController = interfaceController
            interfaceController.delegate = self

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
            self.tabManager = manager
            manager.buildAndSetRoot()
            log.info("CarPlay: tab manager built successfully")

            NotificationCenter.default.post(name: .carPlayDidConnect, object: nil)
        }
    }

    nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        log.info("CarPlay: templateApplicationScene didDisconnect")
        Task { @MainActor in
            self.interfaceController = nil
            self.tabManager = nil
            NotificationCenter.default.post(name: .carPlayDidDisconnect, object: nil)
        }
    }
}

// MARK: - CPInterfaceControllerDelegate

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    nonisolated func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {}
    nonisolated func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {}
    nonisolated func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {}
    nonisolated func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {}
}

// MARK: - Notification Names

extension Notification.Name {
    static let carPlayDidConnect = Notification.Name("carPlayDidConnect")
    static let carPlayDidDisconnect = Notification.Name("carPlayDidDisconnect")
    static let carPlayRebuildTabs = Notification.Name("carPlayRebuildTabs")
}
