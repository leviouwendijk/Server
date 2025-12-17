import Foundation
import HTTP

public enum RequestAuth: Sendable {
    case none
    case bearer(String)
    case custom(String, String) // header, value
}

public enum RequestKind {
    case get(path: String, bearer: String?)
    case post(path: String, bearer: String?, body: String, contentType: String?)
}

// func buildWireRequest(host: String, request: RequestKind) -> String {
//     switch request {
//     case .get(let path, let bearer):
//         var lines: [String] = []
//         lines.append("GET \(path)")
//         lines.append("Host: \(host)")
//         if let bearer = bearer, !bearer.isEmpty {
//             lines.append("Authorization: Bearer \(bearer)")
//         }
//         lines.append("") // blank line between headers and body
//         let headerString = lines.joined(separator: "\r\n")
//         return headerString + "\r\n" // no body for GET

//     case .post(let path, let bearer, let body, let contentType):
//         let bodyData = body.data(using: .utf8) ?? Data()
//         var lines: [String] = []
//         lines.append("POST \(path)")
//         lines.append("Host: \(host)")
//         lines.append("Content-Length: \(bodyData.count)")
//         if let contentType = contentType {
//             lines.append("Content-Type: \(contentType)")
//         }
//         if let bearer = bearer, !bearer.isEmpty {
//             lines.append("Authorization: Bearer \(bearer)")
//         }
//         lines.append("") // blank line between headers and body
//         let headerString = lines.joined(separator: "\r\n")
//         return headerString + "\r\n" + body
//     }
// }

public func buildWireRequest(
    host: String,
    method: HTTPMethod,
    path: String,
    headers: [String: String],
    body: String?
) -> String {
    var lines: [String] = []
    lines.append("\(method.rawValue) \(path)")
    lines.append("Host: \(host)")
    
    if let body = body {
        let bodyData = body.data(using: .utf8) ?? Data()
        lines.append("Content-Length: \(bodyData.count)")
    }
    
    for (key, value) in headers {
        lines.append("\(key): \(value)")
    }
    
    lines.append("")
    let headerString = lines.joined(separator: "\r\n")
    
    if let body = body {
        return headerString + "\r\n" + body
    } else {
        return headerString + "\r\n"
    }
}
