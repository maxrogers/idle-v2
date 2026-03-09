import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let sharedSuite = "group.com.steverogers.idle"
    private let pendingURLKey = "pendingQueueURL"
    private let pendingTitleKey = "pendingQueueTitle"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extractURL()
    }

    private func extractURL() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            cancelWithError()
            return
        }

        // Try to find a URL in the attachments
        let urlType = UTType.url.identifier
        let webPageType = "public.url"

        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(urlType) {
                attachment.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.handleURL(url)
                        } else if let urlString = item as? String, let url = URL(string: urlString) {
                            self?.handleURL(url)
                        } else {
                            self?.cancelWithError()
                        }
                    }
                }
                return
            }

            if attachment.hasItemConformingToTypeIdentifier(webPageType) {
                attachment.loadItem(forTypeIdentifier: webPageType, options: nil) { [weak self] item, _ in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            self?.handleURL(url)
                        } else {
                            self?.cancelWithError()
                        }
                    }
                }
                return
            }
        }

        cancelWithError()
    }

    private func handleURL(_ url: URL) {
        // Write to shared App Group container
        if let defaults = UserDefaults(suiteName: sharedSuite) {
            defaults.set(url.absoluteString, forKey: pendingURLKey)
            defaults.synchronize()
        }

        // Open main app via URL scheme
        let idleURL = URL(string: "idle://queue/add?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!

        // Use openURL to hand off to main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(idleURL, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }

        // Complete the extension
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancelWithError() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
