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

/// Sliding-window limiter per principal (client IP by default).
///
/// Only the requested key is pruned per request; all keys are swept at most once per
/// window, so the cost per request does not grow with the number of principals.
public actor PerUserRateLimiter: Sendable {
    private var userRequests: [String: [Date]] = [:]
    private var lastSweep = Date.distantPast

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

        let cutoff = now.addingTimeInterval(
            -Double(
                windowSeconds
            )
        )

        sweepIfDue(
            now: now,
            cutoff: cutoff
        )

        var requests =
            userRequests[key] ?? []

        requests.removeAll {
            $0 <= cutoff
        }

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

    @_spi(Testing) public var retainedPrincipalCount: Int {
        userRequests.count
    }

    private func sweepIfDue(
        now: Date,
        cutoff: Date
    ) {
        guard now.timeIntervalSince(lastSweep) >= Double(windowSeconds) else {
            return
        }

        lastSweep = now

        userRequests = userRequests.compactMapValues { requests in
            let live = requests.filter {
                $0 > cutoff
            }

            return live.isEmpty ? nil : live
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
        principal: @escaping Principal = { $0.clientIP }
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
