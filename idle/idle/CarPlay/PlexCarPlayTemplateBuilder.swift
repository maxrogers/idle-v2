import CarPlay
import UIKit

/// Builds and populates CPListTemplate sections for the Plex CarPlay tab.
enum PlexCarPlayTemplateBuilder {

    private static var serverURL: URL? {
        guard let s = UserDefaults.standard.string(forKey: "plex_server_url") else { return nil }
        return URL(string: s)
    }

    private static var token: String? {
        KeychainHelper.loadString(key: "plex_user_token")
    }

    // MARK: - Populate root template

    @MainActor
    static func populate(
        template: CPListTemplate,
        interfaceController: CPInterfaceController
    ) async {
        guard let serverURL, let token else {
            template.updateSections([notAuthenticatedSection()])
            return
        }

        async let onDeckTask = try? PlexAPI.shared.getOnDeck(serverURL: serverURL, token: token)
        async let recentTask = try? PlexAPI.shared.getRecentlyAdded(serverURL: serverURL, token: token)
        async let sectionsTask = try? PlexAPI.shared.getLibrarySections(serverURL: serverURL, token: token)

        let (onDeck, recent, sections) = await (onDeckTask, recentTask, sectionsTask)

        var cpSections: [CPListSection] = []

        // Continue Watching
        if let onDeck, !onDeck.isEmpty {
            let items = await buildMediaItems(
                onDeck.prefix(10).map { $0 },
                serverURL: serverURL,
                token: token,
                interfaceController: interfaceController
            )
            cpSections.append(CPListSection(items: items, header: "Continue Watching", sectionIndexTitle: nil))
        }

        // Recently Added
        if let recent, !recent.isEmpty {
            let items = await buildMediaItems(
                recent.prefix(10).map { $0 },
                serverURL: serverURL,
                token: token,
                interfaceController: interfaceController
            )
            cpSections.append(CPListSection(items: items, header: "Recently Added", sectionIndexTitle: nil))
        }

        // Library sections
        if let sections, !sections.isEmpty {
            let sectionItems: [CPListItem] = sections.map { section in
                let item = CPListItem(
                    text: section.title,
                    detailText: section.type.capitalized
                )
                item.handler = { [weak interfaceController] _, completion in
                    Task { @MainActor in
                        await pushSectionBrowser(
                            section: section,
                            interfaceController: interfaceController,
                            serverURL: serverURL,
                            token: token
                        )
                    }
                    completion()
                }
                return item
            }
            cpSections.append(CPListSection(items: sectionItems, header: "Libraries", sectionIndexTitle: nil))
        }

        if cpSections.isEmpty {
            cpSections = [emptySection()]
        }

        template.updateSections(cpSections)
    }

    // MARK: - Section Browser

    @MainActor
    static func pushSectionBrowser(
        section: PlexLibrarySection,
        interfaceController: CPInterfaceController?,
        serverURL: URL,
        token: String
    ) async {
        let template = CPListTemplate(title: section.title, sections: [
            CPListSection(items: [loadingItem("Loading \(section.title)…")], header: nil, sectionIndexTitle: nil)
        ])

        interfaceController?.pushTemplate(template, animated: true, completion: nil)

        do {
            let items = try await PlexAPI.shared.getSectionContent(serverURL: serverURL, sectionKey: section.key, token: token)
            let cpItems = await buildMediaItems(items.prefix(30).map { $0 }, serverURL: serverURL, token: token, interfaceController: interfaceController)
            template.updateSections([CPListSection(items: cpItems, header: section.title, sectionIndexTitle: nil)])
        } catch {
            template.updateSections([CPListSection(items: [errorItem(error.localizedDescription)], header: nil, sectionIndexTitle: nil)])
        }
    }

    // MARK: - Item builders

    @MainActor
    static func buildMediaItems(
        _ mediaItems: [PlexMediaItem],
        serverURL: URL,
        token: String,
        interfaceController: CPInterfaceController?
    ) async -> [CPListItem] {
        var cpItems: [CPListItem] = []

        for mediaItem in mediaItems {
            let cpItem = CPListItem(
                text: mediaItem.title,
                detailText: mediaItem.year.map { String($0) }
            )

            // Load thumbnail asynchronously
            if let thumbPath = mediaItem.thumb {
                let thumbURL = PlexAPI.shared.thumbnailURL(
                    serverURL: serverURL,
                    thumbPath: thumbPath,
                    token: token,
                    width: 180,
                    height: 100
                )
                if let image = await CarPlayImageLoader.shared.load(url: thumbURL) {
                    cpItem.setImage(image)
                }
            }

            cpItem.handler = { [weak interfaceController] _, completion in
                Task { @MainActor in
                    await handleItemTap(
                        mediaItem,
                        interfaceController: interfaceController,
                        serverURL: serverURL,
                        token: token
                    )
                }
                completion()
            }
            cpItems.append(cpItem)
        }
        return cpItems
    }

    @MainActor
    private static func handleItemTap(
        _ item: PlexMediaItem,
        interfaceController: CPInterfaceController?,
        serverURL: URL,
        token: String
    ) async {
        switch item.type {
        case "movie", "episode":
            await startPlayback(item: item, serverURL: serverURL, token: token)
        case "show":
            await pushChildTemplate(
                title: item.title,
                itemKey: item.key,
                serverURL: serverURL,
                token: token,
                interfaceController: interfaceController
            )
        case "season":
            await pushChildTemplate(
                title: item.title,
                itemKey: item.key,
                serverURL: serverURL,
                token: token,
                interfaceController: interfaceController
            )
        default:
            break
        }
    }

    @MainActor
    private static func pushChildTemplate(
        title: String,
        itemKey: String,
        serverURL: URL,
        token: String,
        interfaceController: CPInterfaceController?
    ) async {
        let template = CPListTemplate(title: title, sections: [
            CPListSection(items: [loadingItem("Loading…")], header: nil, sectionIndexTitle: nil)
        ])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)

        do {
            let children = try await PlexAPI.shared.getChildren(serverURL: serverURL, itemKey: itemKey, token: token)
            let cpItems = await buildMediaItems(children, serverURL: serverURL, token: token, interfaceController: interfaceController)
            template.updateSections([CPListSection(items: cpItems, header: title, sectionIndexTitle: nil)])
        } catch {
            template.updateSections([CPListSection(items: [errorItem(error.localizedDescription)], header: nil, sectionIndexTitle: nil)])
        }
    }

    @MainActor
    private static func startPlayback(item: PlexMediaItem, serverURL: URL, token: String) async {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        do {
            let partKey = try await PlexAPI.shared.getPartKey(serverURL: serverURL, itemKey: item.key, token: token)
            var components = URLComponents(url: serverURL.appendingPathComponent(String(partKey.dropFirst())), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "X-Plex-Token", value: token)]
            if let url = components.url {
                let thumbURL: URL? = item.thumb.flatMap {
                    PlexAPI.shared.thumbnailURL(serverURL: serverURL, thumbPath: $0, token: token)
                }
                appDelegate.playbackEngine.play(url: url, title: item.title, thumbnailURL: thumbURL)
            }
        } catch {
            // Surface error to CarPlay UI
        }
    }

    // MARK: - Helper Items

    private static func loadingItem(_ text: String) -> CPListItem {
        let item = CPListItem(text: text, detailText: nil)
        item.handler = { _, completion in completion() }
        return item
    }

    private static func errorItem(_ text: String) -> CPListItem {
        let item = CPListItem(text: "Error", detailText: text)
        item.handler = { _, completion in completion() }
        return item
    }

    private static func notAuthenticatedSection() -> CPListSection {
        let item = CPListItem(text: "Connect Plex on your iPhone", detailText: "Open idle on your iPhone to sign in")
        item.handler = { _, completion in completion() }
        return CPListSection(items: [item], header: nil, sectionIndexTitle: nil)
    }

    private static func emptySection() -> CPListSection {
        let item = CPListItem(text: "No content found", detailText: "Your Plex library appears to be empty")
        item.handler = { _, completion in completion() }
        return CPListSection(items: [item], header: nil, sectionIndexTitle: nil)
    }
}
