import Foundation
import Server

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum ServerLiveClient {
    static func run(
        config: ServerConfig,
        baseURL: URL
    ) async -> Bool {
        print("ServerLive Checks")
        print("=================")
        print("")
        print("base: \(baseURL.absoluteString)")
        print("")

        let cases = makeCases(
            baseURL: baseURL
        )

        var passed = 0
        var failed = 0

        for liveCase in cases {
            do {
                let result = try await request(
                    liveCase
                )

                guard liveCase.expect(result) else {
                    failed += 1
                    print("fail  \(liveCase.name)  \(result.status)")
                    print("      \(result.body.prefix(300))")
                    continue
                }

                passed += 1
                print("pass  \(liveCase.name)  \(result.status)")
            } catch {
                failed += 1
                print("fail  \(liveCase.name)")
                print("      \(error.localizedDescription)")
            }
        }

        print("")
        print("=================")

        if failed == 0 {
            print("pass \(passed)/\(cases.count) ok, \(passed) passed")
        } else {
            print("fail \(failed)/\(cases.count) failed, \(passed) passed")
        }

        return failed == 0
    }

    private static func makeCases(
        baseURL: URL
    ) -> [ServerLiveCase] {
        [
            ServerLiveCase(
                name: "servlive.root",
                method: "GET",
                url: url(
                    baseURL,
                    []
                )
            ) {
                $0.status == 200
                    && $0.body.contains("servlive mock API")
            },

            ServerLiveCase(
                name: "servlive.health",
                method: "GET",
                url: url(
                    baseURL,
                    [
                        "health"
                    ]
                )
            ) {
                $0.status == 200
                    && $0.body.contains(#""status""#)
                    && $0.body.contains("ok")
            },

            ServerLiveCase(
                name: "servlive.routes",
                method: "GET",
                url: url(
                    baseURL,
                    [
                        "routes"
                    ]
                )
            ) {
                $0.status == 200
                    && $0.body.contains(#""method" : "POST""#)
                    && $0.body.contains(#""path" : "\/v1\/forms\/contact""#)
                    && $0.body.contains(#""path" : "\/v1\/events\/collect""#)
            },

            ServerLiveCase(
                name: "servlive.config",
                method: "GET",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "config"
                    ]
                )
            ) {
                $0.status == 200
                    && $0.body.contains(#""features""#)
                    && $0.body.contains("forms")
            },

            ServerLiveCase(
                name: "servlive.headers",
                method: "GET",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "headers"
                    ]
                ),
                headers: [
                    "X-Request-ID": "servlive-header-check",
                    "Origin": "https://app.example.com"
                ]
            ) {
                $0.status == 200
                    && $0.body.contains("servlive-header-check")
            },

            ServerLiveCase(
                name: "servlive.token.issue",
                method: "GET",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "token"
                    ]
                ),
                headers: [
                    "Origin": "https://app.example.com",
                    "X-Request-ID": "servlive-token-check"
                ]
            ) {
                $0.status == 200
                    && $0.body.contains("servlive-token")
            },

            ServerLiveCase(
                name: "servlive.token.validate",
                method: "POST",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "token",
                        "validate"
                    ]
                ),
                headers: [
                    "Content-Type": "application/json",
                    "Origin": "https://app.example.com"
                ],
                body:
                """
                {
                    "token": "servlive-token-manual"
                }
                """
            ) {
                $0.status == 200
                    && $0.body.contains(#""valid""#)
                    && $0.body.contains("true")
            },

            ServerLiveCase(
                name: "servlive.echo",
                method: "POST",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "echo"
                    ]
                ),
                headers: [
                    "Content-Type": "text/plain"
                ],
                body: "hello live server"
            ) {
                $0.status == 200
                    && $0.body.contains("hello live server")
            },

            ServerLiveCase(
                name: "servlive.forms.contact",
                method: "POST",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "forms",
                        "contact"
                    ]
                ),
                headers: [
                    "Content-Type": "application/json",
                    "Origin": "https://app.example.com",
                    "X-Request-ID": "servlive-contact-check"
                ],
                body:
                """
                {
                    "name": "Example User",
                    "email": "user@example.com",
                    "message": "live process check",
                    "website": ""
                }
                """
            ) {
                $0.status == 200
                    && $0.body.contains(#""status""#)
                    && $0.body.contains("ok")
            },

            ServerLiveCase(
                name: "servlive.forms.signup",
                method: "POST",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "forms",
                        "signup"
                    ]
                ),
                headers: [
                    "Content-Type": "application/json",
                    "Origin": "https://app.example.com"
                ],
                body:
                """
                {
                    "email": "user@example.com",
                    "plan": "demo",
                    "referral": "live-test"
                }
                """
            ) {
                $0.status == 200
                    && $0.body.contains(#""status""#)
                    && $0.body.contains("ok")
            },

            ServerLiveCase(
                name: "servlive.events.collect.empty",
                method: "POST",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "events",
                        "collect"
                    ]
                ),
                headers: [
                    "Content-Type": "application/json",
                    "Origin": "https://app.example.com"
                ],
                body:
                """
                {
                    "source": "servlive.test",
                    "session_id": "servlive-empty",
                    "events": []
                }
                """
            ) {
                $0.status == 200
                    && $0.body.contains(#""accepted""#)
                    && $0.body.contains("0")
            },

            ServerLiveCase(
                name: "servlive.events.collect.pageview",
                method: "POST",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "events",
                        "collect"
                    ]
                ),
                headers: [
                    "Content-Type": "application/json",
                    "Origin": "https://app.example.com"
                ],
                body:
                """
                {
                    "source": "servlive.test",
                    "session_id": "servlive-pageview",
                    "events": [
                        {
                            "type": "pageview",
                            "path": "/demo",
                            "value": "loaded",
                            "timestamp": 1714916400000
                        }
                    ]
                }
                """
            ) {
                $0.status == 200
                    && $0.body.contains(#""accepted""#)
                    && $0.body.contains("1")
            },

            ServerLiveCase(
                name: "servlive.intentional.error",
                method: "GET",
                url: url(
                    baseURL,
                    [
                        "v1",
                        "error"
                    ]
                )
            ) {
                $0.status == 500
                    && $0.body.contains("intentional_error")
            }
        ]
    }

    private static func request(
        _ liveCase: ServerLiveCase
    ) async throws -> ServerLiveResult {
        var request = URLRequest(
            url: liveCase.url
        )

        request.httpMethod = liveCase.method
        request.timeoutInterval = 4

        for header in liveCase.headers {
            request.setValue(
                header.value,
                forHTTPHeaderField: header.key
            )
        }

        if let body = liveCase.body {
            request.httpBody = body.data(
                using: .utf8
            )
        }

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let http = response as? HTTPURLResponse else {
            throw ServerLiveClientError.nonHTTPResponse
        }

        return ServerLiveResult(
            status: http.statusCode,
            body: String(
                data: data,
                encoding: .utf8
            ) ?? ""
        )
    }

    private static func url(
        _ baseURL: URL,
        _ components: [String]
    ) -> URL {
        var result = baseURL

        for component in components {
            result.appendPathComponent(
                component
            )
        }

        return result
    }
}

struct ServerLiveCase: Sendable {
    let name: String
    let method: String
    let url: URL
    let headers: [String: String]
    let body: String?
    let expect: @Sendable (ServerLiveResult) -> Bool

    init(
        name: String,
        method: String,
        url: URL,
        headers: [String: String] = [:],
        body: String? = nil,
        expect: @escaping @Sendable (ServerLiveResult) -> Bool
    ) {
        self.name = name
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.expect = expect
    }
}

struct ServerLiveResult: Sendable {
    let status: Int
    let body: String
}

enum ServerLiveClientError: Error, LocalizedError {
    case nonHTTPResponse

    var errorDescription: String? {
        switch self {
        case .nonHTTPResponse:
            return "Response was not an HTTP response."
        }
    }
}
