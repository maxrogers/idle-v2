import SwiftUI

@main
struct idleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let t = Date()
        print("[idle] ⏱ App.init start")
        print("[idle] ⏱ App.init done \(Date().timeIntervalSince(t) * 1000)ms")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    print("[idle] ⏱ ContentView appeared")
                }
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
