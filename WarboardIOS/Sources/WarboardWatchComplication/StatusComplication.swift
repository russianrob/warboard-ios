import WidgetKit
import SwiftUI

/// watchOS complication that mirrors the iPhone's Energy/Nerve bars on
/// the watch face. Reads from UserDefaults.standard (same process
/// group as the watch app, no App Group needed). Three families:
///   - accessoryCircular: small ring + numeric energy %
///   - accessoryRectangular: two stacked bars + counts
///   - accessoryInline: "E:140 N:75" text
///
/// Refresh model: timeline returns one entry now + a placeholder
/// 5 minutes out, so the cooldown labels stay reasonable as time
/// passes. The watch app force-reloads timelines whenever a new
/// applicationContext arrives — see WatchBarsStore.update.
struct StatusComplication: Widget {
    let kind: String = "WarboardStatus"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StatusComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                // widgetURL with the watch app's own scheme forces a
                // tap-launch back into the watch app. Without it, the
                // 4-ring layout was somehow eating taps on some faces.
                .widgetURL(URL(string: "warboardwatch://status"))
        }
        .configurationDisplayName("Warboard Status")
        .description("Energy and Nerve from Torn.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct StatusEntry: TimelineEntry {
    let date: Date
    let payload: WatchBarsPayload?
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: .now, payload: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: .now, payload: load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let payload = load()
        let now = Date()
        let entries = [
            StatusEntry(date: now, payload: payload),
            StatusEntry(date: now.addingTimeInterval(5 * 60), payload: payload),
        ]
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(5 * 60))))
    }
    private func load() -> WatchBarsPayload? {
        // App Group-shared with WarboardWatch (watch app + complication
        // run in separate processes on watchOS; standard UserDefaults
        // doesn't bridge them).
        let suite = UserDefaults(suiteName: "group.com.tornwar.warboard.watch") ?? .standard
        guard let data = suite.data(forKey: "warboard.watch.bars-payload.v1") else { return nil }
        return try? JSONDecoder().decode(WatchBarsPayload.self, from: data)
    }
}

private struct StatusComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        switch family {
        case .accessoryCircular: Circular(entry: entry)
        case .accessoryRectangular: Rectangular(entry: entry)
        case .accessoryInline: Inline(entry: entry)
        default: Circular(entry: entry)
        }
    }
}

// Color scheme matches the iPhone Status Live Activity + StatusView:
// Energy = yellow, Nerve = red, Drug = purple, Booster = blue.
private enum Stat { case energy, nerve, drug, booster
    var color: Color {
        switch self {
        case .energy: return .green
        case .nerve: return .red
        case .drug: return .purple
        case .booster: return .blue
        }
    }
    var letter: String {
        switch self {
        case .energy: return "E"
        case .nerve: return "N"
        case .drug: return "D"
        case .booster: return "B"
        }
    }
}

// Concentric-rings layout (like Activity rings on iPhone): four
// thin rings stacked at increasing inner radius. Energy outermost,
// then Nerve, Drug, Booster. Each ring fills based on its metric's
// fraction (0–1). Center shows the active-metric number — defaults
// to Energy since that's what users glance at most.
private struct Circular: View {
    let entry: StatusEntry
    private let lineWidth: CGFloat = 3
    private let gap: CGFloat = 1.5
    var body: some View {
        let p = entry.payload
        ZStack {
            ring(Stat.energy, fraction: energyFrac(), inset: 0)
            ring(Stat.nerve, fraction: nerveFrac(), inset: lineWidth + gap)
            ring(Stat.drug, fraction: cooldownFrac(deadline: p?.drugDeadlineMs ?? 0), inset: 2 * (lineWidth + gap))
            ring(Stat.booster, fraction: cooldownFrac(deadline: p?.boosterDeadlineMs ?? 0), inset: 3 * (lineWidth + gap))
            Text("\(p?.energyCurrent ?? 0)")
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.green)
        }
    }
    private func ring(_ stat: Stat, fraction: CGFloat, inset: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(stat.color.opacity(0.25), lineWidth: lineWidth)
                .padding(inset)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(stat.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(inset)
        }
    }
    private func energyFrac() -> CGFloat {
        guard let p = entry.payload, p.energyMax > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, CGFloat(p.energyCurrent) / CGFloat(p.energyMax)))
    }
    private func nerveFrac() -> CGFloat {
        guard let p = entry.payload, p.nerveMax > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, CGFloat(p.nerveCurrent) / CGFloat(p.nerveMax)))
    }
    // Cooldown ring fills when fresh (lots of time remaining), drains
    // toward 0 as the timer counts down. Ready = empty ring.
    // We don't know the original total cooldown duration (Torn never
    // tells us), so use (deadline - writtenAtMs) as the baseline:
    // when BarReporter first saw the cooldown, the ring was 100%;
    // every second after, it drains proportionally. If writtenAtMs
    // is stale, fall back to a 12h max so the ring still drains
    // smoothly.
    private func cooldownFrac(deadline: Int64) -> CGFloat {
        guard deadline > 0, let p = entry.payload else { return 0 }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if nowMs >= deadline { return 0 }
        let remaining = deadline - nowMs
        var total = deadline - p.writtenAtMs
        if total <= 0 { total = 12 * 3600 * 1000 } // fallback: 12h window
        return Swift.min(1, Swift.max(0, CGFloat(remaining) / CGFloat(total)))
    }
}

// Rectangular: four mini-bars stacked. Each gets its full color
// + a letter prefix + the current value. Tight enough that drug
// and booster fit alongside energy + nerve.
private struct Rectangular: View {
    let entry: StatusEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Row(stat: .energy, cur: entry.payload?.energyCurrent ?? 0, max: entry.payload?.energyMax ?? 0)
            Row(stat: .nerve, cur: entry.payload?.nerveCurrent ?? 0, max: entry.payload?.nerveMax ?? 0)
            CooldownRow(stat: .drug, deadlineMs: entry.payload?.drugDeadlineMs ?? 0)
            CooldownRow(stat: .booster, deadlineMs: entry.payload?.boosterDeadlineMs ?? 0)
        }
    }
}

private struct Row: View {
    let stat: Stat
    let cur: Int
    let max: Int
    var body: some View {
        HStack(spacing: 3) {
            Text(stat.letter).font(.system(size: 9, weight: .semibold)).foregroundStyle(stat.color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5).fill(stat.color.opacity(0.25))
                    RoundedRectangle(cornerRadius: 1.5).fill(stat.color)
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 3)
            Text("\(cur)").font(.system(size: 9)).monospacedDigit().frame(width: 28, alignment: .trailing)
        }
    }
    private var frac: CGFloat {
        guard max > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, CGFloat(cur) / CGFloat(max)))
    }
}

private struct CooldownRow: View {
    let stat: Stat
    let deadlineMs: Int64
    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 3) {
            Text(stat.letter).font(.system(size: 9, weight: .semibold)).foregroundStyle(stat.color)
            Text(text)
                .font(.system(size: 9)).monospacedDigit()
                .foregroundStyle(remaining > 0 ? stat.color : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onReceive(tick) { now = $0 }
    }
    private var remaining: Int {
        guard deadlineMs > 0 else { return 0 }
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        return Swift.max(0, Int((deadlineMs - nowMs) / 1000))
    }
    private var text: String {
        let s = remaining
        if s <= 0 { return "ready" }
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

private struct Inline: View {
    let entry: StatusEntry
    var body: some View {
        if let p = entry.payload {
            Text("E:\(p.energyCurrent) N:\(p.nerveCurrent)")
        } else {
            Text("E:— N:—")
        }
    }
}
