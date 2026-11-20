import Foundation

struct ServerProcessFixtureReady:
    Codable,
    Sendable,
    Equatable
{
    let host: String
    let port: UInt16
}
