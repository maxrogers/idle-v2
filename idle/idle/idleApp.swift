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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
