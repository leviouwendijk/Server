import Foundation

@resultBuilder
public enum GroupBuilder: Sendable {
    public static func buildBlock(_ components: [Route]...) -> [Route] {
        components.flatMap { $0 }
    }
    
    public static func buildArray(_ components: [[Route]]) -> [Route] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [Route]?) -> [Route] {
        component ?? []
    }
    
    public static func buildEither(first: [Route]) -> [Route] {
        first
    }
    
    public static func buildEither(second: [Route]) -> [Route] {
        second
    }
    
    public static func buildExpression(_ routes: [Route]) -> [Route] {
        routes
    }
    
    public static func buildExpression(_ route: Route) -> [Route] {
        [route]
    }

    public static func buildExpression(_ group: GroupWithMiddleware) -> [Route] {
        group.routes
    }
}
