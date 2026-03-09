import SwiftUI

struct SettingsView: View {
    @Environment(ServiceRegistry.self) private var serviceRegistry
    @State private var isCarPlayConnected = false

    var body: some View {
        NavigationStack {
            ZStack {
                IdleTheme.background.ignoresSafeArea()

                List {
                    // CarPlay status
                    Section {
                        HStack {
                            Label("CarPlay", systemImage: "car.fill")
                                .foregroundStyle(IdleTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isCarPlayConnected ? Color.green : IdleTheme.textTertiary)
                                    .frame(width: 8, height: 8)
                                Text(isCarPlayConnected ? "Connected" : "Not connected")
                                    .font(IdleTheme.captionFont)
                                    .foregroundStyle(isCarPlayConnected ? .green : IdleTheme.textTertiary)
                            }
                        }
                    } header: {
                        Text("Status")
                            .foregroundStyle(IdleTheme.textSecondary)
                    }

                    // Service-specific settings
                    if !serviceRegistry.services.isEmpty {
                        Section {
                            ForEach(serviceRegistry.services, id: \.id) { service in
                                NavigationLink {
                                    ServiceSettingsView(service: service)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: service.iconSystemName)
                                            .foregroundStyle(IdleTheme.amber)
                                            .frame(width: 28)
                                        Text(service.displayName)
                                            .foregroundStyle(IdleTheme.textPrimary)
                                    }
                                }
                            }
                        } header: {
                            Text("Services")
                                .foregroundStyle(IdleTheme.textSecondary)
                        }
                    }

                    // App info
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(IdleTheme.textPrimary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(IdleTheme.textTertiary)
                        }
                    } header: {
                        Text("About")
                            .foregroundStyle(IdleTheme.textSecondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .carPlayDidConnect)) { _ in
            isCarPlayConnected = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .carPlayDidDisconnect)) { _ in
            isCarPlayConnected = false
        }
    }
}

// MARK: - Per-service settings placeholder

struct ServiceSettingsView: View {
    let service: any VideoServicePlugin

    var body: some View {
        ZStack {
            IdleTheme.background.ignoresSafeArea()
            Text("\(service.displayName) settings coming soon")
                .foregroundStyle(IdleTheme.textSecondary)
        }
        .navigationTitle(service.displayName)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .environment(ServiceRegistry())
}
