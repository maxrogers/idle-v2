import SwiftUI

@main
struct idleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    URLSchemeHandler.shared.handle(url: url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Pick up any URL queued by the Share Extension
                        if let sharedURL = QueueManager.shared.checkForSharedURL() {
                            URLSchemeHandler.shared.handle(url: URL(string: "idle://play?url=\(sharedURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sharedURL)")!)
                        }
                    }
                }
        }
    }
}
