import HTTP

public protocol Requestable:
    Codable,
    HTTPRequestable
{}
