import Foundation

public struct HTTPClientConfig: Sendable {
    public let host: String
    public let port: UInt16
    public let timeout: TimeInterval
    public var debug: Bool
    
    public init(
        host: String = "127.0.0.1",
        port: UInt16 = 9090,
        timeout: TimeInterval = 5,
        debug: Bool = false
    ) {
        self.host = host
        self.port = port
        self.timeout = timeout
        self.debug = debug
    }
}
