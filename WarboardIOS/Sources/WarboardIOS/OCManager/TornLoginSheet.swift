import SwiftUI
import WebKit

/// One-shot Torn sign-in sheet. Loads torn.com's login form in a real
/// WKWebView using the same WKWebsiteDataStore as TornWebSession's
/// offscreen action view, so the cookies the user sets here become
/// the cookies every loan/retrieve POST sends.
///
/// No auto-dismiss — the user taps **Done** when they're back at
/// Torn's home dashboard. Earlier versions auto-closed on landing-page
/// URL changes, but Torn's 2FA flow makes a transient hop through `/`
/// between password and OTP entry; the probe occasionally caught
/// enough partial session to call it "signed in" and closed the sheet
/// mid-OTP. The existing auto-pop on action failure handles the
/// "user dismissed too early" case — next Loan/Retrieve will throw
/// notSignedIn and re-pop this sheet.
struct TornLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = TornWebSession.shared

    var body: some View {
        NavigationStack {
            TornWebView(onURLChange: { _ in })
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Sign in to Torn")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            // Probe the session in the background so the
                            // toolbar reflects reality on the next visit.
                            // Don't gate dismissal on the probe — if the
                            // user tapped Done thinking they're logged
                            // in, trust them; the next action will
                            // re-pop the sheet if they were wrong.
                            Task { await session.refreshSignedInState() }
                            dismiss()
                        }
                        .bold()
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Text("Tap **Done** once you're back on Torn's home dashboard.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }
}

/// Plain UIViewRepresentable around WKWebView. Loads torn.com's login
/// page on first appear; reports every URL change so the host sheet
/// can detect login completion.
private struct TornWebView: UIViewRepresentable {
    let onURLChange: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onURLChange: onURLChange) }

    func makeUIView(context: Context) -> WKWebView {
        // Reuse the shared configuration so cookies set here land in
        // the SAME data store the action webview reads from.
        let cfg = TornWebSession.shared.configuration
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        // Observe URL changes (login redirects don't always fire
        // didFinish before the user's session is set, so observe
        // the URL directly via KVO).
        context.coordinator.observe(wv)
        wv.load(URLRequest(url: URL(string: "https://www.torn.com/login.php")!))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { /* no-op */ }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving(uiView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onURLChange: (URL) -> Void
        private var observation: NSKeyValueObservation?
        init(onURLChange: @escaping (URL) -> Void) { self.onURLChange = onURLChange }
        func observe(_ wv: WKWebView) {
            observation = wv.observe(\.url, options: [.new]) { [weak self] _, change in
                if let url = change.newValue, let url { self?.onURLChange(url) }
            }
        }
        func stopObserving(_ wv: WKWebView) {
            observation?.invalidate()
            observation = nil
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url { onURLChange(url) }
        }
    }
}
