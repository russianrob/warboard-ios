import ActivityKit
import WidgetKit
import SwiftUI

/// Always-on Status Live Activity surface. Renders Energy / Nerve bars
/// + Drug / Booster countdown chips on the lock screen and Dynamic
/// Island. User starts via the Dashboard button; auto-renews on next
/// app launch when active.
struct StatusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StatusActivityAttributes.self) { context in
            // Lock-screen / banner card.
            StatusLockScreenView(state: context.state, attrs: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("E \(context.state.energyCurrent)/\(context.state.energyMax)")
                            .font(.caption.bold().monospacedDigit())
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(Color(red: 0.13, green: 0.83, blue: 0.94))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("N \(context.state.nerveCurrent)/\(context.state.nerveMax)")
                            .font(.caption.bold().monospacedDigit())
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if isDeadlineLive(context.state.drugDeadlineMs) {
                            DICooldownChip(label: "Drug",
                                           deadlineMs: context.state.drugDeadlineMs,
                                           tint: .purple)
                        }
                        if isDeadlineLive(context.state.boosterDeadlineMs) {
                            DICooldownChip(label: "Boost",
                                           deadlineMs: context.state.boosterDeadlineMs,
                                           tint: .green)
                        }
                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Color(red: 0.13, green: 0.83, blue: 0.94))
                    Text("\(context.state.energyCurrent)")
                        .font(.caption2.bold().monospacedDigit())
                }
            } compactTrailing: {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill").foregroundColor(.red)
                    Text("\(context.state.nerveCurrent)")
                        .font(.caption2.bold().monospacedDigit())
                }
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Color(red: 0.13, green: 0.83, blue: 0.94))
            }
            .keylineTint(Color(red: 0.13, green: 0.83, blue: 0.94))
        }
    }

    private func isDeadlineLive(_ deadlineMs: Int64) -> Bool {
        guard deadlineMs > 0 else { return false }
        return deadlineMs > Int64(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Lock-screen card

private struct StatusLockScreenView: View {
    let state: StatusActivityAttributes.ContentState
    let attrs: StatusActivityAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(.tertiary)
                Text(attrs.playerName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                FreshnessLabel(writtenAtMs: state.writtenAtMs)
            }
            BarRow(label: "Energy",
                   current: state.energyCurrent,
                   max: state.energyMax,
                   color: Color(red: 0.13, green: 0.83, blue: 0.94))
            BarRow(label: "Nerve",
                   current: state.nerveCurrent,
                   max: state.nerveMax,
                   color: .red)
            HStack(spacing: 8) {
                if state.drugDeadlineMs > Int64(Date().timeIntervalSince1970 * 1000) {
                    LSCooldownChip(label: "Drug",
                                   deadlineMs: state.drugDeadlineMs,
                                   tint: .purple)
                }
                if state.boosterDeadlineMs > Int64(Date().timeIntervalSince1970 * 1000) {
                    LSCooldownChip(label: "Booster",
                                   deadlineMs: state.boosterDeadlineMs,
                                   tint: .green)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct BarRow: View {
    let label: String
    let current: Int
    let max: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(current) / \(max)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(color).frame(width: geo.size.width * fillFraction)
                }
            }
            .frame(height: 6)
        }
    }

    private var fillFraction: Double {
        guard max > 0 else { return 0 }
        return min(1.0, Double(current) / Double(max))
    }
}

private struct LSCooldownChip: View {
    let label: String
    let deadlineMs: Int64
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.semibold))
            Text(timerInterval: Date()...Date(timeIntervalSince1970: TimeInterval(deadlineMs) / 1000),
                 countsDown: true)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.15)))
    }
}

private struct DICooldownChip: View {
    let label: String
    let deadlineMs: Int64
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(timerInterval: Date()...Date(timeIntervalSince1970: TimeInterval(deadlineMs) / 1000),
                 countsDown: true)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}

private struct FreshnessLabel: View {
    let writtenAtMs: Int64

    var body: some View {
        let writtenAt = Date(timeIntervalSince1970: Double(writtenAtMs) / 1000)
        let s = max(0, Int(Date().timeIntervalSince(writtenAt)))
        let label: String =
            s < 60   ? "live"
          : s < 3600 ? "\(s / 60)m ago"
          : s < 86400 ? "\(s / 3600)h ago"
          : "\(s / 86400)d ago"
        Text(label)
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}
