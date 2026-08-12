import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverJSONCodingFlow = TestFlow(
        "server.json-coding.router",
        title: "Server JSON coding policy remains explicit, scoped, and overridable",
        tags: [
            "server",
            "router",
            "json",
            "casing",
            "task-local",
            "regression",
        ]
    ) {
        Step("default router preserves Foundation behavior and CodingKeys") {
            let router = Router(
                routes: [
                    jsonCodingKeyedRoute(
                        "default"
                    ),
                ]
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/default",
                    body: """
                    {
                        "wire_request_id": "default-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.default"
            )

            try Expect.contains(
                response.body,
                "\"wire_response_id\"",
                "json-coding.default.coding-key"
            )

            try Expect.doesNotContain(
                response.body,
                "\"responseId\"",
                "json-coding.default.no-implicit-transform"
            )
        }

        Step("global policy decodes snake case and encodes snake case") {
            let router = Router(
                routes: [
                    jsonCodingCamelEchoRoute(
                        "global"
                    ),
                ],
                json: .init(
                    decodeTo: .camel,
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/global",
                    body: """
                    {
                        "request_id": "global-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.global"
            )

            try Expect.contains(
                response.body,
                "\"request_id\"",
                "json-coding.global.request-id"
            )

            try Expect.contains(
                response.body,
                "\"response_value\"",
                "json-coding.global.response-value"
            )

            try Expect.contains(
                response.body,
                "global-request",
                "json-coding.global.value"
            )

            try Expect.doesNotContain(
                response.body,
                "\"requestId\"",
                "json-coding.global.no-camel-output"
            )
        }

        Step("decode-only policy leaves response encoding untouched") {
            let router = Router(
                routes: [
                    jsonCodingCamelEchoRoute(
                        "decode-only"
                    ),
                ],
                json: .init(
                    decodeTo: .camel
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/decode-only",
                    body: """
                    {
                        "request_id": "decode-only-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.decode-only"
            )

            try Expect.contains(
                response.body,
                "\"requestId\"",
                "json-coding.decode-only.request-id"
            )

            try Expect.contains(
                response.body,
                "\"responseValue\"",
                "json-coding.decode-only.response-value"
            )

            try Expect.doesNotContain(
                response.body,
                "\"response_value\"",
                "json-coding.decode-only.no-output-transform"
            )
        }

        Step("encode-only policy leaves request decoding untouched") {
            let router = Router(
                routes: [
                    jsonCodingCamelEchoRoute(
                        "encode-only"
                    ),
                ],
                json: .init(
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/encode-only",
                    body: """
                    {
                        "requestId": "encode-only-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.encode-only"
            )

            try Expect.contains(
                response.body,
                "\"request_id\"",
                "json-coding.encode-only.request-id"
            )

            try Expect.contains(
                response.body,
                "\"response_value\"",
                "json-coding.encode-only.response-value"
            )
        }

        Step("route passthrough overrides inherited global policy") {
            let router = Router(
                routes: [
                    jsonCodingLegacyEchoRoute(
                        "passthrough"
                    )
                    .json(.passthrough),
                ],
                json: .init(
                    decodeTo: .camel,
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/passthrough",
                    body: """
                    {
                        "request_id": "legacy-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.passthrough"
            )

            try Expect.contains(
                response.body,
                "\"response_id\"",
                "json-coding.passthrough.response-id"
            )

            try Expect.contains(
                response.body,
                "legacy-request",
                "json-coding.passthrough.value"
            )
        }

        Step("route policy can replace inherited output convention") {
            let router = Router(
                routes: [
                    jsonCodingCamelEchoRoute(
                        "route-override"
                    )
                    .json(
                        decodeTo: .camel,
                        encodeAs: .kebab
                    ),
                ],
                json: .init(
                    decodeTo: .camel,
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/route-override",
                    body: """
                    {
                        "request_id": "override-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.route-override"
            )

            try Expect.contains(
                response.body,
                "\"request-id\"",
                "json-coding.route-override.request-id"
            )

            try Expect.contains(
                response.body,
                "\"response-value\"",
                "json-coding.route-override.response-value"
            )

            try Expect.doesNotContain(
                response.body,
                "\"response_value\"",
                "json-coding.route-override.no-global-output"
            )
        }

        Step("explicit decoder and encoder override ambient policy") {
            let router = Router(
                routes: [
                    jsonCodingExplicitRoute(
                        "explicit"
                    ),
                ],
                json: .init(
                    decodeTo: .camel,
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/explicit",
                    body: """
                    {
                        "request_id": "explicit-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.explicit"
            )

            try Expect.contains(
                response.body,
                "\"requestId\"",
                "json-coding.explicit.encoder"
            )

            try Expect.doesNotContain(
                response.body,
                "\"request_id\"",
                "json-coding.explicit.no-ambient-encoder"
            )
        }

        Step("middleware executes inside the effective JSON coding scope") {
            let router = Router(
                routes: [
                    post(
                        "json-coding",
                        "middleware"
                    ) { _ in
                        do {
                            return try JSONCodingCamelResponse(
                                requestId: "middleware-request",
                                responseValue: "middleware-ok"
                            ).response()
                        } catch {
                            return jsonCodingFailure(
                                error
                            )
                        }
                    }
                    .use(
                        JSONCodingFixtureMiddleware()
                    ),
                ],
                json: .init(
                    decodeTo: .camel,
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/middleware",
                    body: """
                    {
                        "request_id": "middleware-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.middleware"
            )

            try Expect.contains(
                response.body,
                "\"response_value\"",
                "json-coding.middleware.output"
            )
        }

        Step("nested tasks inherit the effective JSON coding scope") {
            let router = Router(
                routes: [
                    jsonCodingNestedTaskRoute(
                        "nested-task"
                    ),
                ],
                json: .init(
                    decodeTo: .camel,
                    encodeAs: .snake
                )
            )

            let response = await router.route(
                jsonCodingRequest(
                    path: "/json-coding/nested-task",
                    body: """
                    {
                        "request_id": "nested-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.nested-task"
            )

            try Expect.contains(
                response.body,
                "\"request_id\"",
                "json-coding.nested-task.output"
            )

            try Expect.contains(
                response.body,
                "nested-request",
                "json-coding.nested-task.value"
            )
        }

        Step("ServerProcess carries ServerConfig JSON policy into Router") {
            let process = ServerProcess(
                config: ServerConfig(
                    json: .init(
                        decodeTo: .camel,
                        encodeAs: .snake
                    )
                ),
                routes: [
                    jsonCodingCamelEchoRoute(
                        "server-process"
                    ),
                ]
            )

            let response = await process.router.route(
                jsonCodingRequest(
                    path: "/json-coding/server-process",
                    body: """
                    {
                        "request_id": "process-request"
                    }
                    """
                )
            )

            try expectJSONCodingOK(
                response,
                "json-coding.server-process"
            )

            try Expect.contains(
                response.body,
                "\"request_id\"",
                "json-coding.server-process.request-id"
            )

            try Expect.contains(
                response.body,
                "\"response_value\"",
                "json-coding.server-process.response-value"
            )
        }
    }
}

private func jsonCodingCamelEchoRoute(
    _ leaf: String
) -> Route {
    post(
        "json-coding",
        leaf
    ) { request in
        do {
            let payload = try request.extract(
                JSONCodingCamelPayload.self
            )

            return try JSONCodingCamelResponse(
                requestId: payload.requestId,
                responseValue: "ok"
            ).response()
        } catch {
            return jsonCodingFailure(
                error
            )
        }
    }
}

private func jsonCodingLegacyEchoRoute(
    _ leaf: String
) -> Route {
    post(
        "json-coding",
        leaf
    ) { request in
        do {
            let payload = try request.extract(
                JSONCodingLegacyPayload.self
            )

            return try JSONCodingLegacyResponse(
                response_id: payload.request_id
            ).response()
        } catch {
            return jsonCodingFailure(
                error
            )
        }
    }
}

private func jsonCodingKeyedRoute(
    _ leaf: String
) -> Route {
    post(
        "json-coding",
        leaf
    ) { request in
        do {
            let payload = try request.extract(
                JSONCodingKeyedPayload.self
            )

            return try JSONCodingKeyedResponse(
                responseId: payload.requestId
            ).response()
        } catch {
            return jsonCodingFailure(
                error
            )
        }
    }
}

private func jsonCodingExplicitRoute(
    _ leaf: String
) -> Route {
    post(
        "json-coding",
        leaf
    ) { request in
        do {
            let decoder = JSONDecoder()

            let payload = try request.extract(
                JSONCodingLegacyPayload.self,
                using: decoder
            )

            let encoder = JSONEncoder()

            return try JSONCodingCamelResponse(
                requestId: payload.request_id,
                responseValue: "explicit"
            ).response(
                using: encoder
            )
        } catch {
            return jsonCodingFailure(
                error
            )
        }
    }
}

private func jsonCodingNestedTaskRoute(
    _ leaf: String
) -> Route {
    post(
        "json-coding",
        leaf
    ) { request in
        do {
            let payload = try await Task {
                try request.extract(
                    JSONCodingCamelPayload.self
                )
            }.value

            return try JSONCodingCamelResponse(
                requestId: payload.requestId,
                responseValue: "nested"
            ).response()
        } catch {
            return jsonCodingFailure(
                error
            )
        }
    }
}

private func jsonCodingRequest(
    path: String,
    body: String
) -> HTTPRequest {
    HTTPRequest(
        method: .post,
        path: path,
        headers: [
            "Content-Type": "application/json",
        ],
        body: body
    )
}

private func expectJSONCodingOK(
    _ response: HTTPResponse,
    _ label: String
) throws {
    try Expect.equal(
        response.status.code,
        200,
        "\(label).status"
    )

    try Expect.equal(
        response.header(
            "Content-Type"
        ),
        "application/json; charset=utf-8",
        "\(label).content-type"
    )
}

private func jsonCodingFailure(
    _ error: Error
) -> HTTPResponse {
    .badRequest(
        body: "JSON coding fixture failed: \(error)"
    )
}

private struct JSONCodingFixtureMiddleware: Middleware {
    let name = "json-coding-fixture"

    func handle(
        _ request: HTTPRequest,
        _ router: Router,
        next: @Sendable (HTTPRequest, Router) async -> HTTPResponse
    ) async -> HTTPResponse {
        do {
            let payload = try request.extract(
                JSONCodingCamelPayload.self
            )

            guard payload.requestId == "middleware-request" else {
                return .badRequest(
                    body: "Unexpected middleware fixture value"
                )
            }

            return await next(
                request,
                router
            )
        } catch {
            return jsonCodingFailure(
                error
            )
        }
    }
}

private struct JSONCodingCamelPayload:
    Codable,
    Sendable
{
    let requestId: String
}

private struct JSONCodingCamelResponse:
    ReturnableResponse
{
    let requestId: String
    let responseValue: String
}

private struct JSONCodingLegacyPayload:
    Codable,
    Sendable
{
    let request_id: String
}

private struct JSONCodingLegacyResponse:
    ReturnableResponse
{
    let response_id: String
}

private struct JSONCodingKeyedPayload:
    Codable,
    Sendable
{
    let requestId: String

    enum CodingKeys:
        String,
        CodingKey
    {
        case requestId = "wire_request_id"
    }
}

private struct JSONCodingKeyedResponse:
    ReturnableResponse
{
    let responseId: String

    enum CodingKeys:
        String,
        CodingKey
    {
        case responseId = "wire_response_id"
    }
}
