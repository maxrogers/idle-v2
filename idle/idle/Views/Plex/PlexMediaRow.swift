import SwiftUI

enum ThumbnailStyle {
    case poster   // 2:3 ratio, for movies/shows
    case wide     // 16:9 ratio, for episodes/on deck
}

struct PlexMediaRow: View {
    let title: String
    let items: [PlexMediaItem]
    var thumbnailStyle: ThumbnailStyle = .poster

    private var thumbnailSize: CGSize {
        switch thumbnailStyle {
        case .poster: return CGSize(width: 110, height: 165)
        case .wide: return CGSize(width: 180, height: 101)
        }
    }

    private var serverURL: URL? {
        guard let s = UserDefaults.standard.string(forKey: "plex_server_url") else { return nil }
        return URL(string: s)
    }

    private var token: String? {
        KeychainHelper.loadString(key: "plex_user_token")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(IdleTheme.titleFont)
                .foregroundStyle(IdleTheme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            PlexDetailView(item: item)
                        } label: {
                            PlexThumbnailCard(
                                item: item,
                                size: thumbnailSize,
                                serverURL: serverURL,
                                token: token
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}

struct PlexThumbnailCard: View {
    let item: PlexMediaItem
    let size: CGSize
    let serverURL: URL?
    let token: String?

    private var thumbnailURL: URL? {
        guard let serverURL, let token, let thumb = item.thumb else { return nil }
        return PlexAPI.shared.thumbnailURL(
            serverURL: serverURL,
            thumbPath: thumb,
            token: token,
            width: Int(size.width * 2),
            height: Int(size.height * 2)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(IdleTheme.surfacePrimary)

                if let url = thumbnailURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: item.type == "movie" ? "film" : "tv")
                            .font(.title)
                            .foregroundStyle(IdleTheme.textTertiary)
                    }
                } else {
                    Image(systemName: item.type == "movie" ? "film" : "tv")
                        .font(.title)
                        .foregroundStyle(IdleTheme.textTertiary)
                }

                // Progress bar for items with watch progress
                if let offset = item.viewOffset, let duration = item.duration, duration > 0 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(height: 3)
                                Rectangle()
                                    .fill(IdleTheme.amber)
                                    .frame(
                                        width: geo.size.width * CGFloat(offset) / CGFloat(duration),
                                        height: 3
                                    )
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Title
            Text(item.title)
                .font(IdleTheme.captionFont)
                .foregroundStyle(IdleTheme.textSecondary)
                .lineLimit(2)
                .frame(width: size.width, alignment: .leading)
        }
        .frame(width: size.width)
    }
}
