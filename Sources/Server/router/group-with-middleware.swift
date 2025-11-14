import Foundation

public struct GroupWithMiddleware: Sendable {
    public let routes: [Route]
    
    public func use(_ m: Middleware) -> [Route] {
        routes.map { $0.use(m) }
    }
    
    public func use(_ middleware: [Middleware]) -> [Route] {
        routes.map { $0.use(middleware) }
    }
}
