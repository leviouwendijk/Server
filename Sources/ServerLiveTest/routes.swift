import HTTP
import Server

public func routes() throws -> [Route] {
    let cors = CORSMiddleware(
        allowedOrigin: .whitelist(
            [
                "http://127.0.0.1:49161",
                "http://localhost:49161",
                "https://example.com",
                "https://app.example.com",
                "https://api.example.com"
            ]
        ),
        allowCredentials: false,
        allowedMethods: [
            .get,
            .post,
            .options
        ],
        allowedHeaders: [
            "Content-Type",
            "Accept",
            "Authorization",
            "X-Requested-With",
            "X-Request-ID"
        ],
        exposedHeaders: [],
        maxAgeSeconds: 600
    )

    return Server.routes {
        StandardRoutes.listRoutes()

        get {
            ServerLiveTrace.route(
                "home",
                method: .get,
                path: "/"
            ) {
                Operation.Live.home()
            }
        }
        .use(cors)
        .allow(.options)

        get("health") {
            ServerLiveTrace.route(
                "health",
                method: .get,
                path: "/health"
            ) {
                try Operation.Live.health()
            }
        }
        .use(cors)
        .allow(.options)

        get("routes") {
            ServerLiveTrace.route(
                "routes",
                method: .get,
                path: "/routes"
            ) {
                try Operation.Live.routeList()
            }
        }
        .use(cors)
        .allow(.options)

        group("v1") {
            get("config") {
                ServerLiveTrace.route(
                    "config",
                    method: .get,
                    path: "/v1/config"
                ) {
                    try Operation.Live.config()
                }
            }
            .allow(.options)

            get("headers") { request in
                ServerLiveTrace.route(
                    "headers",
                    request: request
                ) {
                    try Operation.Live.headers(
                        request: request
                    )
                }
            }
            .allow(.options)

            get("token") { request in
                ServerLiveTrace.route(
                    "token.issue",
                    request: request
                ) {
                    try Operation.Live.token(
                        request: request
                    )
                }
            }
            .allow(.options)

            group("token") {
                post("validate") { request in
                    ServerLiveTrace.route(
                        "token.validate",
                        request: request,
                        failureStatus: .badRequest
                    ) {
                        let payload = try request.extract(
                            Model.Payload.TokenValidate.self
                        )

                        return try Operation.Live.validateToken(
                            payload
                        )
                    }
                }
                .allow(.options)
            }

            post("echo") { request in
                ServerLiveTrace.route(
                    "echo",
                    request: request
                ) {
                    try Operation.Live.echo(
                        request: request
                    )
                }
            }
            .allow(.options)

            group("forms") {
                post("contact") { request in
                    ServerLiveTrace.route(
                        "forms.contact",
                        request: request,
                        failureStatus: .badRequest
                    ) {
                        let payload = try request.extract(
                            Model.Payload.ContactForm.self
                        )

                        return try Operation.Live.contact(
                            payload
                        )
                    }
                }
                .allow(.options)

                post("signup") { request in
                    ServerLiveTrace.route(
                        "forms.signup",
                        request: request,
                        failureStatus: .badRequest
                    ) {
                        let payload = try request.extract(
                            Model.Payload.SignupForm.self
                        )

                        return try Operation.Live.signup(
                            payload
                        )
                    }
                }
                .allow(.options)
            }

            group("events") {
                post("collect") { request in
                    ServerLiveTrace.route(
                        "events.collect",
                        request: request,
                        failureStatus: .badRequest
                    ) {
                        let payload = try request.extract(
                            Model.Payload.CollectEnvelope.self
                        )

                        return try Operation.Live.collect(
                            payload
                        )
                    }
                }
                .allow(.options)
            }

            get("error") {
                ServerLiveTrace.route(
                    "intentional.error",
                    method: .get,
                    path: "/v1/error"
                ) {
                    try Operation.Live.intentionalError()
                }
            }
        }
        .use(cors)
    }
}
