import SwiftUI
import UIKit

/// Manager tab — admin audit views for the faction's OCs. Three
/// sub-tabs picked via segmented control:
///   • Missing — slot owners without their required item (Loan)
///   • Unused  — loaned items not needed by any current OC (Retrieve)
///   • Payouts — completed OCs awaiting payment
///
/// Loan / Retrieve actions run in-app via TornWebSession (a hidden
/// WKWebView authenticated with the user's torn.com cookies). Payouts
/// still deep-link to the completed-crimes page because that flow
/// involves a Torn UI checklist that's not API-postable.
struct ManagerView: View {
    @EnvironmentObject private var prefs: PrefsStore
    @StateObject private var vm = ManagerViewModel()
    @ObservedObject private var session = TornWebSession.shared
    @State private var sub: SubTab = .missing
    @State private var showSettings = false
    @State private var showLogin = false

    enum SubTab: String, CaseIterable, Identifiable {
        case missing = "Missing"
        case unused  = "Unused"
        case payouts = "Payouts"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sub) {
                ForEach(SubTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.vertical, 8)

            // Sign-in banner appears only on Missing/Unused — Payouts
            // doesn't need the WebView path. Keeps the surface clean
            // for users who don't manage armoury.
            if sub != .payouts, !session.signedIn {
                TornSignInBanner { showLogin = true }
            }

            Group {
                switch sub {
                case .missing: MissingTab(vm: vm, session: session,
                                          onSignIn: { showLogin = true })
                case .unused:  UnusedTab(vm: vm, session: session,
                                          onSignIn: { showLogin = true })
                case .payouts: PayoutsTab(vm: vm)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("Manager")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { vm.refresh() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    if session.signedIn {
                        Button(role: .destructive) {
                            Task { await session.signOut() }
                        } label: {
                            Label("Sign out of Torn", systemImage: "arrow.right.square")
                        }
                    } else {
                        Button { showLogin = true } label: {
                            Label("Sign in to Torn", systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                    Divider()
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $showLogin)    { TornLoginSheet() }
        .onAppear {
            vm.bind(prefs: prefs); vm.start()
            Task { await session.refreshSignedInState() }
        }
        .onDisappear { vm.stop() }
        .onChange(of: sub) { _, newValue in
            switch newValue {
            case .missing, .unused: vm.ensureMissingAndUnusedReady()
            case .payouts:          vm.ensurePayoutsReady()
            }
        }
    }
}

private struct TornSignInBanner: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.exclam")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sign in to Torn for in-app actions")
                        .font(.subheadline.bold())
                    Text("Enables Loan / Retrieve without leaving the app.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12).padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Missing items

private struct MissingTab: View {
    @ObservedObject var vm: ManagerViewModel
    @ObservedObject var session: TornWebSession
    let onSignIn: () -> Void

    var body: some View {
        switch vm.crimes {
        case .idle, .loading:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            OCMessageView(icon: "exclamationmark.triangle.fill", text: msg)
        case .ready:
            let rows = vm.missing
            if rows.isEmpty {
                OCMessageView(icon: "checkmark.seal.fill",
                            text: "All OC items allocated.")
            } else {
                List {
                    ForEach(rows) { item in
                        ActionRow(
                            title: item.itemName ?? "Item #\(item.itemId)",
                            subtitle: "\(item.userName) · \(item.crimeName) · \(item.positionName)",
                            actionLabel: "Loan",
                            actionTint: .green,
                            requiresSignIn: !session.signedIn,
                            onSignIn: onSignIn,
                            perform: {
                                // category may be nil when the item isn't
                                // currently in stock — TornWebSession will
                                // sweep every bucket in that case.
                                try await session.loan(
                                    itemId: item.itemId, userId: item.userId,
                                    userName: item.userName,
                                    category: item.armoryCategory
                                )
                            },
                            onSuccess: {
                                vm.markActioned(itemId: item.itemId, userId: item.userId)
                            },
                            onSessionExpired: onSignIn
                        )
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { vm.refresh() }
            }
        }
    }
}

// MARK: — Unused loaned items

private struct UnusedTab: View {
    @ObservedObject var vm: ManagerViewModel
    @ObservedObject var session: TornWebSession
    let onSignIn: () -> Void

    var body: some View {
        Group {
            switch vm.armory {
            case .idle, .loading:
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let msg):
                OCMessageView(icon: "exclamationmark.triangle.fill", text: msg)
            case .ready:
                let rows = vm.unused
                if rows.isEmpty {
                    OCMessageView(icon: "checkmark.seal.fill",
                                text: "No unused loaned items.")
                } else {
                    List {
                        ForEach(rows) { entry in
                            ActionRow(
                                title: entry.itemName,
                                subtitle: "\(entry.userName) · \(entry.armoryCategory.capitalized)",
                                actionLabel: "Retrieve",
                                actionTint: .orange,
                                requiresSignIn: !session.signedIn,
                                onSignIn: onSignIn,
                                perform: {
                                    try await session.retrieve(
                                        itemId: entry.itemId, userId: entry.userId,
                                        userName: entry.userName, category: entry.armoryCategory
                                    )
                                },
                                onSuccess: {
                                    vm.markActioned(itemId: entry.itemId, userId: entry.userId)
                                },
                                onSessionExpired: onSignIn
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { vm.refresh() }
                }
            }
        }
    }
}

/// Generic row used by Missing + Unused — title + subtitle + a single
/// pill button that runs an async action and shows progress / result
/// inline so the user sees what happened without a separate alert.
private struct ActionRow: View {
    let title: String
    let subtitle: String
    let actionLabel: String
    let actionTint: Color
    let requiresSignIn: Bool
    let onSignIn: () -> Void
    let perform: () async throws -> Void
    let onSuccess: () -> Void
    /// Fired when TornWebSession.ActionError.notSignedIn comes back —
    /// tells the host to pop the login sheet automatically so the user
    /// doesn't have to read the error and find the menu.
    let onSessionExpired: () -> Void

    enum RowState: Equatable {
        case idle, running, success, failed(String)
    }
    @State private var state: RowState = .idle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                if case .failed(let msg) = state {
                    Text(msg).font(.caption2).foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }
            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .running:
            ProgressView().controlSize(.small)
                .padding(.horizontal, 10).padding(.vertical, 5)
        case .success:
            Label("Done", systemImage: "checkmark")
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.green.opacity(0.2), in: Capsule())
                .foregroundStyle(.green)
        default:
            Button(requiresSignIn ? "Sign in" : actionLabel) {
                if requiresSignIn { onSignIn(); return }
                state = .running
                Task {
                    do {
                        try await perform()
                        state = .success
                        onSuccess()
                    } catch let actionErr as TornWebSession.ActionError {
                        if case .notSignedIn = actionErr {
                            state = .idle
                            onSessionExpired()
                        } else {
                            state = .failed(actionErr.errorDescription ?? "\(actionErr)")
                        }
                    } catch {
                        state = .failed(
                            (error as? LocalizedError)?.errorDescription
                            ?? error.localizedDescription
                        )
                    }
                }
            }
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(actionTint.opacity(0.2), in: Capsule())
            .foregroundStyle(actionTint)
            .buttonStyle(.plain)
        }
    }
}

// MARK: — Payouts

/// Completed OCs awaiting distribution. Tap a row to open Torn's
/// completed-crimes page where the actual payout button lives.
/// (Payout flow involves a per-OC checklist that's not exposed via a
/// single armouryActionItem-style POST.)
private struct PayoutsTab: View {
    @ObservedObject var vm: ManagerViewModel
    private static let completedURL = URL(string:
        "https://www.torn.com/factions.php?step=your#/tab=crimes&subTab=completed")!

    var body: some View {
        switch vm.payouts {
        case .idle, .loading:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            OCMessageView(icon: "exclamationmark.triangle.fill", text: msg)
        case .ready(let list):
            if list.isEmpty {
                OCMessageView(icon: "checkmark.seal.fill", text: "All OCs paid out.")
            } else {
                List {
                    Section {
                        Button {
                            UIApplication.shared.open(Self.completedURL)
                        } label: {
                            PayoutsSummary(list: list)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Section {
                        ForEach(list) { p in
                            PayoutRow(payout: p) {
                                UIApplication.shared.open(Self.completedURL)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { vm.refresh() }
            }
        }
    }
}

private struct PayoutsSummary: View {
    let list: [ManagerAPI.UnpaidPayout]

    private var totalMoney: Int64 { list.reduce(0) { $0 + $1.money } }
    private var withItems: Int { list.filter(\.hasItems).count }

    var body: some View {
        VStack(spacing: 4) {
            Text("Summary").font(.caption2).foregroundStyle(.secondary)
            if totalMoney > 0 {
                Text("$\(formatMoney(totalMoney))")
                    .font(.title3.bold()).foregroundStyle(.green)
            }
            Text("\(list.count) Unpaid OCs\(withItems > 0 ? " · \(withItems) with Items" : "")")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("Open Payouts Page").font(.caption.bold())
                Image(systemName: "arrow.up.right.square").font(.caption)
            }
            .foregroundStyle(.green)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func formatMoney(_ n: Int64) -> String {
        let v = Double(n)
        switch n {
        case 1_000_000_000...:  return String(format: "%.2fB", v / 1_000_000_000)
        case 1_000_000...:      return String(format: "%.2fM", v / 1_000_000)
        case 1_000...:          return String(format: "%.1fK", v / 1_000)
        default:                return String(n)
        }
    }
}

private struct PayoutRow: View {
    let payout: ManagerAPI.UnpaidPayout
    let onTap: () -> Void

    private var ageDays: Int {
        Int((Date().timeIntervalSince1970 - payout.executedAt) / 86400)
    }
    private var ageText: String {
        let secs = Int(Date().timeIntervalSince1970 - payout.executedAt)
        if ageDays > 0 { return "\(ageDays)d" }
        return "\(secs / 3600)h"
    }
    private var ageColor: Color {
        if ageDays >= 7 { return .red }
        if ageDays >= 3 { return .orange }
        return .secondary
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(payout.name).font(.subheadline.bold())
                    Spacer()
                    Text(ageText).font(.caption.bold()).foregroundStyle(ageColor)
                }
                HStack {
                    if payout.money > 0 {
                        Text("$\(formatMoney(payout.money))")
                            .font(.caption.bold()).foregroundStyle(.green)
                    }
                    if let pct = payout.payoutPct {
                        Text("· \(Int(pct))%").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if payout.hasItems {
                        Text("Items")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(.green)
                    }
                    if let d = payout.difficulty {
                        Text("D\(d)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatMoney(_ n: Int64) -> String {
        let v = Double(n)
        switch n {
        case 1_000_000_000...: return String(format: "%.2fB", v / 1_000_000_000)
        case 1_000_000...:     return String(format: "%.2fM", v / 1_000_000)
        case 1_000...:         return String(format: "%.1fK", v / 1_000)
        default:               return String(n)
        }
    }
}
