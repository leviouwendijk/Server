import Foundation

public struct HTTPResponseBuilder {
    public static func build(_ response: HTTPResponse) -> String {
        var headers = HTTPHeaders(response.headers)
        
        // Calculate and set Content-Length
        let bodyData = response.body.data(using: .utf8) ?? Data()
        headers.set(HTTPConstants.contentLengthHeader, "\(bodyData.count)")
        
        // Set default Content-Type if not provided
        if headers.get(HTTPConstants.contentTypeHeader) == nil {
            headers.set(HTTPConstants.contentTypeHeader, HTTPConstants.defaultContentType)
        }
        
        // Build status line
        let statusLine = "\(HTTPConstants.httpVersion) \(response.status.code) \(response.status.reason)"
        
        // Build header lines (deterministic order)
        let headerLines = headers.lines()
        
        // Assemble response
        var lines: [String] = [statusLine]
        lines.append(contentsOf: headerLines)
        lines.append("")  // blank line
        
        let headerString = lines.joined(separator: HTTPConstants.crlf)
        return headerString + HTTPConstants.crlf + response.body + "\n"
    }
}
