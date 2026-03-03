import SwiftUI

@main
struct idleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    URLSchemeHandler.shared.handle(url: url)
                }
        }
    }
}
