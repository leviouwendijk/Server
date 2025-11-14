import Foundation

public struct RouteSummary: Codable, ReturnableResponse {
    public let method: String
    public let path: String
    
    public init(method: String, path: String) {
        self.method = method
        self.path = path
    }
    
    public init(from route: Route) {
        self.method = route.method.rawValue
        self.path = route.path
    }
}
