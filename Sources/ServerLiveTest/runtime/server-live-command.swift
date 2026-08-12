import Foundation
import HTTP
import Server

enum ServerLiveMode: Sendable, Equatable {
    case serve
    case test
    case bench
}

struct ServerLiveCommand: Sendable {
    let mode: ServerLiveMode
    let config: ServerConfig
    let baseURL: URL

    let benchmark: ServerLiveBenchmarkOptions
    let selfHostedBenchmark: Bool
    let noActivity: Bool

    static func parse(
        _ arguments: [String]
    ) throws -> Self {
        guard let rawMode = arguments.first else {
            throw ServerLiveCommandError.missingMode
        }

        let mode: ServerLiveMode

        switch rawMode {
        case "serve":
            mode = .serve

        case "test":
            mode = .test

        case "bench":
            mode = .bench

        case "help",
             "--help",
             "-h":
            throw ServerLiveCommandError.helpRequested

        default:
            throw ServerLiveCommandError.unknownMode(
                rawMode
            )
        }

        let options =
            try ServerLiveOptions.parse(
                Array(
                    arguments.dropFirst()
                )
            )

        if mode == .bench,
           options.base != nil,
           options.maxConnections != nil {
            throw ServerLiveCommandError.externalBenchmarkConnectionCap
        }

        let defaults =
            ServerLiveCommand.defaultConfig

        let resolvedPort: UInt16

        if mode == .bench,
           options.base == nil,
           options.port == nil {
            resolvedPort = 0
        } else {
            resolvedPort =
                options.port
                ?? defaults.port
        }

        let resolvedConfig = ServerConfig(
            name: defaults.name,
            port: resolvedPort,
            host: options.host ?? defaults.host,
            logLevel: defaults.logLevel,
            maxConnections:
                options.maxConnections
                ?? defaults.maxConnections,
            limits: defaults.limits,
            timeouts: defaults.timeouts,
            security: defaults.security,
            json: defaults.json
        )

        let benchmark =
            ServerLiveBenchmarkOptions(
                paths:
                    options.paths.isEmpty
                    ? [
                        "/_benchmark"
                    ]
                    : options.paths,
                method:
                    options.method
                    ?? .get,
                body: options.body,
                headers: options.headers,
                requests:
                    options.requests
                    ?? 1_000,
                concurrency:
                    options.concurrency
                    ?? 32,
                timeout:
                    options.timeout
                    ?? 5
            )

        return Self(
            mode: mode,
            config: resolvedConfig,
            baseURL: options.baseURL(
                fallbackHost: resolvedConfig.host,
                fallbackPort: resolvedConfig.port
            ),
            benchmark: benchmark,
            selfHostedBenchmark:
                mode == .bench
                && options.base == nil,
            noActivity: options.noActivity
        )
    }

    private static let defaultConfig =
        ServerConfig(
            name: "servlive",
            port: 49161,
            host: "127.0.0.1",
            logLevel: .info,
            limits: .init(
                content: .standardJSONAPI,
                headers: HTTPHeaderPolicy.request.default
            ),
            security: .default
        )
}

private struct ServerLiveOptions: Sendable {
    var host: String?
    var port: UInt16?
    var base: URL?

    var maxConnections: Int?
    var noActivity = false

    var paths: [String] = []
    var method: HTTPMethod?
    var body: String?
    var headers: [String: String] = [:]

    var requests: Int?
    var concurrency: Int?
    var timeout: TimeInterval?

    static func parse(
        _ arguments: [String]
    ) throws -> Self {
        var result =
            Self()

        var index = 0

        while index < arguments.count {
            let argument =
                arguments[index]

            switch argument {
            case "--help",
                 "-h":
                throw ServerLiveCommandError.helpRequested

            case "--no-activity":
                result.noActivity = true

            case "--host":
                result.host =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

            case "--port":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                guard let port =
                    UInt16(
                        raw
                    )
                else {
                    throw ServerLiveCommandError.invalidPort(
                        raw
                    )
                }

                result.port =
                    port

            case "--base":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                guard let url =
                    URL(
                        string: raw
                    )
                else {
                    throw ServerLiveCommandError.invalidBase(
                        raw
                    )
                }

                result.base =
                    url

            case "--max-connections":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                result.maxConnections =
                    try positiveInteger(
                        raw,
                        option: argument
                    )

            case "--path":
                result.paths.append(
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )
                )

            case "--method":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                guard let method =
                    HTTPMethod(
                        caseInsensitive: raw
                    )
                else {
                    throw ServerLiveCommandError.invalidMethod(
                        raw
                    )
                }

                result.method =
                    method

            case "--body":
                result.body =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

            case "--header":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                let header =
                    try parseHeader(
                        raw
                    )

                result.headers[
                    header.name
                ] = header.value

            case "--requests":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                result.requests =
                    try positiveInteger(
                        raw,
                        option: argument
                    )

            case "--concurrency":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                result.concurrency =
                    try positiveInteger(
                        raw,
                        option: argument
                    )

            case "--timeout":
                let raw =
                    try value(
                        after: &index,
                        in: arguments,
                        option: argument
                    )

                result.timeout =
                    try positiveNumber(
                        raw,
                        option: argument
                    )

            default:
                throw ServerLiveCommandError.unknownOption(
                    argument
                )
            }

            index += 1
        }

        return result
    }

    func baseURL(
        fallbackHost: String,
        fallbackPort: UInt16
    ) -> URL {
        if let base {
            return base
        }

        return URL(
            string: "http://\(fallbackHost):\(fallbackPort)"
        )!
    }

    private static func value(
        after index: inout Int,
        in arguments: [String],
        option: String
    ) throws -> String {
        index += 1

        guard index < arguments.count else {
            throw ServerLiveCommandError.missingValue(
                option
            )
        }

        return arguments[
            index
        ]
    }

    private static func positiveInteger(
        _ raw: String,
        option: String
    ) throws -> Int {
        guard let value =
            Int(
                raw
            ),
            value > 0
        else {
            throw ServerLiveCommandError.invalidInteger(
                option: option,
                value: raw
            )
        }

        return value
    }

    private static func positiveNumber(
        _ raw: String,
        option: String
    ) throws -> Double {
        guard let value =
            Double(
                raw
            ),
            value > 0
        else {
            throw ServerLiveCommandError.invalidNumber(
                option: option,
                value: raw
            )
        }

        return value
    }

    private static func parseHeader(
        _ raw: String
    ) throws -> (
        name: String,
        value: String
    ) {
        guard let separator =
            raw.firstIndex(
                of: ":"
            )
        else {
            throw ServerLiveCommandError.invalidHeader(
                raw
            )
        }

        let name =
            raw[..<separator]
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let value =
            raw[
                raw.index(
                    after: separator
                )...
            ]
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !name.isEmpty else {
            throw ServerLiveCommandError.invalidHeader(
                raw
            )
        }

        return (
            name,
            value
        )
    }
}

enum ServerLiveCommandError: Error, LocalizedError {
    case missingMode
    case helpRequested
    case unknownMode(String)
    case unknownOption(String)
    case missingValue(String)

    case invalidPort(String)
    case invalidBase(String)
    case invalidMethod(String)
    case invalidHeader(String)

    case invalidInteger(
        option: String,
        value: String
    )

    case invalidNumber(
        option: String,
        value: String
    )

    case externalBenchmarkConnectionCap

    var errorDescription: String? {
        switch self {
        case .missingMode:
            return "Missing mode.\n\n\(Self.usage)"

        case .helpRequested:
            return Self.usage

        case .unknownMode(
            let mode
        ):
            return "Unknown mode: \(mode)\n\n\(Self.usage)"

        case .unknownOption(
            let option
        ):
            return "Unknown option: \(option)\n\n\(Self.usage)"

        case .missingValue(
            let option
        ):
            return "Missing value for \(option)."

        case .invalidPort(
            let value
        ):
            return "Invalid port: \(value)"

        case .invalidBase(
            let value
        ):
            return "Invalid base URL: \(value)"

        case .invalidMethod(
            let value
        ):
            return "Invalid HTTP method: \(value)"

        case .invalidHeader(
            let value
        ):
            return "Invalid header: \(value). Expected 'Name: Value'."

        case .invalidInteger(
            let option,
            let value
        ):
            return "Invalid positive integer for \(option): \(value)"

        case .invalidNumber(
            let option,
            let value
        ):
            return "Invalid positive number for \(option): \(value)"

        case .externalBenchmarkConnectionCap:
            return "--max-connections only applies to a self-hosted servlive benchmark."
        }
    }

    static let usage =
    """
    usage:
        swift run servlive serve [--host 127.0.0.1] [--port 49161] [--max-connections N] [--no-activity]

        swift run servlive test  [--host 127.0.0.1] [--port 49161]
        swift run servlive test  [--base http://127.0.0.1:49161]

        swift run servlive bench [--max-connections N]
                                 [--path /_benchmark]
                                 [--method GET]
                                 [--body VALUE]
                                 [--header "Name: Value"]
                                 [--requests 1000]
                                 [--concurrency 32]
                                 [--timeout 5]

        swift run servlive bench --base http://127.0.0.1:49161
                                 [--path /health]
                                 [--path /other]
                                 [--method GET]
                                 [--body VALUE]
                                 [--header "Name: Value"]
                                 [--requests 1000]
                                 [--concurrency 32]
                                 [--timeout 5]

    modes:
        serve
            Starts the mock API server.

        test
            Runs all live HTTP checks against an already-running server.

        bench
            Runs concurrent HTTP benchmark traffic.

            Without --base, servlive starts an isolated local server itself.
            --max-connections applies to that self-hosted server.

            With --base, servlive benchmarks an already-running server.
    """
}
