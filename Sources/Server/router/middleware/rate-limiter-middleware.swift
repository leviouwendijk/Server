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

    public init(
        maxRequests: Int,
        windowSeconds: Int
    ) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    public func recordRequest(
        for key: String
    ) -> Bool {
        let now = Date()

        let windowStart = now.addingTimeInterval(
            -Double(
                windowSeconds
            )
        )

        prune(
            through: windowStart
        )

        var requests =
            userRequests[key] ?? []

        guard requests.count < maxRequests else {
            userRequests[key] = requests
            return false
        }

        requests.append(
            now
        )

        userRequests[key] = requests

        return true
    }

    package var retainedPrincipalCount: Int {
        userRequests.count
    }

    private func prune(
        through cutoff: Date
    ) {
        for key in Array(
            userRequests.keys
        ) {
            guard var requests =
                userRequests[key]
            else {
                continue
            }

            requests.removeAll {
                $0 <= cutoff
            }

            if requests.isEmpty {
                userRequests.removeValue(
                    forKey: key
                )
            } else {
                userRequests[key] = requests
            }
        }
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
    public typealias Principal = @Sendable (HTTPRequest) -> String?

    public let name = "per-user-rate-limit"

    private let limiter: PerUserRateLimiter
    private let principal: Principal

    public init(
        maxRequests: Int,
        windowSeconds: Int,
        principal: @escaping Principal = { _ in nil }
    ) {
        self.limiter = PerUserRateLimiter(
            maxRequests: maxRequests,
            windowSeconds: windowSeconds
        )

        self.principal = principal
    }

    public init(
        maxRequests: Int,
        windowSeconds: Int,
        trustedHeader: String
    ) {
        self.init(
            maxRequests: maxRequests,
            windowSeconds: windowSeconds,
            principal: { request in
                request.header(
                    trustedHeader
                )
            }
        )
    }

    @available(
        *,
        deprecated,
        message: "Use trustedHeader: only for identity supplied by a trusted upstream."
    )
    public init(
        maxRequests: Int,
        windowSeconds: Int,
        userKeyHeader: String
    ) {
        self.init(
            maxRequests: maxRequests,
            windowSeconds: windowSeconds,
            trustedHeader: userKeyHeader
        )
    }

    public func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        let key = principal(
            request
        ) ?? "anonymous"

        let allowed = await limiter.recordRequest(
            for: key
        )

        guard allowed else {
            return HTTPResponse(
                status: .tooManyRequests,
                body: "Rate limit exceeded"
            )
        }

        return await next(
            request,
            router
        )
    }
}
