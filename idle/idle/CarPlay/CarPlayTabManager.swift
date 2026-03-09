import CarPlay
import Foundation

/// Builds and manages the CPTabBarTemplate from the enabled services,
/// Queue tab (when non-empty), and Settings tab (lowest priority, first removed).
final class CarPlayTabManager {

    private let interfaceController: CPInterfaceController
    private let serviceRegistry: ServiceRegistry
    private let queueManager: QueueManager
    private let playbackEngine: PlaybackEngine

    private static let maxTabs = 4

    init(
        interfaceController: CPInterfaceController,
        serviceRegistry: ServiceRegistry,
        queueManager: QueueManager,
        playbackEngine: PlaybackEngine
    ) {
        self.interfaceController = interfaceController
        self.serviceRegistry = serviceRegistry
        self.queueManager = queueManager
        self.playbackEngine = playbackEngine

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuild),
            name: .carPlayRebuildTabs,
            object: nil
        )
    }

    @objc func rebuild() {
        buildAndSetRoot()
    }

    func buildAndSetRoot() {
        let tabs = buildTabs()
        if tabs.isEmpty {
            // Show a minimal settings-only template if no services enabled
            let settingsTemplate = CarPlaySettingsTemplate.build()
            interfaceController.setRootTemplate(settingsTemplate, animated: false, completion: nil)
        } else if tabs.count == 1 {
            interfaceController.setRootTemplate(tabs[0], animated: false, completion: nil)
        } else {
            let tabBar = CPTabBarTemplate(templates: tabs)
            interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
        }
    }

    // MARK: - Private

    private func buildTabs() -> [CPTemplate] {
        var tabs: [CPTemplate] = []

        // 1. Service tabs (in user-defined order)
        for service in serviceRegistry.enabledServices {
            guard tabs.count < Self.maxTabs else { break }
            let template = service.carPlayTab(interfaceController: interfaceController)
            tabs.append(template)
        }

        // 2. Queue tab — only if non-empty (we use a placeholder check here;
        //    QueueManager.modelContext is set by the time this runs from main app)
        let hasQueueItems = false // Will be wired properly in Phase 11
        if hasQueueItems && tabs.count < Self.maxTabs {
            tabs.append(buildQueueTab())
        }

        // 3. Settings tab — last priority, first to be dropped
        if tabs.count < Self.maxTabs {
            tabs.append(CarPlaySettingsTemplate.build())
        }

        return tabs
    }

    private func buildQueueTab() -> CPListTemplate {
        let template = CPListTemplate(title: "Queue", sections: [])
        template.tabTitle = "Queue"
        template.tabImage = UIImage(systemName: "list.bullet")
        return template
    }
}
