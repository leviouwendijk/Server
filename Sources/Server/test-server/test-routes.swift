import Foundation
import Structures

public let testRoutes = routes {
    // Basic Routes
    get { _, _ in
        HTTPResponse(
            status: .ok,
            body: "Root handler. Try GET /ping, GET /routes or POST /echo."
        )
    }
    
    get("ping") { _, _ in
        .ok(body: "pong")
    }
    
    get("routes") { _, router in
        // let lines = router.listRoutes().joined(separator: "\n")
        // var resp = HTTPResponse(status: .ok, body: lines)
        // resp.headers["Content-Type"] = "text/plain; charset=utf-8"
        // return resp
        .text(router.listRoutes().joined(separator: "\n"))
    }
    
    // Echo Routes
    group("test") {
        post("echo") { request, _ in
            .ok(body: "echo: \(request.body)")
        }
        
        group("text") {
            post("upper") { request, _ in
                .ok(body: request.body.uppercased())
            }
            
            post("length") { request, _ in
                .ok(body: "body length: \(request.body.count)")
            }
        }
    }
    
    group("pkl") {
        post("info") { request, _ in
            guard let token = request.bearerToken() else {
                return .unauthorized(body: "Missing or invalid Authorization header.")
            }
            
            let parsed = parseSimplePKL(request.body)
            if parsed.isEmpty {
                return .badRequest(body: "No PKL-style key/value pairs could be parsed.")
            }
            
            let pklDict: [String: JSONValue] = parsed.mapValues { .string($0) }
            do {
                return try HTTPResponse.pkl(pklDict)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
        
        // post("eval") { request, _ async in
        //     do {
        //         let output = try await evaluatePklBody(request.body)
        //         return HTTPResponse.pkl(output)
        //     } catch {
        //         return .internalServerError(body: "PKL eval error: \(error.localizedDescription)")
        //     }
        // }
        
        // post("json") { request, _ async in
        //     do {
        //         let value = try await evaluatePklJSONBody(request.body)
        //         return try HTTPResponse.pkl(value)
        //     } catch {
        //         return .internalServerError(body: "PKL json error: \(error.localizedDescription)")
        //     }
        // }
        
        // post("pkl") { request, _ async in
        //     do {
        //         let value = try await evaluatePklJSONBody(request.body)
        //         return try HTTPResponse.pkl(value)
        //     } catch {
        //         return .internalServerError(body: "PKL rendering error: \(error.localizedDescription)")
        //     }
        // }
        
        // post("flatten") { request, _ async in
        //     do {
        //         let value = try await evaluatePklJSONBody(request.body)
        //         let flat = flattenJSONValue(value)
        //         let pklDict: [String: JSONValue] = flat.mapValues { .string($0) }
        //         return try HTTPResponse.pkl(pklDict)
        //     } catch {
        //         return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
        //     }
        // }
        
        // post("types") { request, _ async in
        //     do {
        //         let value = try await evaluatePklJSONBody(request.body)
        //         let types = flattenJSONTypes(value)
        //         let pklDict: [String: JSONValue] = types.mapValues { .string($0) }
        //         return try HTTPResponse.pkl(pklDict)
        //     } catch {
        //         return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
        //     }
        // }
    }
    
    group("admin", "users") {
        get { _, _ in
            let userList: [String: JSONValue] = [
                "total": .int(2),
                "users": .array([
                    .object(["id": .int(1), "name": .string("Alice"), "role": .string("admin")]),
                    .object(["id": .int(2), "name": .string("Bob"), "role": .string("user")])
                ])
            ]
            do {
                return try HTTPResponse.json(userList)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
        
        post { request, _ in
            let newUser: [String: JSONValue] = [
                "id": .int(3),
                "name": .string("Charlie"),
                "role": .string("user"),
                "created_at": .string("2025-11-14T12:00:00Z")
            ]
            do {
                return try HTTPResponse.json(newUser, status: .created)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
        
        get("123") { _, _ in
            let user: [String: JSONValue] = [
                "id": .int(123),
                "name": .string("Alice"),
                "email": .string("alice@example.com"),
                "role": .string("admin"),
                "active": .bool(true),
                "permissions": .array([
                    .string("read"),
                    .string("write"),
                    .string("delete")
                ])
            ]
            do {
                return try HTTPResponse.json(user)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
        
        put("123") { request, _ in
            let updatedUser: [String: JSONValue] = [
                "id": .int(123),
                "name": .string("Alice Updated"),
                "role": .string("super_admin"),
                "updated_at": .string("2025-11-14T12:30:00Z")
            ]
            do {
                return try HTTPResponse.json(updatedUser)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
        
        delete("123") { _, _ in
            .noContent()
        }
    }
    .use(BearerMiddleware(envSymbol: "LIBTEST_API_KEY"))

    // MARK: - Config Routes (PKL Examples)

    group("config") {
        get("app") { _, _ in
            let config: [String: JSONValue] = [
                "version": .string("1.0.0"),
                "debug": .bool(true),
                "port": .int(9090),
                "features": .array([
                    .string("authentication"),
                    .string("logging"),
                    .string("caching")
                ]),
                "database": .object([
                    "host": .string("localhost"),
                    "port": .int(5432),
                    "name": .string("myapp")
                ])
            ]
            do {
                return try HTTPResponse.json(config)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
        
        get("features") { _, _ in
            let features: [JSONValue] = [
                .object([
                    "name": .string("auth"),
                    "enabled": .bool(true),
                    "version": .string("2.0")
                ]),
                .object([
                    "name": .string("caching"),
                    "enabled": .bool(true),
                    "version": .string("1.5")
                ]),
                .object([
                    "name": .string("logging"),
                    "enabled": .bool(false),
                    "version": .string("1.0")
                ])
            ]
            do {
                return try HTTPResponse.json(features)
            } catch {
                return .internalServerError(body: "Failed to render response: \(error.localizedDescription)")
            }
        }
    }
}
