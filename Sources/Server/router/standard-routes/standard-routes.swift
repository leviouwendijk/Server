import Foundation

// public enum StandardRoutes { 
//     public static func listRoutes() -> Route {
//         get("routes") { _, router in
//             do {
//                 return try router.listRoutes().response()
//             } catch {
//                 return .internalServerError(body: "Failed to list routes: \(error.localizedDescription)")
//             }
//         }
//     }
// }

import HTTP

public enum StandardRoutes {
    public static func disabledListRoutes() -> Route {
        get("routes") { _, _ in
            .notFound(
                body: "Not Found"
            )
        }
    }

    public static func listRoutes() -> Route {
        routeListHandler()
    }

    public static func publicListRoutes() -> Route {
        listRoutes()
    }

    public static func protectedListRoutes(
        rawKey: String,
        realmName: String = "routes"
    ) -> Route {
        listRoutes()
            .use(
                BearerMiddleware(
                    rawKey: rawKey,
                    realmName: realmName
                )
            )
    }

    public static func protectedListRoutes(
        symbol: String,
        realmName: String = "routes"
    ) -> Route {
        listRoutes()
            .use(
                BearerMiddleware(
                    symbol: symbol,
                    realmName: realmName
                )
            )
    }

    public static func protectedListRoutes(
        envSymbol: String,
        realmName: String = "routes"
    ) -> Route {
        listRoutes()
            .use(
                BearerMiddleware(
                    envSymbol: envSymbol,
                    realmName: realmName
                )
            )
    }

    private static func routeListHandler() -> Route {
        get("routes") { _, router in
            do {
                return try router.listRoutes().response()
            } catch {
                return .internalServerError(
                    body: "Failed to list routes"
                )
            }
        }
    }
}
