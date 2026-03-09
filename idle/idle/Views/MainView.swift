import SwiftUI

struct MainView: View {
    @Environment(ServiceRegistry.self) private var serviceRegistry
    @Environment(QueueManager.self) private var queueManager
    @Environment(PlaybackEngine.self) private var playbackEngine

    @State private var selectedTab: Tab = .services
    @State private var isCarPlayConnected = false
    @State private var showPlayer = false

    enum Tab {
        case services, queue, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ServicesView()
                .tabItem {
                    Label("Services", systemImage: "square.grid.2x2")
                }
                .tag(Tab.services)

            QueueView()
                .tabItem {
                    Label("Queue", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(Tab.queue)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .idleBackground()
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .environment(playbackEngine)
        }
        .onChange(of: playbackEngine.isPlaying) { _, isPlaying in
            if isPlaying && !showPlayer {
                showPlayer = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .carPlayDidConnect)) { _ in
            isCarPlayConnected = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .carPlayDidDisconnect)) { _ in
            isCarPlayConnected = false
        }
    }
}

#Preview {
    MainView()
        .environment(ServiceRegistry())
        .environment(QueueManager())
        .environment(PlaybackEngine())
}
