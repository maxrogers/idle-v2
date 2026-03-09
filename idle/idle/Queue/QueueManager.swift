import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class QueueManager {
    var modelContext: ModelContext?

    // MARK: - Queue Operations

    func addToFront(urlString: String, title: String?, thumbnailURLString: String?, sourceService: String?) {
        guard let context = modelContext else { return }
        // Shift existing queue items down
        let existing = queueItems(in: context)
        for item in existing {
            item.sortOrder += 1
        }
        let newItem = QueueItem(
            urlString: urlString,
            title: title,
            thumbnailURLString: thumbnailURLString,
            sortOrder: 0,
            sourceService: sourceService
        )
        context.insert(newItem)
        try? context.save()
    }

    func markPlayed(_ item: QueueItem) {
        item.playedAt = .now
        try? modelContext?.save()
    }

    func remove(_ item: QueueItem) {
        modelContext?.delete(item)
        try? modelContext?.save()
    }

    func clearHistory() {
        guard let context = modelContext else { return }
        let history = historyItems(in: context)
        for item in history {
            context.delete(item)
        }
        try? context.save()
    }

    func moveQueueItem(from source: IndexSet, to destination: Int) {
        guard let context = modelContext else { return }
        var items = queueItems(in: context)
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        try? context.save()
    }

    // MARK: - Queries

    func queueItems(in context: ModelContext) -> [QueueItem] {
        let descriptor = FetchDescriptor<QueueItem>(
            predicate: #Predicate { $0.playedAt == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func historyItems(in context: ModelContext) -> [QueueItem] {
        let descriptor = FetchDescriptor<QueueItem>(
            predicate: #Predicate { $0.playedAt != nil },
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Shared Container (App Group)

    private let sharedDefaultsSuite = "group.com.steverogers.idle"
    private let pendingURLKey = "pendingQueueURL"

    func checkForPendingURLFromExtension() -> URL? {
        guard let defaults = UserDefaults(suiteName: sharedDefaultsSuite),
              let urlString = defaults.string(forKey: pendingURLKey),
              let url = URL(string: urlString) else { return nil }
        defaults.removeObject(forKey: pendingURLKey)
        return url
    }
}

// Convenience initializer ordering fix for SwiftData
extension QueueItem {
    convenience init(
        urlString: String,
        title: String?,
        thumbnailURLString: String?,
        sortOrder: Int,
        sourceService: String?
    ) {
        self.init(
            urlString: urlString,
            title: title,
            thumbnailURLString: thumbnailURLString,
            addedAt: .now,
            playedAt: nil,
            sourceService: sourceService,
            sortOrder: sortOrder
        )
    }
}
