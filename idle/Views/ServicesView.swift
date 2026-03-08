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
    @StateObject private var pinAuth = PlexPINAuth()
    @State private var servers: [PlexResource] = []
    @State private var homeUsers: [PlexHomeUser] = []
    @State private var isLoadingServers = false
    @State private var isLoadingUsers = false
    @State private var existingConfig: PlexConfig?
    @State private var errorMessage: String?
    @State private var pendingServer: PlexResource?
    @State private var pendingServerURL: String?
    @State private var pinEntry: String = ""
    @State private var selectedProtectedUser: PlexHomeUser?

    private var isConnected: Bool {
        existingConfig != nil
    }

    var body: some View {
        ZStack {
            Color.idleSurface.ignoresSafeArea()

            Form {
                if isConnected, let config = existingConfig {
                    connectedSection(config: config)
                } else {
                    loginSection
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Plex")
        .onAppear { loadExistingConfig() }
        .onChange(of: pinAuth.state) { _, newState in
            if case .authenticated(let token) = newState {
                fetchServers(token: token)
            }
        }
    }

    // MARK: - Connected State

    private func connectedSection(config: PlexConfig) -> some View {
        Group {
            Section("Connected Server") {
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundColor(.idleAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.serverName)
                            .font(.idleBody)
                            .foregroundColor(.white)
                        Text(config.serverURL)
                            .font(.idleCaption)
                            .foregroundColor(.gray)
                    }
                }

                if let userName = config.selectedUserName {
                    HStack {
                        Text("User")
                        Spacer()
                        Text(userName)
                            .foregroundColor(.idleAmber)
                    }
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.idleAmber)
                    Text("Connected")
                        .font(.idleCaption)
                        .foregroundColor(.idleAmber)
                }
            }

            Section {
                Button(role: .destructive) {
                    signOut()
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Login Flow

    private var loginSection: some View {
        Group {
            switch pinAuth.state {
            case .idle, .failed:
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundColor(.idleAmber)

                        Text("Sign in with Plex")
                            .font(.idleHeadline)
                            .foregroundColor(.white)

                        Text("Link your Plex account to browse and play your media library from CarPlay.")
                            .font(.idleBody)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.idleSurface)
                }

                if case .failed(let message) = pinAuth.state {
                    Section {
                        Text(message)
                            .font(.idleCaption)
                            .foregroundColor(.red)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.idleCaption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        self.errorMessage = nil
                        pinAuth.startAuth()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign In with Plex", systemImage: "link")
                                .foregroundColor(.idleAmber)
                            Spacer()
                        }
                    }
                } footer: {
                    Text("You'll get a code to enter at plex.tv/link")
                        .font(.idleCaption)
                }

            case .polling:
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.idleAmber)
                        Text("Requesting code...")
                            .font(.idleBody)
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

            case .waitingForUser(let code):
                linkCodeSection(code: code)

            case .authenticated:
                if isLoadingServers || isLoadingUsers {
                    serverLoadingSection
                } else if selectedProtectedUser != nil {
                    pinEntrySection
                } else if !homeUsers.isEmpty {
                    userPickerSection
                } else if !servers.isEmpty {
                    serverPickerSection
                }
            }
        }
    }

    // MARK: - Link Code Display

    private func linkCodeSection(code: String) -> some View {
        Group {
            Section {
                VStack(spacing: 20) {
                    Text("Enter this code at")
                        .font(.idleBody)
                        .foregroundColor(.gray)

                    Link("plex.tv/link", destination: URL(string: "https://plex.tv/link")!)
                        .font(.idleHeadline)
                        .foregroundColor(.idleAmber)

                    // Code display — use indexed ForEach to avoid duplicate character IDs
                    HStack(spacing: 12) {
                        ForEach(Array(code.enumerated()), id: \.offset) { index, char in
                            Text(String(char).uppercased())
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 64)
                                .background(Color.idleCard)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 8)

                    Text("Waiting for authorization...")
                        .font(.idleCaption)
                        .foregroundColor(.gray)

                    ProgressView()
                        .tint(.idleAmber)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.idleSurface)
            }

            Section {
                Button(role: .cancel) {
                    pinAuth.cancel()
                } label: {
                    HStack {
                        Spacer()
                        Text("Cancel")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Server Selection

    private var serverLoadingSection: some View {
        Section {
            HStack {
                Spacer()
                ProgressView()
                    .tint(.idleAmber)
                Text("Finding your servers...")
                    .font(.idleBody)
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    private var serverPickerSection: some View {
        Section("Select a Server") {
            ForEach(servers, id: \.clientIdentifier) { server in
                Button {
                    selectServer(server)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .foregroundColor(.idleAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(.idleBody)
                                .foregroundColor(.white)

                            if let conn = server.connections?.first {
                                Text(conn.uri)
                                    .font(.idleCaption)
                                    .foregroundColor(.gray)
                            }

                            if server.owned == true {
                                Text("Owned")
                                    .font(.idleCaption)
                                    .foregroundColor(.idleAmber)
                            } else {
                                Text("Shared")
                                    .font(.idleCaption)
                                    .foregroundColor(.idleAmberMuted)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - User Picker

    private var userPickerSection: some View {
        Section("Select User") {
            ForEach(homeUsers) { user in
                Button {
                    selectUser(user)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: user.isAdmin ? "person.badge.key" : "person")
                            .foregroundColor(.idleAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.title)
                                .font(.idleBody)
                                .foregroundColor(.white)

                            if user.isAdmin {
                                Text("Admin")
                                    .font(.idleCaption)
                                    .foregroundColor(.idleAmber)
                            }
                        }

                        Spacer()

                        if user.isProtected {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }

                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - PIN Entry

    private var pinEntrySection: some View {
        Group {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.idleAmber)

                    Text("Enter PIN for \(selectedProtectedUser?.title ?? "user")")
                        .font(.idleHeadline)
                        .foregroundColor(.white)

                    SecureField("PIN", text: $pinEntry)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 60)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.idleCaption)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowBackground(Color.idleSurface)
            }

            Section {
                Button {
                    confirmPINEntry()
                } label: {
                    HStack {
                        Spacer()
                        Text("Continue")
                            .foregroundColor(.idleAmber)
                        Spacer()
                    }
                }
                .disabled(pinEntry.isEmpty)

                Button(role: .cancel) {
                    selectedProtectedUser = nil
                    pinEntry = ""
                    errorMessage = nil
                } label: {
                    HStack {
                        Spacer()
                        Text("Back")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadExistingConfig() {
        existingConfig = PlexService.loadStoredConfig()
    }

    private func fetchServers(token: String) {
        isLoadingServers = true
        Task {
            do {
                let found = try await PlexServerDiscovery.fetchServers(token: token)
                servers = found
                if servers.isEmpty {
                    errorMessage = "No Plex servers found on your account."
                    pinAuth.cancel()
                }
            } catch {
                errorMessage = "Failed to load servers: \(error.localizedDescription)"
                pinAuth.cancel()
            }
            isLoadingServers = false
        }
    }

    private func selectServer(_ server: PlexResource) {
        guard case .authenticated(let authToken) = pinAuth.state else { return }
        errorMessage = nil

        guard let connectionURL = PlexServerDiscovery.bestConnectionURL(for: server) else {
            errorMessage = "No connection available for this server."
            return
        }

        // Store the pending server info and fetch home users
        pendingServer = server
        pendingServerURL = connectionURL

        // Fetch home users to see if user selection is needed
        isLoadingUsers = true
        Task {
            do {
                let users = try await PlexHomeUserManager.fetchHomeUsers(token: authToken)
                homeUsers = users
                isLoadingUsers = false

                // If only one user (admin only, no managed users), skip user selection
                if users.count <= 1 {
                    finalizeConfig(userToken: authToken, userName: users.first?.title, userID: users.first?.id)
                }
            } catch {
                // If we can't fetch users, proceed without user selection
                isLoadingUsers = false
                finalizeConfig(userToken: authToken, userName: nil, userID: nil)
            }
        }
    }

    private func selectUser(_ user: PlexHomeUser) {
        if user.isProtected {
            selectedProtectedUser = user
            pinEntry = ""
            errorMessage = nil
        } else {
            // No PIN needed — switch directly
            switchToUser(user, pin: nil)
        }
    }

    private func confirmPINEntry() {
        guard let user = selectedProtectedUser else { return }
        switchToUser(user, pin: pinEntry)
    }

    private func switchToUser(_ user: PlexHomeUser, pin: String?) {
        guard case .authenticated(let authToken) = pinAuth.state else { return }
        isLoadingUsers = true
        errorMessage = nil

        Task {
            do {
                let userToken = try await PlexHomeUserManager.switchUser(
                    userID: user.id,
                    pin: pin,
                    adminToken: authToken
                )
                selectedProtectedUser = nil
                pinEntry = ""
                isLoadingUsers = false
                finalizeConfig(userToken: userToken, userName: user.title, userID: user.id)
            } catch let error as PlexError where error == .incorrectPIN {
                errorMessage = "Incorrect PIN"
                isLoadingUsers = false
            } catch {
                errorMessage = "Failed to switch user: \(error.localizedDescription)"
                isLoadingUsers = false
            }
        }
    }

    private func finalizeConfig(userToken: String, userName: String?, userID: Int?) {
        guard case .authenticated(let authToken) = pinAuth.state,
              let server = pendingServer,
              let connectionURL = pendingServerURL else { return }

        let config = PlexConfig(
            authToken: authToken,
            userToken: userToken,
            serverAccessToken: server.accessToken ?? userToken,
            serverURL: connectionURL,
            serverName: server.name,
            machineIdentifier: server.clientIdentifier,
            allConnectionURLs: PlexServerDiscovery.allConnectionURLs(for: server),
            selectedUserName: userName,
            selectedUserID: userID
        )
        PlexService.saveConfig(config)
        existingConfig = config
        homeUsers = []
        pendingServer = nil
        pendingServerURL = nil
        pinAuth.cancel()

        // Refresh the service registry and notify CarPlay to rebuild tabs
        Task { @MainActor in
            try? await (ServiceRegistry.shared.service(byID: "plex") as? PlexService)?.authenticate()
            NotificationCenter.default.post(name: .plexServiceAuthChanged, object: nil)
        }
    }

    private func signOut() {
        (ServiceRegistry.shared.service(byID: "plex") as? PlexService)?.signOut()
        existingConfig = nil
        servers = []
        homeUsers = []
        pendingServer = nil
        pendingServerURL = nil
        pinAuth.cancel()
        NotificationCenter.default.post(name: .plexServiceAuthChanged, object: nil)
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
