import Foundation
import SwiftData

/// The source type of a video item.
enum VideoSource: String, Codable {
    case youtube
    case plex
    case generic
    case directURL
}

/// Status of stream extraction for a queued item.
enum ExtractionStatus: String, Codable {
    case pending
    case extracting
    case ready
    case failed
}

/// A video item in the queue or from a service browse.
@Model
final class VideoItem {
    var id: String
    var title: String
    var originalURL: String
    var streamURL: String?
    var thumbnailURL: String?
    var source: VideoSource
    var extractionStatus: ExtractionStatus
    var addedAt: Date
    var playedAt: Date?
    var durationSeconds: Double?

    init(
        title: String,
        originalURL: String,
        source: VideoSource,
        thumbnailURL: String? = nil,
        streamURL: String? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.originalURL = originalURL
        self.source = source
        self.thumbnailURL = thumbnailURL
        self.streamURL = streamURL
        self.extractionStatus = streamURL != nil ? .ready : .pending
        self.addedAt = Date()
    }
}
