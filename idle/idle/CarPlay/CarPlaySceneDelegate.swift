import CarPlay
import UIKit
import os.log

private let log = Logger(subsystem: "com.steverogers.idle", category: "CarPlayDelegate")

// MARK: - CarPlaySceneDelegate
//
// CRITICAL NOTES on actor isolation and Obj-C interop:
//
// 1. SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor makes this class implicitly @MainActor.
//    CPTemplateApplicationSceneDelegate is an Obj-C protocol. The CarPlay runtime calls
//    the lifecycle selectors before the main runloop is ready for actor-isolated dispatch,
//    so any Swift actor wrapper around the IMP causes the selector lookup to fail, throwing:
//    "Application does not implement CarPlay template application lifecycle methods"
//
// 2. Fix: mark every protocol method `nonisolated` so Swift registers a bare Obj-C IMP
//    with no actor wrapper. Dispatch to @MainActor explicitly inside.
//
// 3. Do NOT add @objc(SomeName) to this class. The Info.plist UISceneDelegateClassName
//    is NOT used here (AppDelegate.configurationForConnecting sets delegateClass
//    programmatically), but the Obj-C runtime still looks up the class by its Swift
//    module-qualified name "idle.CarPlaySceneDelegate". Renaming it with @objc() breaks
//    that lookup and prevents the scene from being created at all.

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var tabManager: CarPlayTabManager?

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
