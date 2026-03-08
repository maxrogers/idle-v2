import UIKit
import UniformTypeIdentifiers

/// Share Extension entry point.
/// Accepts a URL from the share sheet, writes it to the shared app group,
/// then opens the main idle app via URL scheme to process and queue it.
class ShareViewController: UIViewController {

    private static let appGroupID = "group.com.steverogers.idle.shared"
    private static let sharedURLKey = "idle_shared_url"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extractURL()
    }

    private func extractURL() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            done()
            return
        }

        // Look for a URL attachment across all input items
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                // Prefer explicit URL type
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        let urlString: String?
                        if let url = data as? URL {
                            urlString = url.absoluteString
                        } else if let str = data as? String {
                            urlString = str
                        } else {
                            urlString = nil
                        }
                        DispatchQueue.main.async {
                            if let urlString {
                                self?.handOff(urlString: urlString)
                            } else {
                                self?.done()
                            }
                        }
                    }
                    return
                }
                // Fallback: plain text that looks like a URL
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        let urlString: String?
                        if let str = data as? String, str.hasPrefix("http") {
                            urlString = str
                        } else {
                            urlString = nil
                        }
                        DispatchQueue.main.async {
                            if let urlString {
                                self?.handOff(urlString: urlString)
                            } else {
                                self?.done()
                            }
                        }
                    }
                    return
                }
            }
        }

        done()
    }

    private func handOff(urlString: String) {
        // Save URL to shared app group so the main app can pick it up
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        defaults?.set(urlString, forKey: Self.sharedURLKey)
        defaults?.synchronize()

        // Open the main app — this brings idle to the foreground where it will
        // read the shared URL, extract the stream, and queue it for CarPlay
        let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let appURL = URL(string: "idle://play?url=\(encoded)")!
        openURL(appURL)

        done()
    }

    // UIViewController extension contexts can't call UIApplication.shared.open directly.
    // Use a selector-based workaround to open URLs from an extension.
    @objc private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = r.next
        }
    }

    private func done() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
