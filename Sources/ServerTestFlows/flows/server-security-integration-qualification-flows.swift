import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let connectionCapNotEnforcedQualification = TestFlow(
        "security.server.connection-cap.qualification",
        title: "Qualify whether maxConnections limit is enforced",
        tags: [
            "security",
            "server",
            "connections",
            "dos",
            "integration",
            "qualification",
        ]
    ) {
        Vulnerability(
            "maxConnections configuration does not reject excess active connections",
            id: "SERVER-SEC-042",
            severity: .high,
            cwe: "CWE-400",
            vector: "TCP connection flood",
            impact: "connections beyond the configured cap can continue reaching application routes",
            evidence: "a second request succeeds while the first connection remains active and maxConnections is 1"
        ) {
            let server = try await SecurityTestServer.start(
                maxConnections: 1,
                routes: [
                    get("ok") {
                        .ok(
                            body: "cap-ok"
                        )
                    }
                ]
            )

            let held = SecurityTestConnection(
                port: server.port
            )

            guard await held.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            guard await held.send(
                "GET /held HTTP/1.1\r\nHost: localhost\r\n"
            ) else {
                held.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            let excess = SecurityTestConnection(
                port: server.port
            )

            guard await excess.start() else {
                held.cancel()
                await server.stop()

                return false
            }

            guard await excess.send(
                "GET /ok HTTP/1.1\r\nHost: localhost\r\n\r\n"
            ) else {
                held.cancel()
                excess.cancel()
                await server.stop()

                return false
            }

            let response = await excess.receive(
                until: {
                    $0.contains(
                        "cap-ok"
                    )
                }
            )

            held.cancel()
            excess.cancel()

            await server.stop()

            return response?.contains(
                "cap-ok"
            ) == true
        }
    }

    static let connectionHandlerRetentionQualification = TestFlow(
        "security.server.handler-retention.qualification",
        title: "Qualify whether completed connection handlers are released",
        tags: [
            "security",
            "server",
            "connections",
            "memory",
            "lifecycle",
            "qualification",
        ]
    ) {
        Vulnerability(
            "completed connection handlers remain retained by the engine",
            id: "SERVER-SEC-043",
            severity: .high,
            cwe: "CWE-772",
            vector: "connection lifecycle",
            impact: "server memory grows as completed handlers remain rooted",
            evidence: "retainedConnectionHandlerCount remains nonzero after completed client connections are cancelled"
        ) {
            let server = try await SecurityTestServer.start(
                routes: [
                    get("ok") {
                        .ok(
                            body: "retention-ok"
                        )
                    }
                ]
            )

            for _ in 0..<3 {
                let connection = SecurityTestConnection(
                    port: server.port
                )

                guard await connection.start() else {
                    await server.stop()

                    throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
                }

                guard await connection.send(
                    "GET /ok HTTP/1.1\r\nHost: localhost\r\n\r\n"
                ) else {
                    connection.cancel()
                    await server.stop()

                    throw SecurityNetworkHarnessError.sendFailed
                }

                _ = await connection.receive(
                    until: {
                        $0.contains(
                            "retention-ok"
                        )
                    }
                )

                connection.cancel()

                await securityTestDelay(
                    0.05
                )
            }

            await securityTestDelay(
                0.1
            )

            let retained =
                await server.engine.retainedConnectionHandlerCount

            await server.stop()

            return retained >= 3
        }
    }

    static let slowHeaderTimeoutQualification = TestFlow(
        "security.server.slow-header.qualification",
        title: "Qualify incomplete request-header timeout behavior",
        tags: [
            "security",
            "server",
            "slowloris",
            "timeout",
            "dos",
            "qualification",
        ]
    ) {
        Vulnerability(
            "trickled request headers remain serviceable beyond the configured absolute header deadline",
            id: "SERVER-SEC-044",
            severity: .high,
            cwe: "CWE-400",
            vector: "slow or trickled request headers",
            impact: "an attacker can retain a connection indefinitely while sending header bytes slowly",
            evidence: "a request can still reach the route after the configured header phase deadline has elapsed"
        ) {
            let marker =
                "slow-header-routed"

            let server = try await SecurityTestServer.start(
                timeouts: ServerTimeouts(
                    idle: .seconds(1),
                    headers: .milliseconds(200),
                    content: .seconds(1)
                ),
                routes: [
                    get("slow-header") {
                        .ok(
                            body: marker
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            guard await connection.send(
                "GET /slow-header HTTP/1.1\r\n"
            ) else {
                connection.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            await securityTestDelay(
                0.12
            )

            guard await connection.send(
                "Host: local"
            ) else {
                connection.cancel()
                await server.stop()

                return false
            }

            await securityTestDelay(
                0.12
            )

            let completed = await connection.send(
                "host\r\n\r\n",
                timeout: 0.25
            )

            let response: String?

            if completed {
                response = await connection.receive(
                    until: {
                        $0.contains(
                            marker
                        ) || $0.contains(
                            "HTTP/1.1 408"
                        )
                    },
                    timeout: 0.5
                )
            } else {
                response = nil
            }

            connection.cancel()

            await server.stop()

            return response?.contains(
                marker
            ) == true
        }
    }

    static let slowBodyTimeoutQualification = TestFlow(
        "security.server.slow-body.qualification",
        title: "Qualify incomplete request-body timeout behavior",
        tags: [
            "security",
            "server",
            "slowloris",
            "timeout",
            "dos",
            "body",
            "qualification",
        ]
    ) {
        Vulnerability(
            "trickled request body remains serviceable beyond the configured absolute content deadline",
            id: "SERVER-SEC-045",
            severity: .high,
            cwe: "CWE-400",
            vector: "slow or trickled HTTP request body",
            impact: "an attacker can retain request resources indefinitely while slowly completing a declared body",
            evidence: "a request can still reach the route after the configured content phase deadline has elapsed"
        ) {
            let marker =
                "slow-body-routed"

            let server = try await SecurityTestServer.start(
                timeouts: ServerTimeouts(
                    idle: .seconds(1),
                    headers: .seconds(1),
                    content: .milliseconds(200)
                ),
                routes: [
                    post("slow-body") {
                        .ok(
                            body: marker
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            guard await connection.send(
                "POST /slow-body HTTP/1.1\r\n"
                    + "Host: localhost\r\n"
                    + "Content-Length: 4\r\n"
                    + "\r\n"
                    + "a"
            ) else {
                connection.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            await securityTestDelay(
                0.12
            )

            guard await connection.send(
                "b"
            ) else {
                connection.cancel()
                await server.stop()

                return false
            }

            await securityTestDelay(
                0.12
            )

            let completed = await connection.send(
                "cd",
                timeout: 0.25
            )

            let response: String?

            if completed {
                response = await connection.receive(
                    until: {
                        $0.contains(
                            marker
                        ) || $0.contains(
                            "HTTP/1.1 408"
                        )
                    },
                    timeout: 0.5
                )
            } else {
                response = nil
            }

            connection.cancel()

            await server.stop()

            return response?.contains(
                marker
            ) == true
        }
    }

    static let idleConnectionTimeoutQualification = TestFlow(
        "security.server.idle-connection-timeout.qualification",
        title: "Qualify idle TCP connection lifetime",
        tags: [
            "security",
            "server",
            "connections",
            "idle",
            "timeout",
            "dos",
            "qualification",
        ]
    ) {
        Vulnerability(
            "idle connection remains serviceable beyond the configured idle deadline",
            id: "SERVER-SEC-050",
            severity: .high,
            cwe: "CWE-400",
            vector: "idle TCP connection",
            impact: "an attacker can retain connection slots and socket resources without transmitting a request",
            evidence: "an idle connection can still submit and route a request after the configured idle deadline"
        ) {
            let marker =
                "idle-timeout-routed"

            let server = try await SecurityTestServer.start(
                timeouts: ServerTimeouts(
                    idle: .milliseconds(200),
                    headers: .seconds(1),
                    content: .seconds(1)
                ),
                routes: [
                    get("idle-timeout") {
                        .ok(
                            body: marker
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            await securityTestDelay(
                0.3
            )

            let sent = await connection.send(
                "GET /idle-timeout HTTP/1.1\r\nHost: localhost\r\n\r\n",
                timeout: 0.25
            )

            let response: String?

            if sent {
                response = await connection.receive(
                    until: {
                        $0.contains(
                            marker
                        )
                    },
                    timeout: 0.35
                )
            } else {
                response = nil
            }

            connection.cancel()

            await server.stop()

            return response?.contains(
                marker
            ) == true
        }
    }

    static let hostBindingNotEnforcedQualification: TestFlow = {
        let name =
            "security.server.host-binding.qualification"

        let title =
            "Qualify whether server host configuration actually restricts binding"

        let tags: Set<String> = [
            "security",
            "server",
            "binding",
            "network",
            "integration",
            "qualification",
        ]

        guard let nonLoopback =
            SecurityNetworkHarness.nonLoopbackIPv4
        else {
            return TestFlow(
                name,
                title: title,
                tags: tags
            ) {
                Skip(
                    "No non-loopback IPv4 interface is available for the live host-binding qualification."
                )
            }
        }

        return TestFlow(
            name,
            title: title,
            tags: tags
        ) {
            Vulnerability(
                "loopback-configured server is reachable through a non-loopback interface",
                id: "SERVER-SEC-046",
                severity: .high,
                cwe: "CWE-668",
                vector: "network listener binding",
                impact: "a service intended for loopback can be exposed through another local interface",
                evidence: "a request through a non-loopback local address succeeds while ServerConfig.host is 127.0.0.1"
            ) {
                let server = try await SecurityTestServer.start(
                    host: "127.0.0.1",
                    routes: [
                        get("binding") {
                            .ok(
                                body: "binding-ok"
                            )
                        }
                    ]
                )

                let connection = SecurityTestConnection(
                    host: nonLoopback,
                    port: server.port
                )

                guard await connection.start() else {
                    await server.stop()

                    return false
                }

                guard await connection.send(
                    "GET /binding HTTP/1.1\r\nHost: localhost\r\n\r\n"
                ) else {
                    connection.cancel()
                    await server.stop()

                    return false
                }

                let response = await connection.receive(
                    until: {
                        $0.contains(
                            "binding-ok"
                        )
                    }
                )

                connection.cancel()

                await server.stop()

                return response?.contains(
                    "binding-ok"
                ) == true
            }
        }
    }()

    static let clientResponseHeaderUnboundedQualification = TestFlow(
        "security.client.response-header-unbounded.qualification",
        title: "Qualify whether client response header buffering has a size limit",
        tags: [
            "security",
            "client",
            "response",
            "memory",
            "dos",
            "integration",
            "qualification",
        ]
    ) {
        Vulnerability(
            "client waits for timeout after receiving an over-limit unterminated response header",
            id: "SERVER-SEC-047",
            severity: .high,
            cwe: "CWE-400",
            vector: "malicious HTTP response with enormous unterminated headers",
            impact: "a malicious peer can force response-header buffering until the overall request timeout",
            evidence: "HTTPClient times out rather than rejecting the oversized unterminated response header"
        ) {
            let oversized =
                HTTPPolicies.response.default
                    .headers
                    .maximumHeaderBytes * 2

            let raw =
                "HTTP/1.1 200 OK\r\nX-Fill: "
                + String(
                    repeating: "A",
                    count: oversized
                )

            let peer = try await SecurityTestPeer.start(
                payload: Data(
                    raw.utf8
                )
            )

            let client = HTTPClient(
                config: HTTPClientConfig(
                    host: "127.0.0.1",
                    port: peer.port,
                    timeout: 0.25,
                    debug: false
                )
            )

            let reproduced: Bool

            do {
                _ = try await client.get(
                    "/"
                )

                reproduced = false
            } catch let error as ServerError {
                switch error {
                case .connectionFailed(let message):
                    reproduced =
                        message.localizedCaseInsensitiveContains(
                            "timed out"
                        )

                default:
                    reproduced = false
                }
            } catch {
                reproduced = false
            }

            peer.stop()

            return reproduced
        }
    }

    static let httpPipeliningUndefinedQualification = TestFlow(
        "security.server.pipelining-undefined.qualification",
        title: "Qualify HTTP/1.1 pipelining and response ordering behavior",
        tags: [
            "security",
            "server",
            "http",
            "pipelining",
            "concurrency",
            "integration",
            "qualification",
        ]
    ) {
        Vulnerability(
            "HTTP/1.1 requests on one connection can stall or violate response order",
            id: "SERVER-SEC-048",
            severity: .medium,
            cwe: "CWE-362",
            vector: "multiple HTTP/1.1 requests on one persistent connection",
            impact: "response association on a persistent connection is not serialized predictably",
            evidence: "a later fast request either overtakes or fails to complete behind an earlier slow request"
        ) {
            let server = try await SecurityTestServer.start(
                routes: [
                    get("slow") {
                        await securityTestDelay(
                            0.25
                        )

                        return .ok(
                            body: "slow-response"
                        )
                    },
                    get("fast") {
                        .ok(
                            body: "fast-response"
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            guard await connection.send(
                "GET /slow HTTP/1.1\r\nHost: localhost\r\n\r\n"
            ) else {
                connection.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            await securityTestDelay(
                0.05
            )

            guard await connection.send(
                "GET /fast HTTP/1.1\r\nHost: localhost\r\n\r\n"
            ) else {
                connection.cancel()
                await server.stop()

                return false
            }

            let response = await connection.receive(
                until: {
                    $0.contains(
                        "slow-response"
                    )
                        && $0.contains(
                            "fast-response"
                        )
                },
                timeout: 0.75
            ) ?? ""

            connection.cancel()

            await server.stop()

            let hasSlow =
                response.contains(
                    "slow-response"
                )

            let hasFast =
                response.contains(
                    "fast-response"
                )

            if hasSlow != hasFast {
                return true
            }

            guard hasSlow,
                  hasFast,
                  let slow =
                    response.range(
                        of: "slow-response"
                    ),
                  let fast =
                    response.range(
                        of: "fast-response"
                    )
            else {
                return false
            }

            return fast.lowerBound
                < slow.lowerBound
        }
    }

    static let serverRequestHeaderSizeLimitQualification = TestFlow(
        "security.server.request-header-size.regression",
        title: "Server bounds oversized unterminated request headers",
        tags: [
            "security",
            "server",
            "headers",
            "memory",
            "dos",
            "regression",
        ]
    ) {
        Step(
            "oversized unterminated request header is rejected without routing"
        ) {
            let policy = HTTPHeaderPolicy(
                maximumHeaderBytes: 256,
                maximumHeaderLineBytes: 256,
                maximumHeaderCount: 20,
                singletonHeaderNames:
                    HTTPHeaderPolicy.request.default.singletonHeaderNames,
                rejectTransferEncoding: true
            )

            let server = try await SecurityTestServer.start(
                limits: ServerLimits(
                    headers: policy
                ),
                routes: [
                    get("ok") {
                        .ok(
                            body: "should-not-route"
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            let connected =
                await connection.start()

            var sent = false
            var response: String?

            if connected {
                let oversized =
                    "GET /ok HTTP/1.1\r\n"
                    + "Host: localhost\r\n"
                    + "X-Fill: "
                    + String(
                        repeating: "A",
                        count: 512
                    )

                sent = await connection.send(
                    oversized
                )

                if sent {
                    response = await connection.receive(
                        until: {
                            $0.contains(
                                "should-not-route"
                            )
                        },
                        timeout: 0.25
                    )
                }
            }

            connection.cancel()

            await server.stop()

            try Expect.true(
                connected,
                "request-header-limit.connection-ready"
            )

            try Expect.true(
                sent,
                "request-header-limit.request-sent"
            )

            try Expect.false(
                response?.contains(
                    "should-not-route"
                ) == true,
                "request-header-limit.does-not-route"
            )
        }

        Vulnerability(
            "oversized-header rejection response can be cancelled before delivery",
            id: "SERVER-SEC-049",
            severity: .low,
            cwe: "CWE-703",
            vector: "oversized unterminated request header",
            impact: "clients may observe abrupt connection termination instead of the intended HTTP 431 response",
            evidence: "ServerConnectionHandler schedules the 431 send and immediately cancels the connection"
        ) {
            let policy = HTTPHeaderPolicy(
                maximumHeaderBytes: 256,
                maximumHeaderLineBytes: 256,
                maximumHeaderCount: 20,
                singletonHeaderNames:
                    HTTPHeaderPolicy.request.default.singletonHeaderNames,
                rejectTransferEncoding: true
            )

            let server = try await SecurityTestServer.start(
                limits: ServerLimits(
                    headers: policy
                ),
                routes: []
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            let oversized =
                "GET / HTTP/1.1\r\n"
                + "Host: localhost\r\n"
                + "X-Fill: "
                + String(
                    repeating: "A",
                    count: 512
                )

            guard await connection.send(
                oversized
            ) else {
                connection.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            let response = await connection.receive(
                until: {
                    $0.contains(
                        "HTTP/1.1 431"
                    )
                },
                timeout: 0.25
            )

            connection.cancel()

            await server.stop()

            return response?.contains(
                "HTTP/1.1 431"
            ) != true
        }
    }

    static let pipelinedBacklogQualification = TestFlow(
        "security.server.pipelined-backlog.qualification",
        title: "Qualify per-connection pipelined request backlog",
        tags: [
            "security",
            "server",
            "http",
            "pipelining",
            "backpressure",
            "memory",
            "dos",
            "qualification",
        ]
    ) {
        Vulnerability(
            "one persistent connection can accumulate a large pipelined request backlog without backpressure",
            id: "SERVER-SEC-051",
            severity: .high,
            cwe: "CWE-400",
            vector: "many pipelined HTTP/1.1 requests on one connection",
            impact: "one client can create an unbounded chain of pending request tasks faster than the application services them",
            evidence: "32 complete pipelined requests become pending simultaneously while the first route remains blocked"
        ) {
            let entered =
                SecurityOneShot<Bool>()

            let release =
                SecurityOneShot<Bool>()

            let requestCount =
                32

            let server = try await SecurityTestServer.start(
                timeouts: ServerTimeouts(
                    idle: .seconds(2),
                    headers: .seconds(1),
                    content: .seconds(1)
                ),
                routes: [
                    get("backlog") {
                        entered.resolve(
                            true
                        )

                        _ = await release.wait()

                        return .ok(
                            body: "backlog-ok"
                        )
                    }
                ]
            )

            let connection = SecurityTestConnection(
                port: server.port
            )

            guard await connection.start() else {
                await server.stop()

                throw SecurityNetworkHarnessError.connectionDidNotBecomeReady
            }

            let request =
                "GET /backlog HTTP/1.1\r\nHost: localhost\r\n\r\n"

            let pipeline = Array(
                repeating: request,
                count: requestCount
            ).joined()

            guard await connection.send(
                pipeline
            ) else {
                connection.cancel()
                await server.stop()

                throw SecurityNetworkHarnessError.sendFailed
            }

            guard await entered.wait(
                timeout: 0.5,
                fallback: false
            ) else {
                connection.cancel()
                await server.stop()

                return false
            }

            let deadline =
                Date().addingTimeInterval(
                    0.5
                )

            var observed = 0

            repeat {
                observed =
                    await server.engine.maximumPendingOperationCount()

                if observed >= requestCount {
                    break
                }

                await securityTestDelay(
                    0.01
                )
            } while Date() < deadline

            release.resolve(
                true
            )

            await securityTestDelay(
                0.1
            )

            connection.cancel()

            await server.stop()

            return observed >= requestCount
        }
    }
}
