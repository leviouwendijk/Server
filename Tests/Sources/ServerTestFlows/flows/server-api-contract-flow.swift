import Foundation
import HTTP
import Server
import TestFlows

extension ServerSecurityFlows {
    static let serverAPIContractFlow = TestFlow(
        "server.api-contract.connector-v2",
        title: "Server preserves connector-v2 style API behavior",
        tags: [
            "api-contract",
            "connector-v2",
            "server",
            "router",
            "cors",
            "bearer",
            "regression"
        ]
    ) {
        Step("public lead route decodes JSON with request.extract and returns ReturnableResponse JSON") {
            let router = contractRouter()
            let body = contractLeadJSON()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/form/lead/main",
                    headers: [
                        "Content-Type": "application/json",
                        "Accept": "application/json",
                        "Origin": "https://hondenmeesters.nl"
                    ],
                    body: body
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "api-contract.lead.status"
            )

            try Expect.equal(
                response.header("Content-Type"),
                "application/json; charset=utf-8",
                "api-contract.lead.content-type"
            )

            try Expect.equal(
                response.header("Access-Control-Allow-Origin"),
                "https://hondenmeesters.nl",
                "api-contract.lead.cors-origin"
            )

            let decoded = try decodeResponse(
                ContractLeadResponse.self,
                from: response
            )

            try Expect.equal(
                decoded.success,
                true,
                "api-contract.lead.success"
            )

            try Expect.equal(
                decoded.status,
                "ok",
                "api-contract.lead.response-status"
            )

            try Expect.equal(
                decoded.payload.form_id,
                "hero_alt_lead",
                "api-contract.lead.form-id"
            )

            try Expect.equal(
                decoded.payload.email,
                "test@example.com",
                "api-contract.lead.email"
            )

            try Expect.equal(
                decoded.payload.issues,
                [
                    "Uitvallen aan de lijn",
                    "Onrust in huis"
                ],
                "api-contract.lead.issues"
            )

            try Expect.equal(
                decoded.payload.session?.page_path,
                "/",
                "api-contract.lead.session-page-path"
            )
        }

        Step("public lead route preserves normal JSON newlines and UTF-8 text in extracted payload") {
            let router = contractRouter()
            let body = contractLeadJSON(
                issue: "Regel één\nRegel twee met café en hond"
            )

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/form/lead/main",
                    headers: [
                        "Content-Type": "application/json",
                        "Origin": "https://test.hondenmeesters.nl"
                    ],
                    body: body
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "api-contract.lead-utf8.status"
            )

            let decoded = try decodeResponse(
                ContractLeadResponse.self,
                from: response
            )

            try Expect.equal(
                decoded.payload.issue,
                "Regel één\nRegel twee met café en hond",
                "api-contract.lead-utf8.issue"
            )
        }

        Step("public lead route returns bad request for invalid JSON") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/form/lead/main",
                    headers: [
                        "Content-Type": "application/json",
                        "Origin": "https://hondenmeesters.nl"
                    ],
                    body: #"{"form_id":"broken""#
                )
            )

            try Expect.equal(
                response.status.code,
                400,
                "api-contract.lead-invalid-json.status"
            )

            try Expect.contains(
                response.body,
                "invalid_request",
                "api-contract.lead-invalid-json.body"
            )
        }

        Step("public support route decodes connector-shaped support payload") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/form/support",
                    headers: [
                        "Content-Type": "application/json",
                        "Origin": "https://docs.hondenmeesters.nl"
                    ],
                    body: contractSupportJSON()
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "api-contract.support.status"
            )

            try Expect.equal(
                response.header("Access-Control-Allow-Origin"),
                "https://docs.hondenmeesters.nl",
                "api-contract.support.cors-origin"
            )

            let decoded = try decodeResponse(
                ContractSupportResponse.self,
                from: response
            )

            try Expect.equal(
                decoded.success,
                true,
                "api-contract.support.success"
            )

            try Expect.equal(
                decoded.status,
                "ok",
                "api-contract.support.response-status"
            )

            try Expect.equal(
                decoded.category,
                "technical",
                "api-contract.support.category"
            )

            try Expect.equal(
                decoded.intent,
                "report",
                "api-contract.support.intent"
            )

            try Expect.equal(
                decoded.contact_email,
                "support@example.com",
                "api-contract.support.email"
            )
        }

        Step("public form route handles connector-style CORS preflight") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .options,
                    path: "/form/lead/main",
                    headers: [
                        "Origin": "https://hondenmeesters.nl",
                        "Access-Control-Request-Method": "POST",
                        "Access-Control-Request-Headers": "Content-Type, Accept, X-Requested-With"
                    ]
                )
            )

            try Expect.equal(
                response.status.code,
                204,
                "api-contract.cors-preflight.status"
            )

            try Expect.equal(
                response.header("Access-Control-Allow-Origin"),
                "https://hondenmeesters.nl",
                "api-contract.cors-preflight.allow-origin"
            )

            try Expect.contains(
                response.header("Access-Control-Allow-Methods") ?? "",
                "POST",
                "api-contract.cors-preflight.allow-methods-post"
            )

            try Expect.contains(
                response.header("Access-Control-Allow-Methods") ?? "",
                "OPTIONS",
                "api-contract.cors-preflight.allow-methods-options"
            )

            try Expect.contains(
                response.header("Access-Control-Allow-Headers") ?? "",
                "Content-Type",
                "api-contract.cors-preflight.allow-headers-content-type"
            )

            try Expect.contains(
                response.header("Access-Control-Allow-Headers") ?? "",
                "X-Requested-With",
                "api-contract.cors-preflight.allow-headers-requested-with"
            )
        }

        Step("public form route does not require bearer token") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/form/support",
                    headers: [
                        "Content-Type": "application/json",
                        "Origin": "https://hondenmeesters.nl"
                    ],
                    body: contractSupportJSON()
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "api-contract.public-form-without-bearer.status"
            )
        }

        Step("protected test route rejects missing bearer token") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/tests/lead/preflight",
                    headers: [
                        "Content-Type": "application/json"
                    ],
                    body: contractLeadJSON()
                )
            )

            try Expect.equal(
                response.status.code,
                401,
                "api-contract.protected.missing-bearer.status"
            )

            try Expect.contains(
                response.body,
                "Authorization",
                "api-contract.protected.missing-bearer.body"
            )
        }

        Step("protected test route rejects invalid bearer token") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/tests/lead/preflight",
                    headers: [
                        "Content-Type": "application/json",
                        "Authorization": "Bearer wrong-token"
                    ],
                    body: contractLeadJSON()
                )
            )

            try Expect.equal(
                response.status.code,
                401,
                "api-contract.protected.invalid-bearer.status"
            )

            try Expect.contains(
                response.body,
                "Invalid API token",
                "api-contract.protected.invalid-bearer.body"
            )
        }

        Step("protected test route accepts valid bearer token and still extracts JSON body") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .post,
                    path: "/tests/lead/preflight",
                    headers: [
                        "Content-Type": "application/json",
                        "Authorization": "Bearer \(contractBearerToken)"
                    ],
                    body: contractLeadJSON()
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "api-contract.protected.valid-bearer.status"
            )

            let decoded = try decodeResponse(
                ContractLeadPreflightResponse.self,
                from: response
            )

            try Expect.equal(
                decoded.success,
                true,
                "api-contract.protected.valid-bearer.success"
            )

            try Expect.equal(
                decoded.status,
                "preflight_ok",
                "api-contract.protected.valid-bearer.response-status"
            )

            try Expect.equal(
                decoded.payload.form_id,
                "hero_alt_lead",
                "api-contract.protected.valid-bearer.form-id"
            )
        }

        Step("protected standard routes listing remains bearer protected and lists mounted paths") {
            let router = contractRouter()

            let response = await router.route(
                contractRequest(
                    method: .get,
                    path: "/routes",
                    headers: [
                        "Authorization": "Bearer \(contractBearerToken)"
                    ]
                )
            )

            try Expect.equal(
                response.status.code,
                200,
                "api-contract.routes-list.status"
            )

            let decoded = try decodeResponse(
                ContractRoutesResponse.self,
                from: response
            )

            try Expect.equal(
                decoded.count,
                4,
                "api-contract.routes-list.count"
            )

            try Expect.equal(
                decoded.routes.contains {
                    $0.method == "GET" && $0.path == "/routes"
                },
                true,
                "api-contract.routes-list.routes-path"
            )

            try Expect.equal(
                decoded.routes.contains {
                    $0.method == "POST" && $0.path == "/form/lead/main"
                },
                true,
                "api-contract.routes-list.lead-path"
            )

            try Expect.equal(
                decoded.routes.contains {
                    $0.method == "POST" && $0.path == "/form/support"
                },
                true,
                "api-contract.routes-list.support-path"
            )

            try Expect.equal(
                decoded.routes.contains {
                    $0.method == "POST" && $0.path == "/tests/lead/preflight"
                },
                true,
                "api-contract.routes-list.preflight-path"
            )
        }

        Step("router still distinguishes 404 from 405 for connector-shaped routes") {
            let router = contractRouter()

            let methodNotAllowed = await router.route(
                contractRequest(
                    method: .get,
                    path: "/form/lead/main"
                )
            )

            try Expect.equal(
                methodNotAllowed.status.code,
                405,
                "api-contract.router.method-not-allowed"
            )

            let notFound = await router.route(
                contractRequest(
                    method: .post,
                    path: "/form/unknown"
                )
            )

            try Expect.equal(
                notFound.status.code,
                404,
                "api-contract.router.not-found"
            )
        }
    }
}

private let contractBearerToken = "connector-contract-token"

private func contractRouter() -> Router {
    let bearer = BearerMiddleware(
        rawKey: contractBearerToken
    )

    let limiter = GlobalRateLimitMiddleware(
        maxRequests: 10_000,
        windowSeconds: 15
    )

    let cors = CORSMiddleware(
        allowedOrigin: .whitelist(
            [
                "https://hondenmeesters.nl",
                "https://test.hondenmeesters.nl",
                "https://docs.hondenmeesters.nl",
                "https://hondenmeesters.lan",
                "https://test.hondenmeesters.lan",
                "https://docs.hondenmeesters.lan"
            ]
        ),
        allowCredentials: false,
        allowedMethods: [
            .post,
            .options
        ],
        allowedHeaders: [
            "Content-Type",
            "Accept",
            "X-Requested-With"
        ],
        exposedHeaders: [],
        maxAgeSeconds: 600
    )

    return Router(
        routes: routes {
            StandardRoutes.listRoutes()
                .use(bearer)

            post("form", "lead", "main") { request in
                do {
                    let payload = try request.extract(
                        ContractLeadPayload.self
                    )

                    return try ContractLeadResponse(
                        success: true,
                        status: "ok",
                        payload: payload
                    ).response(status: .ok)
                } catch {
                    return .badRequest(
                        body: #"{"success":false,"status":"invalid_request","message":"Invalid request"}"#
                    )
                }
            }
            .allow(.options)
            .use(cors, limiter)

            post("form", "support") { request in
                do {
                    let payload = try request.extract(
                        ContractSupportPayload.self
                    )

                    return try ContractSupportResponse(
                        success: true,
                        status: "ok",
                        category: payload.category,
                        intent: payload.intent,
                        contact_email: payload.contact?.email
                    ).response(status: .ok)
                } catch {
                    return .badRequest(
                        body: #"{"success":false,"status":"invalid_request","message":"Invalid support request"}"#
                    )
                }
            }
            .allow(.options)
            .use(cors, limiter)

            post("tests", "lead", "preflight") { request in
                do {
                    let payload = try request.extract(
                        ContractLeadPayload.self
                    )

                    return try ContractLeadPreflightResponse(
                        success: true,
                        status: "preflight_ok",
                        payload: .init(
                            form_id: payload.form_id,
                            page_url: payload.session?.page_url,
                            page_title: payload.session?.page_title
                        )
                    ).response(status: .ok)
                } catch {
                    return .badRequest(
                        body: #"{"success":false,"status":"invalid_request","message":"Invalid test request"}"#
                    )
                }
            }
            .use(bearer, limiter)
        }
    )
}

private func contractRequest(
    method: HTTPMethod,
    path: String,
    headers: [String: String] = [:],
    body: String = ""
) -> HTTPRequest {
    HTTPRequest(
        method: method,
        path: path,
        headers: headers,
        body: body
    )
}

private func decodeResponse<T: Decodable>(
    _ type: T.Type,
    from response: HTTPResponse
) throws -> T {
    let data = Data(
        response.body.utf8
    )

    return try JSONDecoder().decode(
        T.self,
        from: data
    )
}

private func contractLeadJSON(
    issue: String = "Uitvallen aan de lijn"
) -> String {
    """
    {
      "schema_version": 1,
      "form_id": "hero_alt_lead",
      "full_name": "Test Persoon",
      "dog_name": "Bobby",
      "dog_breed": "Labrador",
      "issue": "\(jsonEscaped(issue))",
      "issues": [
        "Uitvallen aan de lijn",
        "Onrust in huis"
      ],
      "email": "test@example.com",
      "phone": "0612345678",
      "name": "Test",
      "middle_names": null,
      "infix": null,
      "last_name": "Persoon",
      "postcode": "1811AA",
      "huisnummer": "1",
      "straatnaam": "Teststraat",
      "place": "Alkmaar",
      "consent": "on",
      "my_custom_field": "",
      "captcha": {
        "token": "connector-test-fixture-token",
        "securityToken": null,
        "timeSpent": 20,
        "mouseMovements": 15,
        "scrollEvents": 3,
        "keypresses": 8,
        "focusEvents": 2,
        "visibilityStayed": true,
        "pointerTypes": [
          "mouse"
        ],
        "maxScrollDepthPct": 60,
        "firstInteractionAt": 1200,
        "prefersReducedMotion": false
      },
      "agreement": {
        "terms_and_conditions": {
          "accepted": true,
          "version": null,
          "version_date": null
        },
        "privacy_policy": {
          "accepted": true,
          "version": null,
          "version_date": null
        }
      },
      "session": {
        "page_url": "https://hondenmeesters.nl/",
        "page_path": "/",
        "page_title": "Hondentrainers in Alkmaar - Hondenmeesters",
        "page_id": "index",
        "referrer": null,
        "source": "connector_contract",
        "form_id": "hero_alt_lead",
        "form_dom_id": "hero-alt-form",
        "form_name": null,
        "form_selector": "#hero-alt-form",
        "form_location": "hero_alt",
        "form_nearest_location": "#hero-alt-form"
      }
    }
    """
}

private func contractSupportJSON() -> String {
    """
    {
      "schema_version": 1,
      "form_id": "support_v2",
      "category": "technical",
      "intent": "report",
      "message": "Ik krijg een foutmelding bij het formulier.\\nTweede regel.",
      "details": "Browser: Safari",
      "contact": {
        "name": "Support Persoon",
        "email": "support@example.com",
        "phone": "0612345678",
        "contact_ok": true
      },
      "dog": {
        "name": "Moos"
      },
      "emotion": {
        "feelings": [
          "frustrated",
          "confused"
        ],
        "intensity": 3
      },
      "session": {
        "page_url": "https://hondenmeesters.nl/support",
        "page_path": "/support",
        "page_title": "Support",
        "referrer": "https://hondenmeesters.nl/",
        "user_agent": "ContractFlow/1.0",
        "language": "nl-NL"
      },
      "validation": {
        "consent": true,
        "my_custom_field": "",
        "captcha": {
          "token": "connector-test-fixture-token",
          "securityToken": null,
          "timeSpent": 20,
          "mouseMovements": 15,
          "scrollEvents": 3,
          "keypresses": 8,
          "focusEvents": 2,
          "visibilityStayed": true,
          "pointerTypes": [
            "mouse"
          ],
          "maxScrollDepthPct": 60,
          "firstInteractionAt": 1200,
          "prefersReducedMotion": false
        }
      }
    }
    """
}

private func jsonEscaped(
    _ value: String
) -> String {
    value
        .replacingOccurrences(
            of: "\\",
            with: "\\\\"
        )
        .replacingOccurrences(
            of: "\"",
            with: "\\\""
        )
        .replacingOccurrences(
            of: "\n",
            with: "\\n"
        )
        .replacingOccurrences(
            of: "\r",
            with: "\\r"
        )
}

private struct ContractLeadPayload: Codable, Sendable, Equatable {
    var schema_version: Int?
    var form_id: String?

    var full_name: String?
    var dog_name: String?
    var dog_breed: String?

    var issue: String?
    var issues: [String]?

    var email: String?
    var phone: String?

    var name: String?
    var middle_names: [String]?
    var infix: String?
    var last_name: String?

    var postcode: String?
    var huisnummer: String?
    var straatnaam: String?
    var place: String?

    var consent: String?
    var my_custom_field: String?

    var captcha: ContractCaptchaPayload?
    var agreement: ContractAgreementPayload?
    var session: ContractLeadSessionPayload?
}

private struct ContractCaptchaPayload: Codable, Sendable, Equatable {
    var token: String?
    var securityToken: String?

    var timeSpent: Int?
    var mouseMovements: Int?
    var scrollEvents: Int?
    var keypresses: Int?
    var focusEvents: Int?
    var visibilityStayed: Bool?
    var pointerTypes: [String]?
    var maxScrollDepthPct: Int?
    var firstInteractionAt: Int?
    var prefersReducedMotion: Bool?
}

private struct ContractAgreementPayload: Codable, Sendable, Equatable {
    var terms_and_conditions: ContractAgreementEntryPayload?
    var privacy_policy: ContractAgreementEntryPayload?
}

private struct ContractAgreementEntryPayload: Codable, Sendable, Equatable {
    var accepted: Bool?
    var version: ContractAgreementVersionPayload?
    var version_date: String?
}

private struct ContractAgreementVersionPayload: Codable, Sendable, Equatable {
    var major: Int?
    var minor: Int?
    var patch: Int?
}

private struct ContractLeadSessionPayload: Codable, Sendable, Equatable {
    var page_url: String?
    var page_path: String?
    var page_title: String?
    var page_id: String?
    var referrer: String?
    var source: String?

    var form_id: String?
    var form_dom_id: String?
    var form_name: String?
    var form_selector: String?
    var form_location: String?
    var form_nearest_location: String?
}

private struct ContractSupportPayload: Codable, Sendable, Equatable {
    var schema_version: Int?
    var form_id: String?

    var category: String?
    var intent: String?
    var message: String?
    var details: String?

    var contact: ContractSupportContactPayload?
    var dog: ContractSupportDogPayload?
    var emotion: ContractSupportEmotionPayload?
    var session: ContractSupportSessionPayload?
    var validation: ContractSupportValidationPayload?
}

private struct ContractSupportContactPayload: Codable, Sendable, Equatable {
    var name: String?
    var email: String?
    var phone: String?
    var contact_ok: Bool?
}

private struct ContractSupportDogPayload: Codable, Sendable, Equatable {
    var name: String?
}

private struct ContractSupportEmotionPayload: Codable, Sendable, Equatable {
    var feelings: [String]?
    var intensity: Int?
}

private struct ContractSupportSessionPayload: Codable, Sendable, Equatable {
    var page_url: String?
    var page_path: String?
    var page_title: String?
    var referrer: String?
    var user_agent: String?
    var language: String?
}

private struct ContractSupportValidationPayload: Codable, Sendable, Equatable {
    var consent: Bool?
    var my_custom_field: String?
    var captcha: ContractCaptchaPayload?
}

private struct ContractLeadResponse: ReturnableResponse, Equatable {
    var success: Bool
    var status: String
    var payload: ContractLeadPayload
}

private struct ContractSupportResponse: ReturnableResponse, Equatable {
    var success: Bool
    var status: String
    var category: String?
    var intent: String?
    var contact_email: String?
}

private struct ContractLeadPreflightResponse: ReturnableResponse, Equatable {
    var success: Bool
    var status: String
    var payload: ContractLeadPreflightPayload
}

private struct ContractLeadPreflightPayload: Codable, Sendable, Equatable {
    var form_id: String?
    var page_url: String?
    var page_title: String?
}

private struct ContractRoutesResponse: Codable, Sendable, Equatable {
    var count: Int
    var routes: [ContractRouteEntry]
}

private struct ContractRouteEntry: Codable, Sendable, Equatable {
    var method: String
    var path: String
}
