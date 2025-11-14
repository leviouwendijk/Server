import Foundation

public enum StandardRoutes { 
    public static func listRoutes() -> Route {
        get("routes") { _, router in
            do {
                return try router.listRoutes().response()
            } catch {
                return .internalServerError(body: "Failed to list routes: \(error.localizedDescription)")
            }
        }
    }
}
