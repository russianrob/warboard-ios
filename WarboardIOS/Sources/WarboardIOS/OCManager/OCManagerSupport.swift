import Foundation
import SwiftUI

/// Glue types the ported OC Manager files expect. Kept here so the
/// rest of the OCManager/ module can stay verbatim from oc-spawn-ios
/// (which has been discontinued — only this Manager subset survived).
///
/// Everything here is owner-only — wired into ContentView behind the
/// `auth.isOwner` gate, so non-RussianRob installs never see the tab
/// nor execute any of this module's networking.
enum OCAPIError: Error, LocalizedError {
    case noKey
    case http(Int)
    case decode(Error)
    case transport(Error)
    var errorDescription: String? {
        switch self {
        case .noKey:        return "Set your Torn API key in Settings."
        case .http(let s):
            // 5xx codes mean Torn's gateway / origin is having a moment
            // — usually clears within a tick. Surfacing the raw code is
            // alarming and uninformative for the end user; ManagerVM
            // auto-retries on the next 30s tick so the friendlier copy
            // sets the right expectation.
            if (500...599).contains(s) {
                return "Torn is slow right now (HTTP \(s)) — retrying automatically."
            }
            return "Torn API returned HTTP \(s)."
        case .decode(let e): return "Couldn't parse Torn response: \(e.localizedDescription)"
        case .transport(let e): return "Network error: \(e.localizedDescription)"
        }
    }
    /// True for transient gateway / upstream errors that auto-retry
    /// is expected to fix. Used by ManagerVM to keep prior data on
    /// screen instead of swapping in an error placeholder.
    var isTransient: Bool {
        switch self {
        case .http(let s):  return (500...599).contains(s)
        case .transport:    return true
        default:            return false
        }
    }
}

/// Mini faction-member record — only the fields ManagerViewModel
/// actually reads (id + name). Lives separately from warboard-ios's
/// own member models so the OCManager module can be lifted in/out
/// without touching the rest of the codebase.
struct OCFactionMember: Identifiable, Equatable {
    let id: Int64
    let name: String
}

/// Plain centred icon-and-text placeholder. Mirrors the `MessageView`
/// helper used by the rest of warboard-ios but file-scoped to the
/// OCManager module so it doesn't clash with the existing fileprivate
/// declarations in WarRoomView / DashboardView.
struct OCMessageView: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum OCMembersAPI {
    /// GET /v2/faction?selections=members → faction roster.
    /// Mirrors the helper that lived in oc-spawn-ios's TornAPI.
    static func fetchMembers(apiKey: String) async throws -> [OCFactionMember] {
        guard !apiKey.isEmpty else { throw OCAPIError.noKey }
        guard var comps = URLComponents(string: "https://api.torn.com/v2/faction") else {
            throw OCAPIError.http(0)
        }
        comps.queryItems = [
            URLQueryItem(name: "selections", value: "members"),
            URLQueryItem(name: "key",        value: apiKey),
            URLQueryItem(name: "comment",    value: "warboard-ios-oc"),
        ]
        guard let url = comps.url else { throw OCAPIError.http(0) }
        var req = URLRequest(url: url); req.timeoutInterval = 15
        let data: Data
        let resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw OCAPIError.transport(error) }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw OCAPIError.http(code) }
        do {
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            guard let arr = root["members"] as? [[String: Any]] else { return [] }
            return arr.compactMap { m in
                let id: Int64 = (m["id"] as? Int64) ?? Int64((m["id"] as? Int) ?? 0)
                guard id > 0 else { return nil }
                return OCFactionMember(
                    id: id,
                    name: (m["name"] as? String) ?? "?"
                )
            }
        } catch { throw OCAPIError.decode(error) }
    }
}
