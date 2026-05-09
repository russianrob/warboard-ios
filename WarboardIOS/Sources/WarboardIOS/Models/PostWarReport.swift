import Foundation

/// Post-war report payload from `/api/war/<warId>/post-war-report`.
/// Mirrors the factionops userscript's renderPostWarReport shape so the
/// native iOS view can render every section identically. All sections
/// are optional because the server may be missing data for early-war
/// reports or factions without FFScouter estimates.
struct PostWarReport {
    let warSummary: WarSummary?
    let factionPerformance: FactionPerformance?
    let energyEfficiency: EnergyEfficiency?
    let positiveHighlights: PositiveHighlights?
    let negativeHighlights: NegativeHighlights?
    let recommendations: [Recommendation]
    let memberTable: [MemberRow]
    let xanaxAccountability: XanaxAccountability?

    struct WarSummary {
        let result: String          // "VICTORY" | "DEFEAT" | "UNKNOWN"
        let ourScore: Int
        let enemyScore: Int
        let ourName: String
        let enemyName: String
        let totalOurHits: Int
        let totalEnemyHits: Int
        let totalRespect: Double
        let durationFormatted: String?
    }

    struct FactionPerformance {
        let participationCount: Int
        let totalRoster: Int
        let participationRate: Int
        let avgHitsPerMember: Double
        let avgRespectPerHit: Double
        let avgFairFight: Double?
        let efficiencyRating: Int   // 0–100
    }

    struct EnergyEfficiency {
        let totalEstimatedEnergy: Int
        let totalWastedEnergy: Int
        let factionAvgRespectPerHit: Double
        let efficiencyPct: Int
        let belowThresholdCount: Int
    }

    struct PositiveHighlights {
        let achievements: [Achievement]
        let topPerformers: [TopPerformer]

        struct Achievement {
            let title: String
            let name: String
            let value: String
        }
        struct TopPerformer {
            let name: String
            let level: Int
            let attacks: Int
            let assists: Int?
            let respect: Double
            let respectPerHit: Double
            let score: Int
        }
    }

    struct NegativeHighlights {
        let areasToImprove: [Underperformer]

        struct Underperformer {
            let name: String
            let level: Int
            let attacks: Int
            let respect: Double
            let respectPerHit: Double?
            let score: Int
            let issue: String
        }
    }

    struct Recommendation {
        let category: String
        let priority: String        // "low" | "medium" | "high"
        let text: String
    }

    struct MemberRow {
        let name: String
        let level: Int
        let attacks: Int
        let respect: Double
        let respectPerHit: Double?
        let timesAttacked: Int
        let respectBled: Double
        let netScore: Double
        let efficiencyPct: Int
    }

    /// Per-member xanax accountability — who took xanax during the
    /// 24h pre-war + war window and whether their attack count met
    /// the 1 xanax = 10 attacks expectation.
    struct XanaxAccountability {
        let totalXanaxTaken: Int
        let membersWhoTook: Int
        let membersFlagged: Int
        let rule: String
        let rows: [Row]

        struct Row: Identifiable {
            let id: String      // playerId
            let name: String
            let xanaxTaken: Int
            let attacks: Int
            let expectedAttacks: Int
            let attackDeficit: Int
            let flagged: Bool
        }
    }
}
