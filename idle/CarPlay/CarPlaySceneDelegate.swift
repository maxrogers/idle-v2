import CarPlay
import UIKit

/// Manages the CarPlay scene lifecycle and UI.
/// Uses the audio entitlement with CPNowPlayingTemplate + AirPlay video routing.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?

    /// Track whether CarPlay is connected for auto-play decisions.
    static var isConnected = false

    // MARK: - Scene Lifecycle (Audio App — Templates Only)

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        Self.isConnected = true

        setupTemplates(interfaceController: interfaceController)
        checkForPendingPlayback()

        // Observe auth state changes so CarPlay tabs update when user configures a service
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleServiceAuthChanged),
            name: .plexServiceAuthChanged,
            object: nil
        )
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        Self.isConnected = false
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleServiceAuthChanged() {
        guard let interfaceController else { return }
        setupTemplates(interfaceController: interfaceController)
    }

    // MARK: - Template Setup

    private func setupTemplates(interfaceController: CPInterfaceController) {
        let queueTab = buildQueueTab()

        // Audio apps only allow CPListTemplate and CPGridTemplate as tab roots.
        // CPNowPlayingTemplate must be pushed onto a tab's navigation stack, not used as a tab root.
        var tabs: [CPTemplate] = [queueTab]

        // Register as now-playing observer for up-next/album-artist button taps
        CPNowPlayingTemplate.shared.add(self)

        // Service tabs appear only when authenticated
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

        // For Plex, show watchlist; for others, show categories
        Task { @MainActor in
            do {
                if let plexService = service as? PlexService {
                    let watchlistItems = try await plexService.fetchWatchlistItems()
                    if watchlistItems.isEmpty {
                        let emptyItem = CPListItem(text: "Watchlist empty", detailText: "Add items at plex.tv")
                        listTemplate.updateSections([CPListSection(items: [emptyItem])])
                    } else {
                        let items = watchlistItems.map { videoItem in
                            let item = CPListItem(
                                text: videoItem.title,
                                detailText: videoItem.streamURL != nil ? nil : "Not on server"
                            )
                            if videoItem.streamURL != nil {
                                item.handler = { [weak self] _, completion in
                                    self?.playFromService(service: service, item: videoItem)
                                    completion()
                                }
                            }
                            return item
                        }
                        listTemplate.updateSections([CPListSection(items: items, header: "Watchlist", sectionIndexTitle: nil)])
                    }
                } else {
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
                }
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
        pushNowPlaying()
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
                pushNowPlaying()
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
            pushNowPlaying()
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

    // MARK: - Now Playing

    /// Push the system Now Playing template after starting playback.
    private func pushNowPlaying() {
        guard let interfaceController else { return }
        let nowPlaying = CPNowPlayingTemplate.shared

        // Only push if not already the top template
        if interfaceController.topTemplate !== nowPlaying {
            interfaceController.pushTemplate(nowPlaying, animated: true, completion: nil)
        }
    }

    // MARK: - Error Display

    private func showError(_ message: String) {
        let action = CPAlertAction(title: "OK", style: .default, handler: { _ in })
        let alert = CPAlertTemplate(titleVariants: [message], actions: [action])
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}

// MARK: - CPNowPlayingTemplateObserver

extension CarPlaySceneDelegate: @preconcurrency CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        // Show the queue when user taps "Up Next"
        let queueTab = buildQueueTab()
        interfaceController?.pushTemplate(queueTab, animated: true, completion: nil)
    }

    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        // Show source info for current item
        guard let currentItem = PlaybackEngine.shared.currentItem else { return }
        let detailItem = CPListItem(
            text: currentItem.title,
            detailText: currentItem.source.rawValue.capitalized
        )
        let detail = CPListTemplate(
            title: currentItem.source.rawValue.capitalized,
            sections: [CPListSection(items: [detailItem])]
        )
        interfaceController?.pushTemplate(detail, animated: true, completion: nil)
    }
}
