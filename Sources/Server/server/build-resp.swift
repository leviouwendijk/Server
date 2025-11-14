import Foundation

@available(*, message: "use new methods instead")
public func buildHTTPResponseString(_ response: HTTPResponse) -> String {
    let bodyData = response.body.data(using: .utf8) ?? Data()
    var headers = response.headers
    headers["Content-Length"] = "\(bodyData.count)"
    if headers["Content-Type"] == nil {
        headers["Content-Type"] = "text/plain; charset=utf-8"
    }

    var lines: [String] = []
    lines.append("HTTP/1.1 \(response.status.code) \(response.status.reason)")  // ← Use .code instead
    for (k, v) in headers {
        lines.append("\(k): \(v)")
    }
    lines.append("") // blank line
    let headerString = lines.joined(separator: "\r\n")
    return headerString + "\r\n" + response.body
}

// public func buildHTTPResponseString(_ response: HTTPResponse) -> String {
//     let bodyData = response.body.data(using: .utf8) ?? Data()
//     var headers = response.headers
//     headers["Content-Length"] = "\(bodyData.count)"
//     if headers["Content-Type"] == nil {
//         headers["Content-Type"] = "text/plain; charset=utf-8"
//     }

//     var lines: [String] = []
//     lines.append("HTTP/1.1 \(response.status.rawValue) \(response.status.reason)")
//     for (k, v) in headers {
//         lines.append("\(k): \(v)")
//     }
//     lines.append("") // blank line
//     let headerString = lines.joined(separator: "\r\n")
//     return headerString + "\r\n" + response.body
// }
