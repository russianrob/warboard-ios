import SwiftUI
import UIKit

enum WarSubTab: String, CaseIterable, Identifiable {
    case targets, chat, report, heatmap
    var id: String { rawValue }
    var label: String {
        switch self {
        case .targets: return "Targets"
        case .chat:    return "Chat"
        case .report:  return "Report"
        case .heatmap: return "Heatmap"
        }
    }
}

struct WarRoomView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var vm = WarRoomViewModel()
    @State private var nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    @State private var subTab: WarSubTab = .targets
    @State private var showShout = false
    @State private var shoutText = ""
    @State private var showPostWar = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $subTab) {
                ForEach(WarSubTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.top, 8)

            switch vm.state {
            case .noKey:
                MessageView(icon: "key.slash", text: "Set your Torn API key in Settings.")
            case .loading:
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .noWar:
                MessageView(icon: "shield.slash", text: "No active war.")
            case .active(let war):
                switch subTab {
                case .targets:
                    WarBody(war: war, poll: vm.poll, nowMs: nowMs,
                            enemyStats: vm.enemyStats,
                            travelInfo: vm.travelInfo,
                            onCall:   { target in Task { await vm.call(target) } },
                            onUncall: { target in Task { await vm.uncall(target) } },
                            onDeal:   { target in Task { await vm.dealCall(target) } },
                            onShowReport: {
                                showPostWar = true
                                if vm.postWarReport == nil { vm.loadPostWarReport() }
                            })
                case .chat:
                    ChatPanel(warId: war.warId)
                case .report:
                    ReportTab(report: vm.scoutReport, loading: vm.scoutLoading,
                              onLoad: { vm.loadScoutReport() })
                case .heatmap:
                    HeatmapTab(ours: vm.ourHeatmap, theirs: vm.theirHeatmap)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showShout = true }) {
                    Image(systemName: "megaphone.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { vm.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showShout) {
            ShoutSheet(text: $shoutText, onSend: {
                if !shoutText.trimmingCharacters(in: .whitespaces).isEmpty {
                    vm.sendShout(shoutText.trimmingCharacters(in: .whitespaces))
                    shoutText = ""
                }
                showShout = false
            }, onCancel: { showShout = false })
        }
        .sheet(isPresented: $showPostWar) {
            if let report = vm.postWarReport {
                PostWarReportView(report: report)
            } else if vm.postWarLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Loading post-war report…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40)).foregroundStyle(.orange)
                    Text(vm.postWarError ?? "Couldn't load report.").foregroundStyle(.secondary)
                    Button("Retry") { vm.loadPostWarReport() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert(item: Binding(
            get: { vm.shoutResult.map { IdString(value: $0) } },
            set: { _ in vm.shoutResult = nil })
        ) { msg in
            Alert(title: Text(msg.value))
        }
        .navigationTitle("War Room")
        .toolbar {
            // Realtime connection indicator. Green dot = Socket.IO is
            // open (broadcasts/status updates arrive instantly), grey =
            // poll-only fallback. Useful when debugging "did my shout
            // actually go out?".
            ToolbarItem(placement: .navigationBarTrailing) {
                RealtimeIndicator()
            }
        }
        .onAppear {
            vm.bind(prefs: prefs)
            vm.start()
        }
        .onDisappear { vm.stop() }
        .onReceive(ticker) { _ in
            nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        }
        .onChange(of: subTab) { _, new in
            // First time the user opens the report tab, kick the fetch.
            if new == .report && vm.scoutReport == nil && !vm.scoutLoading {
                vm.loadScoutReport()
            }
        }
    }
}

private struct MessageView: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WarBody: View {
    let war: WarSnapshot
    let poll: WarPoll?
    let nowMs: Int64
    let enemyStats: [String: Int64]
    let travelInfo: [String: TravelInfo]
    let onCall: (EnemyTarget) -> Void
    let onUncall: (EnemyTarget) -> Void
    let onDeal: (EnemyTarget) -> Void
    let onShowReport: () -> Void

    var body: some View {
        let warEnded = poll?.warEnded == true
        VStack(spacing: 0) {
            HeaderCard(war: war, poll: poll, nowMs: nowMs)
                .padding(12)
            if warEnded {
                WarEndedBanner(war: war, poll: poll, onShowReport: onShowReport)
            }
            Divider()
            TargetList(war: war, nowMs: nowMs,
                       enemyStats: enemyStats, travelInfo: travelInfo,
                       onCall: onCall, onUncall: onUncall, onDeal: onDeal,
                       warEnded: warEnded)
                .opacity(warEnded ? 0.4 : 1.0)
                .allowsHitTesting(!warEnded)
        }
    }
}

/// Post-war banner — VICTORY / DEFEAT / DRAW with the final score.
/// Mirrors the factionops userscript's showWarEndedBanner styling
/// (green/red/yellow tints).
private struct WarEndedBanner: View {
    let war: WarSnapshot
    let poll: WarPoll?
    let onShowReport: () -> Void

    var body: some View {
        let myScore    = poll?.myScore    ?? war.myScore
        let enemyScore = poll?.enemyScore ?? war.enemyScore
        let isVictory = myScore > enemyScore
        let result: (label: String, color: Color, bg: Color) = isVictory
            ? ("VICTORY", Color(red: 0.00, green: 0.72, blue: 0.58),
                          Color(red: 0.00, green: 0.72, blue: 0.58).opacity(0.12))
            : ("DEFEAT",  Color(red: 1.00, green: 0.46, blue: 0.46),
                          Color(red: 1.00, green: 0.46, blue: 0.46).opacity(0.12))
        VStack(spacing: 6) {
            Text(result.label)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundColor(result.color)
            Text("\(myScore) – \(enemyScore)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(action: onShowReport) {
                Label("View Post-War Report", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(result.color)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(result.bg)
    }
}

private struct HeaderCard: View {
    let war: WarSnapshot
    let poll: WarPoll?
    let nowMs: Int64

    var body: some View {
        let myScore    = poll?.myScore    ?? war.myScore
        let enemyScore = poll?.enemyScore ?? war.enemyScore
        let target     = poll?.targetScore ?? war.currentTarget ?? 0
        let scoreColor: Color = (myScore == 0 && enemyScore == 0) ? .secondary
            : (myScore >= enemyScore ? .green : .red)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(war.enemyFactionName ?? poll?.enemyFactionName ?? "Enemy \(war.enemyFactionId)")")
                    .font(.headline)
                Spacer()
                if let online = poll?.ourFactionOnline {
                    Text("Us \(online)").foregroundStyle(.secondary).font(.caption)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(myScore) – \(enemyScore)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                Spacer()
                if target > 0 {
                    Text("target \(target)")
                        .foregroundStyle(.secondary).font(.caption)
                }
            }
            WarTimerRow(war: war, poll: poll, nowMs: nowMs)
            // Chain bar lives in the Status tab only — having it here
            // too caused the Status copy to lag because both tabs were
            // tugging on the same min-deadline guard.
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// War-end estimate. Mirrors the torn-ranked-war-timer.user.js formula:
/// the target score drops 1 % of its original value per hour after the
/// 24-hour mark, so the time until war-end is `gap / drop_per_hour`
/// where `lead = abs(myScore - enemyScore)` and `gap = target - lead`.
/// Unavailable until 24 h elapsed (target hasn't started dropping yet).
private struct WarTimerRow: View {
    let war: WarSnapshot
    let poll: WarPoll?
    let nowMs: Int64

    var body: some View {
        // War over — banner takes over below; suppress the countdown.
        if poll?.warEnded == true {
            return AnyView(EmptyView())
        }
        let myScore    = poll?.myScore    ?? war.myScore
        let enemyScore = poll?.enemyScore ?? war.enemyScore
        let target     = poll?.targetScore ?? war.currentTarget ?? 0
        guard let warStart = war.warStart, warStart > 0, target > 0 else {
            return AnyView(EmptyView())
        }
        let elapsedHours = Double(nowMs / 1000 - warStart) / 3600
        if elapsedHours <= 24 {
            // Wait for the drop phase to start.
            let waitHours = max(0, 24 - elapsedHours)
            return AnyView(
                Label("Drop starts in \(formatHM(Int(waitHours * 3600)))",
                      systemImage: "hourglass")
                    .foregroundStyle(.secondary).font(.caption.bold())
            )
        }
        let dropHours = floor(elapsedHours - 24)
        // Reverse-engineer the original target from the current target +
        // how many 1 % drops have happened.
        let originalTarget = Double(target) / max(0.01, 1 - (dropHours * 0.01))
        let dropPerHour = originalTarget * 0.01
        let lead = abs(myScore - enemyScore)
        let gap = max(0, Double(target - lead))
        if gap <= 0 {
            return AnyView(
                Label("War ending now", systemImage: "flag.checkered")
                    .foregroundStyle(.green).font(.caption.bold())
            )
        }
        let remHours = gap / dropPerHour
        let remSeconds = Int(remHours * 3600)
        let color: Color = remHours <= 2 ? .red : remHours <= 6 ? .orange : .green
        return AnyView(
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("ends in \(formatHM(remSeconds))")
                    .monospacedDigit()
            }
            .font(.caption.bold())
            .foregroundColor(color)
        )
    }

    /// HH:MM (or H:MM if under 10 h) — matches the userscript display.
    private func formatHM(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }
}

private struct TargetList: View {
    let war: WarSnapshot
    let nowMs: Int64
    let enemyStats: [String: Int64]
    let travelInfo: [String: TravelInfo]
    let onCall: (EnemyTarget) -> Void
    let onUncall: (EnemyTarget) -> Void
    let onDeal: (EnemyTarget) -> Void
    let warEnded: Bool

    var body: some View {
        // Skip the per-tick remap when the war has ended — we're in the
        // post-war hold state, no countdowns matter, and creating fresh
        // EnemyTarget instances each tick was triggering SwiftUI List's
        // built-in move animations even with stable IDs (the user
        // perceived this as "rows moving back and forth" while the
        // DEFEAT/VICTORY banner was up). When live, the remap stays —
        // it's what powers the live "X:YY" countdown chips.
        // ViewBuilder doesn't allow if/else for value assignment, so
        // compute via an immediately-invoked closure.
        let live: [EnemyTarget] = warEnded ? war.targets : war.targets.map { t -> EnemyTarget in
            guard t.releaseAtMs > 0 else { return t }
            let remaining = max(0, (t.releaseAtMs - nowMs) / 1000)
            return EnemyTarget(
                id: t.id, name: t.name, level: t.level, status: t.status,
                description: t.description, untilSec: remaining,
                releaseAtMs: t.releaseAtMs, activity: t.activity,
                calledBy: t.calledBy, calledById: t.calledById,
                calledIsDeal: t.calledIsDeal
            )
        }
        // Sort by (priority, releaseAtMs, id):
        //   - priority — bucket order (called → okay/online → okay/idle → …)
        //   - releaseAtMs — within bucket, sooner-available floats up
        //   - id — TIE-BREAKER. Two okay/online targets both have
        //          releaseAtMs=0; without a tertiary key, ties resolve
        //          on input order, and Torn's enemyStatuses keys come
        //          back in different orders between fetches → tied rows
        //          visibly swap places on each refresh. Locking on id
        //          makes ordering deterministic across renders.
        let sorted = live.sorted { lhs, rhs in
            let lp = priority(lhs); let rp = priority(rhs)
            if lp != rp { return lp < rp }
            if lhs.releaseAtMs != rhs.releaseAtMs { return lhs.releaseAtMs < rhs.releaseAtMs }
            return lhs.id < rhs.id
        }
        List(sorted) { t in
            TargetRow(target: t,
                      stats: enemyStats[t.id],
                      travel: travelInfo[t.id],
                      nowMs: nowMs,
                      onCall: onCall, onUncall: onUncall, onDeal: onDeal)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        // Belt-and-suspenders: even with stable IDs + sort, disable any
        // implicit list animations driven by per-second nowMs ticks.
        // SwiftUI's default List animation otherwise re-runs on each
        // body re-eval whenever the (sorted) array reference changes,
        // which is every second.
        .animation(nil, value: nowMs)
    }

    /// Sort priority — called targets pinned to the very top (you're
    /// committing to attack, want quick access), then actionable
    /// targets, then unavailable at the bottom. This is the inverse
    /// of the previous bottom-pinning; user wants their called
    /// targets surfaced for fast tap-through.
    private func priority(_ t: EnemyTarget) -> Double {
        if !(t.calledBy ?? "").isEmpty { return 0.0 }
        switch t.status.lowercased() {
        case "okay", "ok":          return t.activity == "online" ? 1.0 : 1.5
        case "hospital":            return 2.0
        case "traveling", "abroad": return 3.0
        case "jail":                return 4.0
        case "federal", "fallen":   return 7.0
        default:                    return 6.0
        }
    }
}

private struct TargetRow: View {
    let target: EnemyTarget
    let stats: Int64?
    let travel: TravelInfo?
    let nowMs: Int64
    let onCall: (EnemyTarget) -> Void
    let onUncall: (EnemyTarget) -> Void
    let onDeal: (EnemyTarget) -> Void
    @EnvironmentObject private var prefs: PrefsStore
    @State private var sheet: SafariSheet?
    /// Track whether the user is currently holding the Call button.
    /// Tints the button orange during the press so the user has visual
    /// confirmation the long-press is registering before the 0.6s deal-
    /// call threshold triggers. Mirrors factionops' pattern at
    /// factionops.user.js:8386 (mousedown → 600ms timer →
    /// emitCallTarget(targetId, true) → "Deal call placed" toast).
    /// (v0.4.37 originally placed this gesture on the red Attack button;
    /// v0.4.38 moved it to Call to match the userscript and unify UX
    /// across iOS / Android / web.)
    @State private var callPressing = false
    @State private var dealJustPlaced = false
    /// Long-press timer for the Call button. We can't use SwiftUI's
    /// `.onLongPressGesture` because Button's internal tap recognizer
    /// absorbs the press and short-circuits the long-press threshold —
    /// in v0.4.38 production we observed every press logging server-side
    /// as `called` (isDeal=false) regardless of hold duration. Manual
    /// DragGesture with our own Task-based timer sidesteps the conflict.
    @State private var callPressTimer: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(activityColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(target.name).font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text("L\(target.level)").font(.caption2).foregroundStyle(.secondary)
                    if let s = stats { StatChip(total: s) }
                }
            }
            Spacer()
            StatusChip(target: target, travel: travel, nowMs: nowMs)
            if let caller = target.calledBy {
                // Deal calls (long-press) get an orange tint + 🔒 prefix
                // so they're distinguishable at a glance from regular
                // calls. Mirrors factionops's .fo-called-tag.fo-called-deal
                // styling on web.
                Button(action: { onUncall(target) }) {
                    HStack(spacing: 3) {
                        if target.calledIsDeal {
                            Text("🔒").font(.caption2)
                        }
                        Text("by \(caller)")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(target.calledIsDeal ? .orange : Color.accentColor)
            } else if target.status.lowercased() == "okay" {
                // Custom-styled "Call" pill driven by a manual DragGesture
                // so we control press-down / release / long-press timing
                // ourselves. SwiftUI's Button + .onLongPressGesture combo
                // didn't deliver the long-press threshold reliably (v0.4.38
                // shipped that path; production calls all came through
                // with isDeal=false), so this version owns the gesture
                // pipeline outright.
                Text("Call")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(callPressing ? Color.orange : Color.accentColor)
                    .clipShape(Capsule())
                    .scaleEffect(callPressing ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: callPressing)
                    .contentShape(Capsule())   // hit-test the full pill, not just the text
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !callPressing {
                                    callPressing = true
                                    callPressTimer?.cancel()
                                    callPressTimer = Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 600_000_000)
                                        guard !Task.isCancelled else { return }
                                        // 0.6s reached → deal call
                                        onDeal(target)
                                        dealJustPlaced = true
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    }
                                }
                            }
                            .onEnded { _ in
                                callPressing = false
                                callPressTimer?.cancel()
                                callPressTimer = nil
                                // If the long-press already fired the
                                // deal call, suppress the "released =
                                // tap = regular call" path. Otherwise
                                // a quick release fires a normal call.
                                if dealJustPlaced {
                                    dealJustPlaced = false
                                    return
                                }
                                onCall(target)
                            }
                    )
            }
            if target.status.lowercased() == "okay" {
                Button("Attack") {
                    openLink("https://www.torn.com/loader.php?sid=attack&user2ID=\(target.id)")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            openLink("https://www.torn.com/profiles.php?XID=\(target.id)")
        }
        .sheet(item: $sheet) { $0 }
    }

    /// Routes through the in-app Safari sheet or the system browser
    /// based on the user's `linkOpenInApp` pref.
    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if prefs.linkOpenInApp {
            sheet = url.asSafariSheet
        } else {
            UIApplication.shared.open(url)
        }
    }

    private var activityColor: Color {
        switch target.activity { case "online": return .green; case "idle": return .yellow; default: return .gray }
    }
}

private struct StatusChip: View {
    let target: EnemyTarget
    let travel: TravelInfo?
    let nowMs: Int64

    var body: some View {
        switch target.status.lowercased() {
        case "okay", "ok":
            EmptyView()
        case "hospital":
            chip(icon: "🏥", text: hospitalOrJailTimerText(prefix: "In hospital"), color: .red)
        case "jail":
            chip(icon: "🔒", text: hospitalOrJailTimerText(prefix: "In jail"), color: .purple)
        case "traveling":
            let country = travel?.destination.nilIfBlank ?? countryFromDescription(target.description)
            let arrow = (travel?.returning ?? target.description.hasPrefix("Returning")) ? "←" : "→"
            // FFScouter landing time → live countdown when available.
            let timer: String = {
                if let landing = travel?.landingAt, landing > 0 {
                    let remaining = max(0, landing - nowMs / 1000)
                    return remaining > 0 ? " \(formatHms(Int(remaining)))" : ""
                }
                return ""
            }()
            chip(icon: "✈", text: "\(arrow) \(country)\(timer)", color: .cyan)
        case "abroad":
            let country = travel?.destination.nilIfBlank ?? countryFromAbroad(target.description)
            chip(icon: "🛬", text: country, color: .cyan)
        default:
            chip(icon: "", text: target.status, color: .secondary)
        }
    }

    @ViewBuilder
    private func chip(icon: String, text: String, color: Color) -> some View {
        Text(icon.isEmpty ? text : "\(icon) \(text)")
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func countryFromDescription(_ s: String) -> String {
        if let r = s.range(of: "Traveling to ") { return String(s[r.upperBound...]) }
        if let r = s.range(of: "Returning to Torn from ") { return String(s[r.upperBound...]) }
        return s
    }
    private func countryFromAbroad(_ s: String) -> String {
        if let r = s.range(of: "In ") { return String(s[r.upperBound...]) }
        return s
    }

    /// Returns the timer text for hospital / jail chips. Prefers the live
    /// untilSec countdown; falls back to parsing the description (e.g.
    /// "In hospital for 15 mins") when untilSec is 0. The fallback prevents
    /// the chip from flashing "out" while a target is still in-state but
    /// our snapshot's `until` has either ticked to 0 client-side (server
    /// hasn't yet detected the actual release via enemy-profile poll) or
    /// was never populated by the bulk-update path that sets status from
    /// intercepted Torn DOM data.
    private func hospitalOrJailTimerText(prefix: String) -> String {
        if target.untilSec > 0 {
            return formatHms(Int(target.untilSec))
        }
        if let parsed = parseInStateDescription(target.description, prefix: prefix) {
            return formatHms(parsed)
        }
        return "—"
    }

    /// Parses Torn-style "In <state> for N mins" / "In <state> for N hr"
    /// descriptions to remaining seconds. Tolerates "min", "mins", "hr",
    /// "hrs", "hour", "hours", and decimal values. Returns nil if the
    /// pattern doesn't match.
    private func parseInStateDescription(_ desc: String, prefix: String) -> Int? {
        guard let range = desc.range(of: "\(prefix) for "), range.upperBound < desc.endIndex else {
            return nil
        }
        let tail = desc[range.upperBound...]
        // Pull the leading numeric value (may be int, may be decimal).
        var numStr = ""
        for ch in tail {
            if ch.isNumber || ch == "." { numStr.append(ch) }
            else if !numStr.isEmpty { break }
        }
        guard let n = Double(numStr), n >= 0 else { return nil }
        let lower = tail.lowercased()
        if lower.contains("hr") || lower.contains("hour") {
            return Int(n * 3600)
        }
        // default: minutes
        return Int(n * 60)
    }
}

// MARK: - Report tab

struct ReportTab: View {
    let report: ScoutReport?
    let loading: Bool
    let onLoad: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("War analysis").font(.title3.bold())
                    Spacer()
                    Button(loading ? "Refreshing…" : "Refresh", action: onLoad)
                        .disabled(loading)
                }
                if let r = report {
                    ReportBody(r: r)
                } else if loading {
                    ProgressView().padding()
                } else {
                    Text("No report yet — tap Refresh.").foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }
}

private struct ReportBody: View {
    let r: ScoutReport
    private let ourColor   = Color.green
    private let enemyColor = Color.red

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Win probability headline
            let winColor: Color = r.winProbability >= 65 ? .green
                : r.winProbability >= 45 ? .yellow : .red
            HStack {
                Text("Win probability").foregroundColor(winColor).font(.subheadline.bold())
                Spacer()
                Text("\(r.winProbability)%").font(.system(size: 32, weight: .bold)).foregroundColor(winColor)
            }
            .padding(12)
            .background(winColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(r.hasEstimates
                 ? "Based on FFScouter battle-stat estimates"
                 : "Based on level only — no FFS estimates available")
                .font(.caption.bold())
                .foregroundColor(r.hasEstimates ? .green : .secondary)

            if !r.winReasoning.isEmpty {
                ForEach(r.winReasoning, id: \.self) { line in
                    Text("• \(line)").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            sectionCard("War Overview") {
                CompareHeader(left: r.our.factionName, right: r.enemy.factionName,
                              leftColor: ourColor, rightColor: enemyColor)
                CompareRow(label: "Members",    left: "\(r.our.members)",   right: "\(r.enemy.members)")
                CompareRow(label: "Respect",    left: fmtNum(r.our.respect), right: fmtNum(r.enemy.respect))
                CompareRow(label: "Best chain", left: fmtNum(r.our.bestChain), right: fmtNum(r.enemy.bestChain))
                CompareRow(label: "Age",        left: "\(r.our.age)d",      right: "\(r.enemy.age)d")
            }

            if !r.matchups.isEmpty {
                sectionCard("Top-End Comparison") {
                    ForEach(r.matchups) { mu in
                        MatchupRow(mu: mu, ourColor: ourColor, enemyColor: enemyColor)
                    }
                }
            }

            sectionCard("Stat Tier Breakdown") {
                let max = Swift.max(
                    r.our.tiers.s, r.our.tiers.a, r.our.tiers.b, r.our.tiers.c, r.our.tiers.d,
                    r.enemy.tiers.s, r.enemy.tiers.a, r.enemy.tiers.b, r.enemy.tiers.c, r.enemy.tiers.d, 1
                )
                let rows: [(String, Int, Int, String)] = [
                    ("S", r.our.tiers.s, r.enemy.tiers.s, r.tierDescriptions.s),
                    ("A", r.our.tiers.a, r.enemy.tiers.a, r.tierDescriptions.a),
                    ("B", r.our.tiers.b, r.enemy.tiers.b, r.tierDescriptions.b),
                    ("C", r.our.tiers.c, r.enemy.tiers.c, r.tierDescriptions.c),
                    ("D", r.our.tiers.d, r.enemy.tiers.d, r.tierDescriptions.d),
                ]
                ForEach(rows, id: \.0) { row in
                    TierBarRow(label: row.0, ours: row.1, enemy: row.2, max: max,
                               ourColor: ourColor, enemyColor: enemyColor)
                    Text(row.3).font(.caption2).foregroundStyle(.secondary)
                        .padding(.leading, 22)
                }
            }

            sectionCard("Activity") {
                CompareHeader(left: r.our.factionName, right: r.enemy.factionName,
                              leftColor: ourColor, rightColor: enemyColor)
                CompareRow(label: "Online",      left: "\(r.our.online)",       right: "\(r.enemy.online)")
                CompareRow(label: "Idle",        left: "\(r.our.idle)",         right: "\(r.enemy.idle)")
                CompareRow(label: "Offline",     left: "\(r.our.offline)",      right: "\(r.enemy.offline)")
                CompareRow(label: "Combat ready", left: "\(r.our.activeCombat)", right: "\(r.enemy.activeCombat)")
            }

            if !r.safeHits.thresholds.isEmpty {
                sectionCard("Safe Hits") {
                    ForEach(r.safeHits.thresholds) { th in
                        HStack {
                            Text(th.label).bold().frame(width: 84, alignment: .leading)
                            Text(th.desc).foregroundStyle(.secondary).font(.caption)
                            Spacer()
                            Text("\(th.ourCount) us · \(th.enemyFarmable) them")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Roster that can hit: \(r.safeHits.ourCanHitPct)% · Enemy farmable: \(r.safeHits.enemyFarmablePct)%")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let bp = r.battlePlan {
                sectionCard("Tactical Battle Plan") {
                    Text("Phase: \(bp.warPhase.capitalized)").foregroundColor(.yellow).font(.subheadline.bold())
                    if let p = bp.opening { phaseSection(label: "Phase 1 — Opening", phase: p, accent: .green) }
                    if let p = bp.midWar  { phaseSection(label: "Phase 2 — Mid-war", phase: p, accent: .yellow) }
                    if let p = bp.endgame { phaseSection(label: "Phase 3 — Endgame", phase: p, accent: .orange) }
                    if !bp.keyPermaTargets.isEmpty {
                        Text("Key perma-targets").foregroundColor(.red).font(.subheadline.bold())
                        ForEach(bp.keyPermaTargets) { p in
                            Text("  • \(p.name) (L\(p.level), \(p.statsFormatted))")
                                .font(.caption)
                        }
                    }
                    if !bp.ignore.isEmpty {
                        Text("Avoid (\(bp.ignore.count))").foregroundStyle(.secondary).font(.subheadline.bold())
                        ForEach(bp.ignore) { p in
                            Text("  • \(p.name) (L\(p.level), \(p.statsFormatted))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.bold()).foregroundColor(.accentColor)
            content()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func phaseSection(label: String, phase: BattlePhase, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).foregroundColor(accent).font(.subheadline.bold())
            Text(phase.description).font(.caption)
            if !phase.targets.isEmpty {
                Text("Hit (\(phase.targets.count))").font(.caption.bold()).foregroundColor(.red)
                ForEach(phase.targets) { p in
                    Text("  • \(p.name) (L\(p.level), \(p.statsFormatted))").font(.caption2)
                }
            }
            if !phase.ourPlayers.isEmpty {
                Text("Deploy (\(phase.ourPlayers.count))").font(.caption.bold()).foregroundColor(.green)
                ForEach(phase.ourPlayers) { p in
                    Text("  • \(p.name) (L\(p.level), \(p.statsFormatted))").font(.caption2)
                }
            }
        }
        .padding(8)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct CompareHeader: View {
    let left: String; let right: String
    let leftColor: Color; let rightColor: Color
    var body: some View {
        HStack {
            Text("").frame(width: 100, alignment: .leading)
            Text(left).foregroundColor(leftColor).font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(right).foregroundColor(rightColor).font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CompareRow: View {
    let label: String; let left: String; let right: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).font(.caption)
                .frame(width: 100, alignment: .leading)
            Text(left).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Text(right).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MatchupRow: View {
    let mu: Matchup
    let ourColor: Color; let enemyColor: Color
    var body: some View {
        HStack {
            Text("\(mu.rank)").foregroundStyle(.secondary).font(.caption).frame(width: 24)
            VStack(alignment: .leading) {
                Text(mu.ours?.name ?? "—").foregroundColor(ourColor).font(.subheadline.weight(.medium))
                Text(mu.ours.map { "L\($0.level) · \($0.statsFormatted)" } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(advantageSymbol)
                .foregroundColor(advantageColor)
                .font(.subheadline.bold())
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(mu.theirs?.name ?? "—").foregroundColor(enemyColor).font(.subheadline.weight(.medium))
                Text(mu.theirs.map { "L\($0.level) · \($0.statsFormatted)" } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var advantageSymbol: String {
        switch mu.advantage { case "ours": return "◀"; case "theirs": return "▶"; default: return "•" }
    }
    private var advantageColor: Color {
        switch mu.advantage { case "ours": return ourColor; case "theirs": return enemyColor; default: return .secondary }
    }
}

private struct TierBarRow: View {
    let label: String
    let ours: Int; let enemy: Int; let max: Int
    let ourColor: Color; let enemyColor: Color
    var body: some View {
        let ourFrac = max > 0 ? Double(ours) / Double(max) : 0
        let enemyFrac = max > 0 ? Double(enemy) / Double(max) : 0
        HStack {
            Text(label).font(.subheadline.bold()).frame(width: 22)
            HStack(spacing: 4) {
                Spacer()
                Text("\(ours)").foregroundColor(ourColor).font(.caption.bold())
                Capsule().fill(ourColor.opacity(0.6))
                    .frame(maxWidth: 100 * ourFrac, minHeight: 8, maxHeight: 10)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 4) {
                Capsule().fill(enemyColor.opacity(0.6))
                    .frame(maxWidth: 100 * enemyFrac, minHeight: 8, maxHeight: 10)
                Text("\(enemy)").foregroundColor(enemyColor).font(.caption.bold())
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private func fmtNum(_ n: Int) -> String {
    if n <= 0 { return "—" }
    return n.formatted(.number.grouping(.automatic))
}

// MARK: - Heatmap tab

struct HeatmapTab: View {
    let ours: [Int: [Int: HeatmapCell]]
    let theirs: [Int: [Int: HeatmapCell]]

    var body: some View {
        if ours.isEmpty && theirs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis").font(.system(size: 40)).foregroundStyle(.tertiary)
                Text("No heatmap samples yet — warboard collects activity over time.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView { content }
        }
    }

    private var content: some View {
        let avg: ([Int: [Int: HeatmapCell]], Int, Int) -> Double = { hm, d, h in
            guard let c = hm[d]?[h], c.samples > 0 else { return 0 }
            return Double(c.total) / Double(c.samples)
        }
        // Server stores days as 0=Mon..6=Sun (see activity-heatmap.js).
        // Earlier 1..7 indexing was off-by-one and silently dropped Sun.
        let maxSingle = (0...6).flatMap { d in (0...23).map { h in
            Swift.max(avg(ours, d, h), avg(theirs, d, h))
        }}.max() ?? 1.0
        let days: [(Int, String)] = [
            (0,"Mon"),(1,"Tue"),(2,"Wed"),(3,"Thu"),(4,"Fri"),(5,"Sat"),(6,"Sun")
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Text("Activity heatmap — us vs them").font(.title3.bold())
            Text("Diverging color per hour. Brighter green = our side more active; brighter red = enemy more active.")
                .font(.caption).foregroundStyle(.secondary)

            // Hour labels
            HStack(spacing: 1) {
                Text("").frame(width: 36)
                ForEach(0..<24, id: \.self) { h in
                    Text(h % 3 == 0 ? "\(h)" : "")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(days, id: \.0) { (day, label) in
                HStack(spacing: 1) {
                    Text(label).font(.caption.bold()).foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                    ForEach(0..<24, id: \.self) { h in
                        let o = avg(ours, day, h)
                        let t = avg(theirs, day, h)
                        let delta = o - t
                        let intensity = Swift.min(1.0, abs(delta) / Swift.max(maxSingle, 1.0))
                        let noData = ours[day]?[h] == nil && theirs[day]?[h] == nil
                        let tint: Color = {
                            if noData { return Color.gray.opacity(0.05) }
                            if delta > 0 { return Color.green.opacity(0.15 + intensity * 0.75) }
                            if delta < 0 { return Color.red.opacity(0.15 + intensity * 0.75) }
                            return Color.gray.opacity(0.10)
                        }()
                        Rectangle().fill(tint)
                            .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Misc small components

struct StatChip: View {
    let total: Int64
    var body: some View {
        let (tier, color) = StatChip.tier(total)
        Text("\(tier) \(StatChip.fmt(total))")
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.4)))
    }
    static func tier(_ n: Int64) -> (String, Color) {
        if n >= 3_000_000_000 { return ("S", .red) }
        if n >= 1_000_000_000 { return ("A", .yellow) }
        if n >=   500_000_000 { return ("B", .green) }
        return ("C", .gray)
    }
    static func fmt(_ n: Int64) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
        if n >= 1_000_000     { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000         { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

struct IdString: Identifiable {
    let value: String
    var id: String { value }
}

struct ShoutSheet: View {
    @Binding var text: String
    let onSend: () -> Void
    let onCancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Faction shout").font(.title3.bold())
            Text("Leaders + bankers only. Sends a toast + push notification to every member subscribed to this war.")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .frame(minHeight: 90)
                .border(Color.secondary.opacity(0.3))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Send", action: onSend)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}

extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}

// MARK: - Helpers

func nextChainMilestone(_ current: Int) -> Int {
    let tiers = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
    return tiers.first(where: { current < $0 }) ?? tiers.last!
}

func formatDur(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    let sec = s % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
    return String(format: "%d:%02d", m, sec)
}

func formatHms(_ seconds: Int) -> String { formatDur(seconds) }
