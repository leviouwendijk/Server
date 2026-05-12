import Foundation
import HTTP
import Server

extension Operation {
    public enum Live {
        public static let routeDescriptions: [String] = [
            "GET  /",
            "GET  /health",
            "GET  /routes",
            "GET  /v1/config",
            "GET  /v1/headers",
            "GET  /v1/token",
            "POST /v1/token/validate",
            "POST /v1/echo",
            "POST /v1/forms/contact",
            "POST /v1/forms/signup",
            "POST /v1/events/collect",
            "GET  /v1/error"
        ]

        public static func home() -> HTTPResponse {
            .ok(
                body: "servlive mock API"
            )
        }

        public static func health() throws -> HTTPResponse {
            try Model.Response.Status(
                success: true,
                status: "ok"
            ).response()
        }

        public static func routeList() throws -> HTTPResponse {
            try Model.Response.RouteList(
                routes: routeDescriptions
            ).response()
        }

        public static func config() throws -> HTTPResponse {
            try Model.Response.Config(
                features: [
                    "health",
                    "headers",
                    "token",
                    "forms",
                    "events",
                    "echo"
                ]
            ).response()
        }

        public static func headers(
            request: HTTPRequest
        ) throws -> HTTPResponse {
            try Model.Response.HeaderEcho(
                request_id: request.header("X-Request-ID"),
                user_agent: request.header("User-Agent"),
                origin: request.header("Origin"),
                content_type: request.header("Content-Type")
            ).response()
        }

        public static func token(
            request: HTTPRequest
        ) throws -> HTTPResponse {
            let seed = [
                request.clientIP ?? "local",
                request.header("X-Request-ID") ?? UUID().uuidString,
                "\(Date().timeIntervalSince1970)"
            ]
            .joined(separator: ":")

            let token = "servlive-token-\(abs(seed.hashValue))"

            return try Model.Response.TokenIssue(
                token: token
            ).response()
        }

        public static func validateToken(
            _ payload: Model.Payload.TokenValidate
        ) throws -> HTTPResponse {
            let token = payload.token.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard token.hasPrefix("servlive-token") else {
                return try Model.Response.TokenValidation(
                    success: false,
                    valid: false,
                    reason: "invalid_token"
                ).response(status: .badRequest)
            }

            return try Model.Response.TokenValidation(
                success: true,
                valid: true
            ).response()
        }

        public static func echo(
            request: HTTPRequest
        ) throws -> HTTPResponse {
            try Model.Response.Echo(
                received: request.body
            ).response()
        }

        public static func contact(
            _ payload: Model.Payload.ContactForm
        ) throws -> HTTPResponse {
            if clean(payload.website) != nil {
                return try Model.Response.Accepted(
                    id: "contact_mock_honeypot",
                    message: "mock contact accepted"
                ).response()
            }

            guard clean(payload.name) != nil,
                  clean(payload.email) != nil,
                  clean(payload.message) != nil
            else {
                return try Model.Response.ErrorOut(
                    status: "validation_error",
                    message: "Missing required contact fields."
                ).response(status: .badRequest)
            }

            return try Model.Response.Accepted(
                id: "contact_mock_001",
                message: "mock contact accepted"
            ).response()
        }

        public static func signup(
            _ payload: Model.Payload.SignupForm
        ) throws -> HTTPResponse {
            guard clean(payload.email) != nil else {
                return try Model.Response.ErrorOut(
                    status: "validation_error",
                    message: "Missing email."
                ).response(status: .badRequest)
            }

            return try Model.Response.Accepted(
                id: "signup_mock_001",
                message: "mock signup accepted"
            ).response()
        }

        public static func collect(
            _ payload: Model.Payload.CollectEnvelope
        ) throws -> HTTPResponse {
            guard !payload.session_id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return try Model.Response.ErrorOut(
                    status: "validation_error",
                    message: "Missing session_id."
                ).response(status: .badRequest)
            }

            return try Model.Response.CollectAck(
                accepted: payload.events.count
            ).response()
        }

        public static func intentionalError() throws -> HTTPResponse {
            try Model.Response.ErrorOut(
                status: "intentional_error",
                message: "This is an intentional mock fixture error."
            ).response(status: .internalServerError)
        }

        private static func clean(
            _ raw: String?
        ) -> String? {
            guard let raw else {
                return nil
            }

            let trimmed = raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !trimmed.isEmpty else {
                return nil
            }

            return trimmed
        }
    }
}
