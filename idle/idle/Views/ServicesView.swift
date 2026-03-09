import SwiftUI

struct ServicesView: View {
    @Environment(ServiceRegistry.self) private var serviceRegistry
    @State private var showAddService = false

    var body: some View {
        NavigationStack {
            ZStack {
                IdleTheme.background.ignoresSafeArea()

                if serviceRegistry.services.isEmpty {
                    emptyState
                } else {
                    servicesList
                }
            }
            .navigationTitle("Services")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddService = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(IdleTheme.amber)
                    }
                }
            }
            .sheet(isPresented: $showAddService) {
                AddServiceSheet()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(IdleTheme.textTertiary)

            Text("No services added")
                .font(IdleTheme.titleFont)
                .foregroundStyle(IdleTheme.textSecondary)

            Text("Tap + to add a service like Plex")
                .font(IdleTheme.bodyFont)
                .foregroundStyle(IdleTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var servicesList: some View {
        @Bindable var registry = serviceRegistry

        return List {
            Section {
                ForEach(serviceRegistry.serviceOrder, id: \.self) { serviceID in
                    if let service = serviceRegistry.services.first(where: { $0.id == serviceID }) {
                        ServiceRow(service: service, registry: serviceRegistry)
                    }
                }
                .onMove { from, to in
                    serviceRegistry.moveService(from: from, to: to)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { serviceRegistry.serviceOrder[$0] }
                    for id in ids {
                        serviceRegistry.setEnabled(id, enabled: false)
                    }
                }
            } footer: {
                Text("Drag to reorder. Tab order on CarPlay follows this list. CarPlay supports a limited number of tabs.")
                    .foregroundStyle(IdleTheme.textTertiary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }
}

// MARK: - Service Row

struct ServiceRow: View {
    let service: any VideoServicePlugin
    let registry: ServiceRegistry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: service.iconSystemName)
                .font(.title3)
                .foregroundStyle(IdleTheme.amber)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName)
                    .foregroundStyle(IdleTheme.textPrimary)
                    .font(IdleTheme.headlineFont)

                Text(service.isAuthenticated ? "Connected" : "Not connected")
                    .foregroundStyle(service.isAuthenticated ? .green : IdleTheme.textTertiary)
                    .font(IdleTheme.captionFont)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { registry.isEnabled(service.id) },
                set: { registry.setEnabled(service.id, enabled: $0) }
            ))
            .tint(IdleTheme.amber)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Service Sheet

struct AddServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServiceRegistry.self) private var serviceRegistry

    @State private var navigatingToPlexAuth = false

    // Known available services
    private let availableServices: [(id: String, name: String, icon: String)] = [
        ("plex", "Plex", "play.rectangle.fill")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                IdleTheme.background.ignoresSafeArea()

                List {
                    ForEach(availableServices, id: \.id) { service in
                        if !serviceRegistry.services.contains(where: { $0.id == service.id }) {
                            Button {
                                if service.id == "plex" {
                                    // Register first so PlexAuthView can save state against it,
                                    // then navigate into the auth flow
                                    serviceRegistry.register(PlexService())
                                    navigatingToPlexAuth = true
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: service.icon)
                                        .font(.title3)
                                        .foregroundStyle(IdleTheme.amber)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(service.name)
                                            .foregroundStyle(IdleTheme.textPrimary)
                                        Text("Sign in via plex.tv/link")
                                            .font(IdleTheme.captionFont)
                                            .foregroundStyle(IdleTheme.textTertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IdleTheme.amber)
                }
            }
            .navigationDestination(isPresented: $navigatingToPlexAuth) {
                PlexAuthView(onComplete: { dismiss() })
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ServicesView()
        .environment(ServiceRegistry())
}
