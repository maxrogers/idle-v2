import Foundation
import SwiftData

/// Manages the persistent video queue and playback history.
@MainActor
final class QueueManager: ObservableObject {

    static let shared = QueueManager()

    @Published private(set) var pendingItems: [VideoItem] = []
    @Published private(set) var historyItems: [VideoItem] = []

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private init() {
        setupSwiftData()
        refresh()
    }

    // MARK: - Setup

    private func setupSwiftData() {
        do {
            let schema = Schema([VideoItem.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer?.mainContext
        } catch {
            print("[idle] SwiftData setup failed: \(error)")
        }
    }

    // MARK: - Public API

    func addItem(_ item: VideoItem) {
        modelContext?.insert(item)
        save()
        refresh()
    }

    func addFromURL(_ urlString: String, title: String? = nil, source: VideoSource = .generic) -> VideoItem {
        let item = VideoItem(
            title: title ?? urlString,
            originalURL: urlString,
            source: source
        )
        addItem(item)
        return item
    }

    func markAsReady(_ item: VideoItem, streamURL: String) {
        item.streamURL = streamURL
        item.extractionStatus = .ready
        save()
        refresh()
    }

    func markAsPlayed(_ item: VideoItem) {
        item.playedAt = Date()
        save()
        refresh()
    }

    func markAsFailed(_ item: VideoItem) {
        item.extractionStatus = .failed
        save()
        refresh()
    }

    func removeItem(_ item: VideoItem) {
        modelContext?.delete(item)
        save()
        refresh()
    }

    func clearHistory() {
        for item in historyItems {
            modelContext?.delete(item)
        }
        save()
        refresh()
    }

    // MARK: - Queries

    func refresh() {
        guard let context = modelContext else { return }

        // Pending: not yet played, sorted by added date
        let pendingDescriptor = FetchDescriptor<VideoItem>(
            predicate: #Predicate { $0.playedAt == nil },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )

        // History: played items, sorted by played date
        let historyDescriptor = FetchDescriptor<VideoItem>(
            predicate: #Predicate { $0.playedAt != nil },
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )

        do {
            pendingItems = try context.fetch(pendingDescriptor)
            historyItems = try context.fetch(historyDescriptor)
        } catch {
            print("[idle] Fetch failed: \(error)")
        }
    }

    // MARK: - Shared Container (for Share Extension)

    static let appGroupID = "group.com.idle.shared"
    static let sharedURLKey = "idle_shared_url"

    /// Check if the share extension has queued a URL.
    func checkForSharedURL() -> String? {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        guard let url = defaults?.string(forKey: Self.sharedURLKey) else { return nil }
        defaults?.removeObject(forKey: Self.sharedURLKey)
        return url
    }

    // MARK: - Private

    private func save() {
        try? modelContext?.save()
    }
}
