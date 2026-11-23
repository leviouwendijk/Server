import Foundation
import HTTP
import Primitives

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
    ) throws -> Route {
        listRoutes()
            .use(
                try BearerMiddleware(
                    symbol: symbol,
                    realmName: realmName
                )
            )
    }

    /// `GET /whoami`: the client address this server resolved, with the socket peer and the
    /// forwarding headers it saw. A diagnostic for the proxy chain; protect it with the
    /// service's bearer middleware.
    public static func whoami() -> Route {
        get("whoami") { request, _ in
            let fields: [String: JSONValue] = [
                "client_ip": request.clientIP.map(JSONValue.string) ?? .null,
                "peer": request.peerAddress.map(JSONValue.string) ?? .null,
                "x_forwarded_for": request.header("X-Forwarded-For").map(JSONValue.string) ?? .null,
                "x_real_ip": request.header("X-Real-IP").map(JSONValue.string) ?? .null,
            ]

            do {
                return try .json(
                    fields
                )
            } catch {
                return .internalServerError(
                    body: "Failed to render whoami"
                )
            }
        }
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
