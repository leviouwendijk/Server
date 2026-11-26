import Foundation
import Milieu
import Path
import Primitives

/// A keys directory that exists, from a configured path such as `env/keys`.
///
/// A relative path is found upwards: the nearest ancestor of the executable,
/// then of the working directory, that holds it, never above the home folder.
/// So a checkout works under any home folder, layout or OS, and the env names
/// `env/keys` instead of an absolute path. Climbing is allowed here because
/// the path comes from the service's own configuration, never from a request.
/// An absolute, `~/…` or `$HOME/…` path is used as given.
public struct KeysDirectory: Invariant, Sendable, Hashable {
    public typealias Raw = String
    public typealias Error = KeysError

    public let raw: String
    public let url: URL

    public init(
        _ raw: String
    ) throws(KeysError) {
        try self.init(
            raw,
            from: Self.searchStarts(),
            home: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    /// Searches from `starts` (in order) within `home`; for tests and tools.
    public init(
        _ raw: String,
        from starts: [URL],
        home: URL
    ) throws(KeysError) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw .directoryNotFound(raw)
        }

        let expanded = Self.expandingHome(trimmed, home: home)
        if expanded.hasPrefix("/") {
            let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
            guard PathExistence.isDirectory(url: url) else {
                throw .directoryNotFound(raw)
            }
            self.raw = raw
            self.url = url
            return
        }

        for start in starts {
            if let found = PathAncestorSearch.resolvingUpwards(
                expanded,
                startingAt: start,
                boundary: home
            ), PathExistence.isDirectory(url: found) {
                self.raw = raw
                self.url = found.standardizedFileURL
                return
            }
        }
        throw .directoryNotFound(raw)
    }

    /// From the environment: `KEYS_DIRECTORY=env/keys`.
    public init(
        symbol: String = "KEYS_DIRECTORY"
    ) throws(KeysError) {
        guard let value = try? EnvironmentExtractor.value(.symbol(symbol)),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw .unset(symbol: symbol)
        }
        try self.init(value)
    }

    /// The executable's folder (symlinks resolved), then the working directory.
    public static func searchStarts() -> [URL] {
        var starts: [URL] = []
        if let executable = Bundle.main.executableURL {
            starts.append(executable.resolvingSymlinksInPath().deletingLastPathComponent())
        }
        starts.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
        return starts
    }

    static func expandingHome(
        _ path: String,
        home: URL
    ) -> String {
        if path == "~" || path == "$HOME" {
            return home.path
        }
        for prefix in ["~/", "$HOME/"] where path.hasPrefix(prefix) {
            return home.appendingPathComponent(String(path.dropFirst(prefix.count))).path
        }
        return path
    }
}
