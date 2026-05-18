import WidgetKit
import SwiftUI

/// Widget extension entry point. Hosts the chain-break Live Activity
/// and the home-screen Status widget (v0.4.60+: Energy / Nerve /
/// Drug / Booster card driven by App Group-shared BarsCache).
@main
struct ChainWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChainLiveActivity()
        StatusWidget()
    }
}
