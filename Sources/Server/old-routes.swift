// import Foundation

// public let router = Router(routes: [
//     // GET /
//     Route(method: .GET, path: "/", handler: { _, _ async -> HTTPResponse in
//         HTTPResponse(status: .ok, body: "Root handler. Try GET /ping, GET /routes or POST /echo.")
//     }),

//     // GET /ping -> pong
//     Route(method: .GET, path: "/ping", handler: { _, _ async -> HTTPResponse in
//         HTTPResponse(status: .ok, body: "pong")
//     }),

//     // GET /routes -> list endpoints (now safe)
//     Route(method: .GET, path: "/routes", handler: { _, router async -> HTTPResponse in
//         let lines = router.routes
//             .map { "\($0.method.rawValue) \($0.path)" }
//             .joined(separator: "\n")

//         var resp = HTTPResponse(status: .ok, body: lines)
//         resp.headers["Content-Type"] = "text/plain; charset=utf-8"
//         return resp
//     }),

//     // POST /echo -> echo body
//     Route(method: .POST, path: "/echo", handler: { request, _ async -> HTTPResponse in
//         HTTPResponse(status: .ok, body: "echo: \(request.body)")
//     }),

//     // POST /upper -> uppercase of body
//     Route(method: .POST, path: "/upper", handler: { request, _ async -> HTTPResponse in
//         HTTPResponse(status: .ok, body: request.body.uppercased())
//     }),

//     // POST /length -> length of body
//     Route(method: .POST, path: "/length", handler: { request, _ async -> HTTPResponse in
//         let count = request.body.count
//         return HTTPResponse(status: .ok, body: "body length: \(count)")
//     }),

//     // POST /pkl-info -> parse PKL-ish body and return flattened keys
//     // Route(method: .POST, path: "/pkl-info", handler: { request, _ async -> HTTPResponse in
//     Route(method: .POST, path: "/pkl-info", handler: requireBearerAuth { request, _ in
//         let parsed = parseSimplePKL(request.body)
//         if parsed.isEmpty {
//             return HTTPResponse(
//                 status: .badRequest,
//                 body: "No PKL-style key/value pairs could be parsed."
//             )
//         }

//         let lines = parsed
//             .sorted(by: { $0.key < $1.key })
//             .map { "\($0.key) = \($0.value)" }
//             .joined(separator: "\n")

//         var resp = HTTPResponse(status: .ok, body: lines)
//         resp.headers["Content-Type"] = "text/plain; charset=utf-8"
//         return resp
//     }),

//     // NEW: POST /pkl-eval -> run PKL through PklSwift evaluator
//     Route(method: .POST, path: "/pkl-eval", handler: { request, _ async -> HTTPResponse in
//         do {
//             let output = try await evaluatePklBody(request.body)
//             var resp = HTTPResponse(status: .ok, body: output)
//             resp.headers["Content-Type"] = "text/plain; charset=utf-8"
//             return resp
//         } catch {
//             // You can branch on PKLEvalError if you want 4xx vs 5xx
//             return HTTPResponse(
//                 status: .internalServerError,
//                 body: "PKL eval error: \(error.localizedDescription)"
//             )
//         }
//     }),

//     // POST /pkl-json -> JSONValue as pretty JSON
//     Route(method: .POST, path: "/pkl-json", handler: { request, _ async -> HTTPResponse in
//         do {
//             let value = try await evaluatePklJSONBody(request.body)

//             let encoder = JSONEncoder()
//             encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

//             let data = try encoder.encode(value)
//             guard let json = String(data: data, encoding: .utf8) else {
//                 return HTTPResponse(status: .internalServerError, body: "Encoding error")
//             }

//             var resp = HTTPResponse(status: .ok, body: json)
//             resp.headers["Content-Type"] = "application/json; charset=utf-8"
//             return resp
//         } catch {
//             return HTTPResponse(
//                 status: .internalServerError,
//                 body: "PKL json error: \(error.localizedDescription)"
//             )
//         }
//     }),

//     // POST /pkl-flatten -> "path = value"
//     Route(method: .POST, path: "/pkl-flatten", handler: { request, _ async -> HTTPResponse in
//         do {
//             let value = try await evaluatePklJSONBody(request.body)
//             let flat = flattenJSONValue(value)

//             let lines = flat
//                 .sorted(by: { $0.key < $1.key })
//                 .map { "\($0.key) = \($0.value)" }
//                 .joined(separator: "\n")

//             var resp = HTTPResponse(status: .ok, body: lines)
//             resp.headers["Content-Type"] = "text/plain; charset=utf-8"
//             return resp
//         } catch {
//             return HTTPResponse(
//                 status: .internalServerError,
//                 body: "PKL flatten error: \(error.localizedDescription)"
//             )
//         }
//     }),

//     // POST /pkl-types -> "path: Type"
//     Route(method: .POST, path: "/pkl-types", handler: { request, _ async -> HTTPResponse in
//         do {
//             let value = try await evaluatePklJSONBody(request.body)
//             let types = flattenJSONTypes(value)

//             let lines = types
//                 .sorted(by: { $0.key < $1.key })
//                 .map { "\($0.key): \($0.value)" }
//                 .joined(separator: "\n")

//             var resp = HTTPResponse(status: .ok, body: lines)
//             resp.headers["Content-Type"] = "text/plain; charset=utf-8"
//             return resp
//         } catch {
//             return HTTPResponse(
//                 status: .internalServerError,
//                 body: "PKL types error: \(error.localizedDescription)"
//             )
//         }
//     })
// ])
