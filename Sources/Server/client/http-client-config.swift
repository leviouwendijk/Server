import Foundation
import HTTP

public struct HTTPClientConfig: Sendable {
    public enum Transport: Sendable {
        case tcp(
            security: Security = .plaintext
        )
    }

    public enum Security: Sendable {
        case plaintext
        case tls(TLS = .init())
    }

    public struct TLS: Sendable {
        public init() {
        }
    }

    public let host: String
    public let port: UInt16
    public let transport: Transport
    public let timeout: TimeInterval
    public let policies: HTTPResponsePolicies
    public var debug: Bool

    public init(
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        transport: Transport = .tcp(),
        timeout: TimeInterval = 5,
        policies: HTTPResponsePolicies = HTTPPolicies.response.default,
        debug: Bool = false
    ) {
        self.host = host
        self.port = port
        self.transport = transport
        self.timeout = timeout
        self.policies = policies
        self.debug = debug
    }
}
