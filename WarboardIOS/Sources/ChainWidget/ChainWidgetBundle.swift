import WidgetKit
import SwiftUI

/// Widget extension entry point. v0.3.0 ships only the chain-break
/// Live Activity; lock-screen widgets / home-screen complications can
/// be added here later as additional cases.
@main
struct ChainWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChainLiveActivity()
    }
}
