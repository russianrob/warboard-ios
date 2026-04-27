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

        public init(chain: Int,
                    timeoutDeadlineMs: Int64,
                    cooldownDeadlineMs: Int64,
                    myScore: Int,
                    enemyScore: Int) {
            self.chain = chain
            self.timeoutDeadlineMs = timeoutDeadlineMs
            self.cooldownDeadlineMs = cooldownDeadlineMs
            self.myScore = myScore
            self.enemyScore = enemyScore
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
