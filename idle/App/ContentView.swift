import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .queue

    enum Tab {
        case queue
        case services
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            QueueView()
                .tabItem {
                    Label("Queue", systemImage: "list.bullet")
                }
                .tag(Tab.queue)

            ServicesView()
                .tabItem {
                    Label("Services", systemImage: "play.square.stack")
                }
                .tag(Tab.services)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .tint(Color.idleAmber)
    }
}
