import Cryptography
import Foundation
import Path
import Primitives
import Security

/// A service's loaded key pair, from `<keys directory>/<service>/`.
///
/// The file names are the service's own, fixed in code (`jwt_public.pem`);
/// only the keys directory comes from configuration.
public struct ServiceKeys: Invariant, Sendable {
    public struct Raw: Sendable, Hashable {
        public var directory: KeysDirectory
        public var service: String
        public var publicKey: String
        public var privateKey: String

        public init(
            directory: KeysDirectory,
            service: String,
            publicKey: String = "public.pem",
            privateKey: String = "private.pem"
        ) {
            self.directory = directory
            self.service = service
            self.publicKey = publicKey
            self.privateKey = privateKey
        }
    }

    public typealias Error = KeysError

    /// `<keys directory>/<service>/`.
    public let directory: URL
    public let pair: CryptographicKeyPair

    public init(
        _ raw: Raw
    ) throws(KeysError) {
        let service = try Self.name(raw.service)
        let directory = raw.directory.url.appendingPathComponent(service, isDirectory: true)
        let publicURL = directory.appendingPathComponent(try Self.name(raw.publicKey))
        let privateURL = directory.appendingPathComponent(try Self.name(raw.privateKey))

        for url in [publicURL, privateURL] where !PathExistence.isFile(url: url) {
            throw .missingFile(url.path)
        }

        let publicKey: SecKey
        let privateKey: SecKey
        do {
            publicKey = try CryptographicKeyOperation.loadPublicKey(at: publicURL.path)
        } catch {
            throw .unreadable(path: publicURL.path, reason: "\(error)")
        }
        do {
            privateKey = try CryptographicKeyOperation.loadPrivateKey(at: privateURL.path)
        } catch {
            throw .unreadable(path: privateURL.path, reason: "\(error)")
        }

        self.directory = directory
        self.pair = CryptographicKeyPair(
            publicKey: publicKey,
            privateKey: privateKey
        )
    }

    /// One plain name: the service folder or a file inside it, never a way out.
    static func name(
        _ value: String
    ) throws(KeysError) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              trimmed != ".",
              trimmed != ".." else {
            throw .invalidName(value)
        }
        return trimmed
    }
}
