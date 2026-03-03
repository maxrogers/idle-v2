import SwiftUI

struct ServicesView: View {
    @ObservedObject private var registry = ServiceRegistry.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.idleSurface.ignoresSafeArea()

                List {
                    Section {
                        ForEach(registry.services, id: \.id) { service in
                            serviceRow(service)
                        }
                    } header: {
                        Text("Video Services")
                    } footer: {
                        Text("Configure services to browse and play content directly from CarPlay.")
                            .font(.idleCaption)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Services")
        }
    }

    private func serviceRow(_ service: VideoService) -> some View {
        NavigationLink {
            serviceDetailView(for: service)
        } label: {
            HStack(spacing: 12) {
                Image(uiImage: service.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.idleAmber)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.idleBody)
                        .foregroundColor(.white)

                    Text(service.isAuthenticated ? "Connected" : "Not configured")
                        .font(.idleCaption)
                        .foregroundColor(service.isAuthenticated ? .idleAmber : .gray)
                }

                Spacer()

                if service.isAuthenticated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.idleAmber)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.idleCard)
    }

    @ViewBuilder
    private func serviceDetailView(for service: VideoService) -> some View {
        switch service.id {
        case "plex":
            PlexSettingsView()
        case "youtube":
            YouTubeSettingsView()
        default:
            Text("Settings for \(service.name)")
        }
    }
}

// MARK: - Plex Settings

struct PlexSettingsView: View {
    @State private var serverURL: String = ""
    @State private var token: String = ""
    @State private var serverName: String = ""
    @State private var isConnecting = false
    @State private var connectionStatus: String?
    @State private var isConnected = false

    var body: some View {
        ZStack {
            Color.idleSurface.ignoresSafeArea()

            Form {
                Section("Server Configuration") {
                    TextField("Server URL", text: $serverURL, prompt: Text("http://192.168.1.100:32400"))
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("X-Plex-Token", text: $token, prompt: Text("Your Plex token"))

                    TextField("Server Name (optional)", text: $serverName, prompt: Text("My Plex Server"))
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isConnecting {
                                ProgressView()
                                    .tint(.idleAmber)
                            }
                        }
                    }
                    .disabled(serverURL.isEmpty || token.isEmpty || isConnecting)

                    if let status = connectionStatus {
                        Text(status)
                            .font(.idleCaption)
                            .foregroundColor(isConnected ? .idleAmber : .red)
                    }
                }

                if isConnected {
                    Section {
                        Button("Save") {
                            saveConfig()
                        }
                        .foregroundColor(.idleAmber)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Plex")
        .onAppear { loadExistingConfig() }
    }

    private func loadExistingConfig() {
        if let config = PlexService.loadStoredConfig() {
            serverURL = config.serverURL
            token = config.token
            serverName = config.serverName ?? ""
            isConnected = true
            connectionStatus = "Connected"
        }
    }

    private func testConnection() {
        isConnecting = true
        connectionStatus = nil

        Task {
            let config = PlexConfig(serverURL: serverURL, token: token, serverName: serverName.isEmpty ? nil : serverName)
            PlexService.saveConfig(config)

            do {
                let service = ServiceRegistry.shared.service(byID: "plex") as? PlexService
                try await service?.authenticate()
                isConnected = true
                connectionStatus = "Connected successfully"
            } catch {
                isConnected = false
                connectionStatus = error.localizedDescription
            }
            isConnecting = false
        }
    }

    private func saveConfig() {
        let config = PlexConfig(serverURL: serverURL, token: token, serverName: serverName.isEmpty ? nil : serverName)
        PlexService.saveConfig(config)
    }
}

// MARK: - YouTube Settings

struct YouTubeSettingsView: View {
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationStatus: String?
    @State private var isValid = false

    var body: some View {
        ZStack {
            Color.idleSurface.ignoresSafeArea()

            Form {
                Section("API Configuration") {
                    SecureField("YouTube Data API Key", text: $apiKey, prompt: Text("Your API key"))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section {
                    Button {
                        validateKey()
                    } label: {
                        HStack {
                            Text("Validate Key")
                            Spacer()
                            if isValidating {
                                ProgressView()
                                    .tint(.idleAmber)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating)

                    if let status = validationStatus {
                        Text(status)
                            .font(.idleCaption)
                            .foregroundColor(isValid ? .idleAmber : .red)
                    }
                } footer: {
                    Text("Get a free YouTube Data API key from the Google Cloud Console. Free tier allows 10,000 units per day.")
                        .font(.idleCaption)
                }

                if isValid {
                    Section {
                        Button("Save") {
                            YouTubeService.saveAPIKey(apiKey)
                        }
                        .foregroundColor(.idleAmber)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("YouTube")
        .onAppear {
            if let key = YouTubeService.loadStoredAPIKey() {
                apiKey = key
                isValid = true
                validationStatus = "Key configured"
            }
        }
    }

    private func validateKey() {
        isValidating = true
        validationStatus = nil

        Task {
            YouTubeService.saveAPIKey(apiKey)
            do {
                let service = ServiceRegistry.shared.service(byID: "youtube") as? YouTubeService
                try await service?.authenticate()
                isValid = true
                validationStatus = "Key is valid"
            } catch {
                isValid = false
                validationStatus = error.localizedDescription
            }
            isValidating = false
        }
    }
}
