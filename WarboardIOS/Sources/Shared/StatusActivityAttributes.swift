import Foundation
import ActivityKit

/// Always-on Status Live Activity — Energy / Nerve / Drug / Booster
/// surface on the lock screen + Dynamic Island. Independent of war or
/// chain state; user starts/stops it explicitly via the Dashboard
/// button.
///
/// Lives in Sources/Shared/ so both the Warboard app target (which
/// starts/updates/ends the activity) and the ChainWidget extension
/// (which renders it) can see the struct.
struct StatusActivityAttributes: ActivityAttributes {
    public typealias StatusState = ContentState

    public struct ContentState: Codable, Hashable {
        public var energyCurrent: Int
        public var energyMax: Int
        public var nerveCurrent: Int
        public var nerveMax: Int
        /// Absolute epoch-ms deadlines so countdowns stay accurate
        /// even when iOS reads a cached snapshot minutes after the
        /// last push.
        public var drugDeadlineMs: Int64
        public var boosterDeadlineMs: Int64
        /// When this state was written (epoch ms) — used for a
        /// "synced Nm ago" freshness label when the activity has
        /// been backgrounded for a while.
        public var writtenAtMs: Int64

        public init(energyCurrent: Int,
                    energyMax: Int,
                    nerveCurrent: Int,
                    nerveMax: Int,
                    drugDeadlineMs: Int64,
                    boosterDeadlineMs: Int64,
                    writtenAtMs: Int64) {
            self.energyCurrent = energyCurrent
            self.energyMax = energyMax
            self.nerveCurrent = nerveCurrent
            self.nerveMax = nerveMax
            self.drugDeadlineMs = drugDeadlineMs
            self.boosterDeadlineMs = boosterDeadlineMs
            self.writtenAtMs = writtenAtMs
        }
    }

    /// Static metadata. Just the player's display name — set when the
    /// activity starts so the lock-screen header can show "TomTronical"
    /// rather than a generic "warboard" label.
    public let playerName: String

    public init(playerName: String) {
        self.playerName = playerName
    }
}
