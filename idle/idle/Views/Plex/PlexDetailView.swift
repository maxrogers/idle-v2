import SwiftUI

struct PlexDetailView: View {
    let item: PlexMediaItem

    @Environment(PlaybackEngine.self) private var playbackEngine
    @State private var children: [PlexMediaItem] = []
    @State private var isLoadingChildren = false
    @State private var isStartingPlayback = false
    @State private var errorMessage: String?

    private var serverURL: URL? {
        guard let s = UserDefaults.standard.string(forKey: "plex_server_url") else { return nil }
        return URL(string: s)
    }

    private var token: String? {
        KeychainHelper.loadString(key: "plex_user_token")
    }

    private var isPlayable: Bool {
        item.type == "movie" || item.type == "episode"
    }

    var body: some View {
        ZStack {
            IdleTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Hero backdrop
                    heroImage

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title.bold())
                            .foregroundStyle(IdleTheme.textPrimary)

                        if let year = item.year {
                            Text(String(year))
                                .font(IdleTheme.captionFont)
                                .foregroundStyle(IdleTheme.textTertiary)
                        }

                        if let summary = item.summary, !summary.isEmpty {
                            Text(summary)
                                .font(IdleTheme.bodyFont)
                                .foregroundStyle(IdleTheme.textSecondary)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.horizontal)

                    // Play button (movies / episodes)
                    if isPlayable {
                        Button {
                            Task { await startPlayback() }
                        } label: {
                            HStack(spacing: 10) {
                                if isStartingPlayback {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(isStartingPlayback ? "Loading…" : "Play")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(IdleTheme.amber)
                        .padding(.horizontal)
                        .disabled(isStartingPlayback)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(IdleTheme.captionFont)
                            .padding(.horizontal)
                    }

                    // Children (seasons for shows, episodes for seasons)
                    if !children.isEmpty {
                        childrenList
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle(item.type == "show" ? item.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task {
            if item.type == "show" || item.type == "season" {
                await loadChildren()
            }
        }
    }

    // MARK: - Subviews

    private var heroImage: some View {
        ZStack(alignment: .bottomLeading) {
            if let serverURL, let token, let artPath = item.art ?? item.thumb {
                let artURL = PlexAPI.shared.thumbnailURL(
                    serverURL: serverURL,
                    thumbPath: artPath,
                    token: token,
                    width: 800,
                    height: 450
                )
                AsyncImage(url: artURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(IdleTheme.surfacePrimary)
                        .aspectRatio(16/9, contentMode: .fill)
                }
            } else {
                Rectangle()
                    .fill(IdleTheme.surfacePrimary)
                    .aspectRatio(16/9, contentMode: .fill)
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, IdleTheme.background.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var childrenList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.type == "show" ? "Seasons" : "Episodes")
                .font(IdleTheme.titleFont)
                .foregroundStyle(IdleTheme.textPrimary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if isLoadingChildren {
                HStack { Spacer(); ProgressView().tint(IdleTheme.amber); Spacer() }
                    .padding()
            } else {
                ForEach(children) { child in
                    NavigationLink {
                        PlexDetailView(item: child)
                    } label: {
                        PlexChildRow(item: child, serverURL: serverURL, token: token)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(IdleTheme.separator)
                        .padding(.leading, 70)
                }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func startPlayback() async {
        guard let serverURL, let token else {
            errorMessage = "Not connected to Plex"
            return
        }
        isStartingPlayback = true
        errorMessage = nil
        do {
            let partKey = try await PlexAPI.shared.getPartKey(
                serverURL: serverURL,
                itemKey: item.key,
                token: token
            )
            var components = URLComponents(url: serverURL.appendingPathComponent(String(partKey.dropFirst())), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "X-Plex-Token", value: token)]
            if let playURL = components.url {
                let thumbURL: URL? = item.thumb.flatMap {
                    PlexAPI.shared.thumbnailURL(serverURL: serverURL, thumbPath: $0, token: token)
                }
                playbackEngine.play(url: playURL, title: item.title, thumbnailURL: thumbURL)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isStartingPlayback = false
    }

    @MainActor
    private func loadChildren() async {
        guard let serverURL, let token else { return }
        isLoadingChildren = true
        do {
            children = try await PlexAPI.shared.getChildren(
                serverURL: serverURL,
                itemKey: item.key,
                token: token
            )
        } catch {
            // Silently fail — detail view is still useful without children
        }
        isLoadingChildren = false
    }
}

// MARK: - Child Row

struct PlexChildRow: View {
    let item: PlexMediaItem
    let serverURL: URL?
    let token: String?

    private var thumbnailURL: URL? {
        guard let serverURL, let token, let thumb = item.thumb else { return nil }
        return PlexAPI.shared.thumbnailURL(serverURL: serverURL, thumbPath: thumb, token: token, width: 160, height: 90)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(IdleTheme.surfacePrimary)
                if let url = thumbnailURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "tv").foregroundStyle(IdleTheme.textTertiary)
                    }
                } else {
                    Image(systemName: "tv").foregroundStyle(IdleTheme.textTertiary)
                }
            }
            .frame(width: 80, height: 45)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .foregroundStyle(IdleTheme.textPrimary)
                    .font(IdleTheme.bodyFont)
                    .lineLimit(2)

                if let duration = item.duration {
                    Text(formatDuration(duration))
                        .font(IdleTheme.captionFont)
                        .foregroundStyle(IdleTheme.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(IdleTheme.textTertiary)
                .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Section Browse View

struct PlexSectionView: View {
    let section: PlexLibrarySection

    @State private var items: [PlexMediaItem] = []
    @State private var isLoading = true

    private var serverURL: URL? {
        guard let s = UserDefaults.standard.string(forKey: "plex_server_url") else { return nil }
        return URL(string: s)
    }
    private var token: String? { KeychainHelper.loadString(key: "plex_user_token") }

    var body: some View {
        ZStack {
            IdleTheme.background.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(IdleTheme.amber)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)],
                        spacing: 16
                    ) {
                        ForEach(items) { item in
                            NavigationLink {
                                PlexDetailView(item: item)
                            } label: {
                                PlexThumbnailCard(
                                    item: item,
                                    size: CGSize(width: 130, height: 195),
                                    serverURL: serverURL,
                                    token: token
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .task { await loadContent() }
    }

    @MainActor
    private func loadContent() async {
        guard let serverURL, let token else { isLoading = false; return }
        do {
            items = try await PlexAPI.shared.getSectionContent(
                serverURL: serverURL,
                sectionKey: section.key,
                token: token
            )
        } catch { }
        isLoading = false
    }
}
