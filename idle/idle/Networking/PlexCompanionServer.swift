import Foundation
import Network
import Observation

/// Lightweight HTTP server implementing the Plex Companion protocol.
/// Allows the native Plex iOS app to cast media to idle.
///
/// Endpoints implemented:
///   GET  /resources             — Device capabilities
///   POST /player/playback/playMedia  — Receive cast command
///   GET  /player/timeline/poll  — Report playback state
///   POST /player/playback/pause
///   POST /player/playback/play
///   POST /player/playback/stop
@Observable
final class PlexCompanionServer {

    static let shared = PlexCompanionServer()

    var isRunning = false
    let port: UInt16 = 32412

    private var listener: NWListener?
    private var playbackEngine: PlaybackEngine?

    private init() {}

    // MARK: - Start / Stop

    func start(playbackEngine: PlaybackEngine) {
        self.playbackEngine = playbackEngine
        guard !isRunning else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[CompanionServer] Failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.isRunning = state == .ready
            }
        }

        listener?.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        readRequest(connection: connection)
    }

    private func readRequest(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let data, let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self?.processRequest(requestString, connection: connection)
        }
    }

    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return sendResponse("400 Bad Request", body: "", connection: connection) }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return sendResponse("400 Bad Request", body: "", connection: connection) }

        let method = parts[0]
        let path = parts[1].components(separatedBy: "?").first ?? parts[1]
        let queryString = parts[1].components(separatedBy: "?").dropFirst().first ?? ""

        switch (method, path) {
        case ("GET", "/resources"):
            sendResourcesResponse(connection: connection)

        case ("POST", "/player/playback/playMedia"):
            handlePlayMedia(queryString: queryString, connection: connection)

        case ("GET", "/player/timeline/poll"), ("GET", "/player/timeline"):
            sendTimelineResponse(connection: connection)

        case ("POST", "/player/playback/pause"):
            Task { @MainActor [weak self] in self?.playbackEngine?.pause() }
            sendResponse("200 OK", body: "<Response code=\"200\" status=\"OK\"/>", connection: connection)

        case ("POST", "/player/playback/play"):
            Task { @MainActor [weak self] in self?.playbackEngine?.resume() }
            sendResponse("200 OK", body: "<Response code=\"200\" status=\"OK\"/>", connection: connection)

        case ("POST", "/player/playback/stop"):
            Task { @MainActor [weak self] in self?.playbackEngine?.stop() }
            sendResponse("200 OK", body: "<Response code=\"200\" status=\"OK\"/>", connection: connection)

        default:
            sendResponse("404 Not Found", body: "", connection: connection)
        }
    }

    private func handlePlayMedia(queryString: String, connection: NWConnection) {
        // Parse query parameters
        var params: [String: String] = [:]
        for pair in queryString.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 {
                params[kv[0]] = kv[1].removingPercentEncoding
            }
        }

        guard let key = params["key"],
              let serverURI = params["address"].flatMap({ URL(string: "http://\($0):\(params["port"] ?? "32400")") }),
              let token = params["token"] else {
            sendResponse("400 Bad Request", body: "", connection: connection)
            return
        }

        // Build playback URL
        Task { @MainActor [weak self] in
            guard let engine = self?.playbackEngine else { return }
            do {
                let partKey = try await PlexAPI.shared.getPartKey(serverURL: serverURI, itemKey: key, token: token)
                var components = URLComponents(url: serverURI.appendingPathComponent(String(partKey.dropFirst())), resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "X-Plex-Token", value: token)]
                if let url = components.url {
                    engine.play(url: url, title: params["title"], thumbnailURL: nil)
                }
            } catch {
                print("[CompanionServer] Failed to resolve playback URL: \(error)")
            }
        }

        sendResponse("200 OK", body: "<Response code=\"200\" status=\"OK\"/>", connection: connection)
    }

    private func sendResourcesResponse(connection: NWConnection) {
        let uuid = UserDefaults.standard.string(forKey: "plex_client_id") ?? UUID().uuidString
        let body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <MediaContainer>
          <Player title="idle" protocol="plex" protocolVersion="1" machineIdentifier="\(uuid)"
                  product="idle" platform="iOS" platformVersion="26.4" protocolCapabilities="timeline,playback,playqueues"/>
        </MediaContainer>
        """
        sendResponse("200 OK", body: body, connection: connection, contentType: "text/xml")
    }

    private func sendTimelineResponse(connection: NWConnection) {
        // Reported asynchronously since we need MainActor state
        Task { @MainActor [weak self] in
            let engine = self?.playbackEngine
            let state = engine?.isPlaying == true ? "playing" : "paused"
            let time = Int((engine?.progress ?? 0) * 1000)
            let duration = Int((engine?.duration ?? 0) * 1000)
            let uuid = UserDefaults.standard.string(forKey: "plex_client_id") ?? ""

            let body = """
            <?xml version="1.0" encoding="UTF-8"?>
            <MediaContainer commandID="0" location="fullScreenVideo">
              <Timeline type="video" state="\(state)" time="\(time)" duration="\(duration)"
                        machineIdentifier="\(uuid)" controllable="playPause,stop,seekTo"/>
            </MediaContainer>
            """
            self?.sendResponse("200 OK", body: body, connection: connection, contentType: "text/xml")
        }
    }

    private func sendResponse(_ status: String, body: String, connection: NWConnection, contentType: String = "application/json") {
        let response = """
        HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)
        """
        guard let data = response.data(using: .utf8) else { connection.cancel(); return }
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }
}
