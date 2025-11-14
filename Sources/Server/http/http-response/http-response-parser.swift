import Foundation

public struct HTTPResponseParser {
    public static func parse(_ raw: String) throws -> HTTPResponse {
        let parts = raw.components(separatedBy: HTTPConstants.crlfCrLf)
        guard !parts.isEmpty else {
            throw HTTPParsingError.incompleteResponse
        }
        
        let head = parts[0]
        let body = parts.count > 1 ? parts[1] : ""
        
        let headLines = head.split(separator: "\n", omittingEmptySubsequences: false)
        
        guard let statusLine = headLines.first else {
            throw HTTPParsingError.incompleteResponse
        }
        
        let status = try parseStatus(from: statusLine)
        let headers = try parseHeaders(from: headLines.dropFirst())
        
        return HTTPResponse(status: status, headers: headers, body: body)
    }
    
    private static func parseStatus(from line: Substring) throws -> HTTPStatus {
        let parts = line.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2,
              let code = Int(parts[1]) else {
            throw HTTPParsingError.invalidStatusLine(String(line))
        }
        
        return HTTPStatus.resolve(code: code)
    }
    
    private static func parseHeaders(from lines: ArraySlice<Substring>) throws -> [String: String] {
        var headers: [String: String] = [:]
        
        for line in lines {
            guard !line.isEmpty else { continue }
            
            guard let idx = line.firstIndex(of: Character(HTTPConstants.headerSeparator)) else {
                throw HTTPParsingError.malformedHeaders
            }
            
            let key = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            
            headers[key] = value
        }
        
        return headers
    }

    public static func extractContentLength(from headerData: Data) -> Int? {
        guard let text = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = text.split(separator: "\r\n")
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let parts = line.split(separator: ":")
                if parts.count > 1 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    return Int(value)
                }
            }                                                                                                                    }
        return nil
    }
}
