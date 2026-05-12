import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let transferEncodingSmugglingQualification = TestFlow(
        "security.inbound.transfer-encoding-smuggling.qualification",
        title: "Qualify whether Transfer-Encoding request smuggling risks are real",
        tags: [
            "security",
            "http",
            "parser",
            "framing",
            "transfer-encoding",
            "smuggling",
            "qualification",
        ]
    ) {
        Vulnerability(
            "Transfer-Encoding plus Content-Length is accepted",
            id: "SERVER-SEC-015",
            severity: .high,
            cwe: "CWE-444",
            vector: "Transfer-Encoding + Content-Length",
            impact: "parser/proxy disagreement can enable request smuggling when an upstream honors chunked framing",
            evidence: "Transfer-Encoding: chunked is accepted while Content-Length still drives local framing",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let body = "0\r\n\r\n"

            let raw = securityRawMessage(
                headLines: [
                    "POST /submit HTTP/1.1",
                    "Host: localhost",
                    "Transfer-Encoding: chunked",
                    "Content-Length: 5"
                ],
                body: body
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                let contentLength = try HTTPFraming.extractContentLength(
                    from: Data(raw.utf8)
                )

                return request.header("Transfer-Encoding")?.lowercased() == "chunked"
                    && contentLength == 5
            } catch {
                return false
            }
        }

        Vulnerability(
            "chunked request without Content-Length is accepted",
            id: "SERVER-SEC-016",
            severity: .high,
            cwe: "CWE-444",
            vector: "Transfer-Encoding: chunked",
            impact: "connection framing can treat the body as zero-length while the parser still accepts chunked-looking body bytes",
            evidence: "Transfer-Encoding: chunked parses successfully and Content-Length extraction returns nil",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let body = "5\r\nhello\r\n0\r\n\r\n"

            let raw = securityRawMessage(
                headLines: [
                    "POST /submit HTTP/1.1",
                    "Host: localhost",
                    "Transfer-Encoding: chunked"
                ],
                body: body
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                let contentLength = try HTTPFraming.extractContentLength(
                    from: Data(raw.utf8)
                )

                return request.header("Transfer-Encoding")?.lowercased() == "chunked"
                    && request.body == body
                    && contentLength == nil
            } catch {
                return false
            }
        }

        Vulnerability(
            "duplicate Transfer-Encoding headers are accepted",
            id: "SERVER-SEC-017",
            severity: .high,
            cwe: "CWE-444",
            vector: "duplicate Transfer-Encoding",
            impact: "framing layers can disagree about whether chunked framing applies",
            evidence: "duplicate Transfer-Encoding headers do not cause parser rejection",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let raw = securityRawMessage(
                headLines: [
                    "POST /submit HTTP/1.1",
                    "Host: localhost",
                    "Transfer-Encoding: gzip",
                    "Transfer-Encoding: chunked",
                    "Content-Length: 0"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("Transfer-Encoding") != nil
            } catch {
                return false
            }
        }
    }

    static let duplicateSecurityHeaderQualification = TestFlow(
        "security.inbound.duplicate-security-headers.qualification",
        title: "Qualify whether duplicate security-sensitive headers collapse unsafely",
        tags: [
            "security",
            "http",
            "headers",
            "duplicates",
            "qualification",
        ]
    ) {
        Vulnerability(
            "duplicate X-Forwarded-For collapses into attacker-controlled client IP",
            id: "SERVER-SEC-018",
            severity: .high,
            cwe: "CWE-444",
            vector: "duplicate X-Forwarded-For",
            impact: "rate limiting, logging, allowlists, or abuse detection can observe a different client IP than upstream framing intended",
            evidence: "second X-Forwarded-For overwrites the first and request.clientIP returns the overwritten value",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let raw = securityRawMessage(
                headLines: [
                    "GET /admin HTTP/1.1",
                    "Host: localhost",
                    "X-Forwarded-For: 198.51.100.10",
                    "X-Forwarded-For: 203.0.113.66"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("X-Forwarded-For") == "203.0.113.66"
                    && request.clientIP == "203.0.113.66"
            } catch {
                return false
            }
        }

        Vulnerability(
            "duplicate X-Real-IP collapses into attacker-controlled client IP",
            id: "SERVER-SEC-019",
            severity: .medium,
            cwe: "CWE-444",
            vector: "duplicate X-Real-IP",
            impact: "client identity helpers can consume an overwritten proxy identity header",
            evidence: "second X-Real-IP overwrites the first and request.clientIP returns the overwritten value",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let raw = securityRawMessage(
                headLines: [
                    "GET /admin HTTP/1.1",
                    "Host: localhost",
                    "X-Real-IP: 198.51.100.10",
                    "X-Real-IP: 203.0.113.66"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("X-Real-IP") == "203.0.113.66"
                    && request.clientIP == "203.0.113.66"
            } catch {
                return false
            }
        }

        Vulnerability(
            "duplicate Content-Type collapses by overwrite",
            id: "SERVER-SEC-020",
            severity: .medium,
            cwe: "CWE-20",
            vector: "duplicate Content-Type",
            impact: "validation and decoding layers can disagree about body interpretation",
            evidence: "Content-Type: text/plain is overwritten by Content-Type: application/json",
            references: [
                .cwe("CWE-444")
            ]
        ) {
            let raw = securityRawMessage(
                headLines: [
                    "POST /submit HTTP/1.1",
                    "Host: localhost",
                    "Content-Type: text/plain",
                    "Content-Type: application/json",
                    "Content-Length: 2"
                ],
                body: "{}"
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("Content-Type") == "application/json"
            } catch {
                return false
            }
        }
    }

    static let corsCredentialReflectionQualification = TestFlow(
        "security.cors.credentials-origin-reflection.qualification",
        title: "Qualify whether credentialed CORS origin reflection is possible",
        tags: [
            "security",
            "http",
            "cors",
            "credentials",
            "origin",
            "qualification",
        ]
    ) {
        Vulnerability(
            "CORS .any with credentials reflects arbitrary Origin",
            id: "SERVER-SEC-021",
            severity: .high,
            cwe: "CWE-942",
            vector: "Origin header",
            impact: "credentialed browser requests can be authorized for arbitrary origins when this config is used",
            evidence: "Access-Control-Allow-Origin echoes https://evil.example with Access-Control-Allow-Credentials: true"
        ) {
            let cors = CORS(
                config: CORSConfig(
                    allowedOrigin: .any,
                    allowCredentials: true
                )
            )

            let request = HTTPRequest(
                method: .get,
                path: "/account",
                headers: [
                    "Origin": "https://evil.example"
                ]
            )

            let response = cors.apply(
                to: .ok(body: "account"),
                for: request
            )

            return response.header("Access-Control-Allow-Origin") == "https://evil.example"
                && response.header("Access-Control-Allow-Credentials") == "true"
        }
    }

    static let inboundHeaderLimitQualification = TestFlow(
        "security.inbound.header-limits.qualification",
        title: "Qualify whether inbound header resource limits are absent",
        tags: [
            "security",
            "http",
            "headers",
            "resource-limit",
            "dos",
            "qualification",
        ]
    ) {
        Vulnerability(
            "large single header value is accepted",
            id: "SERVER-SEC-022",
            severity: .medium,
            cwe: "CWE-400",
            vector: "large request header value",
            impact: "large headers can consume memory and CPU before routing",
            evidence: "a 128 KiB header value parses successfully"
        ) {
            let value = String(
                repeating: "A",
                count: 128.kib
            )

            let raw = securityRawMessage(
                headLines: [
                    "GET /large-header HTTP/1.1",
                    "Host: localhost",
                    "X-Large: \(value)"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("X-Large")?.count == value.count
            } catch {
                return false
            }
        }

        Vulnerability(
            "large header count is accepted",
            id: "SERVER-SEC-023",
            severity: .medium,
            cwe: "CWE-400",
            vector: "large request header count",
            impact: "many headers can consume parser and dictionary resources before routing",
            evidence: "512 distinct headers parse successfully"
        ) {
            let generatedHeaders = (0..<512).map {
                "X-Fill-\($0): \($0)"
            }

            let raw = securityRawMessage(
                headLines: [
                    "GET /many-headers HTTP/1.1",
                    "Host: localhost"
                ] + generatedHeaders
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("X-Fill-511") == "511"
            } catch {
                return false
            }
        }
    }

    static let unsafeMethodQualification = TestFlow(
        "security.routing.unsafe-methods.qualification",
        title: "Qualify whether TRACE and CONNECT can enter the route layer",
        tags: [
            "security",
            "http",
            "methods",
            "routing",
            "trace",
            "connect",
            "qualification",
        ]
    ) {
        Vulnerability(
            "TRACE request parses and can execute a route",
            id: "SERVER-SEC-024",
            severity: .medium,
            cwe: "CWE-16",
            vector: "TRACE method",
            impact: "TRACE can be accidentally exposed by route configuration instead of being denied globally",
            evidence: "router executes a TRACE route when one is present"
        ) {
            let router = Router(
                routes: [
                    Route(
                        method: .trace,
                        path: "/debug",
                        handler: { request, _ in
                            .ok(
                                body: "trace:\(request.method.rawValue)"
                            )
                        }
                    )
                ]
            )

            let raw = securityRawMessage(
                headLines: [
                    "TRACE /debug HTTP/1.1",
                    "Host: localhost"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)
                let response = await router.route(request)

                return response.status.code == 200
                    && response.body.contains("TRACE")
            } catch {
                return false
            }
        }

        Vulnerability(
            "CONNECT request parses and can execute a route",
            id: "SERVER-SEC-025",
            severity: .medium,
            cwe: "CWE-16",
            vector: "CONNECT method",
            impact: "CONNECT can be accidentally exposed by route configuration instead of being denied globally",
            evidence: "router executes a CONNECT route when one is present"
        ) {
            let router = Router(
                routes: [
                    Route(
                        method: .connect,
                        path: "/tunnel",
                        handler: { request, _ in
                            .ok(
                                body: "connect:\(request.method.rawValue)"
                            )
                        }
                    )
                ]
            )

            let raw = securityRawMessage(
                headLines: [
                    "CONNECT /tunnel HTTP/1.1",
                    "Host: localhost"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)
                let response = await router.route(request)

                return response.status.code == 200
                    && response.body.contains("CONNECT")
            } catch {
                return false
            }
        }
    }

    static let requestTargetNormalizationQualification = TestFlow(
        "security.routing.request-target-normalization.qualification",
        title: "Qualify whether ambiguous request targets are accepted unnormalized",
        tags: [
            "security",
            "http",
            "routing",
            "path",
            "normalization",
            "qualification",
        ]
    ) {
        Vulnerability(
            "encoded dot-segments are accepted in request target",
            id: "SERVER-SEC-026",
            severity: .medium,
            cwe: "CWE-22",
            vector: "request target percent-encoding",
            impact: "prefix authorization, static-file serving, or reverse proxy routing can disagree with application routing",
            evidence: "/admin/%2e%2e/public parses unchanged"
        ) {
            let raw = securityRawMessage(
                headLines: [
                    "GET /admin/%2e%2e/public HTTP/1.1",
                    "Host: localhost"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.path == "/admin/%2e%2e/public"
            } catch {
                return false
            }
        }

        Vulnerability(
            "double-slash request target is accepted unchanged",
            id: "SERVER-SEC-027",
            severity: .low,
            cwe: "CWE-20",
            vector: "request target path normalization",
            impact: "route matching, proxy matching, and logs can disagree about canonical path identity",
            evidence: "//admin parses unchanged"
        ) {
            let raw = securityRawMessage(
                headLines: [
                    "GET //admin HTTP/1.1",
                    "Host: localhost"
                ]
            )

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.path == "//admin"
            } catch {
                return false
            }
        }
    }
}

private func securityRawMessage(
    headLines: [String],
    body: String = ""
) -> String {
    headLines.joined(
        separator: HTTPConstants.crlf
    ) + HTTPConstants.crlfCrLf + body
}
