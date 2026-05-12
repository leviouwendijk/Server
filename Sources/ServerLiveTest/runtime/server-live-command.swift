import Foundation
import Server

enum ServerLiveMode: Sendable {
    case serve
    case test
}

struct ServerLiveCommand: Sendable {
    let mode: ServerLiveMode
    let config: ServerConfig
    let baseURL: URL

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

        case "help", "--help", "-h":
            throw ServerLiveCommandError.helpRequested

        default:
            throw ServerLiveCommandError.unknownMode(rawMode)
        }

        let options = try ServerLiveOptions.parse(
            Array(
                arguments.dropFirst()
            )
        )

        let defaults = ServerLiveCommand.defaultConfig

        let resolvedConfig = ServerConfig(
            name: defaults.name,
            port: options.port ?? defaults.port,
            host: options.host ?? defaults.host,
            logLevel: defaults.logLevel,
            maxConnections: defaults.maxConnections,
            limits: defaults.limits,
            security: defaults.security
        )

        return Self(
            mode: mode,
            config: resolvedConfig,
            baseURL: options.baseURL(
                fallbackHost: resolvedConfig.host,
                fallbackPort: resolvedConfig.port
            )
        )
    }

    private static let defaultConfig = ServerConfig(
        name: "servlive",
        port: 49161,
        host: "127.0.0.1",
        logLevel: .info,
        limits: .init(
            content: .standardJSONAPI,
            headers: .requestDefault
        ),
        security: .default
    )
}

private struct ServerLiveOptions: Sendable {
    var host: String?
    var port: UInt16?
    var base: URL?

    static func parse(
        _ arguments: [String]
    ) throws -> Self {
        var result = Self()
        var index = arguments.startIndex

        while index < arguments.endIndex {
            let argument = arguments[index]

            switch argument {
            case "--host":
                index = arguments.index(after: index)

                guard index < arguments.endIndex else {
                    throw ServerLiveCommandError.missingValue(argument)
                }

                result.host = arguments[index]

            case "--port":
                index = arguments.index(after: index)

                guard index < arguments.endIndex else {
                    throw ServerLiveCommandError.missingValue(argument)
                }

                guard let port = UInt16(arguments[index]) else {
                    throw ServerLiveCommandError.invalidPort(arguments[index])
                }

                result.port = port

            case "--base":
                index = arguments.index(after: index)

                guard index < arguments.endIndex else {
                    throw ServerLiveCommandError.missingValue(argument)
                }

                guard let url = URL(string: arguments[index]) else {
                    throw ServerLiveCommandError.invalidBase(arguments[index])
                }

                result.base = url

            default:
                throw ServerLiveCommandError.unknownOption(argument)
            }

            index = arguments.index(after: index)
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
}

enum ServerLiveCommandError: Error, LocalizedError {
    case missingMode
    case helpRequested
    case unknownMode(String)
    case unknownOption(String)
    case missingValue(String)
    case invalidPort(String)
    case invalidBase(String)

    var errorDescription: String? {
        switch self {
        case .missingMode:
            return "Missing mode.\n\n\(Self.usage)"

        case .helpRequested:
            return Self.usage

        case .unknownMode(let mode):
            return "Unknown mode: \(mode)\n\n\(Self.usage)"

        case .unknownOption(let option):
            return "Unknown option: \(option)\n\n\(Self.usage)"

        case .missingValue(let option):
            return "Missing value for \(option)."

        case .invalidPort(let value):
            return "Invalid port: \(value)"

        case .invalidBase(let value):
            return "Invalid base URL: \(value)"
        }
    }

    static let usage =
    """
    usage:
        swift run servlive serve [--host 127.0.0.1] [--port 49161]
        swift run servlive test  [--host 127.0.0.1] [--port 49161]
        swift run servlive test  [--base http://127.0.0.1:49161]

    modes:
        serve
            Starts the mock API server.

        test
            Runs all live HTTP checks against an already-running server.
    """
}
