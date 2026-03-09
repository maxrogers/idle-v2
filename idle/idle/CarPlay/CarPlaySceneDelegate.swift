import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var tabManager: CarPlayTabManager?

    // MARK: - CPTemplateApplicationSceneDelegate
    //
    // These methods MUST be nonisolated. With SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
    // the class is MainActor-isolated by default, but CPTemplateApplicationSceneDelegate
    // is an Obj-C protocol whose methods are called by the CarPlay runtime from a
    // non-MainActor context. Without nonisolated the Obj-C runtime can't find the
    // selector and the app crashes with "does not implement CarPlay lifecycle methods".

    nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            self.interfaceController = interfaceController
            interfaceController.delegate = self

            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

            let manager = CarPlayTabManager(
                interfaceController: interfaceController,
                serviceRegistry: appDelegate.serviceRegistry,
                queueManager: appDelegate.queueManager,
                playbackEngine: appDelegate.playbackEngine
            )
            self.tabManager = manager
            manager.buildAndSetRoot()

            NotificationCenter.default.post(name: .carPlayDidConnect, object: nil)
        }
    }

    nonisolated func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            self.interfaceController = nil
            self.tabManager = nil
            NotificationCenter.default.post(name: .carPlayDidDisconnect, object: nil)
        }
    }
}

// MARK: - CPInterfaceControllerDelegate

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    // Also nonisolated — CPInterfaceControllerDelegate is an Obj-C protocol called
    // from a non-MainActor context; same reasoning as the lifecycle methods above.
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
