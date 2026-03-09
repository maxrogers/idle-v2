//
//  idleApp.swift
//  idle
//
//  Created by Steve Rogers on 3/8/26.
//

import SwiftUI
import SwiftData

@main
struct idleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([QueueItem.self])
        // Explicitly store in the app's private Application Support directory.
        // Without a URL, SwiftData resolves to the App Group container which
        // lacks an Application Support subdirectory, causing a 30s startup delay.
        let appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupportURL.appendingPathComponent("idle.store")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appDelegate.serviceRegistry)
                .environment(appDelegate.queueManager)
                .environment(appDelegate.playbackEngine)
                .onOpenURL { url in
                    URLSchemeHandler.handle(url, appDelegate: appDelegate)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
