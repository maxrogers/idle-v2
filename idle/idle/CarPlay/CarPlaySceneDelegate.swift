import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var tabManager: CarPlayTabManager?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.delegate = self

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let manager = CarPlayTabManager(
            interfaceController: interfaceController,
            serviceRegistry: appDelegate.serviceRegistry,
            queueManager: appDelegate.queueManager,
            playbackEngine: appDelegate.playbackEngine
        )
        tabManager = manager
        manager.buildAndSetRoot()

        NotificationCenter.default.post(name: .carPlayDidConnect, object: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        tabManager = nil
        NotificationCenter.default.post(name: .carPlayDidDisconnect, object: nil)
    }
}

// MARK: - CPInterfaceControllerDelegate

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {}
    func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {}
    func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {}
    func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {}
}

// MARK: - Notification Names

extension Notification.Name {
    static let carPlayDidConnect = Notification.Name("carPlayDidConnect")
    static let carPlayDidDisconnect = Notification.Name("carPlayDidDisconnect")
    static let carPlayRebuildTabs = Notification.Name("carPlayRebuildTabs")
}
