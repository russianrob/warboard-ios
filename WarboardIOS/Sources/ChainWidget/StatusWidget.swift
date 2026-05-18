import WidgetKit
import SwiftUI

/// Home-screen status widget — Energy / Nerve bars + Drug / Booster
/// countdowns. Data is read from the App Group-shared `BarsCache`
/// that the main app's `BarReporter` writes after each Torn API tick.
///
/// Refresh model: Apple budgets widget timeline refreshes at roughly
/// 30-40 per day per widget. The app force-pushes a reload whenever
/// fresh bars data lands (via `WidgetCenter.shared.reloadAllTimelines()`
/// in BarsCache.write), so as long as the user opens warboard at
/// least once an hour the widget stays fresh.
struct StatusWidget: Widget {
    let kind: String = "warboard-status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Warboard Status")
        .description("Live Energy, Nerve, and cooldown timers from your Torn dashboard.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct StatusEntry: TimelineEntry {
    let date: Date
    let snapshot: BarsCache.Snapshot?
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), snapshot: BarsCache.read()))
    }

    /// Ask iOS to render now, then re-poll in 15 min as a safety net
    /// in case the app isn't running to push a reload after the next
    /// BarReporter tick.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date()
        let entry = StatusEntry(date: now, snapshot: BarsCache.read())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snap = entry.snapshot {
            switch family {
            case .systemSmall:  StatusSmall(snap: snap, now: entry.date)
            default:            StatusMedium(snap: snap, now: entry.date)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Open warboard")
                    .font(.caption.bold())
                Text("to see your bars")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct StatusSmall: View {
    let snap: BarsCache.Snapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BarRow(label: "E", current: snap.energyCurrent, max: snap.energyMax,
                   color: Color(red: 0.13, green: 0.83, blue: 0.94))
            BarRow(label: "N", current: snap.nerveCurrent, max: snap.nerveMax, color: .red)
            HStack(spacing: 6) {
                CooldownChipCompact(label: "Drug", deadlineMs: snap.drugDeadlineMs, now: now, tint: .purple)
                CooldownChipCompact(label: "Boost", deadlineMs: snap.boosterDeadlineMs, now: now, tint: .green)
            }
            Spacer(minLength: 0)
            FreshnessLabel(writtenAtMs: snap.writtenAtMs, now: now)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusMedium: View {
    let snap: BarsCache.Snapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BarRow(label: "Energy", current: snap.energyCurrent, max: snap.energyMax,
                   color: Color(red: 0.13, green: 0.83, blue: 0.94), wide: true)
            BarRow(label: "Nerve", current: snap.nerveCurrent, max: snap.nerveMax,
                   color: .red, wide: true)
            HStack(spacing: 8) {
                CooldownChip(label: "Drug",    deadlineMs: snap.drugDeadlineMs,    now: now, tint: .purple)
                CooldownChip(label: "Booster", deadlineMs: snap.boosterDeadlineMs, now: now, tint: .green)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            FreshnessLabel(writtenAtMs: snap.writtenAtMs, now: now)
        }
    }
}

// MARK: - Bar + Chip components

private struct BarRow: View {
    let label: String
    let current: Int
    let max: Int
    let color: Color
    var wide: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(current)\(wide ? " / \(max)" : "/\(max)")")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * fillFraction)
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

private struct CooldownChip: View {
    let label: String
    let deadlineMs: Int64
    let now: Date
    let tint: Color

    var body: some View {
        let remaining = remainingSeconds(deadlineMs: deadlineMs, now: now)
        HStack(spacing: 4) {
            Circle().fill(remaining > 0 ? tint : .gray.opacity(0.4))
                .frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.semibold))
            Text(remaining > 0 ? formatCountdown(remaining) : "—")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(remaining > 0 ? 0.15 : 0.05)))
    }
}

private struct CooldownChipCompact: View {
    let label: String
    let deadlineMs: Int64
    let now: Date
    let tint: Color

    var body: some View {
        let remaining = remainingSeconds(deadlineMs: deadlineMs, now: now)
        HStack(spacing: 3) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            Text(remaining > 0 ? formatCountdown(remaining) : "—")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(remaining > 0 ? tint : .secondary)
        }
    }
}

private struct FreshnessLabel: View {
    let writtenAtMs: Int64
    let now: Date

    var body: some View {
        Text("synced \(formatAge(now: now, writtenAtMs: writtenAtMs))")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Formatting helpers

private func remainingSeconds(deadlineMs: Int64, now: Date) -> Int {
    let nowMs = Int64(now.timeIntervalSince1970 * 1000)
    let diff = deadlineMs - nowMs
    if diff <= 0 { return 0 }
    return Int(diff / 1000)
}

private func formatCountdown(_ s: Int) -> String {
    if s >= 3600 { return "\(s / 3600)h\((s % 3600) / 60)m" }
    if s >= 60 { return "\(s / 60)m\(s % 60)s" }
    return "\(s)s"
}

private func formatAge(now: Date, writtenAtMs: Int64) -> String {
    let writtenAt = Date(timeIntervalSince1970: Double(writtenAtMs) / 1000)
    let s = max(0, Int(now.timeIntervalSince(writtenAt)))
    if s < 60 { return "just now" }
    if s < 3600 { return "\(s / 60)m ago" }
    if s < 86400 { return "\(s / 3600)h ago" }
    return "\(s / 86400)d ago"
}
