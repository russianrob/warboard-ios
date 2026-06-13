import SwiftUI
import UIKit
import WarboardIOS

/// War Payouts — shows the most-recent ended war's owed cuts so a
/// faction admin can pay each member. Read-only compute (server's
/// `dynamic` payout mode); tapping Pay opens Torn's pre-filled
/// give-money form in the in-app browser tab and dismisses this screen.
///
/// No war picker, no paid/unpaid tracking — mirrors the warboard web
/// `/payouts` page scoped to mobile.
struct WarPayoutsView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = WarPayoutsViewModel()

    /// Player IDs whose attack-breakdown detail is expanded.
    @State private var expanded: Set<String> = []
    @State private var showSettings = false

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let msg):
                OCMessageView(icon: "exclamationmark.triangle.fill", text: msg)
            case .ready(let payouts):
                if payouts.members.isEmpty {
                    OCMessageView(icon: "flag.checkered", text: "No completed wars yet.")
                } else {
                    payoutList(payouts)
                }
            }
        }
        .navigationTitle("War Payouts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .disabled(loadedPayouts == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { vm.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            if let payouts = loadedPayouts {
                WarPayoutsSettingsSheet(vm: vm, current: payouts)
            }
        }
        .onAppear {
            vm.bind(prefs: prefs)
            vm.start()
        }
    }

    /// The currently-loaded payout object, if any (used to gate the gear
    /// + seed the settings sheet).
    private var loadedPayouts: WarboardAPI.WarPayouts? {
        if case .ready(let p) = vm.state { return p }
        return nil
    }

    private func payoutList(_ payouts: WarboardAPI.WarPayouts) -> some View {
        // Sort by owed amount desc — biggest cuts first.
        let members = payouts.members.sorted { $0.dollarPayout > $1.dollarPayout }
        return List {
            Section {
                PayoutHeader(payouts: payouts)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(members) { m in
                    PayoutMemberRow(
                        member: m,
                        isExpanded: expanded.contains(m.playerId),
                        onToggle: { toggle(m) },
                        onPay: { pay(m) }
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { vm.refresh() }
    }

    private func toggle(_ member: WarboardAPI.PayoutMember) {
        if expanded.contains(member.playerId) { expanded.remove(member.playerId) }
        else { expanded.insert(member.playerId) }
    }

    /// Open Torn's pre-filled give-money form in the logged-in browser
    /// tab, then dismiss so the user lands on it and confirms there.
    private func pay(_ member: WarboardAPI.PayoutMember) {
        let amount = max(0, member.dollarPayout)
        // Clipboard fallback in case the prefilled amount doesn't stick.
        UIPasteboard.general.string = "\(amount)"
        let urlStr =
            "https://www.torn.com/factions.php?step=your#/tab=controls&addMoneyTo=\(member.playerId)&money=\(amount)"
        if let url = URL(string: urlStr) {
            BrowserRouter.shared.open(url)
        }
        dismiss()
    }
}

/// Header card: enemy faction + Win/Loss, plus the pool math
/// ("Pool $X · Y% of $Z loot"). Money via the canonical `formatMoney`.
private struct PayoutHeader: View {
    let payouts: WarboardAPI.WarPayouts

    private var resultLabel: String? {
        guard let r = payouts.warResult?.trimmingCharacters(in: .whitespaces),
              !r.isEmpty else { return nil }
        return r.capitalized
    }

    /// Green for a win, red for a loss, secondary otherwise.
    private var resultColor: Color {
        switch payouts.warResult?.lowercased() {
        case "win", "won", "victory": return .green
        case "loss", "lost", "defeat": return .red
        default: return .secondary
        }
    }

    private var poolPctText: String {
        // payoutPct is a 0..1 fraction — render as a whole percent.
        let pct = (payouts.payoutPct * 100).rounded()
        return "\(Int(pct))%"
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(payouts.enemyFactionName.isEmpty ? "War" : payouts.enemyFactionName)
                    .font(.headline)
                if let resultLabel {
                    Text(resultLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(resultColor.opacity(0.2), in: Capsule())
                        .foregroundStyle(resultColor)
                }
            }
            Text("\(payouts.mode.capitalized) · Pool $\(formatMoney(payouts.payoutPool)) · \(poolPctText) of $\(formatMoney(payouts.lootTotal)) loot")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if payouts.isArchived {
                Text("Archived war — amounts frozen (settings apply only to a war still being computed).")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

/// One member row: name · "<n> hits" · owed $ (green) · Pay button.
/// Tapping the row (anywhere but Pay) toggles an expanded section with
/// the per-category attack breakdown + totals.
private struct PayoutMemberRow: View {
    let member: WarboardAPI.PayoutMember
    let isExpanded: Bool
    let onToggle: () -> Void
    let onPay: () -> Void

    /// A rendered breakdown chip. `id` (the category key) is stable and
    /// unique within a row, so it doubles as the ForEach identity.
    private struct BreakdownChip: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    /// Server order, most-valuable first. Only nonzero categories render.
    private static let breakdownOrder: [(key: String, label: String)] = [
        ("war_hit", "War hits"), ("retal", "Retals"),
        ("overseas_war", "Overseas war"), ("assist", "Assists"),
        ("chain_hit", "Chain hits"), ("os_chain", "OS chain"),
        ("non_war", "Non-war"), ("failed", "Losses"),
    ]

    private var chips: [BreakdownChip] {
        Self.breakdownOrder.compactMap { entry in
            let count = member.breakdown[entry.key] ?? 0
            return count > 0 ? BreakdownChip(id: entry.key, label: entry.label, count: count) : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.name).font(.subheadline.bold())
                    Text("\(member.attackCount) hits")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("$\(formatMoney(member.dollarPayout))")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Button("Pay", action: onPay)
                    .font(.caption.bold())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .foregroundStyle(.green)
                    .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            if isExpanded {
                if !chips.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(chips) { chip in
                            Text("\(chip.label) \(chip.count)")
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("\(member.totalAttacks) attacks · share \(String(format: "%.1f", member.sharePct))% · score \(String(format: "%.0f", member.score))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

/// Admin settings sheet — change mode, loot override, payout %, and the
/// assist / non-war / loss weights, then Apply to re-compute. Loot/weight
/// inputs are disabled for archived (frozen) wars. Seeded from the
/// currently-loaded payout object.
private struct WarPayoutsSettingsSheet: View {
    @ObservedObject var vm: WarPayoutsViewModel
    let current: WarboardAPI.WarPayouts
    @Environment(\.dismiss) private var dismiss

    @State private var mode: String
    @State private var lootText: String
    @State private var payoutPctText: String
    @State private var assistText: String
    @State private var nonWarText: String
    @State private var failedText: String

    init(vm: WarPayoutsViewModel, current: WarboardAPI.WarPayouts) {
        self.vm = vm
        self.current = current
        _mode = State(initialValue: current.mode)
        // Loot override placeholder shows the current loot total; the
        // field itself starts blank (only a typed value is sent).
        _lootText = State(initialValue: "")
        // Payout % seeded from the current fraction (0..1 → 0..100).
        _payoutPctText = State(initialValue: "")
        _assistText = State(initialValue: "")
        _nonWarText = State(initialValue: "")
        _failedText = State(initialValue: "")
    }

    private var isArchived: Bool { current.isArchived }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("Dynamic").tag("dynamic")
                        Text("Static").tag("static")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Loot & payout") {
                    HStack {
                        Text("Loot override")
                        Spacer()
                        TextField("$\(formatMoney(current.lootTotal))", text: $lootText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .disabled(isArchived)
                    }
                    HStack {
                        Text("Payout %")
                        Spacer()
                        TextField("\(Int((current.payoutPct * 100).rounded()))", text: $payoutPctText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .disabled(isArchived)
                    }
                }

                Section("Weights") {
                    weightField("Assists", text: $assistText, current: current.settings?.assistWeight)
                    weightField("Non-war", text: $nonWarText, current: current.settings?.nonWarWeight)
                    weightField("Losses", text: $failedText, current: current.settings?.failedWeight)
                }

                if isArchived {
                    Section {
                        Text("Archived war — loot and weights are frozen. You can still switch mode.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Payout Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if vm.applying {
                        ProgressView()
                    } else {
                        Button("Apply") { apply() }
                    }
                }
            }
        }
    }

    private func weightField(_ label: String, text: Binding<String>, current: Double?) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(current.map { String(format: "%g", $0) } ?? "1", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .disabled(isArchived)
        }
    }

    /// Parse a trimmed numeric field; blank → nil (unchanged).
    private func parsed(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Double(t)
    }

    private func apply() {
        // Mode is transient — switch it first (re-fetches on its own).
        if mode != current.mode { vm.setMode(mode) }

        if isArchived {
            // Frozen war: only mode applies; dismiss.
            dismiss()
            return
        }

        let loot = parsed(lootText)
        // Payout % entered 0..100 → server fraction 0..1.
        let pct = parsed(payoutPctText).map { $0 / 100 }
        let assist = parsed(assistText)
        let nonWar = parsed(nonWarText)
        let failed = parsed(failedText)

        Task {
            await vm.apply(
                lootOverride: loot, payoutPct: pct,
                assistWeight: assist, nonWarWeight: nonWar, failedWeight: failed
            )
        }
        dismiss()
    }
}
