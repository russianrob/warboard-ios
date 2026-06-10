import Foundation
import SwiftUI

/// Drives the Tampermonkey-style install-confirmation sheet shown when the
/// Browser tab navigates to a `.user.js`. Fetches + parses the script, decides
/// install-vs-update against the on-disk registry, and on confirmation resolves
/// its `@require` libs before adding it. Backed by the same shared registry +
/// resolver as the Scripts tab, so the install takes effect on the next
/// navigation (the controller re-reads the registry then).
@MainActor
final class InstallViewModel: ObservableObject {

    enum Phase: Equatable {
        case loading
        case ready
        case installing
        case installed
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading

    /// Parsed display fields, populated once `load` reaches `.ready`.
    @Published private(set) var name: String = ""
    @Published private(set) var version: String?
    @Published private(set) var matches: [String] = []
    @Published private(set) var grants: [String] = []
    @Published private(set) var connects: [String] = []

    /// True when an already-installed script matches this one; flips the
    /// primary button to "Update" and routes the registry write through upsert.
    @Published private(set) var isUpdate: Bool = false

    private let registry: ScriptRegistry
    private let resolver: RequireResolver
    private let session: URLSession

    /// Fetched script body, held between `load` and `install`.
    private var source: String?
    /// Parsed metadata, held between `load` and `install`.
    private var meta: ScriptMetadata?
    /// The URL the script was fetched from (used as the download URL fallback).
    private var sourceURL: URL?
    /// The installed script this one updates, if any.
    private var existing: Userscript?

    init(registry: ScriptRegistry = ScriptRegistry.shared,
         requireCache: RequireCache = RequireCache(root: RequireCache.defaultRoot()),
         session: URLSession = .shared) {
        self.registry = registry
        self.resolver = RequireResolver.live(cache: requireCache, session: session)
        self.session = session
    }

    /// Fetch + parse the `.user.js`, surfacing display fields and the
    /// install-vs-update decision. Failures set `.error(...)`.
    func load(url: URL) async {
        phase = .loading
        sourceURL = url
        do {
            let (data, _) = try await session.data(from: url)
            guard let body = String(data: data, encoding: .utf8) else {
                phase = .error("Couldn't read the script (not UTF-8).")
                return
            }
            let parsed = try MetadataParser.parse(body)
            guard !parsed.matches.isEmpty else {
                phase = .error("This doesn't look like a userscript.")
                return
            }

            source = body
            meta = parsed
            name = parsed.name ?? url.absoluteString
            version = parsed.version
            matches = parsed.matches
            grants = parsed.grants
            connects = parsed.connects

            let installed = findInstalled(meta: parsed, url: url)
            existing = installed
            if let installed,
               let have = installed.version, let want = parsed.version {
                isUpdate = VersionCompare.isUpdate(installed: have, remote: want)
            } else {
                isUpdate = installed != nil
            }

            phase = .ready
        } catch let e as MetadataParseError {
            switch e {
            case .missingBlock, .unterminatedBlock:
                phase = .error("This doesn't look like a userscript.")
            }
        } catch {
            phase = .error("Couldn't download the script: \(error.localizedDescription)")
        }
    }

    /// Assemble the `Userscript`, resolve its `@require` libs, then add (or
    /// upsert on update). A `@require` fetch failure aborts without installing.
    func install() async {
        guard let meta, let source, let url = sourceURL else { return }
        phase = .installing
        do {
            var script = Self.makeScript(from: meta, source: source,
                                         downloadURL: url.absoluteString)
            try await resolver.resolve(script)
            if let existing {
                script.id = existing.id
                script.enabled = existing.enabled
                script.order = existing.order
                script.wildcardConnectGranted = existing.wildcardConnectGranted
                try registry.upsert(script)
            } else {
                try registry.add(script)
            }
            phase = .installed
        } catch let e as RequireResolver.RequireError {
            phase = .error("A @require library failed to download: \(e.url) — \(e.reason)")
        } catch {
            phase = .error("Couldn't install the script: \(error.localizedDescription)")
        }
    }

    /// Match an installed script by name+namespace, falling back to the
    /// download URL / source URL when the new script omits a name.
    private func findInstalled(meta: ScriptMetadata, url: URL) -> Userscript? {
        let installed = registry.all()
        if let name = meta.name {
            if let hit = installed.first(where: {
                $0.name == name && $0.namespace == meta.namespace
            }) {
                return hit
            }
        }
        let urlString = url.absoluteString
        let downloadURL = meta.downloadURL ?? urlString
        return installed.first {
            $0.downloadURL == downloadURL || $0.downloadURL == urlString
        }
    }

    private static func makeScript(from meta: ScriptMetadata,
                                   source: String,
                                   downloadURL: String) -> Userscript {
        Userscript(
            id: SHA256Pure.hexDigest(downloadURL),
            name: meta.name ?? downloadURL,
            namespace: meta.namespace,
            version: meta.version,
            description: meta.description,
            matches: meta.matches,
            includes: meta.includes,
            excludes: meta.excludes,
            requires: meta.requires,
            connects: meta.connects,
            grants: meta.grants,
            runAt: meta.runAt,
            icon: meta.icon,
            downloadURL: meta.downloadURL ?? downloadURL,
            updateURL: meta.updateURL,
            enabled: true,
            order: 0,
            source: source,
            wildcardConnectGranted: false
        )
    }
}

/// Tampermonkey-style install-confirmation sheet. Shows what the script runs on
/// and what it can access, then installs/updates on confirm.
struct InstallScriptView: View {
    let url: URL
    let onClose: () -> Void

    @StateObject private var vm = InstallViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Install Userscript")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onClose)
                    }
                }
        }
        .task { await vm.load(url: url) }
    }

    @ViewBuilder private var content: some View {
        switch vm.phase {
        case .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            errorView(message)
        case .installed:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(vm.isUpdate ? "Updated" : "Installed")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                onClose()
            }
        case .ready, .installing:
            detail
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    HStack {
                        Text(vm.name).font(.headline)
                        Spacer()
                        Text("v\(vm.version ?? "—")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Runs on") {
                    if vm.matches.isEmpty {
                        Text("Nothing").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.matches, id: \.self) { pattern in
                            Text(pattern).font(.footnote.monospaced())
                        }
                    }
                }

                Section("Permissions") {
                    if vm.grants.isEmpty && vm.connects.isEmpty {
                        Text("None requested").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.grants, id: \.self) { grant in
                            Label(grant, systemImage: "key.fill")
                                .font(.footnote)
                        }
                        ForEach(vm.connects, id: \.self) { host in
                            Label("connect: \(host)", systemImage: "network")
                                .font(.footnote)
                        }
                    }
                }
            }

            installButton
                .padding()
        }
    }

    private var installButton: some View {
        Button {
            Task { await vm.install() }
        } label: {
            HStack {
                if vm.phase == .installing { ProgressView() }
                Text(vm.isUpdate ? "Update" : "Install")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(vm.phase == .installing)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Close", action: onClose)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
