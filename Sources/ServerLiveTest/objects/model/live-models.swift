import Foundation
import Server

extension Model.Response {
    public struct Status: ReturnableResponse {
        public let success: Bool
        public let status: String
        public let service: String
        public let mode: String

        public init(
            success: Bool,
            status: String,
            service: String = "servlive",
            mode: String = "mock_api"
        ) {
            self.success = success
            self.status = status
            self.service = service
            self.mode = mode
        }
    }

    public struct Config: ReturnableResponse {
        public let success: Bool
        public let service: String
        public let version: String
        public let features: [String]

        public init(
            success: Bool = true,
            service: String = "servlive",
            version: String = "1.0.0",
            features: [String]
        ) {
            self.success = success
            self.service = service
            self.version = version
            self.features = features
        }
    }

    public struct RouteList: ReturnableResponse {
        public let success: Bool
        public let routes: [String]

        public init(
            success: Bool = true,
            routes: [String]
        ) {
            self.success = success
            self.routes = routes
        }
    }

    public struct HeaderEcho: ReturnableResponse {
        public let success: Bool
        public let request_id: String?
        public let user_agent: String?
        public let origin: String?
        public let content_type: String?

        public init(
            success: Bool = true,
            request_id: String?,
            user_agent: String?,
            origin: String?,
            content_type: String?
        ) {
            self.success = success
            self.request_id = request_id
            self.user_agent = user_agent
            self.origin = origin
            self.content_type = content_type
        }
    }

    public struct TokenIssue: ReturnableResponse {
        public let success: Bool
        public let token: String
        public let expires_in: Int

        public init(
            success: Bool = true,
            token: String,
            expires_in: Int = 300
        ) {
            self.success = success
            self.token = token
            self.expires_in = expires_in
        }
    }

    public struct TokenValidation: ReturnableResponse {
        public let success: Bool
        public let valid: Bool
        public let reason: String?

        public init(
            success: Bool,
            valid: Bool,
            reason: String? = nil
        ) {
            self.success = success
            self.valid = valid
            self.reason = reason
        }
    }

    public struct Echo: ReturnableResponse {
        public let success: Bool
        public let received: String
        public let bytes: Int

        public init(
            success: Bool = true,
            received: String
        ) {
            self.success = success
            self.received = received
            self.bytes = received.utf8.count
        }
    }

    public struct Accepted: ReturnableResponse {
        public let success: Bool
        public let status: String
        public let id: String
        public let message: String

        public init(
            success: Bool = true,
            status: String = "ok",
            id: String,
            message: String
        ) {
            self.success = success
            self.status = status
            self.id = id
            self.message = message
        }
    }

    public struct CollectAck: ReturnableResponse {
        public let success: Bool
        public let accepted: Int

        public init(
            success: Bool = true,
            accepted: Int
        ) {
            self.success = success
            self.accepted = accepted
        }
    }

    public struct ErrorOut: ReturnableResponse {
        public let success: Bool
        public let status: String
        public let message: String

        public init(
            success: Bool = false,
            status: String,
            message: String
        ) {
            self.success = success
            self.status = status
            self.message = message
        }
    }
}

extension Model.Payload {
    public struct TokenValidate: Codable, Sendable {
        public let token: String
    }

    public struct ContactForm: Codable, Sendable {
        public let name: String?
        public let email: String?
        public let message: String?
        public let website: String?
    }

    public struct SignupForm: Codable, Sendable {
        public let email: String?
        public let plan: String?
        public let referral: String?
    }

    public struct CollectEnvelope: Codable, Sendable {
        public let source: String
        public let session_id: String
        public let events: [Event]
    }

    public struct Event: Codable, Sendable {
        public let type: String
        public let path: String?
        public let value: String?
        public let timestamp: Int64?
    }
}
