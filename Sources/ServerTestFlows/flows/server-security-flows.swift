import TestFlows
import Foundation
import HTTP
import Server

extension ServerSecurityFlows {
    static let outboundClientRequestCRLFInjection = TestFlow(
        "security.outbound.client-request.crlf-injection",
        title: "Outbound client request CRLF injection is currently possible",
        tags: [
            "security",
            "http",
            "crlf",
            "characterization",
            "client",
        ]
    ) {
        Exploit(
            "path CRLF escapes into request headers",
            id: "SERVER-SEC-001",
            severity: .critical,
            cwe: "CWE-93",
            vector: "request-target",
            impact: "header injection / request splitting against the downstream HTTP peer",
            evidence:
                "X-Injected-Path reaches the serialized wire request and a second apparent request segment is emitted"
        ) {
            let injectedPath = "/safe HTTP/1.1\r\nX-Injected-Path: yes\r\n\r\nGET /admin"

            let wire = buildWireRequest(
                host: "127.0.0.1",
                method: .get,
                path: injectedPath,
                headers: [:],
                body: nil
            )

            return wire.contains("X-Injected-Path: yes")
                && wire.contains("\r\n\r\nGET /admin")
        }

        Exploit(
            "header value CRLF escapes into another request header",
            id: "SERVER-SEC-002",
            severity: .critical,
            cwe: "CWE-93",
            vector: "request header value",
            impact: "attacker-controlled header value can create additional HTTP headers",
            evidence: "X-Injected-Header reaches the serialized wire request as its own header"
        ) {
            let wire = buildWireRequest(
                host: "127.0.0.1",
                method: .get,
                path: "/safe",
                headers: [
                    "X-Test": "ok\r\nX-Injected-Header: yes"
                ],
                body: nil
            )

            return wire.contains("X-Injected-Header: yes")
        }

        Exploit(
            "header name CRLF escapes into another request header line",
            id: "SERVER-SEC-003",
            severity: .critical,
            cwe: "CWE-93",
            vector: "request header name",
            impact: "attacker-controlled header name can create additional HTTP header lines",
            evidence: "X-Injected-Name reaches the serialized wire request as its own header line"
        ) {
            let wire = buildWireRequest(
                host: "127.0.0.1",
                method: .get,
                path: "/safe",
                headers: [
                    "X-Test\r\nX-Injected-Name": "yes"
                ],
                body: nil
            )

            return wire.contains("X-Injected-Name: yes")
        }

        Exploit(
            "authorization value CRLF escapes into another request header",
            id: "SERVER-SEC-004",
            severity: .critical,
            cwe: "CWE-93",
            vector: "Authorization header value",
            impact: "attacker-controlled auth material can inject additional HTTP headers",
            evidence: "X-Injected-Auth reaches the serialized wire request as its own header"
        ) {
            let wire = buildWireRequest(
                host: "127.0.0.1",
                method: .get,
                path: "/safe",
                headers: [
                    "Authorization": "Bearer good-token\r\nX-Injected-Auth: yes"
                ],
                body: nil
            )

            return wire.contains("X-Injected-Auth: yes")
        }
    }

    static let outboundResponseCRLFInjection = TestFlow(
        "security.outbound.response.crlf-injection",
        title: "Outbound response CRLF injection is currently possible",
        tags: [
            "security",
            "http",
            "crlf",
            "characterization",
            "response",
        ]
    ) {
        Exploit(
            "response header value CRLF escapes into another response header",
            id: "SERVER-SEC-005",
            severity: .critical,
            cwe: "CWE-113",
            vector: "response header value",
            impact: "response splitting / cookie injection / cache or proxy confusion",
            evidence: "Set-Cookie reaches the serialized response as an injected header",
            references: [
                .cwe("CWE-93")
            ]
        ) {
            let response = HTTPResponse(
                status: .ok,
                headers: [
                    "X-Test": "ok\r\nSet-Cookie: injected=yes"
                ],
                body: "hello"
            )

            let wire = HTTPResponseBuilder.build(response)

            return wire.contains("Set-Cookie: injected=yes")
        }

        Exploit(
            "response header name CRLF escapes into another response header",
            id: "SERVER-SEC-006",
            severity: .critical,
            cwe: "CWE-113",
            vector: "response header name",
            impact: "response splitting / injected response metadata",
            evidence: "X-Injected-Name reaches the serialized response as its own header",
            references: [
                .cwe("CWE-93")
            ]
        ) {
            let response = HTTPResponse(
                status: .ok,
                headers: [
                    "X-Test\r\nX-Injected-Name": "yes"
                ],
                body: "hello"
            )

            let wire = HTTPResponseBuilder.build(response)

            return wire.contains("X-Injected-Name: yes")
        }

        Exploit(
            "status reason phrase CRLF escapes into response headers",
            id: "SERVER-SEC-007",
            severity: .critical,
            cwe: "CWE-113",
            vector: "status reason phrase",
            impact: "response status line can be broken into attacker-controlled headers",
            evidence: "X-Injected-Reason reaches the serialized response as its own header",
            references: [
                .cwe("CWE-93")
            ]
        ) {
            let response = HTTPResponse(
                status: HTTPStatus(
                    code: 200,
                    reason: "OK\r\nX-Injected-Reason: yes"
                ),
                headers: [:],
                body: "hello"
            )

            let wire = HTTPResponseBuilder.build(response)

            return wire.contains("X-Injected-Reason: yes")
        }
    }

    static let requestParserFramingConfusion = TestFlow(
        "security.inbound.request-parser.framing-confusion",
        title: "Inbound request parser currently accepts ambiguous or lossy HTTP framing",
        tags: [
            "security",
            "http",
            "parser",
            "framing",
            "characterization",
        ]
    ) {
        Vulnerability(
            "body containing CRLFCRLF is truncated",
            id: "SERVER-SEC-008",
            severity: .high,
            cwe: "CWE-444",
            vector: "request body framing",
            impact: "application receives a different body than the framed HTTP message contained",
            evidence: "body alpha\\r\\n\\r\\nbeta is parsed as alpha",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let body = "alpha\r\n\r\nbeta"

            let raw = """
                POST /echo HTTP/1.1\r
                Host: localhost\r
                Content-Length: \(body.utf8.count)\r
                \r
                \(body)
                """

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.body == "alpha"
                    && request.body != body
            } catch {
                return false
            }
        }

        Vulnerability(
            "request line without HTTP version is accepted",
            id: "SERVER-SEC-009",
            severity: .high,
            cwe: "CWE-20",
            vector: "request line",
            impact: "non-HTTP-shaped input can still route through the application",
            evidence: "GET /admin without HTTP/1.1 parses as a GET /admin request"
        ) {
            let raw = """
                GET /admin\r
                Host: localhost\r
                \r

                """

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.method == .get
                    && request.path == "/admin"
            } catch {
                return false
            }
        }

        Vulnerability(
            "duplicate Authorization headers collapse by overwrite",
            id: "SERVER-SEC-010",
            severity: .high,
            cwe: "CWE-20",
            vector: "duplicate Authorization headers",
            impact: "framing/auth layers can disagree about which credentials are authoritative",
            evidence: "Authorization: Bearer second overwrites Authorization: Bearer first",
            references: [
                .cwe("CWE-444")
            ]
        ) {
            let raw = """
                GET /admin HTTP/1.1\r
                Host: localhost\r
                Authorization: Bearer first\r
                Authorization: Bearer second\r
                \r

                """

            do {
                let request = try HTTPRequestParser.parse(raw)

                return request.header("Authorization") == "Bearer second"
            } catch {
                return false
            }
        }
    }

    static let contentLengthParsingConfusion = TestFlow(
        "security.inbound.content-length.confusion",
        title: "Content-Length parsing currently accepts unsafe values",
        tags: [
            "security",
            "http",
            "content-length",
            "framing",
            "characterization",
        ]
    ) {
        Vulnerability(
            "request Content-Length accepts negative value",
            id: "SERVER-SEC-011",
            severity: .high,
            cwe: "CWE-20",
            vector: "request Content-Length",
            impact: "connection handler can compute invalid framing bounds",
            evidence: "Content-Length: -1 is parsed as -1",
            references: [
                .cwe("CWE-444")
            ]
        ) {
            let headerData = Data(
                """
                POST / HTTP/1.1\r
                Host: localhost\r
                Content-Length: -1\r
                \r

                """.utf8
            )

            let contentLength = HTTPRequestParser.extractContentLength(
                from: headerData
            )

            return contentLength == -1
        }

        Vulnerability(
            "request Content-Length accepts Int.max",
            id: "SERVER-SEC-012",
            severity: .high,
            cwe: "CWE-400",
            vector: "request Content-Length",
            impact:
                "connection handler can wait indefinitely, overflow accounting, or pin resources",
            evidence: "Content-Length: 9223372036854775807 is parsed as Int.max",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let headerData = Data(
                """
                POST / HTTP/1.1\r
                Host: localhost\r
                Content-Length: 9223372036854775807\r
                \r

                """.utf8
            )

            let contentLength = HTTPRequestParser.extractContentLength(
                from: headerData
            )

            return contentLength == Int.max
        }

        Vulnerability(
            "request Content-Length conflicting duplicates are not rejected",
            id: "SERVER-SEC-013",
            severity: .high,
            cwe: "CWE-444",
            vector: "duplicate request Content-Length",
            impact: "request smuggling / parser disagreement with proxies or upstream framing",
            evidence:
                "conflicting Content-Length values 5 and 10 resolve to 5 instead of rejection",
            references: [
                .cwe("CWE-20")
            ]
        ) {
            let headerData = Data(
                """
                POST / HTTP/1.1\r
                Host: localhost\r
                Content-Length: 5\r
                Content-Length: 10\r
                \r

                """.utf8
            )

            let contentLength = HTTPRequestParser.extractContentLength(
                from: headerData
            )

            return contentLength == 5
        }

        Vulnerability(
            "response Content-Length accepts negative value",
            id: "SERVER-SEC-014",
            severity: .high,
            cwe: "CWE-20",
            vector: "response Content-Length",
            impact: "client response framing can compute invalid body bounds",
            evidence: "response Content-Length: -1 is parsed as -1",
            references: [
                .cwe("CWE-444")
            ]
        ) {
            let headerData = Data(
                """
                HTTP/1.1 200 OK\r
                Content-Length: -1\r
                \r

                """.utf8
            )

            let contentLength = HTTPResponseParser.extractContentLength(
                from: headerData
            )

            return contentLength == -1
        }
    }
}
