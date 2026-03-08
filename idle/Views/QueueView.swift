import SwiftUI

struct QueueView: View {
    @ObservedObject private var queue = QueueManager.shared
    @ObservedObject private var playback = PlaybackEngine.shared
    @State private var showNowPlaying = false
    @State private var showAddURL = false
    @State private var urlInput = ""
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.idleSurface.ignoresSafeArea()

                VStack(spacing: 0) {
                    if queue.pendingItems.isEmpty && queue.historyItems.isEmpty && playback.currentItem == nil {
                        emptyState
                            .frame(maxHeight: .infinity)
                    } else {
                        itemsList
                    }

                    if playback.currentItem != nil {
                        NowPlayingBar(showSheet: $showNowPlaying)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("IdleLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        Text("idle")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if playback.isPlaying {
                        nowPlayingBadge
                    } else {
                        Button {
                            // Pre-fill with clipboard URL if available
                            if let clip = UIPasteboard.general.string, clip.hasPrefix("http") {
                                urlInput = clip
                            }
                            showAddURL = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.idleAmber)
                        }
                    }
                }
            }
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingSheet()
            }
            .sheet(isPresented: $showAddURL) {
                addURLSheet
            }
        }
    }

    // MARK: - Add URL Sheet

    private var addURLSheet: some View {
        NavigationStack {
            ZStack {
                Color.idleSurface.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Video URL")
                            .font(.idleCaption)
                            .foregroundColor(.gray)

                        TextField("https://", text: $urlInput)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(Color.idleCard)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)

                    Text("Paste any video URL — YouTube, direct video files, or other supported sources.")
                        .font(.idleCaption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Add Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        urlInput = ""
                        showAddURL = false
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView().tint(.idleAmber)
                    } else {
                        Button("Add") {
                            addURL()
                        }
                        .foregroundColor(.idleAmber)
                        .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func addURL() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isAdding = true

        let item = QueueManager.shared.addFromURL(trimmed)
        Task { @MainActor in
            do {
                let streams = try await ExtractionRouter.shared.extract(from: trimmed)
                if let best = streams.first {
                    QueueManager.shared.markAsReady(item, streamURL: best.url.absoluteString)
                }
            } catch {
                QueueManager.shared.markAsFailed(item)
            }
            isAdding = false
            urlInput = ""
            showAddURL = false
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

// MARK: - Now Playing Bar

struct NowPlayingBar: View {
    @ObservedObject private var playback = PlaybackEngine.shared
    @Binding var showSheet: Bool

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                // Source icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.idleCard)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: playback.currentItem.map { iconForSource($0.source) } ?? "play.fill")
                            .foregroundColor(.idleAmber)
                            .font(.system(size: 14))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(playback.currentItem?.title ?? "Now Playing")
                        .font(.idleBody)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if CarPlaySceneDelegate.isConnected {
                            Circle()
                                .fill(Color.idleAmber)
                                .frame(width: 6, height: 6)
                            Text("CarPlay")
                                .font(.idleCaption)
                                .foregroundColor(.idleAmber)
                        } else {
                            Text(playback.currentItem?.source.rawValue.capitalized ?? "")
                                .font(.idleCaption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                // Play/Pause
                Button {
                    playback.togglePlayPause()
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Stop
                Button {
                    playback.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.idleCard)
        }
        .buttonStyle(.plain)
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

// MARK: - Now Playing Sheet

struct NowPlayingSheet: View {
    @ObservedObject private var playback = PlaybackEngine.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.idleSurface.ignoresSafeArea()

            VStack(spacing: 32) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Spacer()

                // Video icon
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.idleCard)
                    .frame(width: 200, height: 130)
                    .overlay {
                        Image(systemName: "play.tv")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(.idleAmber)
                    }

                // Title & Source
                VStack(spacing: 8) {
                    Text(playback.currentItem?.title ?? "Not Playing")
                        .font(.idleTitle)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    HStack(spacing: 6) {
                        if CarPlaySceneDelegate.isConnected {
                            Circle()
                                .fill(Color.idleAmber)
                                .frame(width: 8, height: 8)
                            Text("Playing on CarPlay")
                                .font(.idleBody)
                                .foregroundColor(.idleAmber)
                        } else {
                            Text(playback.currentItem?.source.rawValue.capitalized ?? "")
                                .font(.idleBody)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Scrubber
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { playback.currentTime },
                            set: { playback.seek(to: $0) }
                        ),
                        in: 0...max(playback.duration, 1)
                    )
                    .tint(.idleAmber)

                    HStack {
                        Text(formatTime(playback.currentTime))
                            .font(.idleCaption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(formatTime(playback.duration))
                            .font(.idleCaption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 24)

                // Transport Controls
                HStack(spacing: 40) {
                    Button {
                        playback.seek(to: max(0, playback.currentTime - 15))
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    Button {
                        playback.togglePlayPause()
                    } label: {
                        Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.idleAmber)
                    }

                    Button {
                        playback.seek(to: playback.currentTime + 15)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                // Stop button
                Button {
                    playback.stop()
                    dismiss()
                } label: {
                    Text("Stop Playback")
                        .font(.idleBody)
                        .foregroundColor(.red)
                }
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
