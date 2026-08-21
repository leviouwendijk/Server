import HTTP

struct RoutePhasedError:
    Error
{
    let underlying:
        any Error

    let phase:
        RouteErrorPhase

    init(
        _ underlying: any Error,
        phase: RouteErrorPhase
    ) {
        self.underlying =
            underlying

        self.phase =
            phase
    }
}

enum RouteErrorBoundary {
    enum Scope:
        String,
        Sendable
    {
        case typed =
            "typed_route"

        case raw =
            "route"
    }

    static func response(
        for error: any Error,
        phase: RouteErrorPhase,
        scope: Scope,
        errors:
            RouteErrorMapper = .none
    ) -> HTTPResponse {
        let effectiveError:
            any Error

        let effectivePhase:
            RouteErrorPhase

        if let phased =
            error as? RoutePhasedError
        {
            effectiveError =
                phased.underlying

            effectivePhase =
                phased.phase
        } else {
            effectiveError =
                error

            effectivePhase =
                phase
        }

        if let mapped =
            errors.response(
                for: effectiveError,
                phase: effectivePhase
            )
        {
            return mapped
        }

        if let reportable =
            effectiveError
                as? any HTTPReportableError
        {
            return reportable.response()
        }

        let failure =
            HTTPFailure(
                code:
                    "server.\(scope.rawValue).\(effectivePhase.rawValue)",
                kind:
                    effectivePhase.failureKind,
                severity:
                    effectivePhase.failureSeverity,
                message:
                    "\(effectivePhase.failureDescription(scope: scope)): \(String(reflecting: type(of: effectiveError)))"
            )

        switch effectivePhase {
        case .request,
             .input:
            return HTTPResponse
                .badRequest()
                .reporting(
                    failure
                )

        case .operation,
             .output,
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
        scope:
            RouteErrorBoundary.Scope
    ) -> String {
        let prefix: String

        switch scope {
        case .typed:
            prefix =
                "Typed route"

        case .raw:
            prefix =
                "Route"
        }

        switch self {
        case .request:
            return "\(prefix) request failed"

        case .input:
            return "\(prefix) input failed"

        case .operation:
            return "\(prefix) operation failed"

        case .output:
            return "\(prefix) output failed"

        case .response:
            return "\(prefix) response failed"
        }
    }

    var failureKind:
        HTTPFailureKind
    {
        switch self {
        case .request,
             .input:
            .validation

        case .operation,
             .output,
             .response:
            .internalFailure
        }
    }

    var failureSeverity:
        HTTPFailureSeverity
    {
        switch self {
        case .request,
             .input:
            .warning

        case .operation,
             .output,
             .response:
            .error
        }
    }
}
