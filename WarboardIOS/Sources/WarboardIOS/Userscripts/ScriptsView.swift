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

    init(registry: ScriptRegistry = ScriptRegistry.shared,
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
        // Download the FULL script from @downloadURL — NOT @updateURL, which is
        // often a metadata-only `.meta.js` (used only for the version check in
        // checkForUpdates). Fetching the .meta.js and saving it as the source
        // truncated the script to just its metadata block — no body, so the
        // script silently did nothing (no button / no overlay). This recurred on
        // every update of any script whose @updateURL is a .meta.js.
        guard let urlStr = script.downloadURL ?? script.updateURL,
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

    func installExtensionUpdate(_ id: String) async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await ExtensionRuntime.shared.installExtensionUpdate(id: id)
            ExtensionUpdateStore.shared.clear(id: id)
        } catch {
            errorMessage = "Extension update failed: \(error.localizedDescription)"
        }
    }

    /// Save an in-app edit of a script's source: re-parse its metadata, preserve
    /// the install identity (id/enabled/order/wildcard grant), upsert, re-resolve
    /// @require, and reload the live page so the change applies immediately.
    func saveEdit(_ script: Userscript, source newSource: String) async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let meta = try MetadataParser.parse(newSource)
            var fresh = Self.makeScript(from: meta, source: newSource,
                                        downloadURL: script.downloadURL ?? script.id)
            fresh.id = script.id
            fresh.enabled = script.enabled
            fresh.order = script.order
            fresh.wildcardConnectGranted = script.wildcardConnectGranted
            try registry.upsert(fresh)
            try? await resolver.resolve(fresh, forceRefetch: false)
            reload()
            NotificationCenter.default.post(name: .userscriptsDidChange, object: nil)
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
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
    @State private var extTick = 0
    @State private var editing: Userscript?
    @ObservedObject private var updateStore = ExtensionUpdateStore.shared

    public var body: some View {
        List {
            extensionsSection
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
                    Task { await vm.checkForUpdates(); await updateStore.check() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .onAppear { vm.reload(); Task { await updateStore.check() } }
        .sheet(item: $editing) { script in
            ScriptEditorView(script: script) { newSource in
                Task { await vm.saveEdit(script, source: newSource) }
            }
        }
    }

    /// Bundled WebExtensions (ReTorn) with an on/off switch. Toggling persists to
    /// ExtensionPrefs and posts `.userscriptsDidChange` so the live page rebuilds
    /// with the extension gated in/out immediately.
    @ViewBuilder private var extensionsSection: some View {
        let exts = ExtensionRuntime.shared.installedExtensions
        if !exts.isEmpty {
            Section("Extensions") {
                ForEach(exts) { ext in
                    Toggle(isOn: Binding(
                        get: { _ = extTick; return ExtensionPrefs.shared.isEnabled(ext.id) },
                        set: { on in
                            ExtensionRuntime.shared.setExtensionEnabled(ext.id, on)
                            extTick &+= 1
                            NotificationCenter.default.post(name: .userscriptsDidChange, object: nil)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ext.name)
                            Text("v\(ext.version) · \(ext.attribution)")
                                .font(.caption).foregroundStyle(.secondary)
                            if let newVersion = updateStore.available[ext.id] {
                                Button {
                                    Task { await vm.installExtensionUpdate(ext.id) }
                                } label: {
                                    Label("Install update: \(newVersion)", systemImage: "arrow.down.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .tint(.orange)
                                .disabled(vm.isWorking)
                            }
                        }
                    }
                }
            }
        }
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
                    onUpdate: { Task { await vm.update(script) } },
                    onEdit: { editing = script }
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
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(script.name).font(.headline)
                Text("v\(script.version ?? "—")").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: onEdit) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
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

/// Full-screen-ish source editor for a userscript. Edits the raw text and saves
/// it back; validates the `// ==UserScript==` block parses before saving so a
/// broken metadata block can't brick the script.
private struct ScriptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let title: String
    private let onSave: (String) -> Void
    @State private var text: String
    @State private var errorText: String?

    init(script: Userscript, onSave: @escaping (String) -> Void) {
        self.title = script.name
        self.onSave = onSave
        _text = State(initialValue: script.source)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .overlay(alignment: .bottom) {
                    if let errorText {
                        Text(errorText)
                            .font(.caption).foregroundStyle(.white)
                            .padding(8).background(.red, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.bottom, 8)
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            do { _ = try MetadataParser.parse(text) }
                            catch {
                                errorText = "The // ==UserScript== block has an error — fix it before saving."
                                return
                            }
                            onSave(text); dismiss()
                        }
                    }
                }
        }
    }
}
