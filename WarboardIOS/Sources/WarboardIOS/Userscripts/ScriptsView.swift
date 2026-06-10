import SwiftUI

@MainActor
final class ScriptsViewModel: ObservableObject {
    @Published var scripts: [Userscript] = []
    @Published var addURLText: String = ""
    @Published var isWorking: Bool = false
    @Published var errorMessage: String?
    @Published var updatesAvailable: Set<String> = []

    private let registry: ScriptRegistry
    private let resolver: RequireResolver
    private let session: URLSession

    init(registry: ScriptRegistry = ScriptRegistry(),
         requireCache: RequireCache = RequireCache(root: RequireCache.defaultRoot()),
         session: URLSession = .shared) {
        self.registry = registry
        self.resolver = RequireResolver.live(cache: requireCache, session: session)
        self.session = session
    }

    func reload() {
        scripts = registry.all()
    }

    func add() async {
        let url = addURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: url), u.scheme == "https" || u.scheme == "http" else {
            errorMessage = "Not a valid URL."
            return
        }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let (data, _) = try await session.data(from: u)
            guard let source = String(data: data, encoding: .utf8) else {
                errorMessage = "Couldn't read the script (not UTF-8)."
                return
            }
            let meta = try MetadataParser.parse(source)
            let script = Self.makeScript(from: meta, source: source, downloadURL: u.absoluteString)
            try await resolver.resolve(script)
            try registry.add(script)
            addURLText = ""
            reload()
        } catch let e as MetadataParseError {
            errorMessage = Self.message(for: e)
        } catch let e as RequireResolver.RequireError {
            errorMessage = "A @require library failed to download: \(e.url) — \(e.reason)"
        } catch {
            errorMessage = "Couldn't add the script: \(error.localizedDescription)"
        }
    }

    func setEnabled(_ script: Userscript, _ enabled: Bool) {
        try? registry.setEnabled(id: script.id, enabled)
        reload()
    }

    func remove(_ script: Userscript) {
        try? registry.remove(id: script.id)
        updatesAvailable.remove(script.id)
        reload()
    }

    func move(from source: IndexSet, to destination: Int) {
        var ordered = scripts
        ordered.move(fromOffsets: source, toOffset: destination)
        try? registry.reorder(ids: ordered.map(\.id))
        reload()
    }

    func checkForUpdates() async {
        var found: Set<String> = []
        for script in scripts {
            guard let urlStr = script.updateURL ?? script.downloadURL,
                  let u = URL(string: urlStr) else { continue }
            guard let (data, _) = try? await session.data(from: u),
                  let source = String(data: data, encoding: .utf8),
                  let remote = try? MetadataParser.parse(source)
            else { continue }
            guard let installed = script.version, let remoteVersion = remote.version else { continue }
            if VersionCompare.isUpdate(installed: installed, remote: remoteVersion) {
                found.insert(script.id)
            }
        }
        updatesAvailable = found
    }

    func update(_ script: Userscript) async {
        guard let urlStr = script.updateURL ?? script.downloadURL,
              let u = URL(string: urlStr) else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let (data, _) = try await session.data(from: u)
            guard let source = String(data: data, encoding: .utf8) else { return }
            let meta = try MetadataParser.parse(source)
            var fresh = Self.makeScript(from: meta, source: source, downloadURL: urlStr)
            try await resolver.resolve(fresh, forceRefetch: true)
            fresh.id = script.id
            fresh.enabled = script.enabled
            fresh.order = script.order
            fresh.wildcardConnectGranted = script.wildcardConnectGranted
            try registry.upsert(fresh)
            updatesAvailable.remove(script.id)
            reload()
        } catch {
            errorMessage = "Update failed: \(error.localizedDescription)"
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

    private static func message(for error: MetadataParseError) -> String {
        switch error {
        case .missingBlock:
            return "No ==UserScript== metadata block — that doesn't look like a userscript."
        case .unterminatedBlock:
            return "The ==UserScript== block is missing its ==/UserScript== close."
        }
    }
}

public struct ScriptsView: View {
    public init() {}
    @StateObject private var vm = ScriptsViewModel()

    public var body: some View {
        List {
            addSection
            if let msg = vm.errorMessage {
                Section { Text(msg).foregroundStyle(.red).font(.footnote) }
            }
            installedSection
        }
        .navigationTitle("Scripts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.checkForUpdates() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .onAppear { vm.reload() }
    }

    private var addSection: some View {
        Section("Add by URL") {
            HStack {
                TextField("https://…/script.user.js", text: $vm.addURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                Button("Add") { Task { await vm.add() } }
                    .disabled(vm.addURLText.isEmpty || vm.isWorking)
            }
            if vm.isWorking { ProgressView() }
        }
    }

    private var installedSection: some View {
        Section("Installed (\(vm.scripts.count))") {
            ForEach(vm.scripts) { script in
                ScriptRow(
                    script: script,
                    updateAvailable: vm.updatesAvailable.contains(script.id),
                    onToggle: { vm.setEnabled(script, $0) },
                    onUpdate: { Task { await vm.update(script) } }
                )
            }
            .onDelete { idx in
                idx.map { vm.scripts[$0] }.forEach(vm.remove)
            }
            .onMove(perform: vm.move)
        }
    }
}

private struct ScriptRow: View {
    let script: Userscript
    let updateAvailable: Bool
    let onToggle: (Bool) -> Void
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(script.name).font(.headline)
                Text("v\(script.version ?? "—")").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(get: { script.enabled }, set: onToggle))
                    .labelsHidden()
            }
            Text(matchSummary).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            if updateAvailable {
                Button(action: onUpdate) {
                    Label("Update available", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var matchSummary: String {
        guard let first = script.matches.first else { return "no @match" }
        let extra = script.matches.count - 1
        return extra > 0 ? "\(first)  +\(extra) more" : first
    }
}
