import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @EnvironmentObject private var chainTicker: ChainTickerViewModel
    @StateObject private var vm = DashboardViewModel()
    /// Per-second tick so the bar / cooldown / travel countdowns
    /// decrement smoothly between 30 s API polls.
    @State private var nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            switch vm.state {
            case .noKey:
                MessageView(icon: "key.slash", text: "Set your Torn API key in Settings.")
            case .loading:
                ProgressView().controlSize(.large)
            case .error(let msg):
                MessageView(icon: "exclamationmark.triangle.fill", text: msg)
            case .ready(let snap):
                ScrollView {
                    DashboardBody(snap: snap, nowMs: nowMs, chainTicker: chainTicker).padding(16)
                }
                .refreshable { await vm.refresh() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Status")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if vm.refreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button { Task { await vm.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear { vm.bind(prefs: prefs); vm.start() }
        .onDisappear { vm.stop() }
        .onReceive(ticker) { _ in
            nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        }
    }
}

private struct MessageView: View {
    let icon: String; let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DashboardBody: View {
    let snap: TornAPI.DashboardSnapshot
    let nowMs: Int64
    @ObservedObject var chainTicker: ChainTickerViewModel

    /// Seconds elapsed since the snapshot was fetched. Used to age all
    /// the snap.* countdowns so they tick smoothly between polls.
    private var elapsed: Int {
        max(0, Int((nowMs - Int64(snap.fetchedAt.timeIntervalSince1970 * 1000)) / 1000))
    }
    private func live(_ seconds: Int) -> Int { max(0, seconds - elapsed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header line — name · faction · role. Role only shown
            // when the API returned one (Limited keys may not).
            let header: String = {
                var parts = [snap.playerName]
                if let f = snap.factionName, !f.isEmpty { parts.append(f) }
                if let r = snap.factionPosition, !r.isEmpty { parts.append(r) }
                return parts.joined(separator: " · ")
            }()
            Text(header)
                .font(.headline).foregroundStyle(.secondary)

            if snap.statusState.lowercased() != "okay" && !snap.statusState.isEmpty {
                StatusBanner(snap: snap, secondsLeft: live(snap.statusSecondsLeft))
            }

            BarRow(label: "Energy",  bar: snap.energy, color: Color(red: 0.13, green: 0.83, blue: 0.94), elapsed: elapsed)
            BarRow(label: "Nerve",   bar: snap.nerve,  color: .red,    elapsed: elapsed)
            BarRow(label: "Happy",   bar: snap.happy,  color: .yellow, elapsed: elapsed)
            BarRow(label: "Life",    bar: snap.life,   color: .green,  elapsed: elapsed)

            // v0.4.62: Start / stop the always-on Status Live Activity.
            // Foreground updates only — BarReporter pushes every 60s
            // while the app is open. Activity persists on lock screen
            // + Dynamic Island even after backgrounding (last-known
            // values + accurate cooldown countdowns via Text(timerInterval:)).
            StatusLiveActivityButton(snap: snap, drugSeconds: live(snap.drugSeconds), boosterSeconds: live(snap.boosterSeconds))
            // Chain bar lives in the same Status section so users see
            // it alongside Energy/Nerve. Synthesised from the
            // ChainTickerViewModel (always-on chain poll, no war
            // required) — same BarRow visual as the personal bars.
            ChainBarRow(
                chainCurrent: chainTicker.chainCurrent,
                nextMilestone: chainTicker.nextMilestone > 0 ? chainTicker.nextMilestone : 10,
                timeoutDeadlineMs: chainTicker.timeoutDeadlineMs,
                cooldownDeadlineMs: chainTicker.cooldownDeadlineMs,
                nowMs: nowMs,
            )

            let drug    = live(snap.drugSeconds)
            let medical = live(snap.medicalSeconds)
            let booster = live(snap.boosterSeconds)
            if drug > 0 || medical > 0 || booster > 0 {
                Divider().padding(.vertical, 4)
                Text("Cooldowns").font(.caption.bold()).foregroundStyle(.secondary)
                if drug > 0    { CooldownChip(label: "Drug",    seconds: drug,    tint: .purple) }
                if medical > 0 { CooldownChip(label: "Medical", seconds: medical, tint: .red) }
                if booster > 0 { CooldownChip(label: "Booster", seconds: booster, tint: .green) }
            }

            if let dest = snap.travelDestination {
                let leftSec = live(snap.travelSecondsLeft)
                Divider().padding(.vertical, 4)
                HStack {
                    Image(systemName: "airplane").foregroundColor(.cyan)
                    Text("Flying to \(dest)" + (leftSec > 0 ? " — lands in \(formatDur(leftSec))" : ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.cyan)
                }
                .padding(10)
                .background(Color.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

/// Start / stop the always-on Status Live Activity. Lives in the
/// Dashboard so the button sits next to the bars it surfaces. Reflects
/// live `isActive` state so re-opening the app while the activity is
/// still running shows the Stop button instead of a redundant Start.
private struct StatusLiveActivityButton: View {
    @EnvironmentObject private var prefs: PrefsStore
    let snap: TornAPI.DashboardSnapshot
    let drugSeconds: Int
    let boosterSeconds: Int
    @State private var isActive: Bool = {
        if #available(iOS 16.2, *) {
            StatusLiveActivityController.shared.adoptExisting()
            return StatusLiveActivityController.shared.isActive
        }
        return false
    }()
    private let ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        if #available(iOS 16.2, *) {
            Button {
                if isActive {
                    StatusLiveActivityController.shared.stop()
                } else {
                    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                    let drugDl    = drugSeconds > 0    ? nowMs + Int64(drugSeconds) * 1000    : 0
                    let boosterDl = boosterSeconds > 0 ? nowMs + Int64(boosterSeconds) * 1000 : 0
                    let auth = prefs.cachedJwt()
                    StatusLiveActivityController.shared.start(
                        playerName: snap.playerName,
                        initialState: StatusActivityAttributes.ContentState(
                            energyCurrent: snap.energy.current,
                            energyMax:     snap.energy.maximum,
                            nerveCurrent:  snap.nerve.current,
                            nerveMax:      snap.nerve.maximum,
                            drugDeadlineMs:    drugDl,
                            boosterDeadlineMs: boosterDl,
                            writtenAtMs: nowMs
                        ),
                        baseUrl: prefs.baseUrl,
                        jwt: auth?.token ?? "",
                        apiKey: prefs.apiKey
                    )
                }
                // Reflect new state immediately; the ticker below also
                // re-checks every 2s in case the activity ends on its
                // own (12h expiry, user dismisses from lock screen, etc.).
                isActive = StatusLiveActivityController.shared.isActive
            } label: {
                Label(isActive ? "Stop Live Activity" : "Start Live Activity",
                      systemImage: isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(isActive ? .red : .accentColor)
            .controlSize(.small)
            .onReceive(ticker) { _ in
                isActive = StatusLiveActivityController.shared.isActive
            }
        }
    }
}

private struct BarRow: View {
    let label: String
    let bar: TornAPI.Bar
    let color: Color
    /// Seconds elapsed since the snapshot was taken.
    let elapsed: Int

    var body: some View {
        // Live current = snap.current + (elapsed / interval) ticks,
        // capped at maximum. We don't have the interval per-bar in the
        // snapshot, so just decrement fulltime and let the API refresh
        // overwrite the current value every 30 s. Visually the
        // "Full in" line counts down smoothly which is what users
        // notice; the numeric current updates in chunks.
        let pct = bar.maximum > 0 ? Double(bar.current) / Double(bar.maximum) : 0
        let liveFulltime = max(0, bar.fulltime - elapsed)
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(bar.current) / \(bar.maximum)").font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: pct).tint(color)
            if liveFulltime > 0 && bar.current < bar.maximum {
                HStack {
                    Spacer()
                    Text("Full in \(formatDur(liveFulltime))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CooldownChip: View {
    let label: String; let seconds: Int; let tint: Color
    var body: some View {
        HStack {
            Image(systemName: "clock.fill").foregroundColor(tint)
            Text("\(label): \(formatDur(seconds))")
                .font(.subheadline.monospacedDigit())
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct StatusBanner: View {
    let snap: TornAPI.DashboardSnapshot
    let secondsLeft: Int
    var body: some View {
        let color: Color = {
            switch snap.statusState.lowercased() {
            case "hospital": return .red
            case "jail":     return .purple
            case "traveling", "abroad": return .cyan
            case "federal":  return .orange
            default:         return .gray
            }
        }()
        HStack {
            Image(systemName: stateIcon).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.statusState).font(.subheadline.bold()).foregroundColor(color)
                if !snap.statusDescription.isEmpty {
                    Text(snap.statusDescription).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if secondsLeft > 0 {
                Text(formatDur(secondsLeft))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(color)
            }
        }
        .padding(10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private var stateIcon: String {
        switch snap.statusState.lowercased() {
        case "hospital": return "cross.case.fill"
        case "jail":     return "lock.fill"
        case "traveling", "abroad": return "airplane"
        case "federal":  return "building.columns.fill"
        default:         return "circle.fill"
        }
    }
}
