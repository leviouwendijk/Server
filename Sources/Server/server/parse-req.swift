// -----------------------------
// HTTP parsing / building
// -----------------------------
@available(*, message: "use new methods instead")
public func parseHTTPRequest(_ raw: String) -> HTTPRequest? {
    // Split header and body
    let parts = raw.components(separatedBy: "\r\n\r\n")
    let head = parts.first ?? raw
    let body = parts.count > 1 ? parts[1] : ""

    let headLines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
    guard let requestLine = headLines.first else { return nil }

    let requestParts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
    guard requestParts.count >= 2 else { return nil }

    guard let method = HTTPMethod(rawValue: String(requestParts[0])) else { return nil }
    let path = String(requestParts[1])

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

    return HTTPRequest(method: method, path: path, headers: headers, body: body)
}
