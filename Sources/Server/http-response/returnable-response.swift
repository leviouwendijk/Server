import Foundation
import HTTP

public protocol ReturnableResponse: Codable, Sendable {
    func response(
        status: HTTPStatus
    ) throws -> HTTPResponse
}

extension ReturnableResponse {
    public func response(
        status: HTTPStatus = .ok
    ) throws -> HTTPResponse {
        let encoder = HTTPJSONCoding.current.encoder()

        encoder.outputFormatting.formUnion(
            [
                .prettyPrinted,
                .sortedKeys,
            ]
        )

        return try response(
            status: status,
            using: encoder
        )
    }

    public func response(
        status: HTTPStatus = .ok,
        using encoder: JSONEncoder
    ) throws -> HTTPResponse {
        let data = try encoder.encode(
            self
        )

        guard let json = String(
            data: data,
            encoding: .utf8
        ) else {
            throw ServerError.responseEncodingFailed
        }

        var response = HTTPResponse(
            status: status,
            body: json
        )

        response.headers[
            "Content-Type"
        ] = "application/json; charset=utf-8"

        return response
    }
}
