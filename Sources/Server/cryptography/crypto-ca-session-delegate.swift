import Foundation
import Security
import plate

public final class CryptographicCASessionDelegate: NSObject, URLSessionDelegate {
    private let caCertificate: SecCertificate
    private let allowedHost: String?
    private let anchorOnly: Bool

    public init(
        caCertificate: SecCertificate,
        allowedHost: String? = nil,
        anchorOnly: Bool = true
    ) {
        self.caCertificate = caCertificate
        self.allowedHost = allowedHost
        self.anchorOnly = anchorOnly
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if let allowedHost {
            let host = challenge.protectionSpace.host
            guard host == allowedHost else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
        }

        // Pin our CA as an anchor certificate
        SecTrustSetAnchorCertificates(trust, [caCertificate] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, anchorOnly)

        var error: CFError?
        let ok = SecTrustEvaluateWithError(trust, &error)

        if ok {
            let credential = URLCredential(trust: trust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

public enum CryptographicTrustedURLSession {
    public static func create(
        caCertificate: SecCertificate,
        allowedHost: String? = nil,
        anchorOnly: Bool = true,
        configuration: URLSessionConfiguration = .ephemeral
    ) -> URLSession {
        let delegate = CryptographicCASessionDelegate(
            caCertificate: caCertificate,
            allowedHost: allowedHost,
            anchorOnly: anchorOnly
        )
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    public static func create(
        caCertificatePathSymbol: String,
        allowedHost: String? = nil,
        anchorOnly: Bool = true,
        configuration: URLSessionConfiguration = .ephemeral
    ) throws -> URLSession {
        let caPath = try EnvironmentExtractor.value(.symbol(caCertificatePathSymbol))
        let caCert = try CryptographicTLSCertificateLoader.loadCertificate(at: caPath)
        let delegate = CryptographicCASessionDelegate(
            caCertificate: caCert,
            allowedHost: allowedHost,
            anchorOnly: anchorOnly
        )
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}
