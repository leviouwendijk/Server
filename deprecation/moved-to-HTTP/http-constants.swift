import Foundation

public enum HTTPConstants {
    public static let crlfCrLf = "\r\n\r\n"
    public static let crlf = "\r\n"
    public static let headerSeparator = ":"
    public static let httpVersion = "HTTP/1.1"
    
    public static let contentLengthHeader = "Content-Length"
    public static let contentTypeHeader = "Content-Type"
    public static let authorizationHeader = "Authorization"
    
    public static let defaultContentType = "text/plain; charset=utf-8"
}
