import Foundation
import Network
import Observation

/// Plex Good Day Mate (GDM) UDP multicast advertising.
/// Advertises idle as a Plex player on the local network so the native
/// Plex iOS app can discover and cast to it.
///
/// Note: iOS aggressively terminates background UDP listeners.
/// GDM works reliably when the app is foregrounded. When backgrounded,
/// the system may suspend the multicast listener within seconds.
@Observable
final class PlexGDM {

    static let shared = PlexGDM()

    var isAdvertising = false

    private let multicastHost = "239.0.0.250"
    private let multicastPort: UInt16 = 32414
    private let companionPort: UInt16 = 32412

    private var listener: NWListener?
    private var clientUUID: String {
        UserDefaults.standard.string(forKey: "plex_client_id") ?? UUID().uuidString
    }

    private init() {}

    // MARK: - Advertise

    func startAdvertising() {
        guard !isAdvertising else { return }

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: multicastPort)!)
        } catch {
            print("[PlexGDM] Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                Task { @MainActor [weak self] in
                    self?.isAdvertising = true
                    print("[PlexGDM] Advertising as Plex player")
                }
            case .failed(let error):
                print("[PlexGDM] Listener failed: \(error)")
                Task { @MainActor [weak self] in
                    self?.isAdvertising = false
                }
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .global(qos: .utility))
    }

    func stopAdvertising() {
        listener?.cancel()
        listener = nil
        isAdvertising = false
    }

    // MARK: - Handle Discovery Requests

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let data, let message = String(data: data, encoding: .utf8) else { return }

            // Plex GDM sends "M-SEARCH * HTTP/1.1"
            if message.contains("M-SEARCH") {
                self?.sendDiscoveryResponse(to: connection)
            }
        }
    }

    private func sendDiscoveryResponse(to connection: NWConnection) {
        let response = gdmResponseString()
        guard let data = response.data(using: .utf8) else { return }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error { print("[PlexGDM] Send error: \(error)") }
            connection.cancel()
        })
    }

    private func gdmResponseString() -> String {
        let now = Int(Date().timeIntervalSince1970)
        return """
        HTTP/1.1 200 OK
        Content-Type: plex/media-player
        Name: idle
        Port: \(companionPort)
        Product: idle
        Protocol: plex
        Protocol-Capabilities: timeline,playback,playqueues,navigation
        Protocol-Version: 1
        Resource-Identifier: \(clientUUID)
        Updated-At: \(now)
        Version: 1.0

        """
    }
}
