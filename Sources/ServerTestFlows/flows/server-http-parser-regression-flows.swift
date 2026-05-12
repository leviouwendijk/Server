import Foundation
import HTTP
import TestFlows

extension ServerSecurityFlows {
    static let httpRequestParserRegressionFlow = TestFlow(
        "http.request-parser.regression",
        title: "HTTPRequestParser preserves ordinary request parsing behavior",
        tags: [
            "http",
            "request",
            "parser-regression",
            "regression"
        ]
    ) {
        Step("parse simple GET request with headers and empty body") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /health HTTP/1.1",
                    "Host: localhost",
                    "User-Agent: ServerFlow/1.0"
                ]
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.method,
                .get,
                "request-parser.simple.method"
            )

            try Expect.equal(
                request.path,
                "/health",
                "request-parser.simple.path"
            )

            try Expect.equal(
                request.header("Host"),
                "localhost",
                "request-parser.simple.host"
            )

            try Expect.equal(
                request.header("User-Agent"),
                "ServerFlow/1.0",
                "request-parser.simple.user-agent"
            )

            try Expect.equal(
                request.body,
                "",
                "request-parser.simple.body"
            )
        }

        Step("parse request target with query string unchanged") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /search?q=dog%20training&page=2 HTTP/1.1",
                    "Host: localhost"
                ]
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.method,
                .get,
                "request-parser.query.method"
            )

            try Expect.equal(
                request.path,
                "/search?q=dog%20training&page=2",
                "request-parser.query.path"
            )
        }

        Step("parse POST request with JSON body unchanged") {
            let body = #"{"name":"Levi","count":3}"#

            let raw = httpRawMessage(
                headLines: [
                    "POST /api/items HTTP/1.1",
                    "Host: localhost",
                    "Content-Type: application/json",
                    "Content-Length: \(body.utf8.count)"
                ],
                body: body
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.method,
                .post,
                "request-parser.post.method"
            )

            try Expect.equal(
                request.path,
                "/api/items",
                "request-parser.post.path"
            )

            try Expect.equal(
                request.header("Content-Type"),
                "application/json",
                "request-parser.post.content-type"
            )

            try Expect.equal(
                request.header("Content-Length"),
                "\(body.utf8.count)",
                "request-parser.post.content-length"
            )

            try Expect.equal(
                request.body,
                body,
                "request-parser.post.body"
            )
        }

        Step("parse header value containing colon") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /callback HTTP/1.1",
                    "Host: localhost",
                    "X-Callback: https://example.test/a:b?token=c:d"
                ]
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.header("X-Callback"),
                "https://example.test/a:b?token=c:d",
                "request-parser.header-value-colon"
            )
        }

        Step("trim ordinary whitespace around header keys and values") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /trim HTTP/1.1",
                    " Host :   localhost   ",
                    " X-Trace-ID :   abc-123   "
                ]
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.header("Host"),
                "localhost",
                "request-parser.trim.host"
            )

            try Expect.equal(
                request.header("X-Trace-ID"),
                "abc-123",
                "request-parser.trim.trace-id"
            )
        }

        Step("lookup headers case-insensitively") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /headers HTTP/1.1",
                    "Host: localhost",
                    "X-Trace-ID: abc-123"
                ]
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.header("host"),
                "localhost",
                "request-parser.header-lookup.host-lowercase"
            )

            try Expect.equal(
                request.header("x-trace-id"),
                "abc-123",
                "request-parser.header-lookup.trace-lowercase"
            )

            try Expect.equal(
                request.header("X-TRACE-ID"),
                "abc-123",
                "request-parser.header-lookup.trace-uppercase"
            )
        }

        Step("extract bearer token from parsed Authorization header") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /auth HTTP/1.1",
                    "Host: localhost",
                    "Authorization: Bearer test-token-123"
                ]
            )

            let request = try HTTPRequestParser.parse(raw)

            try Expect.equal(
                request.bearerToken(),
                "test-token-123",
                "request-parser.bearer-token"
            )

            try Expect.equal(
                request.authorizationHeader(),
                "Bearer test-token-123",
                "request-parser.authorization-header"
            )
        }

        Step("decode JSON request body into Decodable payload") {
            let body = #"{"name":"Levi","count":3}"#

            let raw = httpRawMessage(
                headLines: [
                    "POST /decode HTTP/1.1",
                    "Host: localhost",
                    "Content-Type: application/json",
                    "Content-Length: \(body.utf8.count)"
                ],
                body: body
            )

            let request = try HTTPRequestParser.parse(raw)
            let payload = try request.decode(
                ParserRegressionPayload.self
            )

            try Expect.equal(
                payload,
                ParserRegressionPayload(
                    name: "Levi",
                    count: 3
                ),
                "request-parser.decode-json"
            )
        }

        Step("extract Content-Length from ordinary request headers") {
            let headerData = Data(
                httpRawMessage(
                    headLines: [
                        "POST / HTTP/1.1",
                        "Host: localhost",
                        "Content-Length: 27"
                    ]
                ).utf8
            )

            let contentLength = HTTPRequestParser.extractContentLength(
                from: headerData
            )

            try Expect.equal(
                contentLength,
                27,
                "request-parser.content-length.normal"
            )
        }

        Step("extract Content-Length case-insensitively") {
            let headerData = Data(
                httpRawMessage(
                    headLines: [
                        "POST / HTTP/1.1",
                        "Host: localhost",
                        "content-length: 12"
                    ]
                ).utf8
            )

            let contentLength = HTTPRequestParser.extractContentLength(
                from: headerData
            )

            try Expect.equal(
                contentLength,
                12,
                "request-parser.content-length.lowercase"
            )
        }

        Step("missing Content-Length returns nil") {
            let headerData = Data(
                httpRawMessage(
                    headLines: [
                        "GET / HTTP/1.1",
                        "Host: localhost"
                    ]
                ).utf8
            )

            let contentLength = HTTPRequestParser.extractContentLength(
                from: headerData
            )

            try Expect.isNil(
                contentLength,
                "request-parser.content-length.missing"
            )
        }

        Step("unknown method throws") {
            let raw = httpRawMessage(
                headLines: [
                    "BREW /coffee HTTP/1.1",
                    "Host: localhost"
                ]
            )

            try Expect.throwsError(
                "request-parser.unknown-method"
            ) {
                _ = try HTTPRequestParser.parse(raw)
            }
        }

        Step("request line without path throws") {
            let raw = httpRawMessage(
                headLines: [
                    "GET",
                    "Host: localhost"
                ]
            )

            try Expect.throwsError(
                "request-parser.missing-path"
            ) {
                _ = try HTTPRequestParser.parse(raw)
            }
        }

        Step("malformed request header throws") {
            let raw = httpRawMessage(
                headLines: [
                    "GET /bad HTTP/1.1",
                    "Host localhost"
                ]
            )

            try Expect.throwsError(
                "request-parser.malformed-header"
            ) {
                _ = try HTTPRequestParser.parse(raw)
            }
        }
    }

    static let httpResponseParserRegressionFlow = TestFlow(
        "http.response-parser.regression",
        title: "HTTPResponseParser preserves ordinary response parsing behavior",
        tags: [
            "http",
            "response",
            "parser-regression",
            "regression"
        ]
    ) {
        Step("parse simple 200 response with headers and body") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    "Content-Type: text/plain; charset=utf-8",
                    "Content-Length: 5"
                ],
                body: "hello"
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.status.code,
                200,
                "response-parser.simple.status-code"
            )

            try Expect.equal(
                response.status.reason,
                "Success",
                "response-parser.simple.status-reason"
            )

            try Expect.equal(
                response.headers["Content-Type"],
                "text/plain; charset=utf-8",
                "response-parser.simple.content-type"
            )

            try Expect.equal(
                response.headers["Content-Length"],
                "5",
                "response-parser.simple.content-length"
            )

            try Expect.equal(
                response.body,
                "hello",
                "response-parser.simple.body"
            )
        }

        Step("parse CRLF response headers without retaining carriage returns") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    "Content-Type: text/plain; charset=utf-8",
                    "X-Trace-ID: abc-123",
                    "Content-Length: 5"
                ],
                body: "hello"
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.headers["Content-Type"],
                "text/plain; charset=utf-8",
                "response-parser.crlf-headers.content-type"
            )

            try Expect.equal(
                response.headers["X-Trace-ID"],
                "abc-123",
                "response-parser.crlf-headers.trace-id"
            )

            try Expect.equal(
                response.headers["Content-Length"],
                "5",
                "response-parser.crlf-headers.content-length"
            )

            try Expect.equal(
                response.headers.keys.contains("Content-Type\r"),
                false,
                "response-parser.crlf-headers.no-carriage-return-in-key"
            )

            try Expect.equal(
                response.headers.values.contains("text/plain; charset=utf-8\r"),
                false,
                "response-parser.crlf-headers.no-carriage-return-in-value"
            )
        }

        Step("response header lookup is case-insensitive after parsing") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    "Content-Type: application/json; charset=utf-8",
                    "X-Trace-ID: abc-123",
                    "Content-Length: 2"
                ],
                body: "{}"
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.header("content-type"),
                "application/json; charset=utf-8",
                "response-parser.header-lookup.content-type-lowercase"
            )

            try Expect.equal(
                response.header("CONTENT-TYPE"),
                "application/json; charset=utf-8",
                "response-parser.header-lookup.content-type-uppercase"
            )

            try Expect.equal(
                response.header("x-trace-id"),
                "abc-123",
                "response-parser.header-lookup.trace-lowercase"
            )
        }

        Step("parse response body containing normal newlines unchanged") {
            let body = "line one\nline two\nline three"

            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    "Content-Type: text/plain; charset=utf-8",
                    "Content-Length: \(body.utf8.count)"
                ],
                body: body
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.body,
                body,
                "response-parser.body-newlines"
            )
        }

        Step("parse response body containing CRLFCRLF unchanged") {
            let body = "alpha\r\n\r\nbeta"

            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    "Content-Type: text/plain; charset=utf-8",
                    "Content-Length: \(body.utf8.count)"
                ],
                body: body
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.body,
                body,
                "response-parser.body-containing-header-separator"
            )
        }

        Step("round-trip response builder output through response parser") {
            let original = HTTPResponse.text(
                "hello",
                status: .ok,
                headers: [
                    "X-Trace-ID": "abc-123"
                ]
            )

            let wire = HTTPResponseBuilder.build(original)
            let parsed = try HTTPResponseParser.parse(wire)

            try Expect.equal(
                parsed.status.code,
                200,
                "response-parser.builder-roundtrip.status-code"
            )

            try Expect.equal(
                parsed.header("Content-Type"),
                "text/plain; charset=utf-8",
                "response-parser.builder-roundtrip.content-type"
            )

            try Expect.equal(
                parsed.header("X-Trace-ID"),
                "abc-123",
                "response-parser.builder-roundtrip.trace-id"
            )

            try Expect.equal(
                parsed.body,
                "hello\n",
                "response-parser.builder-roundtrip.body"
            )
        }

        Step("parse no-content response with empty body") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 204 No Content",
                    "Content-Length: 0"
                ]
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.status.code,
                204,
                "response-parser.no-content.status-code"
            )

            try Expect.equal(
                response.body,
                "",
                "response-parser.no-content.body"
            )
        }

        Step("parse response header value containing colon") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 302 Found",
                    "Location: https://example.test/a:b?token=c:d",
                    "Content-Length: 0"
                ]
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.status.code,
                302,
                "response-parser.header-value-colon.status-code"
            )

            try Expect.equal(
                response.headers["Location"],
                "https://example.test/a:b?token=c:d",
                "response-parser.header-value-colon.location"
            )
        }

        Step("trim ordinary whitespace around response header keys and values") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    " Content-Type :   text/plain   ",
                    " X-Trace-ID :   abc-123   "
                ],
                body: "ok"
            )

            let response = try HTTPResponseParser.parse(raw)

            try Expect.equal(
                response.headers["Content-Type"],
                "text/plain",
                "response-parser.trim.content-type"
            )

            try Expect.equal(
                response.headers["X-Trace-ID"],
                "abc-123",
                "response-parser.trim.trace-id"
            )
        }

        Step("extract Content-Length from ordinary response headers") {
            let headerData = Data(
                httpRawMessage(
                    headLines: [
                        "HTTP/1.1 200 OK",
                        "Content-Length: 5"
                    ]
                ).utf8
            )

            let contentLength = HTTPResponseParser.extractContentLength(
                from: headerData
            )

            try Expect.equal(
                contentLength,
                5,
                "response-parser.content-length.normal"
            )
        }

        Step("extract response Content-Length case-insensitively") {
            let headerData = Data(
                httpRawMessage(
                    headLines: [
                        "HTTP/1.1 200 OK",
                        "content-length: 5"
                    ]
                ).utf8
            )

            let contentLength = HTTPResponseParser.extractContentLength(
                from: headerData
            )

            try Expect.equal(
                contentLength,
                5,
                "response-parser.content-length.lowercase"
            )
        }

        Step("missing response Content-Length returns nil") {
            let headerData = Data(
                httpRawMessage(
                    headLines: [
                        "HTTP/1.1 200 OK",
                        "Content-Type: text/plain"
                    ]
                ).utf8
            )

            let contentLength = HTTPResponseParser.extractContentLength(
                from: headerData
            )

            try Expect.isNil(
                contentLength,
                "response-parser.content-length.missing"
            )
        }

        Step("invalid response status code throws") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 nope OK",
                    "Content-Length: 0"
                ]
            )

            try Expect.throwsError(
                "response-parser.invalid-status-code"
            ) {
                _ = try HTTPResponseParser.parse(raw)
            }
        }

        Step("malformed response header throws") {
            let raw = httpRawMessage(
                headLines: [
                    "HTTP/1.1 200 OK",
                    "Content-Type text/plain"
                ],
                body: "ok"
            )

            try Expect.throwsError(
                "response-parser.malformed-header"
            ) {
                _ = try HTTPResponseParser.parse(raw)
            }
        }
    }
}

private func httpRawMessage(
    headLines: [String],
    body: String = ""
) -> String {
    headLines.joined(
        separator: "\r\n"
    ) + "\r\n\r\n" + body
}

private struct ParserRegressionPayload: Decodable, Equatable {
    var name: String
    var count: Int
}
