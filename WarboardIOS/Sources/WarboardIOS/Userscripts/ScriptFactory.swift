import Foundation

enum ScriptFactory {
    static func make(from meta: ScriptMetadata, source: String, downloadURL: String) -> Userscript {
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
