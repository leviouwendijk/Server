import Foundation
import Security

public final class CryptographicCASessionDelegate: NSObject, URLSessionDelegate {
    private let caCertificate: SecCertificate
    private let allowedHost: String?

    public init(
        caCertificate: SecCertificate,
        allowedHost: String? = nil
    ) {
        self.caCertificate = caCertificate
        self.allowedHost = allowedHost
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

        // Pin our CA as the only anchor
        SecTrustSetAnchorCertificates(trust, [caCertificate] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)

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
