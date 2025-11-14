import Foundation
import plate

public protocol Middleware: Sendable {
    var name: String { get }
    func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse
}


// public struct Middleware: Sendable {
//     public let name: String
//     public let handler: @Sendable (HTTPRequest, Router, @Sendable (HTTPRequest, Router) async -> HTTPResponse) async -> HTTPResponse
    
//     public init(
//         name: String,
//         handler: @Sendable @escaping (HTTPRequest, Router, @Sendable (HTTPRequest, Router) async -> HTTPResponse) async -> HTTPResponse
//     ) {
//         self.name = name
//         self.handler = handler
//     }
    
//     // Static Predefined Middleware

//     /// Bearer token authentication middleware
//     public static func bearer(
//         expecting rawKey: String,
//         realmName: String = "api"
//     ) -> Middleware {
//         Middleware(
//             name: "bearer-auth",
//             handler: { request, router, next in
//                 let (status, response) = authenticate(expected: rawKey, provided: request.bearerToken())
//                 if status != .authorized {
//                     return response
//                 }

//                 return await next(request, router)
//             }
//         )
//     }
    
//     /// Bearer token authentication middleware
//     public static func bearer(
//         symbol: String,
//         realmName: String = "api"
//     ) -> Middleware {
//         Middleware(
//             name: "bearer-auth",
//             handler: { request, router, next in
//                 let expected: String?
//                 expected = try? EnvironmentExtractor.value(.symbol(symbol))

//                 let (status, response) = authenticate(expected: expected, provided: request.bearerToken())
//                 if status != .authorized {
//                     return response
//                 }

//                 return await next(request, router)
//             }
//         )
//     }

//     internal enum AuthorizationStatus: Sendable, Codable {
//         case authorized
//         case misconfigured
//         case missing
//         case invalid

//         internal var body: String {
//             switch self {
//                 case .authorized:
//                     return ""
//                 case .misconfigured:
//                     return "Server misconfigured: key has not been set."
//                 case .missing:
//                     return "Missing or invalid Authorization header."
//                 case .invalid:
//                     return "Invalid API token"
//             }
//         }

//         internal var bearerError: String {
//             switch self {
//                 case .authorized:
//                     return ""
//                 case .misconfigured:
//                     return ""
//                 case .missing:
//                     return ""
//                 case .invalid:
//                     return "invalid_token"
//             }
//         }
//     }

//     internal static func authenticate(
//         expected: String?,
//         provided: String?,
//         bearerRealm: String = "api"
//     ) -> (AuthorizationStatus, HTTPResponse) {
//         let status: AuthorizationStatus
//         let response: HTTPResponse

//         if expected == nil {
//             status = .misconfigured
//             response = .unauthorized(
//                 body: status.body,
//                 bearerRealm: bearerRealm
//             )
//         } else if provided == nil {
//             status = .missing
//             response = .unauthorized(
//                 body: status.body,
//                 bearerRealm: bearerRealm
//             )
//         } else if !(provided == expected) {
//             status = .invalid
//             response = .unauthorized(
//                 body: status.body,
//                 bearerError: status.bearerError
//             )
//         } else {
//             status = .authorized
//             response = .ok()
//         }

//         return (status, response)
//     }
    
//     /// Request logging middleware
//     public static func logging(level: LogLevel = .info) -> Middleware {
//         Middleware(
//             name: "logging",
//             handler: { request, router, next in
//                 print("[\(level.rawValue)] \(request.method.rawValue) \(request.path)")
//                 let response = await next(request, router)
//                 print("[\(level.rawValue)] -> \(response.status.code)")
//                 return response
//             }
//         )
//     }
    
//     /// Custom middleware with closure
//     public static func custom(
//         name: String,
//         _ handler: @Sendable @escaping (HTTPRequest, Router, @Sendable (HTTPRequest, Router) async -> HTTPResponse) async -> HTTPResponse
//     ) -> Middleware {
//         Middleware(name: name, handler: handler)
//     }
// }
