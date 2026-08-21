import TestFlows

enum ServerSecurityFlows: TestFlowRegistry {
    static let title = "Server Test Flows"

    static let flows: [TestFlow] = [
        serverAPIContractFlow,
        serverRequestContextFlow,
        serverJSONCodingFlow,
        serverRouterBaselineRegressionFlow,
        serverTypedRouteRegressionFlow,
        serverOperationRegressionFlow,
        serverOperationRouteRegressionFlow,
        serverRouteErrorMappingRegressionFlow,

        httpRequestParserRegressionFlow,
        httpResponseParserRegressionFlow,
        securityNetworkHarnessRegressionFlow,
        serverProductionWireRegressionFlow,
        serverExecutionTimeoutRegressionFlow,
        serverLifecycleTerminationRegressionFlow,

        outboundClientRequestCRLFInjection,
        outboundResponseCRLFInjection,
        requestParserFramingConfusion,
        contentLengthParsingConfusion,

        transferEncodingSmugglingQualification,
        duplicateSecurityHeaderQualification,
        corsCredentialReflectionQualification,
        inboundHeaderLimitQualification,
        unsafeMethodQualification,
        requestTargetNormalizationQualification,

        runtimeHardeningQualification,
        bearerTokenComparisonRegression,

        // SEC-030 through SEC-033: Original batch
        outboundRequestFailClosedQualification,
        perUserRateLimitIdentityQualification,
        bearerAuthorityResponseOracleQualification,
        corsVaryOverwriteQualification,

        // SEC-034: Rate limiter state growth
        rateLimiterUnboundedStateGrowthQualification,

        // SEC-035: Client debug credential leakage
        clientDebugCredentialLeakageQualification,

        // SEC-036: Activity log query leakage
        activityLogQueryStringLeakageQualification,

        // SEC-037: CORS preflight Vary overwrite
        corsPreflightVaryOverwriteQualification,

        // SEC-038: Outbound CRLF header injection via path
        outboundHeaderInjectionQualification,

        // SEC-039: Outbound CRLF header injection via header values
        outboundHeaderValueInjectionQualification,

        // SEC-040: Bearer middleware equality operator
        bearerMiddlewareEqualityQualification,

        // SEC-041: Bearer authority raw token storage
        bearerAuthorityRawTokenStorageQualification,

        // SEC-042: Connection cap not enforced
        connectionCapNotEnforcedQualification,

        // SEC-043: Connection handler retention
        connectionHandlerRetentionQualification,

        // SEC-044: Slow header timeout
        slowHeaderTimeoutQualification,

        // SEC-045: Slow body timeout
        slowBodyTimeoutQualification,

        // SEC-046: Host binding not enforced
        hostBindingNotEnforcedQualification,

        // SEC-047: Client response header unbounded
        clientResponseHeaderUnboundedQualification,

        // SEC-048: HTTP pipelining undefined
        httpPipeliningUndefinedQualification,

        // SEC-049: Server request header size limit
        serverRequestHeaderSizeLimitQualification,

        // SEC-050: Idle connection timeout
        idleConnectionTimeoutQualification,

        // SEC-051: Per-connection pipelined request backlog
        pipelinedBacklogQualification,
    ]
}
