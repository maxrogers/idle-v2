import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(QueueManager.self) private var queueManager
    @Environment(PlaybackEngine.self) private var playbackEngine
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<QueueItem> { $0.playedAt == nil }, sort: [SortDescriptor(\.sortOrder)])
    private var queueItems: [QueueItem]

    @Query(filter: #Predicate<QueueItem> { $0.playedAt != nil }, sort: [SortDescriptor(\.playedAt, order: .reverse)])
    private var historyItems: [QueueItem]

    @State private var urlInput = ""
    @State private var isAddingURL = false
    @State private var isCarPlayConnected = false

    var body: some View {
        NavigationStack {
            ZStack {
                IdleTheme.background.ignoresSafeArea()

                List {
                    // URL entry section
                    Section {
                        HStack(spacing: 12) {
                            TextField("Paste a video URL...", text: $urlInput)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(IdleTheme.textPrimary)

                            if !urlInput.isEmpty {
                                Button {
                                    submitURL()
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(IdleTheme.amber)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Add to Queue")
                            .foregroundStyle(IdleTheme.textSecondary)
                    }

                    // Queue section
                    if !queueItems.isEmpty {
                        Section {
                            ForEach(queueItems) { item in
                                QueueItemRow(item: item) {
                                    playItem(item)
                                }
                            }
                            .onMove { from, to in
                                queueManager.moveQueueItem(from: from, to: to)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    queueManager.remove(queueItems[index])
                                }
                            }
                        } header: {
                            Text("Up Next")
                                .foregroundStyle(IdleTheme.textSecondary)
                        }
                    }

                    // History section
                    if !historyItems.isEmpty {
                        Section {
                            ForEach(historyItems.prefix(20)) { item in
                                QueueItemRow(item: item) {
                                    replayItem(item)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Recently Played")
                                    .foregroundStyle(IdleTheme.textSecondary)
                                Spacer()
                                Button("Clear") {
                                    queueManager.clearHistory()
                                }
                                .font(.caption)
                                .foregroundStyle(IdleTheme.textTertiary)
                            }
                        }
                    }

                    // Empty state
                    if queueItems.isEmpty && historyItems.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "list.bullet.rectangle.portrait")
                                        .font(.system(size: 36))
                                        .foregroundStyle(IdleTheme.textTertiary)
                                    Text("Queue is empty")
                                        .foregroundStyle(IdleTheme.textSecondary)
                                    Text("Paste a video URL above or share from any app")
                                        .font(IdleTheme.captionFont)
                                        .foregroundStyle(IdleTheme.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(queueItems.isEmpty ? .inactive : .active))
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            queueManager.modelContext = modelContext
        }
        .onReceive(NotificationCenter.default.publisher(for: .carPlayDidConnect)) { _ in
            isCarPlayConnected = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .carPlayDidDisconnect)) { _ in
            isCarPlayConnected = false
        }
    }

    // MARK: - Actions

    private func submitURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }

        queueManager.addToFront(
            urlString: url.absoluteString,
            title: nil,
            thumbnailURLString: nil,
            sourceService: "manual"
        )
        urlInput = ""

        if isCarPlayConnected {
            playItem(queueItems.first!)
        }
    }

    private func playItem(_ item: QueueItem) {
        guard let url = item.url else { return }
        queueManager.markPlayed(item)
        playbackEngine.play(url: url, title: item.title, thumbnailURL: item.thumbnailURL)
    }

    private func replayItem(_ item: QueueItem) {
        guard let url = item.url else { return }
        playbackEngine.play(url: url, title: item.title, thumbnailURL: item.thumbnailURL)
    }
}

// MARK: - Queue Item Row

struct QueueItemRow: View {
    let item: QueueItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail or placeholder
                Group {
                    if let thumbURL = item.thumbnailURL {
                        AsyncImage(url: thumbURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(IdleTheme.surfacePrimary)
                        }
                    } else {
                        ZStack {
                            Rectangle().fill(IdleTheme.surfacePrimary)
                            Image(systemName: "play.rectangle")
                                .foregroundStyle(IdleTheme.textTertiary)
                        }
                    }
                }
                .frame(width: 56, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title ?? item.urlString)
                        .lineLimit(2)
                        .foregroundStyle(IdleTheme.textPrimary)
                        .font(IdleTheme.bodyFont)

                    if let played = item.playedAt {
                        Text(played.formatted(.relative(presentation: .named)))
                            .font(IdleTheme.captionFont)
                            .foregroundStyle(IdleTheme.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "play.circle")
                    .foregroundStyle(IdleTheme.amber)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QueueView()
        .environment(QueueManager())
        .environment(PlaybackEngine())
        .modelContainer(for: QueueItem.self, inMemory: true)
}
