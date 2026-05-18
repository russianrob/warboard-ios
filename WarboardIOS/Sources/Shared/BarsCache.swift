import Foundation
import WidgetKit

/// Shared bars/cooldowns cache that lives in the App Group container.
/// The main app writes via `write(...)` after each `BarReporter` tick;
/// the home-screen Status widget reads via `read()` to render Energy /
/// Nerve bars + Drug / Booster countdowns.
///
/// Why App Group: widget extensions run in a separate process from the
/// main app and cannot read `UserDefaults.standard`. The shared
/// `group.com.tornwar.warboard` suite is the supported way to push
/// data across that process boundary.
///
/// Update cadence: BarReporter ticks every 60s while app is foreground;
/// each tick refreshes this cache. Widget's TimelineProvider asks for
/// the latest snapshot when iOS decides to redraw (Apple's budget caps
/// ~30-40 refreshes per day; the widget can also be force-reloaded by
/// the app via `WidgetCenter.shared.reloadAllTimelines()` when fresh
/// data lands).
enum BarsCache {
    static let appGroupSuite = "group.com.tornwar.warboard"
    private static let key = "warboard.bars-cache.v1"

    /// Plain Codable so the widget doesn't have to share the full
    /// `TornAPI.DashboardSnapshot` type. Stamps for both wall-clock
    /// (so the widget can show "synced 3m ago") and absolute deadlines
    /// for cooldowns (so the countdown stays accurate after iOS reads
    /// a cached entry minutes later).
    struct Snapshot: Codable, Hashable {
        var energyCurrent: Int
        var energyMax: Int
        var nerveCurrent: Int
        var nerveMax: Int
        /// Absolute epoch-ms when the drug cooldown ends. 0 if no
        /// active drug cooldown at write time.
        var drugDeadlineMs: Int64
        /// Same for booster.
        var boosterDeadlineMs: Int64
        /// When this snapshot was written by the app (epoch ms).
        var writtenAtMs: Int64
    }

    /// Atomic write. Bumps WidgetCenter so the widget refreshes on the
    /// next iOS-permitted opportunity. Safe to call from MainActor or
    /// background actors.
    static func write(_ snap: Snapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else { return }
        do {
            let data = try JSONEncoder().encode(snap)
            defaults.set(data, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silent — widget will keep showing the last known good
            // snapshot. Adding a logger would just hide in the
            // extension's process-isolated console anyway.
        }
    }

    /// Read latest snapshot. Returns nil when no write has happened
    /// yet (first widget render before app has been opened) — caller
    /// should render a "set up the app to see your bars" placeholder.
    static func read() -> Snapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = defaults.data(forKey: key)
        else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
