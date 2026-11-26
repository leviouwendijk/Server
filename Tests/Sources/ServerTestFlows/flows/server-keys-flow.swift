import Foundation
import Server
import TestFlows

extension ServerSecurityFlows {
    /// Keys come from a directory found upwards from the executable, not from
    /// absolute paths in the env.
    static let serverKeysLocationFlow = TestFlow(
        "server.keys.location",
        title: "KeysDirectory finds env/keys upwards within the home folder; ServiceKeys names what is missing",
        tags: [
            "server",
            "keys",
            "config"
        ]
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ServerKeys-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL
        let home = root.appendingPathComponent("home", isDirectory: true)
        let keys = home.appendingPathComponent("repo/env/keys", isDirectory: true)
        let release = home.appendingPathComponent("repo/api/swift/app/v1/.build/release", isDirectory: true)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: keys.appendingPathComponent("app"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: release, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        // a relative keys directory is found upwards from the executable's folder
            let directory = try KeysDirectory("env/keys", from: [release], home: home)
            try Expect.equal(directory.url.path, keys.path, "nearest ancestor holding env/keys")
            try Expect.equal(directory.raw, "env/keys", "raw kept")


        // the search stays within the home folder
            try Expect.throwsError("boundary below the match") {
                _ = try KeysDirectory(
                    "env/keys",
                    from: [release],
                    home: home.appendingPathComponent("repo/api", isDirectory: true)
                )
            }


        // absolute and home-relative directories must exist as given
            try Expect.equal(
                try KeysDirectory("$HOME/repo/env/keys", from: [], home: home).url.path,
                keys.path,
                "$HOME expanded"
            )
            try Expect.throwsError("missing absolute directory") {
                _ = try KeysDirectory(root.appendingPathComponent("nope").path, from: [], home: home)
            }


        // ServiceKeys names the missing file and refuses names that leave the folder
            let located = try KeysDirectory("env/keys", from: [release], home: home)
            do {
                _ = try ServiceKeys(.init(directory: located, service: "app", publicKey: "jwt_public.pem"))
                throw TestFlowAssertionFailure(label: "missing", message: "loaded without key files")
            } catch let error as KeysError {
                try Expect.equal(
                    error,
                    .missingFile(keys.appendingPathComponent("app/jwt_public.pem").path),
                    "the missing file is named"
                )
            }
            try Expect.throwsError("climbing service name") {
                _ = try ServiceKeys(.init(directory: located, service: "../app"))
            }

        return []
    }
}
