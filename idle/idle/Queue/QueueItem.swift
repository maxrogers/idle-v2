import Foundation
import SwiftData

@Model
final class QueueItem {
    var urlString: String
    var title: String?
    var thumbnailURLString: String?
    var addedAt: Date
    var playedAt: Date?
    var sourceService: String?
    var sortOrder: Int

    init(
        urlString: String,
        title: String? = nil,
        thumbnailURLString: String? = nil,
        addedAt: Date = .now,
        playedAt: Date? = nil,
        sourceService: String? = nil,
        sortOrder: Int = 0
    ) {
        self.urlString = urlString
        self.title = title
        self.thumbnailURLString = thumbnailURLString
        self.addedAt = addedAt
        self.playedAt = playedAt
        self.sourceService = sourceService
        self.sortOrder = sortOrder
    }

    var isInQueue: Bool { playedAt == nil }
    var isInHistory: Bool { playedAt != nil }

    var url: URL? { URL(string: urlString) }
    var thumbnailURL: URL? {
        guard let s = thumbnailURLString else { return nil }
        return URL(string: s)
    }
}
