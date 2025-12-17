import Foundation
import HTTP

public protocol Middleware: Sendable {
    var name: String { get }
    func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse
}
