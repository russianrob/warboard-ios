import Foundation
import ActivityKit

/// ActivityAttributes for the chain-break Live Activity. The attributes
/// (warName, enemyName) are fixed for the activity's lifetime; the
/// ContentState fields (chain, deadlines) are pushed on every poll.
///
/// Lives in Sources/Shared/ so both the Warboard app target (which
/// starts/updates/ends the activity) and the ChainWidget extension
/// (which renders it) can see the same struct.
struct ChainActivityAttributes: ActivityAttributes {
    public typealias ChainState = ContentState

    /// Per-tick mutable state — the widget rebuilds its UI every time
    /// this is replaced via Activity.update(...).
    public struct ContentState: Codable, Hashable {
        /// Current chain count (1-N during a war, 0 between).
        public let chain: Int
        /// Wall-clock deadline (epoch ms) when the chain breaks. 0 if no
        /// active timer (chain dead / cooldown).
        public let timeoutDeadlineMs: Int64
        /// Wall-clock deadline (epoch ms) when post-break cooldown ends.
        /// 0 unless the chain just broke and we're in cooldown.
        public let cooldownDeadlineMs: Int64
        /// Live faction score (the user side), for context in the
        /// expanded presentation.
        public let myScore: Int
        /// Live enemy faction score.
        public let enemyScore: Int
        /// v0.4.61: personal status bars + cooldowns embedded into the
        /// Live Activity so the lock-screen/Dynamic-Island surface acts
        /// as a near-real-time status panel during war. Fields are
        /// optional (default to 0) so older push payloads without these
        /// fields keep decoding cleanly.
        public var energyCurrent: Int = 0
        public var energyMax: Int = 0
        public var nerveCurrent: Int = 0
        public var nerveMax: Int = 0
        /// Absolute epoch-ms deadlines so countdowns stay accurate even
        /// when the activity is read minutes after the push lands.
        public var drugDeadlineMs: Int64 = 0
        public var boosterDeadlineMs: Int64 = 0

        public init(chain: Int,
                    timeoutDeadlineMs: Int64,
                    cooldownDeadlineMs: Int64,
                    myScore: Int,
                    enemyScore: Int,
                    energyCurrent: Int = 0,
                    energyMax: Int = 0,
                    nerveCurrent: Int = 0,
                    nerveMax: Int = 0,
                    drugDeadlineMs: Int64 = 0,
                    boosterDeadlineMs: Int64 = 0) {
            self.chain = chain
            self.timeoutDeadlineMs = timeoutDeadlineMs
            self.cooldownDeadlineMs = cooldownDeadlineMs
            self.myScore = myScore
            self.enemyScore = enemyScore
            self.energyCurrent = energyCurrent
            self.energyMax = energyMax
            self.nerveCurrent = nerveCurrent
            self.nerveMax = nerveMax
            self.drugDeadlineMs = drugDeadlineMs
            self.boosterDeadlineMs = boosterDeadlineMs
        }
    }

    /// Static metadata — set once when the activity starts, never
    /// changes for the activity's lifetime. Survives app relaunches via
    /// ActivityKit's persistence.
    public let warId: String
    public let enemyName: String

    public init(warId: String, enemyName: String) {
        self.warId = warId
        self.enemyName = enemyName
    }
}
