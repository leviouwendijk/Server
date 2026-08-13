import HTTP

enum RouteErrorBoundary {
    enum Scope: String, Sendable {
        case typed = "typed_route"
        case raw = "route"
    }

    static func response(
        for error: any Error,
        phase: RouteErrorPhase,
        scope: Scope,
        errors: RouteErrorMapper = .none
    ) -> HTTPResponse {
        if let mapped = errors.response(
            for: error,
            phase: phase
        ) {
            return mapped
        }

        if let reportable = error as? any HTTPReportableError {
            return reportable.response()
        }

        let failure = HTTPFailure(
            code: "server.\(scope.rawValue).\(phase.rawValue)",
            kind: phase.failureKind,
            severity: phase.failureSeverity,
            message: "\(phase.failureDescription(scope: scope)): \(String(reflecting: type(of: error)))"
        )

        switch phase {
        case .request:
            return HTTPResponse
                .badRequest()
                .reporting(
                    failure
                )

        case .handler,
             .response:
            return HTTPResponse
                .internalServerError()
                .reporting(
                    failure
                )
        }
    }
}

private extension RouteErrorPhase {
    func failureDescription(
        scope: RouteErrorBoundary.Scope
    ) -> String {
        switch (
            scope,
            self
        ) {
        case (
            .typed,
            .request
        ):
            "Typed route request failed"

        case (
            .typed,
            .handler
        ):
            "Typed route handler failed"

        case (
            .typed,
            .response
        ):
            "Typed route response failed"

        case (
            .raw,
            .request
        ):
            "Route request failed"

        case (
            .raw,
            .handler
        ):
            "Route handler failed"

        case (
            .raw,
            .response
        ):
            "Route response failed"
        }
    }

    var failureKind: HTTPFailureKind {
        switch self {
        case .request:
            .validation

        case .handler,
             .response:
            .internalFailure
        }
    }

    var failureSeverity: HTTPFailureSeverity {
        switch self {
        case .request:
            .warning

        case .handler,
             .response:
            .error
        }
    }
}
