import CarPlay
import UIKit
import os.log

private let log = Logger(subsystem: "com.steverogers.idle", category: "CarPlayDelegate")

// MARK: - CarPlaySceneDelegate
//
// This class MUST NOT be implicitly @MainActor-isolated (the project default).
// CPTemplateApplicationSceneDelegate is an Obj-C protocol; the CarPlay runtime calls
// templateApplicationScene:didConnectInterfaceController: from its own internal thread,
// not the main thread. With SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor the Swift runtime
// wraps every method in a MainActor hop — but for @objc methods called from Obj-C, the
// runtime looks up the selector at the Obj-C level. If the selector is wrapped in an
// actor executor check, the Obj-C bridge cannot find a plain IMP and throws:
//   "Application does not implement CarPlay template application lifecycle methods"
//
// Solution: Annotate the class with @objc(CarPlaySceneDelegate) and mark every
// protocol-conformance method @objc nonisolated so they are registered as plain Obj-C
// IMPs without any Swift actor wrapper. MainActor work is dispatched explicitly inside.

@objc(CarPlaySceneDelegate)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var tabManager: CarPlayTabManager?

    // MARK: - CPTemplateApplicationSceneDelegate

    @objc nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        log.info("CarPlay: templateApplicationScene didConnect")
        Task { @MainActor in
            log.info("CarPlay: setting up tab manager")
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
            log.info("CarPlay: tab manager built")

            NotificationCenter.default.post(name: .carPlayDidConnect, object: nil)
        }
    }

    @objc nonisolated func templateApplicationScene(
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
    @objc nonisolated func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {}
    @objc nonisolated func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {}
    @objc nonisolated func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {}
    @objc nonisolated func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {}
}

// MARK: - Notification Names

extension Notification.Name {
    static let carPlayDidConnect = Notification.Name("carPlayDidConnect")
    static let carPlayDidDisconnect = Notification.Name("carPlayDidDisconnect")
    static let carPlayRebuildTabs = Notification.Name("carPlayRebuildTabs")
}
