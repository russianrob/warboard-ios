import SwiftUI
import SafariServices

/// Wraps `SFSafariViewController` so any view can present an in-app
/// Safari view via `.sheet`. Shares the system Safari cookie jar, so
/// the user is already logged in to Torn — attack / profile pages
/// land where they should without a second login. The Safari sheet
/// has a built-in "Done" button (top-left) that dismisses cleanly
/// back to the app — that's the X-in-the-corner.
struct SafariSheet: View, Identifiable {
    let id = UUID()
    let url: URL

    var body: some View {
        SafariViewControllerRepresentable(url: url)
            .ignoresSafeArea()
    }
}

private struct SafariViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = false
        cfg.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: cfg)
        vc.preferredBarTintColor = UIColor(red: 0.04, green: 0.06, blue: 0.07, alpha: 1)
        vc.preferredControlTintColor = .white
        vc.dismissButtonStyle = .close   // shows "✕" instead of "Done"
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Identifier for the @State Binding<SafariSheet?> pattern that makes
/// presenting from multiple buttons in the same view clean.
extension URL {
    var asSafariSheet: SafariSheet { SafariSheet(url: self) }
}
