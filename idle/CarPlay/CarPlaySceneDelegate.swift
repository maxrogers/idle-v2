import CarPlay
import UIKit

/// Manages the CarPlay scene lifecycle and UI.
/// Supports both Path A (CPWindow for navigation entitlement) and Path B (templates only).
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var videoViewController: CarPlayVideoViewController?

    /// Track whether CarPlay is connected for auto-play decisions.
    static var isConnected = false

    // MARK: - Path A: Navigation Entitlement (CPWindow available)

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        Self.isConnected = true

        // Set up the video view controller as the window's root
        let videoVC = CarPlayVideoViewController()
        window.rootViewController = videoVC
        self.videoViewController = videoVC

        // Connect to PlaybackEngine
        videoVC.attachPlayer(PlaybackEngine.shared.player)

        // Set up template hierarchy
        setupTemplates(interfaceController: interfaceController)

        // Check for queued items
        checkForPendingPlayback()
    }

    // MARK: - Path B: Templates Only (no CPWindow)

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        Self.isConnected = true

        setupTemplates(interfaceController: interfaceController)
        checkForPendingPlayback()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.carWindow = nil
        self.videoViewController = nil
        Self.isConnected = false
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        self.carWindow = nil
        self.videoViewController = nil
        Self.isConnected = false
    }

    // MARK: - Template Setup

    private func setupTemplates(interfaceController: CPInterfaceController) {
        let queueTab = buildQueueTab()
        // Service tabs are added dynamically based on authenticated services
        var tabs: [CPTemplate] = [queueTab]

        let services = ServiceRegistry.shared.authenticatedServices
        for service in services {
            tabs.append(buildServiceTab(for: service))
        }

        let tabBar = CPTabBarTemplate(templates: tabs)
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    private func buildQueueTab() -> CPTemplate {
        let manager = QueueManager.shared

        var sections: [CPListSection] = []

        // Pending items
        if !manager.pendingItems.isEmpty {
            let items = manager.pendingItems.prefix(12).map { item in
                let listItem = CPListItem(
                    text: item.title,
                    detailText: item.source.rawValue.capitalized
                )
                listItem.handler = { [weak self] _, completion in
                    self?.playItem(item)
                    completion()
                }
                return listItem
            }
            sections.append(CPListSection(items: Array(items), header: "Up Next", sectionIndexTitle: nil))
        }

        // History items
        if !manager.historyItems.isEmpty {
            let items = manager.historyItems.prefix(8).map { item in
                let listItem = CPListItem(
                    text: item.title,
                    detailText: "Played"
                )
                listItem.handler = { [weak self] _, completion in
                    self?.playItem(item)
                    completion()
                }
                return listItem
            }
            sections.append(CPListSection(items: Array(items), header: "Recently Played", sectionIndexTitle: nil))
        }

        if sections.isEmpty {
            let emptyItem = CPListItem(text: "No videos queued", detailText: "Share a link from Safari to get started")
            sections.append(CPListSection(items: [emptyItem]))
        }

        let listTemplate = CPListTemplate(title: "Queue", sections: sections)
        listTemplate.tabTitle = "Queue"
        listTemplate.tabImage = UIImage(systemName: "list.bullet")
        return listTemplate
    }

    private func buildServiceTab(for service: VideoService) -> CPTemplate {
        let listTemplate = CPListTemplate(
            title: service.name,
            sections: [CPListSection(items: [
                CPListItem(text: "Loading...", detailText: nil)
            ])]
        )
        listTemplate.tabTitle = service.name
        listTemplate.tabImage = service.icon

        // Load categories asynchronously
        Task { @MainActor in
            do {
                let categories = try await service.fetchCategories()
                let items = categories.map { category in
                    let item = CPListItem(text: category.name, detailText: nil)
                    item.handler = { [weak self] _, completion in
                        self?.showCategoryItems(service: service, category: category)
                        completion()
                    }
                    return item
                }
                listTemplate.updateSections([CPListSection(items: items)])
            } catch {
                let errorItem = CPListItem(text: "Failed to load", detailText: error.localizedDescription)
                listTemplate.updateSections([CPListSection(items: [errorItem])])
            }
        }

        return listTemplate
    }

    // MARK: - Navigation

    private func showCategoryItems(service: VideoService, category: ContentCategory) {
        Task { @MainActor in
            do {
                let items = try await service.fetchItems(for: category)
                let listItems = items.prefix(12).map { videoItem in
                    let item = CPListItem(
                        text: videoItem.title,
                        detailText: nil
                    )
                    item.handler = { [weak self] _, completion in
                        self?.playFromService(service: service, item: videoItem)
                        completion()
                    }
                    return item
                }

                let template = CPListTemplate(
                    title: category.name,
                    sections: [CPListSection(items: listItems)]
                )
                interfaceController?.pushTemplate(template, animated: true, completion: nil)
            } catch {
                showError("Couldn't load \(category.name)")
            }
        }
    }

    // MARK: - Playback

    private func playItem(_ item: VideoItem) {
        guard IdleDetector.shared.isIdle else {
            showError("Video available when stopped")
            return
        }

        guard item.extractionStatus == .ready else {
            // Trigger extraction then play
            Task { @MainActor in
                await extractAndPlay(item)
            }
            return
        }
        PlaybackEngine.shared.play(item: item)
        QueueManager.shared.markAsPlayed(item)
    }

    private func playFromService(service: VideoService, item: VideoItem) {
        guard IdleDetector.shared.isIdle else {
            showError("Video available when stopped")
            return
        }

        Task { @MainActor in
            do {
                let stream = try await service.extractStream(for: item)
                item.streamURL = stream.url.absoluteString
                item.extractionStatus = .ready
                QueueManager.shared.addItem(item)
                PlaybackEngine.shared.play(item: item)
                QueueManager.shared.markAsPlayed(item)
            } catch {
                showError("Can't play this one — try a different video")
            }
        }
    }

    private func extractAndPlay(_ item: VideoItem) async {
        item.extractionStatus = .extracting
        do {
            let streams = try await ExtractionRouter.shared.extract(from: item.originalURL)
            guard let best = streams.first else {
                showError("No playable stream found")
                QueueManager.shared.markAsFailed(item)
                return
            }
            QueueManager.shared.markAsReady(item, streamURL: best.url.absoluteString)
            PlaybackEngine.shared.play(item: item)
            QueueManager.shared.markAsPlayed(item)
        } catch {
            showError("Can't play this one — try a direct video link")
            QueueManager.shared.markAsFailed(item)
        }
    }

    private func checkForPendingPlayback() {
        // Check share extension queue
        if let sharedURL = QueueManager.shared.checkForSharedURL() {
            let item = QueueManager.shared.addFromURL(sharedURL)
            Task { @MainActor in
                await extractAndPlay(item)
            }
            return
        }

        // Auto-play first pending item
        if let first = QueueManager.shared.pendingItems.first, first.extractionStatus == .ready {
            playItem(first)
        }
    }

    // MARK: - Error Display

    private func showError(_ message: String) {
        let action = CPAlertAction(title: "OK", style: .default, handler: { _ in })
        let alert = CPAlertTemplate(titleVariants: [message], actions: [action])
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}
