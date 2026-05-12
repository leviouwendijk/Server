import TestFlows

enum ServerSecurityFlows: TestFlowRegistry {
    static let title = "Server Test Flows"

    static let flows: [TestFlow] = [
        serverAPIContractFlow,

        httpRequestParserRegressionFlow,
        httpResponseParserRegressionFlow,

        outboundClientRequestCRLFInjection,
        outboundResponseCRLFInjection,
        requestParserFramingConfusion,
        contentLengthParsingConfusion,

        transferEncodingSmugglingQualification,
        duplicateSecurityHeaderQualification,
        corsCredentialReflectionQualification,
        inboundHeaderLimitQualification,
        unsafeMethodQualification,
        requestTargetNormalizationQualification
    ]
}
