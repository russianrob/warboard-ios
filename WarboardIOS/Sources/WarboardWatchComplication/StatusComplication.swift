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
        guard let data = UserDefaults.standard.data(forKey: "warboard.watch.bars-payload.v1") else { return nil }
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

private struct Circular: View {
    let entry: StatusEntry
    var body: some View {
        let pct = energyFraction()
        ZStack {
            Circle()
                .stroke(.yellow.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(.yellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("E").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                Text("\(entry.payload?.energyCurrent ?? 0)").font(.system(size: 14, weight: .bold)).monospacedDigit()
            }
        }
    }
    private func energyFraction() -> CGFloat {
        guard let p = entry.payload, p.energyMax > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, CGFloat(p.energyCurrent) / CGFloat(p.energyMax)))
    }
}

private struct Rectangular: View {
    let entry: StatusEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Row(label: "E", color: .yellow,
                cur: entry.payload?.energyCurrent ?? 0,
                max: entry.payload?.energyMax ?? 0)
            Row(label: "N", color: .red,
                cur: entry.payload?.nerveCurrent ?? 0,
                max: entry.payload?.nerveMax ?? 0)
        }
    }
}

private struct Row: View {
    let label: String
    let color: Color
    let cur: Int
    let max: Int
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.25))
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * frac)
                }
            }
            .frame(height: 4)
            Text("\(cur)").font(.caption2).monospacedDigit()
        }
    }
    private var frac: CGFloat {
        guard max > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, CGFloat(cur) / CGFloat(max)))
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
