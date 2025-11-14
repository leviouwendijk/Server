import Foundation

public struct RouteList: Codable, ReturnableResponse {
    public let count: Int
    public let routes: [RouteSummary]
    
    public init(routes: [RouteSummary]) {
        self.routes = routes
        self.count = routes.count
    }
}
