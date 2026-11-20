import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let runtimeHardeningQualification = TestFlow(
        "security.runtime-hardening.qualification",
        title: "Qualify runtime hardening gaps around route exposure and forwarded headers",
        tags: [
            "security",
            "server",
            "runtime",
            "routes",
            "headers",
            "qualification"
        ]
    ) {
        Step("public route listing remains explicit for local diagnostics") {
            let router = Router(
                routes: Server.routes {
                    StandardRoutes.publicListRoutes()

                    get("admin", "secret") { _, _ in
                        .ok(
                            body: "secret"
                        )
                    }
                }
            )

            let response = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/routes"
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "runtime-hardening.routes.public-explicit-status"
            )

            try Expect.true(
                securityBodyContainsRoutePath(
                    response.body,
                    "/admin/secret"
                ),
                "runtime-hardening.routes.public-explicit-body"
            )
        }

        Step("protected route listing pattern blocks unauthenticated callers") {
            let router = Router(
                routes: Server.routes {
                    StandardRoutes.listRoutes()
                        .use(
                            BearerMiddleware(
                                rawKey: "route-list-secret"
                            )
                        )

                    get("admin", "secret") { _, _ in
                        .ok(
                            body: "secret"
                        )
                    }
                }
            )

            let unauthenticated = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/routes"
                )
            )

            try Expect.equal(
                unauthenticated.status.code,
                401,
                "runtime-hardening.routes.unauthenticated-status"
            )

            let authenticated = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/routes",
                    headers: [
                        "Authorization": "Bearer route-list-secret"
                    ]
                )
            )

            try Expect.equal(
                authenticated.status.code,
                200,
                "runtime-hardening.routes.authenticated-status"
            )

            try Expect.true(
                securityBodyContainsRoutePath(
                    authenticated.body,
                    "/admin/secret"
                ),
                "runtime-hardening.routes.authenticated-body"
            )
        }

        Vulnerability(
            "HTTPRequest.clientIP trusts spoofable forwarding headers",
            id: "SERVER-SEC-029",
            severity: .medium,
            cwe: "CWE-348",
            vector: "X-Forwarded-For",
            impact: "apps can accidentally trust attacker-supplied IPs for audit, auth, or rate limiting",
            evidence: "clientIP returns the left-most X-Forwarded-For value without peer trust context"
        ) {
            let request = HTTPRequest(
                method: .get,
                path: "/account",
                headers: [
                    "X-Forwarded-For": "203.0.113.99, 10.0.0.10",
                    "X-Real-IP": "198.51.100.7"
                ]
            )

            return request.clientIP == "203.0.113.99"
        }
    }

    static let bearerTokenComparisonRegression = TestFlow(
        "security.auth.bearer-token-comparison.regression",
        title: "Bearer token comparison preserves auth semantics through constant-time helper",
        tags: [
            "security",
            "auth",
            "bearer",
            "timing",
            "regression"
        ]
    ) {
        Step("constant-time string compare preserves equality behavior") {
            try Expect.true(
                ServerConstantTime.equals(
                    "route-list-secret",
                    "route-list-secret"
                ),
                "bearer-compare.equal"
            )

            try Expect.false(
                ServerConstantTime.equals(
                    "route-list-secret",
                    "route-list-secrex"
                ),
                "bearer-compare.same-length-different"
            )

            try Expect.false(
                ServerConstantTime.equals(
                    "route-list-secret",
                    "short"
                ),
                "bearer-compare.different-length"
            )
        }

        Step("BearerMiddleware still authorizes valid token and rejects invalid token") {
            let router = Router(
                routes: Server.routes {
                    get("private") { _, _ in
                        .ok(
                            body: "ok"
                        )
                    }
                    .use(
                        BearerMiddleware(
                            rawKey: "route-list-secret"
                        )
                    )
                }
            )

            let valid = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/private",
                    headers: [
                        "Authorization": "Bearer route-list-secret"
                    ]
                )
            )

            try Expect.equal(
                valid.status.code,
                200,
                "bearer-auth.valid-status"
            )

            let invalid = await router.route(
                HTTPRequest(
                    method: .get,
                    path: "/private",
                    headers: [
                        "Authorization": "Bearer route-list-secrex"
                    ]
                )
            )

            try Expect.equal(
                invalid.status.code,
                401,
                "bearer-auth.invalid-status"
            )
        }
    }
}

private func securityBodyContainsRoutePath(
    _ body: String,
    _ path: String
) -> Bool {
    body.contains(path)
        || body.contains(
            path.replacingOccurrences(
                of: "/",
                with: "\\/"
            )
        )
}
