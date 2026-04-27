import SwiftUI

/// Mirrors the factionops userscript's renderPostWarReport — same
/// seven sections, same color thresholds, same layout (collapsible
/// sections, member table at the bottom).
struct PostWarReportView: View {
    let report: PostWarReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let s = report.warSummary {
                        Section_(title: "War Summary") { WarSummaryCard(s: s) }
                    }
                    if let p = report.factionPerformance {
                        Section_(title: "Overall Faction Performance") { FactionPerfCard(p: p) }
                    }
                    if let e = report.energyEfficiency {
                        Section_(title: "Energy Efficiency Analysis") { EnergyCard(e: e) }
                    }
                    Section_(title: "Top Performers") {
                        if let p = report.positiveHighlights {
                            VStack(alignment: .leading, spacing: 10) {
                                if !p.achievements.isEmpty {
                                    FlowChips(p.achievements.map { "\($0.title): \($0.name) (\($0.value))" })
                                }
                                if p.topPerformers.isEmpty {
                                    EmptyText("No performance data available.")
                                } else {
                                    ForEach(Array(p.topPerformers.enumerated()), id: \.offset) { _, m in
                                        TopPerformerCard(m: m)
                                    }
                                }
                            }
                        } else { EmptyText("No data.") }
                    }
                    Section_(title: "Areas to Improve") {
                        if let n = report.negativeHighlights, !n.areasToImprove.isEmpty {
                            ForEach(Array(n.areasToImprove.enumerated()), id: \.offset) { _, m in
                                UnderperformerCard(m: m)
                            }
                        } else {
                            EmptyText("No notable issues — great performance across the board!")
                        }
                    }
                    Section_(title: "Recommendations") {
                        if report.recommendations.isEmpty {
                            EmptyText("No specific recommendations — solid performance overall.")
                        } else {
                            ForEach(Array(report.recommendations.enumerated()), id: \.offset) { _, r in
                                RecommendationCard(r: r)
                            }
                        }
                    }
                    Section_(title: "Member Performance", initiallyCollapsed: true) {
                        MemberTable(rows: report.memberTable)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Post-War Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: – Section wrapper (collapsible)

private struct Section_<Content: View>: View {
    let title: String
    var initiallyCollapsed: Bool = false
    @ViewBuilder let content: () -> Content
    @State private var collapsed: Bool = false

    init(title: String, initiallyCollapsed: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.initiallyCollapsed = initiallyCollapsed
        self.content = content
        _collapsed = State(initialValue: initiallyCollapsed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
            } label: {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !collapsed { content() }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct EmptyText: View {
    let text: String
    init(_ t: String) { self.text = t }
    var body: some View { Text(text).font(.caption).foregroundStyle(.secondary) }
}

// MARK: – Section A: War Summary

private struct WarSummaryCard: View {
    let s: PostWarReport.WarSummary
    var body: some View {
        let isVictory = s.result.uppercased() == "VICTORY"
        let isDefeat  = s.result.uppercased() == "DEFEAT"
        let badgeColor: Color = isVictory ? Color(red: 0, green: 0.72, blue: 0.58)
                              : isDefeat  ? Color(red: 1, green: 0.46, blue: 0.46)
                              : .gray
        VStack(spacing: 10) {
            Text(s.result.uppercased())
                .font(.subheadline.weight(.heavy)).tracking(2)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(badgeColor.opacity(0.25), in: Capsule())
                .foregroundColor(badgeColor)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.ourScore)").foregroundColor(Color(red: 0, green: 0.72, blue: 0.58))
                Text("–").foregroundStyle(.secondary)
                Text("\(s.enemyScore)").foregroundColor(Color(red: 1, green: 0.46, blue: 0.46))
            }
            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
            Text("\(s.ourName) vs \(s.enemyName)")
                .font(.caption2).foregroundStyle(.secondary)
            statGrid([
                ("Our Total Hits",     "\(s.totalOurHits)"),
                ("Enemy Total Hits",   "\(s.totalEnemyHits)"),
                ("Total Respect",      String(format: "%.0f", s.totalRespect)),
                ("War Duration",       s.durationFormatted ?? "—"),
            ])
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Section B: Faction Performance

private struct FactionPerfCard: View {
    let p: PostWarReport.FactionPerformance
    var body: some View {
        let effColor: Color = p.efficiencyRating >= 70 ? .green
                            : p.efficiencyRating >= 40 ? .yellow
                            : .red
        let partColor: Color = p.participationRate >= 70 ? .green
                             : p.participationRate >= 50 ? .yellow
                             : .red
        statGrid([
            ("Participating Members", "\(p.participationCount) / \(p.totalRoster)"),
            ("Participation Rate",    nil),
            ("Avg Hits / Member",     String(format: "%.1f", p.avgHitsPerMember)),
            ("Avg Respect / Hit",     String(format: "%.2f", p.avgRespectPerHit)),
            ("Avg Fair Fight",        p.avgFairFight.map { String(format: "%.2f", $0) } ?? "—"),
            ("Efficiency Rating",     nil),
        ], colorOverride: { lbl in
            if lbl == "Participation Rate" { return ("\(p.participationRate)%", partColor) }
            if lbl == "Efficiency Rating"  { return ("\(p.efficiencyRating)/100", effColor) }
            return nil
        })
    }
}

// MARK: – Section C: Energy

private struct EnergyCard: View {
    let e: PostWarReport.EnergyEfficiency
    var body: some View {
        let barColor: Color = e.efficiencyPct >= 80 ? .green
                            : e.efficiencyPct >= 60 ? .yellow
                            : .red
        VStack(alignment: .leading, spacing: 10) {
            statGrid([
                ("Total Estimated Energy", "\(e.totalEstimatedEnergy)"),
                ("Wasted Energy",          "\(e.totalWastedEnergy)"),
                ("Faction Avg Resp/Hit",   String(format: "%.2f", e.factionAvgRespectPerHit)),
            ], colorOverride: { lbl in
                if lbl == "Wasted Energy" { return ("\(e.totalWastedEnergy)", Color(red: 1, green: 0.46, blue: 0.46)) }
                return nil
            })
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(min(100, max(0, e.efficiencyPct))) / 100)
                    .tint(barColor)
                Text("Energy Efficiency: \(e.efficiencyPct)%")
                    .font(.caption2.bold()).foregroundColor(barColor)
            }
            if e.belowThresholdCount > 0 {
                Text("\(e.belowThresholdCount) member(s) flagged below 50% of faction avg respect/hit.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: – Section D: Top performer card

private struct TopPerformerCard: View {
    let m: PostWarReport.PositiveHighlights.TopPerformer
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.name).font(.subheadline.bold()).foregroundColor(Color(red: 0, green: 0.72, blue: 0.58))
                Text("Lv\(m.level)").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                StatPill("Hits", "\(m.attacks)")
                if let a = m.assists, a > 0 { StatPill("Assists", "\(a)") }
                StatPill("Resp", String(format: "%.0f", m.respect))
                StatPill("R/Hit", String(format: "%.2f", m.respectPerHit))
                StatPill("Score", "\(m.score)")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0, green: 0.72, blue: 0.58).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: – Section E: Underperformer card

private struct UnderperformerCard: View {
    let m: PostWarReport.NegativeHighlights.Underperformer
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.name).font(.subheadline.bold()).foregroundColor(Color(red: 0.99, green: 0.80, blue: 0.43))
                Text("Lv\(m.level)").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                StatPill("Hits", "\(m.attacks)")
                StatPill("Resp", String(format: "%.0f", m.respect))
                if m.attacks > 0, let r = m.respectPerHit { StatPill("R/Hit", String(format: "%.2f", r)) }
                StatPill("Score", "\(m.score)")
            }
            if !m.issue.isEmpty {
                Text(m.issue).font(.caption2)
                    .foregroundColor(Color(red: 0.99, green: 0.80, blue: 0.43))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.99, green: 0.80, blue: 0.43).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: – Section F: Recommendation card

private struct RecommendationCard: View {
    let r: PostWarReport.Recommendation
    var body: some View {
        let priorityColor: Color = r.priority == "high" ? .red
                                 : r.priority == "low"  ? .green : .yellow
        VStack(alignment: .leading, spacing: 6) {
            Text(r.category.uppercased())
                .font(.caption2.bold()).tracking(1)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(priorityColor.opacity(0.20), in: Capsule())
                .foregroundColor(priorityColor)
            Text(r.text).font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: – Section G: Member table

private struct MemberTable: View {
    let rows: [PostWarReport.MemberRow]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    cell("Name", w: 100, bold: true, align: .leading)
                    cell("Lv",   w: 30,  bold: true)
                    cell("Hits", w: 40,  bold: true)
                    cell("Resp", w: 60,  bold: true, align: .trailing)
                    cell("R/Hit", w: 50, bold: true, align: .trailing)
                    cell("Def",  w: 35,  bold: true)
                    cell("Bled", w: 50,  bold: true, align: .trailing)
                    cell("Net",  w: 60,  bold: true, align: .trailing)
                }
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, m in
                    HStack(spacing: 0) {
                        cell(m.name,                        w: 100, align: .leading)
                        cell("\(m.level)",                  w: 30)
                        cell("\(m.attacks)",                w: 40)
                        cell(String(format: "%.0f", m.respect), w: 60, align: .trailing)
                        cell(m.attacks > 0 ? String(format: "%.2f", m.respectPerHit ?? 0) : "—",
                             w: 50, align: .trailing)
                        cell("\(m.timesAttacked)",          w: 35)
                        cell(m.respectBled > 0 ? String(format: "%.1f", m.respectBled) : "—",
                             w: 50, align: .trailing,
                             color: Color(red: 1, green: 0.46, blue: 0.46))
                        cell(String(format: "%.1f", m.netScore),
                             w: 60, align: .trailing, bold: true,
                             color: m.netScore < 0 ? Color(red: 1, green: 0.46, blue: 0.46)
                                  : m.netScore > 0 ? Color(red: 0, green: 0.72, blue: 0.58)
                                  : .primary)
                    }
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ text: String, w: CGFloat,
                      align: HorizontalAlignment = .center,
                      bold: Bool = false,
                      color: Color = .primary) -> some View {
        Text(text)
            .font(bold ? .caption2.bold() : .caption2.monospacedDigit())
            .foregroundColor(color)
            .lineLimit(1)
            .frame(width: w, alignment: align == .leading ? .leading
                                       : align == .trailing ? .trailing
                                       : .center)
            .padding(.horizontal, 4)
    }
}

// MARK: – Helpers

private struct StatPill: View {
    let label: String
    let value: String
    init(_ l: String, _ v: String) { label = l; value = v }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.caption.bold().monospacedDigit())
        }
    }
}

private struct FlowChips: View {
    let labels: [String]
    init(_ labels: [String]) { self.labels = labels }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, txt in
                Text(txt)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(red: 0, green: 0.72, blue: 0.58).opacity(0.18),
                                in: Capsule())
                    .foregroundColor(Color(red: 0, green: 0.72, blue: 0.58))
            }
        }
    }
}

@ViewBuilder
private func statGrid(_ rows: [(String, String?)],
                      colorOverride: ((String) -> (String, Color)?)? = nil) -> some View {
    VStack(spacing: 4) {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            HStack {
                Text(row.0).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let override = colorOverride?(row.0) {
                    Text(override.0).font(.caption.bold().monospacedDigit())
                        .foregroundColor(override.1)
                } else {
                    Text(row.1 ?? "—").font(.caption.bold().monospacedDigit())
                }
            }
        }
    }
}
