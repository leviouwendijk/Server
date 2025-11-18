import Foundation
import Security

public enum CryptographicTLSCertificateLoader {
    public enum Error: Swift.Error, LocalizedError {
        case failedToReadFile(String)
        case failedToParsePEM(String)
        case failedToCreateCertificate(String)

        public var errorDescription: String? {
            switch self {
            case .failedToReadFile(let path):
                return "Failed to read certificate file at \(path)"
            case .failedToParsePEM(let reason):
                return "Failed to parse PEM certificate: \(reason)"
            case .failedToCreateCertificate(let reason):
                return "Failed to create SecCertificate: \(reason)"
            }
        }
    }

    /// Load an X.509 certificate from a PEM or DER file.
    public static func loadCertificate(at path: String) throws -> SecCertificate {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw Error.failedToReadFile(path)
        }

        // Try PEM first (BEGIN CERTIFICATE)
        if let s = String(data: data, encoding: .utf8),
           s.contains("-----BEGIN CERTIFICATE-----") {
            guard let der = CryptographicKeyOperation.pemBody(
                s,
                begin: "-----BEGIN CERTIFICATE-----",
                end: "-----END CERTIFICATE-----"
            ) else {
                throw Error.failedToParsePEM("PEM body could not be base64 decoded")
            }

            guard let cert = SecCertificateCreateWithData(nil, der as CFData) else {
                throw Error.failedToCreateCertificate("SecCertificateCreateWithData returned nil (PEM)")
            }
            return cert
        }

        // Otherwise assume DER
        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
            throw Error.failedToCreateCertificate("SecCertificateCreateWithData returned nil (DER)")
        }
        return cert
    }
}
