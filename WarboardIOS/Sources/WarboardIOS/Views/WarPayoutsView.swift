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
                Button { vm.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            vm.bind(prefs: prefs)
            vm.start()
        }
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
                    PayoutMemberRow(member: m) { pay(m) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { vm.refresh() }
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
            Text("Pool $\(formatMoney(payouts.payoutPool)) · \(poolPctText) of $\(formatMoney(payouts.lootTotal)) loot")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

/// One member row: name · "<n> hits" · owed $ (green) · Pay button.
private struct PayoutMemberRow: View {
    let member: WarboardAPI.PayoutMember
    let onPay: () -> Void

    var body: some View {
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
    }
}
