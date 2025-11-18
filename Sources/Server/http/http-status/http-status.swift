import Foundation

public struct HTTPStatus: Hashable, Sendable, Equatable {
    public let code: Int
    public let reason: String
    
    public init(code: Int, reason: String) {
        self.code = code
        self.reason = reason
    }
    
    // Standard 1xx Informational
    public static let `continue` = HTTPStatus(code: 100, reason: "Continue")
    public static let switchingProtocols = HTTPStatus(code: 101, reason: "Switching Protocols")
    public static let processing = HTTPStatus(code: 102, reason: "Processing")
    public static let earlyHints = HTTPStatus(code: 103, reason: "Early Hints")
    
    // Standard 2xx Success
    public static let ok = HTTPStatus(code: 200, reason: "OK")
    public static let created = HTTPStatus(code: 201, reason: "Created")
    public static let accepted = HTTPStatus(code: 202, reason: "Accepted")
    public static let nonAuthoritativeInformation = HTTPStatus(code: 203, reason: "Non-Authoritative Information")
    public static let noContent = HTTPStatus(code: 204, reason: "No Content")
    public static let resetContent = HTTPStatus(code: 205, reason: "Reset Content")
    public static let partialContent = HTTPStatus(code: 206, reason: "Partial Content")
    public static let multiStatus = HTTPStatus(code: 207, reason: "Multi-Status")
    public static let alreadyReported = HTTPStatus(code: 208, reason: "Already Reported")
    public static let imUsed = HTTPStatus(code: 226, reason: "IM Used")
    
    // Standard 3xx Redirection
    public static let multipleChoices = HTTPStatus(code: 300, reason: "Multiple Choices")
    public static let movedPermanently = HTTPStatus(code: 301, reason: "Moved Permanently")
    public static let found = HTTPStatus(code: 302, reason: "Found")
    public static let seeOther = HTTPStatus(code: 303, reason: "See Other")
    public static let notModified = HTTPStatus(code: 304, reason: "Not Modified")
    public static let useProxy = HTTPStatus(code: 305, reason: "Use Proxy")
    public static let temporaryRedirect = HTTPStatus(code: 307, reason: "Temporary Redirect")
    public static let permanentRedirect = HTTPStatus(code: 308, reason: "Permanent Redirect")
    
    // Standard 4xx Client Error
    public static let badRequest = HTTPStatus(code: 400, reason: "Bad Request")
    public static let unauthorized = HTTPStatus(code: 401, reason: "Unauthorized")
    public static let paymentRequired = HTTPStatus(code: 402, reason: "Payment Required")
    public static let forbidden = HTTPStatus(code: 403, reason: "Forbidden")
    public static let notFound = HTTPStatus(code: 404, reason: "Not Found")
    public static let methodNotAllowed = HTTPStatus(code: 405, reason: "Method Not Allowed")
    public static let notAcceptable = HTTPStatus(code: 406, reason: "Not Acceptable")
    public static let proxyAuthenticationRequired = HTTPStatus(code: 407, reason: "Proxy Authentication Required")
    public static let requestTimeout = HTTPStatus(code: 408, reason: "Request Timeout")
    public static let conflict = HTTPStatus(code: 409, reason: "Conflict")
    public static let gone = HTTPStatus(code: 410, reason: "Gone")
    public static let lengthRequired = HTTPStatus(code: 411, reason: "Length Required")
    public static let preconditionFailed = HTTPStatus(code: 412, reason: "Precondition Failed")
    public static let payloadTooLarge = HTTPStatus(code: 413, reason: "Payload Too Large")
    public static let uriTooLong = HTTPStatus(code: 414, reason: "URI Too Long")
    public static let unsupportedMediaType = HTTPStatus(code: 415, reason: "Unsupported Media Type")
    public static let rangeNotSatisfiable = HTTPStatus(code: 416, reason: "Range Not Satisfiable")
    public static let expectationFailed = HTTPStatus(code: 417, reason: "Expectation Failed")
    public static let teapot = HTTPStatus(code: 418, reason: "I'm a teapot")
    public static let misdirectedRequest = HTTPStatus(code: 421, reason: "Misdirected Request")
    public static let unprocessableEntity = HTTPStatus(code: 422, reason: "Unprocessable Entity")
    public static let locked = HTTPStatus(code: 423, reason: "Locked")
    public static let failedDependency = HTTPStatus(code: 424, reason: "Failed Dependency")
    public static let tooEarly = HTTPStatus(code: 425, reason: "Too Early")
    public static let upgradeRequired = HTTPStatus(code: 426, reason: "Upgrade Required")
    public static let preconditionRequired = HTTPStatus(code: 428, reason: "Precondition Required")
    public static let tooManyRequests = HTTPStatus(code: 429, reason: "Too Many Requests")
    public static let requestHeaderFieldsTooLarge = HTTPStatus(code: 431, reason: "Request Header Fields Too Large")
    public static let unavailableForLegalReasons = HTTPStatus(code: 451, reason: "Unavailable For Legal Reasons")
    
    // Standard 5xx Server Error
    public static let internalServerError = HTTPStatus(code: 500, reason: "Internal Server Error")
    public static let notImplemented = HTTPStatus(code: 501, reason: "Not Implemented")
    public static let badGateway = HTTPStatus(code: 502, reason: "Bad Gateway")
    public static let serviceUnavailable = HTTPStatus(code: 503, reason: "Service Unavailable")
    public static let gatewayTimeout = HTTPStatus(code: 504, reason: "Gateway Timeout")
    public static let httpVersionNotSupported = HTTPStatus(code: 505, reason: "HTTP Version Not Supported")
    public static let variantAlsoNegotiates = HTTPStatus(code: 506, reason: "Variant Also Negotiates")
    public static let insufficientStorage = HTTPStatus(code: 507, reason: "Insufficient Storage")
    public static let loopDetected = HTTPStatus(code: 508, reason: "Loop Detected")
    public static let notExtended = HTTPStatus(code: 510, reason: "Not Extended")
    public static let networkAuthenticationRequired = HTTPStatus(code: 511, reason: "Network Authentication Required")
    
    // Default Fallbacks
    internal static func defaultFor(code: Int) -> HTTPStatus {
        switch code {
        case 100..<200: return HTTPStatus(code: code, reason: "Informational")
        case 200..<300: return HTTPStatus(code: code, reason: "Success")
        case 300..<400: return HTTPStatus(code: code, reason: "Redirection")
        case 400..<500: return HTTPStatus(code: code, reason: "Client Error")
        case 500..<600: return HTTPStatus(code: code, reason: "Server Error")
        default: return HTTPStatus(code: code, reason: "Unknown")
        }
    }

    public static func resolve(code: Int) -> HTTPStatus {
        defaultFor(code: code)
    }

    public var family: HTTPStatusFamily {
        return .init(from: self)
    }
}

extension HTTPStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        reason = try container.decode(String.self, forKey: .reason)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(reason, forKey: .reason)
    }
    
    private enum CodingKeys: String, CodingKey {
        case code, reason
    }
}
