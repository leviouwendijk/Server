import Foundation
import HTTP
import Parsers

public extension CORSMiddleware {
    init(
        originPatterns: [Prebuilt.CORSOriginPattern],
        schemes: Set<Prebuilt.Origin.Scheme> = [.https],
        port: Prebuilt.CORSOriginMatcher.PortRule = .any,
        allowCredentials: Bool = false,
        allowedMethods: [HTTPMethod] = [.get, .post, .options],
        allowedHeaders: [String] = ["Content-Type", "Authorization"],
        exposedHeaders: [String] = [],
        maxAgeSeconds: Int? = 600
    ) {
        self.init(
            allowedOrigin: .patterns(
                originPatterns,
                schemes: schemes,
                port: port
            ),
            allowCredentials: allowCredentials,
            allowedMethods: allowedMethods,
            allowedHeaders: allowedHeaders,
            exposedHeaders: exposedHeaders,
            maxAgeSeconds: maxAgeSeconds
        )
    }
}
