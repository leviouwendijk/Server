import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-030: Invalid outbound request becomes fallback GET
    // ═══════════════════════════════════════════════════════════════════

    static let outboundRequestFailClosedQualification = TestFlow(
        "security.outbound.request.fail-closed.qualification",
        title: "Qualify outbound request validation failure behavior",
        tags: [
            "security",
            "server",
            "client",
            "http",
            "validation",
            "qualification",
        ]
    ) {
        Vulnerability(
            "invalid outbound request input becomes a fallback request",
            id: "SERVER-SEC-030",
            severity: .high,
            cwe: "CWE-755",
            vector: "invalid outbound request target or header",
            impact: "validation failure can silently cause an unintended GET request to the configured peer",
            evidence: "buildWireRequest converts validation failure into GET / with Host invalid.local instead of failing closed"
        ) {
            let path =
                "/safe\r\nX-Injected: yes"

            guard let wire = try? buildWireRequest(
                host: "127.0.0.1",
                method: .get,
                path: path,
                headers: [:],
                body: nil
            ) else {
                return false
            }

            return wire.contains(
                "X-Injected: yes"
            ) || wire == "GET /\r\nHost: invalid.local\r\n\r\n"
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-031: Per-user rate limit identity spoofing
    // ═══════════════════════════════════════════════════════════════════

    static let perUserRateLimitIdentityQualification = TestFlow(
        "security.rate-limit.identity.qualification",
        title: "Qualify trust boundary of per-user rate limiting",
        tags: [
            "security",
            "server",
            "rate-limit",
            "identity",
            "headers",
            "qualification",
        ]
    ) {
        Vulnerability(
            "caller-controlled X-User-ID bypasses the per-user rate limit",
            id: "SERVER-SEC-031",
            severity: .high,
            cwe: "CWE-345",
            vector: "X-User-ID",
            impact: "an unauthenticated caller can rotate claimed identities to evade a rate limit",
            evidence: "the default middleware keys rate limiting directly from the request X-User-ID header"
        ) {
            let middleware = PerUserRateLimitMiddleware(
                maxRequests: 1,
                windowSeconds: 60
            )

            let router = Router(
                routes: []
            )

            let first = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/limited",
                    headers: [
                        "X-User-ID": "attacker-a"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            let blocked = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/limited",
                    headers: [
                        "X-User-ID": "attacker-a"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            let rotated = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/limited",
                    headers: [
                        "X-User-ID": "attacker-b"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            // Reproduced: rotation bypasses the limit
            return first.status.code == 200
                && blocked.status.code == 429
                && rotated.status.code == 200
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-032: Bearer authority response oracle
    // ═══════════════════════════════════════════════════════════════════

    static let bearerAuthorityResponseOracleQualification = TestFlow(
        "security.auth.bearer-authority.response-oracle.qualification",
        title: "Qualify externally observable BearerAuthority token state",
        tags: [
            "security",
            "server",
            "auth",
            "bearer",
            "oracle",
            "qualification",
        ]
    ) {
        Vulnerability(
            "BearerAuthority distinguishes revoked tokens from unknown tokens",
            id: "SERVER-SEC-032",
            severity: .medium,
            cwe: "CWE-203",
            vector: "Authorization: Bearer",
            impact: "a remote caller can distinguish a known invalidated token from an unknown token",
            evidence: "invalid tokens receive 'Invalid API token' while invalidated tokens receive 'Expired token'"
        ) {
            let authority = try BearerAuthority(
                authorized_tokens: [
                    "active-token"
                ],
                invalidated_tokens: [
                    "revoked-token"
                ]
            )

            let middleware = BearerAuthorityMiddleware(
                authority: authority
            )

            let router = Router(
                routes: []
            )

            let unknown = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/private",
                    headers: [
                        "Authorization": "Bearer unknown-token"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            let revoked = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/private",
                    headers: [
                        "Authorization": "Bearer revoked-token"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            // Reproduced: caller can distinguish the two states
            return unknown.status.code == 401
                && revoked.status.code == 401
                && unknown.body != revoked.body
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-033: CORS Vary overwrite
    // ═══════════════════════════════════════════════════════════════════

    static let corsVaryOverwriteQualification = TestFlow(
        "security.cors.vary-preservation.qualification",
        title: "Qualify preservation of existing Vary response metadata",
        tags: [
            "security",
            "http",
            "cors",
            "cache",
            "headers",
            "qualification",
        ]
    ) {
        Vulnerability(
            "CORS processing overwrites an existing security-relevant Vary value",
            id: "SERVER-SEC-033",
            severity: .medium,
            cwe: "CWE-524",
            vector: "Vary response header",
            impact: "shared caches can lose an existing response-variation boundary when CORS is applied",
            evidence: "CORS replaces Vary: Authorization with Vary: Origin instead of merging Origin"
        ) {
            let cors = CORS(
                config: CORSConfig(
                    allowedOrigin: .only(
                        "https://app.example"
                    )
                )
            )

            let request = HTTPRequest(
                method: .get,
                path: "/private",
                headers: [
                    "Origin": "https://app.example"
                ]
            )

            let response = HTTPResponse(
                status: .ok,
                headers: [
                    "Vary": "Authorization"
                ],
                body: "private"
            )

            let applied = cors.apply(
                to: response,
                for: request
            )

            // Reproduced: original Vary value was destroyed
            return applied.headers["Vary"] == "Origin"
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-034: Unbounded per-user rate limiter state growth
    // ═══════════════════════════════════════════════════════════════════

    static let rateLimiterUnboundedStateGrowthQualification = TestFlow(
        "security.rate-limit.state-growth.qualification",
        title: "Qualify retained principal-state growth in per-user rate limiter",
        tags: [
            "security",
            "server",
            "rate-limit",
            "memory",
            "dos",
            "qualification",
        ]
    ) {
        Vulnerability(
            "attacker-controlled principal cardinality grows retained limiter state",
            id: "SERVER-SEC-034",
            severity: .medium,
            cwe: "CWE-400",
            vector: "unique rate-limit principal keys",
            impact: "attacker-controlled key cardinality can grow retained limiter state",
            evidence: "retainedPrincipalCount grows once for every unique principal and stale principals are not globally evicted"
        ) {
            let limiter = PerUserRateLimiter(
                maxRequests: 1,
                windowSeconds: 0
            )

            for index in 0..<1_000 {
                _ = await limiter.recordRequest(
                    for: "attacker-\(index)"
                )
            }

            let before =
                await limiter.retainedPrincipalCount

            _ = await limiter.recordRequest(
                for: "attacker-final"
            )

            let after =
                await limiter.retainedPrincipalCount

            return before == 1_000
                && after == 1_001
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-035: Debug output leaks Authorization credentials
    // ═══════════════════════════════════════════════════════════════════

    static let clientDebugCredentialLeakageQualification = TestFlow(
        "security.client.debug-credential-leakage.qualification",
        title: "Qualify whether actual HTTPClient debug output exposes authorization secrets",
        tags: [
            "security",
            "client",
            "logging",
            "credentials",
            "integration",
            "qualification",
        ]
    ) {
        Vulnerability(
            "HTTPClient debug output exposes raw authorization credentials",
            id: "SERVER-SEC-035",
            severity: .high,
            cwe: "CWE-532",
            vector: "HTTPClient debug output",
            impact: "authorization tokens can appear in captured or persisted debug output",
            evidence: "the sentinel bearer token appears in stdout emitted by a real debug-enabled HTTPClient request"
        ) {
            let sentinel =
                "NEVER_LOG_THIS_SECRET_TOKEN_12345"

            let peer = try await SecurityTestPeer.start(
                payload: Data(
                    "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok".utf8
                )
            )

            let client = HTTPClient(
                config: HTTPClientConfig(
                    host: "127.0.0.1",
                    port: peer.port,
                    timeout: 1,
                    debug: true
                )
            )

            let output =
                await SecurityStandardOutput.capture {
                    _ = try? await client.get(
                        "/private",
                        auth: .bearer(
                            sentinel
                        )
                    )
                }

            peer.stop()

            return output.contains(
                sentinel
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-036: Activity log persists query string secrets
    // ═══════════════════════════════════════════════════════════════════

    static let activityLogQueryStringLeakageQualification = TestFlow(
        "security.activity-log.query-leakage.qualification",
        title: "Qualify whether live activity events retain query string secrets",
        tags: [
            "security",
            "server",
            "logging",
            "query-string",
            "integration",
            "qualification",
        ]
    ) {
        Vulnerability(
            "live request activity event retains request-target query parameters",
            id: "SERVER-SEC-036",
            severity: .medium,
            cwe: "CWE-532",
            vector: "request path with query string",
            impact: "sensitive query values can propagate into activity logging",
            evidence: "the live ServerEngine activity callback receives the complete query-bearing request target"
        ) {
            let sentinel =
                "NEVER_PERSIST_THIS_RESET_TOKEN"

            let captured =
                SecurityOneShot<String?>()

            let server = try await SecurityTestServer.start(
                activityCallback: { event in
                    captured.resolve(
                        event.path
                    )
                },
                routes: []
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            guard await connection.send(
                "GET /reset-password?token=\(sentinel) HTTP/1.1\r\nHost: localhost\r\n\r\n"
            ) else {
                connection.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            _ = await connection.receive(
                until: {
                    $0.contains(
                        "HTTP/1.1"
                    )
                }
            )

            let path = await captured.wait(
                timeout: 1,
                fallback: nil
            )

            connection.cancel()

            await server.stop()

            return path?.contains(
                sentinel
            ) == true
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-037: CORS preflight also overwrites Vary
    // ═══════════════════════════════════════════════════════════════════

    static let corsPreflightVaryOverwriteQualification = TestFlow(
        "security.cors.preflight-vary.regression",
        title: "CORS preflight explicitly varies on Origin",
        tags: [
            "security",
            "http",
            "cors",
            "preflight",
            "regression",
        ]
    ) {
        Step(
            "preflight response emits Vary Origin"
        ) {
            let cors = CORS(
                config: CORSConfig(
                    allowedOrigin: .only(
                        "https://app.example"
                    )
                )
            )

            let request = HTTPRequest(
                method: .options,
                path: "/api/data",
                headers: [
                    "Origin": "https://app.example",
                    "Access-Control-Request-Method": "POST"
                ]
            )

            let preflight =
                cors.preflightResponse(
                    for: request
                )

            try Expect.equal(
                preflight?.headers["Vary"],
                "Origin",
                "cors.preflight.vary-origin"
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-038: Header injection via buildWireRequest path
    // ═══════════════════════════════════════════════════════════════════

    static let outboundHeaderInjectionQualification = TestFlow(
        "security.outbound.header-injection.qualification",
        title: "Qualify whether CRLF in request path enables header injection",
        tags: [
            "security",
            "client",
            "http",
            "injection",
            "crlf",
            "qualification",
        ]
    ) {
        Vulnerability(
            "CRLF characters in request path inject arbitrary headers into wire request",
            id: "SERVER-SEC-038",
            severity: .critical,
            cwe: "CWE-113",
            vector: "request path containing \\r\\n",
            impact: "attacker-controlled path components can inject arbitrary HTTP headers",
            evidence: "buildWireRequest interpolates path directly into the request line without sanitization"
        ) {
            let maliciousPath = "/api\r\nX-Injected: malicious\r\nX-Another: header"

            guard let wire = try? buildWireRequest(
                host: "victim.example.com",
                method: .get,
                path: maliciousPath,
                headers: [:],
                body: nil
            ) else {
                return false
            }

            // Reproduced: the injected headers appear in the wire output
            return wire.contains("X-Injected: malicious")
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-039: Header injection via buildWireRequest header values
    // ═══════════════════════════════════════════════════════════════════

    static let outboundHeaderValueInjectionQualification = TestFlow(
        "security.outbound.header-value-injection.qualification",
        title: "Qualify whether CRLF in header values enables header injection",
        tags: [
            "security",
            "client",
            "http",
            "injection",
            "crlf",
            "qualification",
        ]
    ) {
        Vulnerability(
            "CRLF characters in header values inject additional headers into wire request",
            id: "SERVER-SEC-039",
            severity: .high,
            cwe: "CWE-113",
            vector: "header value containing \\r\\n",
            impact: "attacker-controlled header values can inject arbitrary HTTP headers",
            evidence: "buildWireRequest interpolates header values without CRLF sanitization"
        ) {
            let maliciousValue = "legitimate\r\nX-Injected: smuggled"

            guard let wire = try? buildWireRequest(
                host: "api.example.com",
                method: .get,
                path: "/safe",
                headers: [
                    "X-Custom": maliciousValue
                ],
                body: nil
            ) else {
                return false
            }

            // Reproduced: the injected header appears on its own line
            return wire.contains("X-Injected: smuggled")
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-040: Bearer middleware comparison regression
    // ═══════════════════════════════════════════════════════════════════

    static let bearerMiddlewareEqualityQualification = TestFlow(
        "security.auth.bearer-middleware.equality-operator.qualification",
        title: "BearerMiddleware preserves constant-time token comparison behavior",
        tags: [
            "security",
            "server",
            "auth",
            "bearer",
            "timing",
            "regression",
        ]
    ) {
        Step("constant-time comparison rejects early and late mismatches") {
            let expected = "correct-token-value"
            let differEarly = "Xorrect-token-value"
            let differLate = "correct-token-valuX"

            try Expect.false(
                ServerConstantTime.equals(
                    expected,
                    differEarly
                ),
                "bearer-middleware.constant-time.early-mismatch"
            )

            try Expect.false(
                ServerConstantTime.equals(
                    expected,
                    differLate
                ),
                "bearer-middleware.constant-time.late-mismatch"
            )
        }

        Step("public middleware API rejects both mismatched bearer tokens") {
            let middleware = BearerMiddleware(
                rawKey: "correct-token-value",
                realmName: "test"
            )

            let router = Router(
                routes: []
            )

            let early = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/private",
                    headers: [
                        "Authorization": "Bearer Xorrect-token-value"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            let late = await middleware.handle(
                HTTPRequest(
                    method: .get,
                    path: "/private",
                    headers: [
                        "Authorization": "Bearer correct-token-valuX"
                    ]
                ),
                router,
                next: { _, _ in
                    .ok()
                }
            )

            try Expect.equal(
                early.status.code,
                401,
                "bearer-middleware.early-mismatch.status"
            )

            try Expect.equal(
                late.status.code,
                401,
                "bearer-middleware.late-mismatch.status"
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SERVER-SEC-041: BearerAuthority raw token storage
    // ═══════════════════════════════════════════════════════════════════

    static let bearerAuthorityRawTokenStorageQualification = TestFlow(
        "security.auth.bearer-authority.raw-storage.qualification",
        title: "Qualify whether BearerAuthority stores raw token secrets",
        tags: [
            "security",
            "server",
            "auth",
            "bearer",
            "storage",
            "qualification",
        ]
    ) {
        Vulnerability(
            "BearerAuthority stores raw token values in memory",
            id: "SERVER-SEC-041",
            severity: .medium,
            cwe: "CWE-312",
            vector: "BearerAuthority credential storage",
            impact: "memory dumps or debug access expose all valid tokens in cleartext",
            evidence: "the raw bearer token appears directly in stored bearer-authority credential material"
        ) {
            let rawToken =
                "super-secret-api-key-never-store-raw"

            let authority = try BearerAuthority(
                authorized_tokens: [
                    rawToken
                ]
            )

            return authority.authorizedFingerprints.contains(
                rawToken
            )
        }
    }
}
