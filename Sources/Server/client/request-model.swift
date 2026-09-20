import Foundation
import HTTP

public enum RequestAuth: Sendable {
    case none
    case bearer(String)
    case custom(String, String) // header, value
}

public func buildValidatedWireRequest(
    host: String,
    method: HTTPMethod,
    path: String,
    headers: [String: String],
    body: String?
) throws -> String {
    try HTTPWireValidation.validateRequestTarget(path)
    try HTTPWireValidation.validateHeader(
        name: "Host",
        value: host
    )

    var lines: [String] = []
    lines.append(
        "\(method.rawValue) \(path) \(HTTPConstants.httpVersion)"
    )
    lines.append(
        try HTTPWireValidation.headerLine(
            name: "Host",
            value: host
        )
    )

    if let body {
        let bodyData = body.data(using: .utf8) ?? Data()
        lines.append(
            try HTTPWireValidation.headerLine(
                name: HTTPConstants.contentLengthHeader,
                value: "\(bodyData.count)"
            )
        )
    }

    let headerLines = try HTTPWireValidation.headerLines(
        headers.map {
            ($0.key, $0.value)
        }
    )

    lines.append(contentsOf: headerLines)
    lines.append("")

    let headerString = lines.joined(
        separator: HTTPConstants.crlf
    )

    if let body {
        return headerString + HTTPConstants.crlf + body
    }

    return headerString + HTTPConstants.crlf
}

public func buildWireRequest(
    host: String,
    method: HTTPMethod,
    path: String,
    headers: [String: String],
    body: String?
) throws -> String {
    try buildValidatedWireRequest(
        host: host,
        method: method,
        path: path,
        headers: headers,
        body: body
    )
}

// public func buildWireRequest(
//     host: String,
//     method: HTTPMethod,
//     path: String,
//     headers: [String: String],
//     body: String?
// ) -> String {
//     do {
//         return try buildValidatedWireRequest(
//             host: host,
//             method: method,
//             path: path,
//             headers: headers,
//             body: body
//         )
//     } catch {
//         return fallbackWireRequest()
//     }
// }

// private func fallbackWireRequest() -> String {
//     [
//         "GET /",
//         "Host: invalid.local",
//         "",
//     ].joined(separator: HTTPConstants.crlf) + HTTPConstants.crlf
// }
