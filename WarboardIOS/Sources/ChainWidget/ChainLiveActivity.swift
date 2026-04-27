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
                    if context.state.timeoutDeadlineMs > 0 {
                        Text(timerInterval: dateRange(deadlineMs: context.state.timeoutDeadlineMs),
                             countsDown: true)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundColor(urgencyColor(deadlineMs: context.state.timeoutDeadlineMs))
                            .multilineTextAlignment(.trailing)
                    } else if context.state.cooldownDeadlineMs > 0 {
                        Text(timerInterval: dateRange(deadlineMs: context.state.cooldownDeadlineMs),
                             countsDown: true)
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("—").foregroundStyle(.secondary)
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
                if context.state.timeoutDeadlineMs > 0 {
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

    private func urgencyColor(deadlineMs: Int64) -> Color {
        guard deadlineMs > 0 else { return .secondary }
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
        HStack(spacing: 14) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Chain \(state.chain)")
                        .font(.subheadline.bold())
                    Text("vs \(attrs.enemyName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if state.timeoutDeadlineMs > 0 {
                    HStack(spacing: 4) {
                        Text("breaks in")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(timerInterval: Date()...Date(timeIntervalSince1970: TimeInterval(state.timeoutDeadlineMs) / 1000),
                             countsDown: true)
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(urgencyColor(state.timeoutDeadlineMs))
                    }
                } else if state.cooldownDeadlineMs > 0 {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func urgencyColor(_ deadlineMs: Int64) -> Color {
        guard deadlineMs > 0 else { return .secondary }
        let remainingSec = max(0, (deadlineMs - Int64(Date().timeIntervalSince1970 * 1000)) / 1000)
        if remainingSec <= 30 { return .red }
        if remainingSec <= 60 { return .orange }
        return .green
    }
}
