import SwiftUI

struct PlexLibraryView: View {
    @State private var sections: [PlexLibrarySection] = []
    @State private var onDeckItems: [PlexMediaItem] = []
    @State private var recentItems: [PlexMediaItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var serverURL: URL? {
        guard let urlString = UserDefaults.standard.string(forKey: "plex_server_url") else { return nil }
        return URL(string: urlString)
    }

    private var token: String? {
        KeychainHelper.loadString(key: "plex_user_token")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IdleTheme.background.ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Plex")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await loadLibrary() }
        }
        .preferredColorScheme(.dark)
        .task { await loadLibrary() }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {

                // Continue Watching
                if !onDeckItems.isEmpty {
                    PlexMediaRow(
                        title: "Continue Watching",
                        items: onDeckItems,
                        thumbnailStyle: .wide
                    )
                }

                // Recently Added
                if !recentItems.isEmpty {
                    PlexMediaRow(
                        title: "Recently Added",
                        items: recentItems,
                        thumbnailStyle: .poster
                    )
                }

                // Library sections
                ForEach(sections) { section in
                    NavigationLink {
                        PlexSectionView(section: section)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(IdleTheme.titleFont)
                                    .foregroundStyle(IdleTheme.textPrimary)
                                Text(section.type.capitalized)
                                    .font(IdleTheme.captionFont)
                                    .foregroundStyle(IdleTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(IdleTheme.textTertiary)
                                .font(.caption)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(IdleTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(IdleTheme.amber)
                .scaleEffect(1.5)
            Text("Loading library…")
                .foregroundStyle(IdleTheme.textSecondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(IdleTheme.amber)
            Text(error)
                .foregroundStyle(IdleTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") { Task { await loadLibrary() } }
                .buttonStyle(.borderedProminent)
                .tint(IdleTheme.amber)
        }
        .padding()
    }

    // MARK: - Data Loading

    @MainActor
    private func loadLibrary() async {
        guard let serverURL, let token else {
            isLoading = false
            errorMessage = "Not connected to Plex. Please check your settings."
            return
        }

        isLoading = true
        errorMessage = nil

        async let sectionsTask = PlexAPI.shared.getLibrarySections(serverURL: serverURL, token: token)
        async let onDeckTask = PlexAPI.shared.getOnDeck(serverURL: serverURL, token: token)
        async let recentTask = PlexAPI.shared.getRecentlyAdded(serverURL: serverURL, token: token)

        do {
            let (newSections, newOnDeck, newRecent) = try await (sectionsTask, onDeckTask, recentTask)
            sections = newSections
            onDeckItems = Array(newOnDeck.prefix(20))
            recentItems = Array(newRecent.prefix(20))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    PlexLibraryView()
}
