import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity for the chain-break countdown. Shows up on the
/// lock screen and in the Dynamic Island whenever the warboard app
/// has an active chain it's tracking. Three Dynamic Island regions
/// (compact leading/trailing, expanded with all the detail, minimal
/// for the small bubble when multiple activities are competing for
/// the island).
struct ChainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChainActivityAttributes.self) { context in
            // Lock-screen / banner presentation.
            LockScreenChainView(state: context.state, attrs: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — when the user long-presses the island.
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Chain \(context.state.chain)")
                            .font(.subheadline.bold())
                    } icon: {
                        Image(systemName: "link").foregroundColor(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if isDeadlineLive(context.state.timeoutDeadlineMs) {
                        Text(timerInterval: dateRange(deadlineMs: context.state.timeoutDeadlineMs),
                             countsDown: true)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundColor(urgencyColor(deadlineMs: context.state.timeoutDeadlineMs))
                            .multilineTextAlignment(.trailing)
                    } else if isDeadlineLive(context.state.cooldownDeadlineMs) {
                        Text(timerInterval: dateRange(deadlineMs: context.state.cooldownDeadlineMs),
                             countsDown: true)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        // Either no deadline at all, or both deadlines
                        // are already in the past (= stale snapshot).
                        // Show chain count as the meaningful fallback
                        // rather than the misleading "0:00" that
                        // Text(timerInterval:) would render for a past
                        // date.
                        Text("\(context.state.chain)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("vs \(context.attributes.enemyName)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(context.state.myScore) – \(context.state.enemyScore)")
                            .font(.caption.bold().monospacedDigit())
                    }
                }
            } compactLeading: {
                Image(systemName: "link").foregroundColor(.orange)
            } compactTrailing: {
                if isDeadlineLive(context.state.timeoutDeadlineMs) {
                    Text(timerInterval: dateRange(deadlineMs: context.state.timeoutDeadlineMs),
                         countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(urgencyColor(deadlineMs: context.state.timeoutDeadlineMs))
                        .frame(width: 48)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("\(context.state.chain)")
                        .font(.caption2.bold())
                }
            } minimal: {
                Image(systemName: "link")
                    .foregroundColor(urgencyColor(deadlineMs: context.state.timeoutDeadlineMs))
            }
            .keylineTint(urgencyColor(deadlineMs: context.state.timeoutDeadlineMs))
        }
    }

    private func dateRange(deadlineMs: Int64) -> ClosedRange<Date> {
        let deadline = Date(timeIntervalSince1970: TimeInterval(deadlineMs) / 1000)
        return Date()...deadline
    }

    /// True if the deadline is meaningfully in the future. Used to gate
    /// `Text(timerInterval:)` so a past deadline (stale snapshot from a
    /// backgrounded activity) doesn't render as a stuck "0:00".
    private func isDeadlineLive(_ deadlineMs: Int64) -> Bool {
        guard deadlineMs > 0 else { return false }
        return deadlineMs > Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func urgencyColor(deadlineMs: Int64) -> Color {
        guard isDeadlineLive(deadlineMs) else { return .secondary }
        let remainingSec = max(0, (deadlineMs - Int64(Date().timeIntervalSince1970 * 1000)) / 1000)
        if remainingSec <= 30 { return .red }
        if remainingSec <= 60 { return .orange }
        return .green
    }
}

/// Lock-screen / banner card. Identical to the userscript's chain bar:
/// chain count + countdown to break, color-coded by urgency.
private struct LockScreenChainView: View {
    let state: ChainActivityAttributes.ContentState
    let attrs: ChainActivityAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Chain \(state.chain)")
                            .font(.subheadline.bold())
                        Text("vs \(attrs.enemyName)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if isDeadlineLive(state.timeoutDeadlineMs) {
                        HStack(spacing: 4) {
                            Text("breaks in")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(timerInterval: Date()...Date(timeIntervalSince1970: TimeInterval(state.timeoutDeadlineMs) / 1000),
                                 countsDown: true)
                                .font(.caption.bold().monospacedDigit())
                                .foregroundColor(urgencyColor(state.timeoutDeadlineMs))
                        }
                    } else if isDeadlineLive(state.cooldownDeadlineMs) {
                        HStack(spacing: 4) {
                            Text("cooldown")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(timerInterval: Date()...Date(timeIntervalSince1970: TimeInterval(state.cooldownDeadlineMs) / 1000),
                                 countsDown: true)
                                .font(.caption.bold().monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Text("\(state.myScore)–\(state.enemyScore)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // v0.4.61: bars + cooldowns embedded under the chain row.
            // Only shown when the BarReporter has pushed values at
            // least once (energyMax > 0). During war we get pushed
            // every 60s from BarReporter while app is foregrounded.
            if state.energyMax > 0 || state.nerveMax > 0
                || state.drugDeadlineMs > 0 || state.boosterDeadlineMs > 0 {
                BarsStripView(state: state)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func isDeadlineLive(_ deadlineMs: Int64) -> Bool {
        guard deadlineMs > 0 else { return false }
        return deadlineMs > Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func urgencyColor(_ deadlineMs: Int64) -> Color {
        guard isDeadlineLive(deadlineMs) else { return .secondary }
        let remainingSec = max(0, (deadlineMs - Int64(Date().timeIntervalSince1970 * 1000)) / 1000)
        if remainingSec <= 30 { return .red }
        if remainingSec <= 60 { return .orange }
        return .green
    }
}

/// v0.4.61: compact Energy/Nerve mini-bars + Drug/Booster cooldown
/// chips, shown beneath the chain row in the lock-screen Live Activity
/// presentation. Uses absolute deadlines so countdowns stay accurate
/// even when iOS reads a cached snapshot minutes after the last push.
private struct BarsStripView: View {
    let state: ChainActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            if state.energyMax > 0 {
                MiniBar(label: "E",
                        current: state.energyCurrent,
                        max: state.energyMax,
                        color: Color(red: 0.13, green: 0.83, blue: 0.94))
            }
            if state.nerveMax > 0 {
                MiniBar(label: "N",
                        current: state.nerveCurrent,
                        max: state.nerveMax,
                        color: .red)
            }
            if state.drugDeadlineMs > Int64(Date().timeIntervalSince1970 * 1000) {
                CooldownChip(label: "Drug",
                             deadlineMs: state.drugDeadlineMs,
                             tint: .purple)
            }
            if state.boosterDeadlineMs > Int64(Date().timeIntervalSince1970 * 1000) {
                CooldownChip(label: "Boost",
                             deadlineMs: state.boosterDeadlineMs,
                             tint: .green)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MiniBar: View {
    let label: String
    let current: Int
    let max: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(current)/\(max)")
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * fillFraction)
                }
            }
            .frame(height: 4)
        }
        .frame(minWidth: 56, maxWidth: 80)
    }

    private var fillFraction: Double {
        guard max > 0 else { return 0 }
        return min(1.0, Double(current) / Double(max))
    }
}

private struct CooldownChip: View {
    let label: String
    let deadlineMs: Int64
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(timerInterval: Date()...Date(timeIntervalSince1970: TimeInterval(deadlineMs) / 1000),
                 countsDown: true)
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}
