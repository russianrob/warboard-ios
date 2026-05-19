import SwiftUI

/// Watch app main screen. Shows current Energy / Nerve as labeled
/// bars and any active Drug / Booster countdowns. Tapping nothing —
/// it's a status mirror, not a control surface (Torn's mutate actions
/// require an active web session, which the watch doesn't have).
struct StatusView: View {
    @EnvironmentObject private var store: WatchBarsStore

    var body: some View {
        if let payload = store.payload {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Bar(label: "Energy",
                        current: payload.energyCurrent,
                        max: payload.energyMax,
                        color: .yellow)
                    Bar(label: "Nerve",
                        current: payload.nerveCurrent,
                        max: payload.nerveMax,
                        color: .red)
                    Cooldown(label: "Drug",
                             deadlineMs: payload.drugDeadlineMs,
                             color: .purple)
                    Cooldown(label: "Booster",
                             deadlineMs: payload.boosterDeadlineMs,
                             color: .blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        } else {
            VStack(spacing: 6) {
                Text("Warboard")
                    .font(.headline)
                Text("Waiting for iPhone…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

private struct Bar: View {
    let label: String
    let current: Int
    let max: Int
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(current) / \(max)").font(.caption2).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * fillFraction)
                }
            }
            .frame(height: 6)
        }
    }
    private var fillFraction: CGFloat {
        guard max > 0 else { return 0 }
        return Swift.min(1, Swift.max(0, CGFloat(current) / CGFloat(max)))
    }
}

private struct Cooldown: View {
    let label: String
    let deadlineMs: Int64
    let color: Color
    @State private var now = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2)
            Spacer()
            Text(text).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
        .onReceive(tick) { now = $0 }
    }
    private var text: String {
        if deadlineMs <= 0 { return "ready" }
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let remaining = (deadlineMs - nowMs) / 1000
        if remaining <= 0 { return "ready" }
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

