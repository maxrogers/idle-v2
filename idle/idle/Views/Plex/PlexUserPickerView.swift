import SwiftUI

struct PlexUserPickerView: View {
    let users: [PlexUser]
    let authToken: String
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedUser: PlexUser?
    @State private var pinInput: String = ""
    @State private var showingPINEntry = false
    @State private var errorMessage: String?
    @State private var isSwitching = false

    var body: some View {
        NavigationStack {
            Group {
                if showingPINEntry, let user = selectedUser {
                    pinEntryView(for: user)
                } else {
                    userListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IdleTheme.background.ignoresSafeArea())
            .navigationTitle("Who's Watching?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(IdleTheme.textTertiary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - User List

    private var userListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(users) { user in
                    Button {
                        selectUser(user)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(IdleTheme.surfacePrimary)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if let thumb = user.thumb, let url = URL(string: thumb) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(IdleTheme.textTertiary)
                                        }
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(IdleTheme.textTertiary)
                                    }
                                }

                            Text(user.title)
                                .foregroundStyle(IdleTheme.textPrimary)
                                .font(IdleTheme.headlineFont)

                            Spacer()

                            if user.protected {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(IdleTheme.textTertiary)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(IdleTheme.surfacePrimary)
                }
            }
        }
    }

    // MARK: - PIN Entry

    private func pinEntryView(for user: PlexUser) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(IdleTheme.amber)

            Text("Enter PIN for \(user.title)")
                .font(IdleTheme.titleFont)
                .foregroundStyle(IdleTheme.textPrimary)

            SecureField("PIN", text: $pinInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.center)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(IdleTheme.captionFont)
            }

            HStack(spacing: 20) {
                Button("Back") {
                    showingPINEntry = false
                    pinInput = ""
                    errorMessage = nil
                }
                .foregroundStyle(IdleTheme.textTertiary)

                Button {
                    Task { await confirmUserSwitch() }
                } label: {
                    if isSwitching {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(IdleTheme.amber)
                .disabled(pinInput.isEmpty || isSwitching)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func selectUser(_ user: PlexUser) {
        selectedUser = user
        if user.protected {
            showingPINEntry = true
        } else {
            Task { await switchToUser(user, pin: nil) }
        }
    }

    @MainActor
    private func confirmUserSwitch() async {
        guard let user = selectedUser else { return }
        await switchToUser(user, pin: pinInput)
    }

    @MainActor
    private func switchToUser(_ user: PlexUser, pin: String?) async {
        isSwitching = true
        errorMessage = nil
        do {
            let userToken = try await PlexAPI.shared.switchUser(
                userID: user.id,
                pin: pin,
                token: authToken
            )
            KeychainHelper.save(key: "plex_auth_token", string: authToken)
            KeychainHelper.save(key: "plex_user_token", string: userToken)

            // Save server for this user
            let servers = try await PlexAPI.shared.getServers(token: userToken)
            if let server = servers.first,
               let connection = server.connections.first(where: { !$0.relay && $0.local })
                                ?? server.connections.first(where: { !$0.relay })
                                ?? server.connections.first {
                UserDefaults.standard.set(connection.uri, forKey: "plex_server_url")
            }

            isSwitching = false
            dismiss()
            onComplete()
        } catch {
            isSwitching = false
            errorMessage = pin != nil ? "Incorrect PIN. Please try again." : error.localizedDescription
        }
    }
}
