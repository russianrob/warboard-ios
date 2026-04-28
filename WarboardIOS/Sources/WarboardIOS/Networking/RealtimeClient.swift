import Foundation
import Combine
import SocketIO

/// Single Socket.IO connection to the warboard server. Replaces the
/// 15s polling loop in WarRoomViewModel for real-time war / chain /
/// target events. View models subscribe to the `events` publisher and
/// react to each event without re-fetching from REST.
///
/// Lifecycle:
///   - call `connect(...)` after the user has authenticated and we
///     have a JWT
///   - call `joinWar(...)` to subscribe to a specific war room
///   - call `disconnect()` when the user signs out / clears API key
@MainActor
final class RealtimeClient {
    static let shared = RealtimeClient()

    /// All real-time events from the server land here. View models
    /// subscribe via `.sink` (Combine) or async-stream and update
    /// their @Published state from the payload.
    let events = PassthroughSubject<Event, Never>()
    @Published private(set) var connected: Bool = false

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var currentBaseUrl: String?
    private var currentJwt: String?
    private var currentRoom: (warId: String, factionId: String)?

    private init() {}

    /// Mirrors the userscript's connection config — JWT in `auth.token`,
    /// polling+websocket transports, infinite reconnect.
    func connect(baseUrl: String, jwt: String) {
        let normalised = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        // Already connected to the same server with the same JWT? No-op.
        if currentBaseUrl == normalised && currentJwt == jwt && socket?.status == .connected {
            return
        }
        disconnect()
        guard let url = URL(string: normalised) else {
            NSLog("[Realtime] Bad base URL: \(baseUrl)")
            return
        }
        currentBaseUrl = normalised
        currentJwt = jwt

        let m = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .connectParams(["token": jwt]),
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWait(2),
            .reconnectWaitMax(30),
            .extraHeaders(["Authorization": "Bearer \(jwt)"]),
        ])
        manager = m
        let s = m.defaultSocket
        socket = s

        s.on(clientEvent: .connect) { [weak self] _, _ in
            NSLog("[Realtime] Connected")
            Task { @MainActor in
                self?.connected = true
                // Re-join the prior room after a reconnect.
                if let room = self?.currentRoom {
                    self?._joinWar(warId: room.warId, factionId: room.factionId)
                }
            }
        }
        s.on(clientEvent: .disconnect) { [weak self] _, _ in
            NSLog("[Realtime] Disconnected")
            Task { @MainActor in self?.connected = false }
        }
        s.on(clientEvent: .error) { data, _ in
            NSLog("[Realtime] Error: \(data)")
        }

        // Wire each server-emitted event into the local PassthroughSubject.
        // Adding new events: register here + extend the Event enum below.
        s.on("war_state")        { [weak self] data, _ in self?.publish(.warState(data.first as? [String: Any] ?? [:])) }
        s.on("war_update")       { [weak self] data, _ in self?.publish(.warUpdate(data.first as? [String: Any] ?? [:])) }
        s.on("war_ended")        { [weak self] data, _ in self?.publish(.warEnded(data.first as? [String: Any] ?? [:])) }
        s.on("status_update")    { [weak self] data, _ in self?.publish(.statusUpdate(data.first as? [String: Any] ?? [:])) }
        s.on("status_updated")   { [weak self] data, _ in self?.publish(.statusUpdated(data.first as? [String: Any] ?? [:])) }
        s.on("statuses_refreshed"){ [weak self] data, _ in self?.publish(.statusesRefreshed(data.first as? [String: Any] ?? [:])) }
        s.on("target_called")    { [weak self] data, _ in self?.publish(.targetCalled(data.first as? [String: Any] ?? [:])) }
        s.on("target_uncalled")  { [weak self] data, _ in self?.publish(.targetUncalled(data.first as? [String: Any] ?? [:])) }
        s.on("member_bars")      { [weak self] data, _ in self?.publish(.memberBars(data.first as? [String: Any] ?? [:])) }
        s.on("global_toast")     { [weak self] data, _ in self?.publish(.globalToast(data.first as? [String: Any] ?? [:])) }

        s.connect()
    }

    /// Subscribe to a specific war's events. Must be called after
    /// `connect(...)` succeeds — but safe to call before; we'll re-emit
    /// the join on the next `connect` callback.
    func joinWar(warId: String, factionId: String) {
        currentRoom = (warId: warId, factionId: factionId)
        if socket?.status == .connected {
            _joinWar(warId: warId, factionId: factionId)
        }
    }

    private func _joinWar(warId: String, factionId: String) {
        socket?.emit("join_war", ["warId": warId, "factionId": factionId])
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        currentBaseUrl = nil
        currentJwt = nil
        currentRoom = nil
        connected = false
    }

    private func publish(_ event: Event) {
        Task { @MainActor in self.events.send(event) }
    }

    /// Inject a synthetic event into the same publisher subscribers
    /// already listen on. Used by sendShout to echo the sender's own
    /// broadcast immediately, so the toast appears even if Socket.IO
    /// hadn't connected by the time the shout fired.
    func injectGlobalToast(_ payload: [String: Any]) {
        publish(.globalToast(payload))
    }

    /// Discriminated union for every event the warboard server emits
    /// over Socket.IO. The associated value is the raw payload — view
    /// models pull what they need (server schemas evolve, view models
    /// shouldn't care about fields they don't use).
    enum Event {
        case warState([String: Any])
        case warUpdate([String: Any])
        case warEnded([String: Any])
        case statusUpdate([String: Any])
        case statusUpdated([String: Any])
        case statusesRefreshed([String: Any])
        case targetCalled([String: Any])
        case targetUncalled([String: Any])
        case memberBars([String: Any])
        case globalToast([String: Any])
    }
}
