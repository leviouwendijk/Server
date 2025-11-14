@available(*, message: "use new methods instead")
public func parseHTTPResponse(_ raw: String) -> HTTPResponse? {
    let parts = raw.components(separatedBy: "\r\n\r\n")
    let head = parts.first ?? raw
    let body = parts.count > 1 ? parts[1] : ""
    
    let headLines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
    guard let statusLine = headLines.first else { return nil }
    
    let statusParts = statusLine.split(separator: " ", maxSplits: 2)
    guard statusParts.count >= 2,
          let statusCode = Int(statusParts[1]) else { return nil }
    
    // ← Change this: use the registry or resolve
    let status = HTTPStatus.defaultFor(code: statusCode)  // Use default resolver
    
    var headers: [String: String] = [:]
    if headLines.count > 1 {
        for line in headLines.dropFirst() {
            if line.isEmpty { continue }
            if let idx = line.firstIndex(of: ":") {
                let key = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
    }
    
    return HTTPResponse(status: status, headers: headers, body: body)
}

// public func parseHTTPResponse(_ raw: String, using registry: HTTPStatusRegistry? = nil) -> HTTPResponse? {
//     let parts = raw.components(separatedBy: "\r\n\r\n")
//     let head = parts.first ?? raw
//     let body = parts.count > 1 ? parts[1] : ""
    
//     let headLines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
//     guard let statusLine = headLines.first else { return nil }
    
//     let statusParts = statusLine.split(separator: " ", maxSplits: 2)
//     guard statusParts.count >= 2,
//           let statusCode = Int(statusParts[1]) else { return nil }
    
//     // Resolve status: custom from registry, or default
//     let status: HTTPStatus
//     if let registry = registry {
//         // Need to handle async differently - use Task
//         status = HTTPStatus.defaultFor(code: statusCode) // fallback for now
//     } else {
//         status = HTTPStatus.defaultFor(code: statusCode)
//     }
    
//     var headers: [String: String] = [:]
//     if headLines.count > 1 {
//         for line in headLines.dropFirst() {
//             if line.isEmpty { continue }
//             if let idx = line.firstIndex(of: ":") {
//                 let key = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
//                 let value = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
//                 headers[key] = value
//             }
//         }
//     }
    
//     return HTTPResponse(status: status, headers: headers, body: body)
// }
