import Foundation

/// Lazy JWT cache. Mirrors the Android AuthRepository — cached token is
/// reused across launches; we only re-auth when it's missing or a 401
/// invalidates it.
@MainActor
final class AuthRepository {
    private let prefs: PrefsStore
    init(prefs: PrefsStore) { self.prefs = prefs }

    func ensureAuth() async -> CachedAuth? {
        if prefs.apiKey.isEmpty { return nil }
        // Force re-auth if factionPosition is empty on the cached entry —
        // caches written by older app versions (pre-v0.4.7) didn't store
        // the role. Without it the Admin section can't gate correctly,
        // silently hiding leader-only settings.
        if let cached = prefs.cachedJwt(),
           !cached.token.isEmpty,
           !cached.factionPosition.isEmpty {
            return cached
        }

        guard let result = await WarboardAPI.authenticate(
            baseUrl: prefs.baseUrl, apiKey: prefs.apiKey
        ) else { return nil }
        let auth = CachedAuth(
            token: result.token,
            factionId: result.player.factionId,
            factionName: result.player.factionName,
            playerId: result.player.playerId,
            factionPosition: result.player.factionPosition ?? ""
        )
        prefs.storeJwt(auth)
        return auth
    }

    func invalidate() { prefs.clearJwt() }
}
