import Foundation
import plate

public enum ServerActivitySelection: Sendable {
    case all
    case failuresOnly                       // 4xx + 5xx
    case onlyFamilies(Set<HTTPStatusFamily>)
    case custom(@Sendable (HTTPActivityEvent) -> Bool)
}

public enum ServerActivityLog {
    public static func file(
        name: String = "server/activity",
        minimumLevel: LogLevel = .info,
        selection: ServerActivitySelection = .failuresOnly
    ) throws -> HTTPActivityCallback {
        let logger = try StandardLogger(name: name, minimumLevel: minimumLevel)

        return { event in
            let code = event.status.code
            let family = event.status.family

            let shouldLog: Bool = {
                switch selection {
                case .all:
                    return true
                case .failuresOnly:
                    return code >= 400
                case .onlyFamilies(let families):
                    return families.contains(family)
                case .custom(let predicate):
                    return predicate(event)
                }
            }()

            guard shouldLog else { return }

            let lineBase = "\(event.method.rawValue) \(event.path) -> \(code)"
            let line: String
            if let client = event.clientDescription {
                line = "[\(client)] \(lineBase)"
            } else {
                line = lineBase
            }

            switch family {
            case .serverError:
                logger.error(line)
            case .clientError:
                logger.warn(line)
            default:
                logger.info(line)
            }
        }
    }
}

extension ServerActivityLog {
    public static func files(
        baseName: String = "server/activity",
        families: Set<HTTPStatusFamily> = Set(HTTPStatusFamily.allCases),
        minimumLevel: LogLevel = .info
    ) throws -> HTTPActivityCallback {
        var tmp: [HTTPStatusFamily: StandardLogger] = [:]

        for family in families {
            let name = "\(baseName)-\(family.suffix)"
            tmp[family] = try StandardLogger(name: name, minimumLevel: minimumLevel)
        }

        let table = tmp

        return { event in
            guard let logger = table[event.status.family] else {
                return
            }

            let lineBase = "\(event.method.rawValue) \(event.path) -> \(event.status.code)"
            let line: String
            if let client = event.clientDescription {
                line = "[\(event.serviceName)] [\(client)] \(lineBase)"
            } else {
                line = "[\(event.serviceName)] \(lineBase)"
            }

        // case informational   // 1xx
        // case success         // 2xx
        // case redirection     // 3xx
        // case clientError     // 4xx
        // case serverError     // 5xx
        // case other           // everything else / weird

            switch event.status.family {
            case .serverError:
                logger.error(line)
            case .clientError, .other:
                logger.warn(line)
            default:
                logger.info(line)
            }
        }
    }
}
