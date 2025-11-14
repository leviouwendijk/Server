import Foundation

public struct HTTPRequestParser {
    public static func parse(_ raw: String) throws -> HTTPRequest {
        let parts = raw.components(separatedBy: HTTPConstants.crlfCrLf)
        guard !parts.isEmpty else {
            throw HTTPParsingError.incompleteRequest
        }
        
        let head = parts[0]
        let body = parts.count > 1 ? parts[1] : ""
        
        let headLines = head.split(
            separator: Character(extendedGraphemeClusterLiteral: HTTPConstants.crlf.first ?? "\n"),
            omittingEmptySubsequences: false
        )
        
        guard let requestLine = headLines.first else {
            throw HTTPParsingError.incompleteRequest
        }
        
        let method = try parseMethod(from: requestLine)
        let path = try parsePath(from: requestLine)
        let headers = try parseHeaders(from: headLines.dropFirst())
        
        return HTTPRequest(method: method, path: path, headers: headers, body: body)
    }
    
    private static func parseMethod(from line: Substring) throws -> HTTPMethod {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 1 else {
            throw HTTPParsingError.invalidRequestLine(String(line))
        }
        
        let methodStr = String(parts[0])
        guard let method = HTTPMethod(rawValue: methodStr) else {
            throw HTTPParsingError.invalidMethod(methodStr)
        }
        
        return method
    }
    
    private static func parsePath(from line: Substring) throws -> String {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            throw HTTPParsingError.invalidRequestLine(String(line))
        }
        
        return String(parts[1])
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
            }
        }
        return nil
    }
}
