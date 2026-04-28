import SwiftUI

/// Shared chain bar — same BarRow visual as Energy / Nerve. Used in
/// both the Status tab (next to the personal bars) and the War Room
/// header so they look identical / flush. Driven by raw values so
/// the caller picks the data source (typically ChainTickerViewModel,
/// which polls Torn /v2/faction directly for the freshest data).
struct ChainBarRow: View {
    let chainCurrent: Int
    let nextMilestone: Int
    let timeoutDeadlineMs: Int64
    let cooldownDeadlineMs: Int64
    let nowMs: Int64

    var body: some View {
        let nextMs = max(nextMilestone, 1)
        let toRemaining = timeoutDeadlineMs > 0
            ? max(0, Int((timeoutDeadlineMs - nowMs) / 1000)) : 0
        let cdRemaining = cooldownDeadlineMs > 0
            ? max(0, Int((cooldownDeadlineMs - nowMs) / 1000)) : 0
        let pct = Double(chainCurrent) / Double(nextMs)
        let color: Color = chainCurrent == 0 ? .secondary
                         : (toRemaining > 0 && toRemaining <= 30) ? .red
                         : (toRemaining > 0 && toRemaining <= 60) ? .orange
                         : .orange

        VStack(spacing: 4) {
            HStack {
                Text("Chain").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(chainCurrent) / \(nextMilestone)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: pct).tint(color)
            if chainCurrent == 0 {
                HStack {
                    Spacer()
                    Text("no chain").font(.caption2).foregroundStyle(.secondary)
                }
            } else if cdRemaining > 0 {
                HStack {
                    Spacer()
                    Text("Cooldown \(formatDur(cdRemaining))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else if toRemaining > 0 {
                HStack {
                    Spacer()
                    Text("Breaks in \(formatDur(toRemaining))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(toRemaining <= 30 ? .red
                                       : toRemaining <= 60 ? .orange : .secondary)
                }
            }
        }
    }
}
