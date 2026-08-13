import Foundation
import HTTP
import Server
import TestFlows

private struct ProductionAnalyzerEnvelope:
    Codable,
    Sendable
{
    let site_id: String
    let ts: Int64
    let visitor_id: String?
    let session_id: String
    let events: [ProductionAnalyzerEvent]
}

private struct ProductionAnalyzerEvent:
    Codable,
    Sendable
{
    let type: String
    let subdomain: String
    let location: String
    let src: String
    let med: String
    let campaign: String
    let landing_path: String
    let url: String
    let ref: String
    let title: String
    let lang: String
    let ua: String
    let vp_w: Int
    let vp_h: Int
    let ms: Int
    let x: Double
    let y: Double
    let el: String
    let id: String
    let step: String
    let tz: String
    let dpr: Double
    let ok: Bool
}

private func productionAnalyzerBody(
    eventCount: Int = 512
) throws -> String {
    let text = String(
        repeating: "gedrag-café-βeta-met-normale-UTF8-tekst-",
        count: 12
    )

    let events = (0..<eventCount).map { index in
        ProductionAnalyzerEvent(
            type: index.isMultiple(of: 3)
                ? "pageview"
                : "interaction",
            subdomain: "www",
            location: "Alkmaar",
            src: "google",
            med: "organic",
            campaign: "production-wire-regression",
            landing_path: "/gedrag/reactiviteit",
            url: "https://hondenmeesters.nl/gedrag/reactiviteit?event=\(index)",
            ref: "https://www.google.com/search?q=hond+reactiviteit&event=\(index)",
            title: "\(text)\(index)",
            lang: "nl-NL",
            ua: "ServerTestFlows/production-wire-regression",
            vp_w: 1440,
            vp_h: 900,
            ms: index * 17,
            x: Double(index % 1440),
            y: Double(index % 900),
            el: "main article section:nth-child(\((index % 8) + 1))",
            id: "event-\(index)",
            step: "step-\(index % 6)",
            tz: "Europe/Amsterdam",
            dpr: 2,
            ok: true
        )
    }

    let envelope = ProductionAnalyzerEnvelope(
        site_id: "hondenmeesters.nl",
        ts: 1_786_574_400_000,
        visitor_id: "production-wire-visitor",
        session_id: "production-wire-session",
        events: events
    )

    let data = try JSONEncoder().encode(
        envelope
    )

    return String(
        decoding: data,
        as: UTF8.self
    )
}

private func productionRawRequest(
    method: String,
    path: String,
    headers: [(String, String)],
    body: String = ""
) -> String {
    var lines = [
        "\(method) \(path) HTTP/1.1"
    ]

    lines.append(
        contentsOf: headers.map { name, value in
            "\(name): \(value)"
        }
    )

    return lines.joined(
        separator: "\r\n"
    ) + "\r\n\r\n" + body
}

private func productionRawResponse(
    body: String
) -> String {
    [
        "HTTP/1.1 200 OK",
        "Content-Type: text/plain; charset=utf-8",
        "Content-Length: \(body.utf8.count)",
        "Connection: close"
    ].joined(
        separator: "\r\n"
    ) + "\r\n\r\n" + body
}

private func productionWireCORS() -> CORSMiddleware {
    CORSMiddleware(
        allowedOrigin: .whitelist([
            "https://hondenmeesters.nl",
            "https://test.hondenmeesters.nl",
            "https://docs.hondenmeesters.nl"
        ]),
        allowCredentials: true,
        allowedMethods: [
            .get,
            .post,
            .options
        ],
        allowedHeaders: [
            "Content-Type",
            "Authorization",
            "Accept",
            "X-Requested-With",
            "X-Captcher-Key",
            "X-Route-Origin"
        ],
        exposedHeaders: [],
        maxAgeSeconds: 600
    )
}

private func productionLargeResponseBody() -> String {
    String(
        repeating: "response-café-βeta-0123456789-normal-body-data\n",
        count: 8_000
    ) + "END-OF-LARGE-RESPONSE"
}

private func withProductionWireServer(
    limits: ServerLimits = .default,
    routes mountedRoutes: [Route],
    operation: @Sendable (
        SecurityTestServer
    ) async throws -> Void
) async throws {
    let server = try await SecurityTestServer.start(
        limits: limits,
        routes: mountedRoutes
    )

    do {
        try await operation(
            server
        )
    } catch {
        await server.stop()

        throw error
    }

    await server.stop()
}

extension ServerSecurityFlows {
    static let serverProductionWireRegressionFlow = TestFlow(
        "server.production-wire.regression",
        title: "Production-shaped HTTP workloads survive real Server wire transport",
        tags: [
            "api-contract",
            "framing",
            "http",
            "integration",
            "network",
            "production-proxy",
            "regression",
            "server",
        ]
    ) {
        Step(
            "large analyzer-shaped JSON request crosses multiple receive windows intact"
        ) {
            let body = try productionAnalyzerBody()

            try Expect.true(
                body.utf8.count > 65_536,
                "production-wire.analyzer.body-crosses-receive-window"
            )

            let cors = productionWireCORS()

            try await withProductionWireServer(
                routes: [
                    post(
                        "collect"
                    ) { request in
                        do {
                            let payload = try request.extract(
                                ProductionAnalyzerEnvelope.self
                            )

                            let clientIP = try request
                                .parseClientIP()
                                .rawValue

                            guard
                                payload.site_id == "hondenmeesters.nl",
                                payload.session_id == "production-wire-session",
                                payload.events.count == 512,
                                payload.events.last?.title.contains(
                                    "café"
                                ) == true,
                                request.header(
                                    "X-Request-ID"
                                ) == "production-wire-regression",
                                clientIP == "203.0.113.27"
                            else {
                                return .badRequest(
                                    body: "production proxy mismatch"
                                )
                            }

                            return .ok(
                                body: [
                                    "accepted=\(payload.events.count)",
                                    "bytes=\(request.body.utf8.count)",
                                    "ip=\(clientIP)"
                                ].joined(
                                    separator: ";"
                                )
                            )
                        } catch {
                            return .badRequest(
                                body: "decode failed: \(error)"
                            )
                        }
                    }
                    .cors(
                        cors
                    )
                ]
            ) { server in
                let connection = SecurityTestConnection(
                    port: server.port
                )

                guard await connection.start() else {
                    throw SecurityNetworkHarnessError
                        .connectionDidNotBecomeReady
                }

                let raw = productionRawRequest(
                    method: "POST",
                    path: "/collect",
                    headers: [
                        (
                            "Host",
                            "127.0.0.1"
                        ),
                        (
                            "Content-Type",
                            "application/json"
                        ),
                        (
                            "Origin",
                            "https://hondenmeesters.nl"
                        ),
                        (
                            "X-Forwarded-For",
                            "203.0.113.27, 10.100.0.1, 10.90.20.15"
                        ),
                        (
                            "X-Real-IP",
                            "10.100.0.1"
                        ),
                        (
                            "X-Request-ID",
                            "production-wire-regression"
                        ),
                        (
                            "User-Agent",
                            "ServerTestFlows/production-wire-regression"
                        ),
                        (
                            "Content-Length",
                            "\(body.utf8.count)"
                        )
                    ],
                    body: body
                )

                guard await connection.send(
                    raw,
                    timeout: 3
                ) else {
                    connection.cancel()

                    throw SecurityNetworkHarnessError.sendFailed
                }

                let response = await connection.receive(
                    until: {
                        $0.contains(
                            "accepted=512"
                        )
                    },
                    timeout: 3
                ) ?? ""

                connection.cancel()

                try Expect.true(
                    response.contains(
                        "HTTP/1.1 200"
                    ),
                    "production-wire.analyzer.status"
                )

                try Expect.true(
                    response.contains(
                        "accepted=512"
                    ),
                    "production-wire.analyzer.event-count"
                )

                try Expect.true(
                    response.contains(
                        "bytes=\(body.utf8.count)"
                    ),
                    "production-wire.analyzer.byte-count"
                )

                try Expect.true(
                    response.contains(
                        "ip=203.0.113.27"
                    ),
                    "production-wire.analyzer.forwarded-client-ip"
                )
            }
        }

        Step(
            "browser-shaped CORS preflight survives the real wire parser and router"
        ) {
            let cors = productionWireCORS()

            try await withProductionWireServer(
                routes: [
                    post(
                        "collect"
                    ) {
                        .ok()
                    }
                    .cors(
                        cors
                    )
                ]
            ) { server in
                let connection = SecurityTestConnection(
                    port: server.port
                )

                guard await connection.start() else {
                    throw SecurityNetworkHarnessError
                        .connectionDidNotBecomeReady
                }

                let raw = productionRawRequest(
                    method: "OPTIONS",
                    path: "/collect",
                    headers: [
                        (
                            "Host",
                            "127.0.0.1"
                        ),
                        (
                            "Origin",
                            "https://hondenmeesters.nl"
                        ),
                        (
                            "Access-Control-Request-Method",
                            "POST"
                        ),
                        (
                            "Access-Control-Request-Headers",
                            "content-type,x-requested-with"
                        ),
                        (
                            "Content-Length",
                            "0"
                        )
                    ]
                )

                guard await connection.send(
                    raw
                ) else {
                    connection.cancel()

                    throw SecurityNetworkHarnessError.sendFailed
                }

                let response = await connection.receive(
                    until: {
                        $0.contains(
                            "\r\n\r\n"
                        )
                    },
                    timeout: 2
                ) ?? ""

                connection.cancel()

                let normalized = response.lowercased()

                try Expect.true(
                    response.contains(
                        "HTTP/1.1 204"
                    ),
                    "production-wire.cors.status"
                )

                try Expect.true(
                    normalized.contains(
                        "access-control-allow-origin: https://hondenmeesters.nl"
                    ),
                    "production-wire.cors.origin"
                )

                try Expect.true(
                    normalized.contains(
                        "access-control-allow-credentials: true"
                    ),
                    "production-wire.cors.credentials"
                )
            }
        }

        Step(
            "request content policy accepts the exact boundary and rejects one byte over it"
        ) {
            let maximumBytes = 128.kib

            try await withProductionWireServer(
                limits: ServerLimits(
                    content: .custom(
                        maximumBytes
                    )
                ),
                routes: [
                    post(
                        "body"
                    ) { request in
                        .ok(
                            body: "bytes=\(request.body.utf8.count)"
                        )
                    }
                ]
            ) { server in
                let acceptedBody = String(
                    repeating: "A",
                    count: maximumBytes
                )

                let accepted = SecurityTestConnection(
                    port: server.port
                )

                guard await accepted.start() else {
                    throw SecurityNetworkHarnessError
                        .connectionDidNotBecomeReady
                }

                guard await accepted.send(
                    productionRawRequest(
                        method: "POST",
                        path: "/body",
                        headers: [
                            (
                                "Host",
                                "127.0.0.1"
                            ),
                            (
                                "Content-Type",
                                "text/plain"
                            ),
                            (
                                "Content-Length",
                                "\(acceptedBody.utf8.count)"
                            )
                        ],
                        body: acceptedBody
                    ),
                    timeout: 3
                ) else {
                    accepted.cancel()

                    throw SecurityNetworkHarnessError.sendFailed
                }

                let acceptedResponse = await accepted.receive(
                    until: {
                        $0.contains(
                            "bytes=\(maximumBytes)"
                        )
                    },
                    timeout: 3
                ) ?? ""

                accepted.cancel()

                try Expect.true(
                    acceptedResponse.contains(
                        "HTTP/1.1 200"
                    ),
                    "production-wire.request-policy.exact-boundary-status"
                )

                try Expect.true(
                    acceptedResponse.contains(
                        "bytes=\(maximumBytes)"
                    ),
                    "production-wire.request-policy.exact-boundary-body"
                )

                let rejectedBody = acceptedBody + "B"

                let rejected = SecurityTestConnection(
                    port: server.port
                )

                guard await rejected.start() else {
                    throw SecurityNetworkHarnessError
                        .connectionDidNotBecomeReady
                }

                guard await rejected.send(
                    productionRawRequest(
                        method: "POST",
                        path: "/body",
                        headers: [
                            (
                                "Host",
                                "127.0.0.1"
                            ),
                            (
                                "Content-Type",
                                "text/plain"
                            ),
                            (
                                "Content-Length",
                                "\(rejectedBody.utf8.count)"
                            )
                        ],
                        body: rejectedBody
                    ),
                    timeout: 3
                ) else {
                    rejected.cancel()

                    throw SecurityNetworkHarnessError.sendFailed
                }

                let rejectedResponse = await rejected.receive(
                    until: {
                        $0.contains(
                            "\r\n\r\n"
                        )
                    },
                    timeout: 3
                ) ?? ""

                rejected.cancel()

                try Expect.true(
                    rejectedResponse.contains(
                        "HTTP/1.1 413"
                    ),
                    "production-wire.request-policy.over-boundary-status"
                )
            }
        }

        Step(
            "large normal Server response survives multi-window transport and reparsing"
        ) {
            let body = productionLargeResponseBody()

            try Expect.true(
                body.utf8.count > 65_536,
                "production-wire.server-response.crosses-receive-window"
            )

            try await withProductionWireServer(
                routes: [
                    get(
                        "large-response"
                    ) {
                        .ok(
                            body: body
                        )
                    }
                ]
            ) { server in
                let connection = SecurityTestConnection(
                    port: server.port
                )

                guard await connection.start() else {
                    throw SecurityNetworkHarnessError
                        .connectionDidNotBecomeReady
                }

                guard await connection.send(
                    productionRawRequest(
                        method: "GET",
                        path: "/large-response",
                        headers: [
                            (
                                "Host",
                                "127.0.0.1"
                            ),
                            (
                                "Content-Length",
                                "0"
                            )
                        ]
                    )
                ) else {
                    connection.cancel()

                    throw SecurityNetworkHarnessError.sendFailed
                }

                let rawResponse = await connection.receive(
                    until: {
                        $0.contains(
                            "END-OF-LARGE-RESPONSE\n"
                        )
                    },
                    timeout: 3
                ) ?? ""

                connection.cancel()

                let response = try HTTPResponse(
                    parsing: rawResponse
                )

                try Expect.equal(
                    response.status.code,
                    200,
                    "production-wire.server-response.status"
                )

                try Expect.equal(
                    response.body,
                    body + "\n",
                    "production-wire.server-response.body"
                )
            }
        }

        Step(
            "HTTPClient receives a large normal response and applies its aggregate content policy"
        ) {
            let body = String(
                repeating: "client-response-café-βeta-0123456789\n",
                count: 8_000
            ) + "END-OF-HTTPCLIENT-RESPONSE"

            try Expect.true(
                body.utf8.count > 65_536,
                "production-wire.http-client.crosses-receive-window"
            )

            let rawResponse = productionRawResponse(
                body: body
            )

            let defaults = HTTPPolicies.response.default

            let allowedPolicies = HTTPResponsePolicies(
                headers: defaults.headers,
                content: .custom(
                    body.utf8.count
                )
            )

            let allowedPeer = try await SecurityTestPeer.start(
                payload: Data(
                    rawResponse.utf8
                )
            )

            do {
                let client = HTTPClient(
                    config: HTTPClientConfig(
                        host: "127.0.0.1",
                        port: allowedPeer.port,
                        timeout: 3,
                        policies: allowedPolicies
                    )
                )

                let response = try await client.get(
                    "/large"
                )

                allowedPeer.stop()

                try Expect.equal(
                    response.status.code,
                    200,
                    "production-wire.http-client.allowed-status"
                )

                try Expect.equal(
                    response.body,
                    body,
                    "production-wire.http-client.allowed-body"
                )
            } catch {
                allowedPeer.stop()

                throw error
            }

            let restrictedPolicies = HTTPResponsePolicies(
                headers: defaults.headers,
                content: .custom(
                    body.utf8.count - 1
                )
            )

            let restrictedPeer = try await SecurityTestPeer.start(
                payload: Data(
                    rawResponse.utf8
                )
            )

            var rejectedByResponseBoundary = false

            do {
                let client = HTTPClient(
                    config: HTTPClientConfig(
                        host: "127.0.0.1",
                        port: restrictedPeer.port,
                        timeout: 3,
                        policies: restrictedPolicies
                    )
                )

                _ = try await client.get(
                    "/large"
                )
            } catch let error as ServerError {
                if case .responseEncodingFailed = error {
                    rejectedByResponseBoundary = true
                }
            } catch {
                rejectedByResponseBoundary = false
            }

            restrictedPeer.stop()

            try Expect.true(
                rejectedByResponseBoundary,
                "production-wire.http-client.restricted-content-policy"
            )
        }
    }
}
