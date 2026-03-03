import SwiftUI

struct QueueView: View {
    @ObservedObject private var queue = QueueManager.shared
    @ObservedObject private var playback = PlaybackEngine.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.idleSurface.ignoresSafeArea()

                if queue.pendingItems.isEmpty && queue.historyItems.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
            }
            .navigationTitle("idle")
            .toolbar {
                if playback.isPlaying {
                    ToolbarItem(placement: .topBarTrailing) {
                        nowPlayingBadge
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.idleAmber)

            Text("Share a video to get started")
                .font(.idleHeadline)
                .foregroundColor(.white)

            Text("Tap the share button in Safari or any app,\nthen choose \"idle\" to send it to CarPlay.")
                .font(.idleBody)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        List {
            if !queue.pendingItems.isEmpty {
                Section("Up Next") {
                    ForEach(queue.pendingItems, id: \.id) { item in
                        VideoItemRow(item: item)
                            .swipeActions {
                                Button(role: .destructive) {
                                    queue.removeItem(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if !queue.historyItems.isEmpty {
                Section("Recently Played") {
                    ForEach(queue.historyItems, id: \.id) { item in
                        VideoItemRow(item: item)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Now Playing Badge

    private var nowPlayingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.idleAmber)
                .frame(width: 8, height: 8)

            Text("CarPlay")
                .font(.idleCaption)
                .foregroundColor(.idleAmber)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.idleAmber.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Video Item Row

struct VideoItemRow: View {
    let item: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.idleCard)
                .frame(width: 64, height: 40)
                .overlay {
                    Image(systemName: iconForSource(item.source))
                        .foregroundColor(.idleAmberMuted)
                        .font(.system(size: 16))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.idleBody)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(item.source.rawValue.capitalized)
                    .font(.idleCaption)
                    .foregroundColor(.gray)
            }

            Spacer()

            statusIndicator
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.idleSurface)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch item.extractionStatus {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.gray)
        case .extracting:
            ProgressView()
                .tint(.idleAmber)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.idleAmber)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
        }
    }

    private func iconForSource(_ source: VideoSource) -> String {
        switch source {
        case .youtube: return "play.rectangle.fill"
        case .plex: return "play.rectangle.on.rectangle"
        case .generic: return "globe"
        case .directURL: return "link"
        }
    }
}
