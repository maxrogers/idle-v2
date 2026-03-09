import UIKit

/// Async image loader for CarPlay templates with NSCache backing.
final class CarPlayImageLoader {

    static let shared = CarPlayImageLoader()
    private let cache = NSCache<NSURL, UIImage>()
    private init() {
        cache.countLimit = 100
    }

    func load(url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) { return cached }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }

        // Resize to CarPlay-appropriate dimensions
        let targetSize = CGSize(width: 90, height: 50)
        let resized = image.resized(to: targetSize)
        cache.setObject(resized, forKey: key)
        return resized
    }
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
