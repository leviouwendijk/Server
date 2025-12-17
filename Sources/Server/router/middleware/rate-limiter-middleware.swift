import Foundation
import HTTP

// Global rate limiter (shared across all requests)
public actor GlobalRateLimiter: Sendable {
    private var requests: [Date] = []
    private let maxRequests: Int
    private let windowSeconds: Int
    
    public init(maxRequests: Int, windowSeconds: Int) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }
    
    public func recordRequest() -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(windowSeconds))
        
        requests.removeAll { $0 < windowStart }
        
        if requests.count < maxRequests {
            requests.append(now)
            return true
        }
        
        return false
    }
}

// Per-user rate limiter (keyed by header value)
public actor PerUserRateLimiter: Sendable {
    private var userRequests: [String: [Date]] = [:]
    private let maxRequests: Int
    private let windowSeconds: Int
    
    public init(maxRequests: Int, windowSeconds: Int) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }
    
    public func recordRequest(for key: String) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-Double(windowSeconds))
        
        if var requests = userRequests[key] {
            requests.removeAll { $0 < windowStart }
            userRequests[key] = requests
        } else {
            userRequests[key] = []
        }
        
        if (userRequests[key]?.count ?? 0) < maxRequests {
            userRequests[key]?.append(now)
            return true
        }
        
        return false
    }
}

public struct GlobalRateLimitMiddleware: Middleware {
    public let name = "global-rate-limit"
    private let limiter: GlobalRateLimiter
    
    public init(maxRequests: Int, windowSeconds: Int) {
        self.limiter = GlobalRateLimiter(maxRequests: maxRequests, windowSeconds: windowSeconds)
    }
    
    public func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        let allowed = await limiter.recordRequest()
        
        guard allowed else {
            return HTTPResponse(
                status: .tooManyRequests,
                body: "Rate limit exceeded"
            )
        }
        
        return await next(request, router)
    }
}

public struct PerUserRateLimitMiddleware: Middleware {
    public let name = "per-user-rate-limit"
    private let limiter: PerUserRateLimiter
    private let userKeyHeader: String
    
    public init(maxRequests: Int, windowSeconds: Int, userKeyHeader: String = "X-User-ID") {
        self.limiter = PerUserRateLimiter(maxRequests: maxRequests, windowSeconds: windowSeconds)
        self.userKeyHeader = userKeyHeader
    }
    
    public func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        let userKey = request.headers[userKeyHeader] ?? "anonymous"
        let allowed = await limiter.recordRequest(for: userKey)
        
        guard allowed else {
            return HTTPResponse(
                status: .tooManyRequests,
                body: "Rate limit exceeded for user: \(userKey)"
            )
        }
        
        return await next(request, router)
    }
}
