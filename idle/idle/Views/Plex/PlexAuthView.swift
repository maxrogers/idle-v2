import SwiftUI

struct PlexAuthView: View {
    @Environment(ServiceRegistry.self) private var serviceRegistry
    @Environment(\.dismiss) private var dismiss

    @State private var pinCode: String = ""
    @State private var pinID: Int = 0
    @State private var isPolling = false
    @State private var errorMessage: String?
    @State private var showUserPicker = false
    @State private var authToken: String = ""
    @State private var homeUsers: [PlexUser] = []

    var body: some View {
        NavigationStack {
            ZStack {
                IdleTheme.background.ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // Logo
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(IdleTheme.amber)

                    // Instruction
                    VStack(spacing: 12) {
                        Text("Link Your Plex Account")
                            .font(.title2.bold())
                            .foregroundStyle(IdleTheme.textPrimary)

                        Text("Visit plex.tv/link on any browser and enter this code:")
                            .font(IdleTheme.bodyFont)
                            .foregroundStyle(IdleTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // PIN display
                    if pinCode.isEmpty {
                        ProgressView()
                            .tint(IdleTheme.amber)
                            .scaleEffect(1.5)
                    } else {
                        Text(formattedPIN)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(IdleTheme.amber)
                            .tracking(12)
                    }

                    // Status
                    if let error = errorMessage {
                        Text(error)
                            .font(IdleTheme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    } else if isPolling {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(IdleTheme.textSecondary)
                                .scaleEffect(0.8)
                            Text("Waiting for authorization…")
                                .font(IdleTheme.captionFont)
                                .foregroundStyle(IdleTheme.textSecondary)
                        }
                    }

                    Spacer()

                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IdleTheme.textTertiary)
                        .padding(.bottom)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .task { await startPINFlow() }
        .sheet(isPresented: $showUserPicker) {
            PlexUserPickerView(users: homeUsers, authToken: authToken) {
                dismiss()
                NotificationCenter.default.post(name: .carPlayRebuildTabs, object: nil)
            }
        }
    }

    // MARK: - PIN display

    private var formattedPIN: String {
        // Insert a space in the middle for readability: XXXX XXXX
        let upper = pinCode.uppercased()
        if upper.count == 8 {
            let mid = upper.index(upper.startIndex, offsetBy: 4)
            return String(upper[..<mid]) + " " + String(upper[mid...])
        }
        return upper
    }

    // MARK: - Flow

    @MainActor
    private func startPINFlow() async {
        do {
            let (id, code) = try await PlexAPI.shared.requestPIN()
            pinID = id
            pinCode = code
            isPolling = true
            await pollForAuth()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func pollForAuth() async {
        // Poll every 2 seconds for up to 5 minutes
        let maxAttempts = 150
        for _ in 0..<maxAttempts {
            guard isPolling else { return }
            try? await Task.sleep(for: .seconds(2))
            guard isPolling else { return }

            do {
                if let token = try await PlexAPI.shared.pollPIN(id: pinID) {
                    isPolling = false
                    authToken = token
                    await loadHomeUsers(token: token)
                    return
                }
            } catch {
                // Continue polling on transient errors
            }
        }
        isPolling = false
        errorMessage = "Authentication timed out. Please try again."
    }

    @MainActor
    private func loadHomeUsers(token: String) async {
        do {
            let users = try await PlexAPI.shared.getHomeUsers(token: token)
            if users.count <= 1 {
                // Single user or no home users — save token directly and proceed
                KeychainHelper.save(key: "plex_auth_token", string: token)
                KeychainHelper.save(key: "plex_user_token", string: token)
                await loadAndSaveServer(token: token)
                dismiss()
                NotificationCenter.default.post(name: .carPlayRebuildTabs, object: nil)
            } else {
                homeUsers = users
                showUserPicker = true
            }
        } catch {
            // Fallback: treat as single user
            KeychainHelper.save(key: "plex_auth_token", string: token)
            KeychainHelper.save(key: "plex_user_token", string: token)
            await loadAndSaveServer(token: token)
            dismiss()
        }
    }

    @MainActor
    private func loadAndSaveServer(token: String) async {
        do {
            let servers = try await PlexAPI.shared.getServers(token: token)
            // Prefer local, non-relay connections; pick first available server
            if let server = servers.first,
               let connection = server.connections.first(where: { !$0.relay && $0.local })
                                ?? server.connections.first(where: { !$0.relay })
                                ?? server.connections.first {
                UserDefaults.standard.set(connection.uri, forKey: "plex_server_url")
            }
        } catch {
            // Server will be resolved later
        }
    }
}

#Preview {
    PlexAuthView()
        .environment(ServiceRegistry())
}
