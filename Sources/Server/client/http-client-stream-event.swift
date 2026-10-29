import Foundation
import HTTP

/// Incremental events emitted by `HTTPClient.stream`.
///
/// The response-head event contains the parsed response metadata before body
/// delivery. Body events contain decoded entity-body bytes after HTTP framing
/// is removed. Trailers are emitted only when trailer fields are present.
public enum HTTPClientStreamEvent: Sendable {
    case responseHead(HTTPResponse)
    case body(Data)
    case trailers(HTTPHeaders)
}
