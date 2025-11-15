import Foundation

public struct GroupWithMiddleware: Sendable {
    public let routes: [Route]
    
    public func use(_ m: Middleware) -> [Route] {
        routes.map { $0.use(m) }
    }
    
    public func use(_ middleware: [Middleware]) -> [Route] {
        routes.map { $0.use(middleware) }
    }

    public func use(_ m: Middleware?) throws -> [Route] {
        guard let m else { throw RouteError.invalidMiddleware } 
        return self.use(m)
    }
    
    public func use(_ middleware: [Middleware]?) throws -> [Route] {
        guard let middleware else { throw RouteError.invalidMiddleware } 
        return self.use(middleware)
    }
}
