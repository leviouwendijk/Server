import Foundation
import HTTP
import Server

enum ServerLiveTrace {
    static let activity: HTTPActivityCallback = { event in
        let ms = Int(
            ((event.duration ?? 0) * 1000).rounded()
        )

        let status = event.status.code
        let family = event.status.family.suffix

        let requestID = event.requestId.map {
            " id=\($0)"
        } ?? ""

        print(
            "[return] \(event.method.rawValue) \(event.path) -> \(status) \(family) \(ms)ms\(requestID)"
        )
    }

    static func route(
        _ name: String,
        request: HTTPRequest,
        failureStatus: HTTPStatus = .internalServerError,
        _ body: () throws -> HTTPResponse
    ) -> HTTPResponse {
        let bodyBytes = request.body.data(
            using: .utf8
        )?.count ?? 0

        return trace(
            name,
            method: request.method,
            path: request.path,
            bodyBytes: bodyBytes,
            failureStatus: failureStatus,
            body
        )
    }

    static func route(
        _ name: String,
        request: HTTPRequest,
        failureStatus: HTTPStatus = .internalServerError,
        _ body: () -> HTTPResponse
    ) -> HTTPResponse {
        let bodyBytes = request.body.data(
            using: .utf8
        )?.count ?? 0

        return trace(
            name,
            method: request.method,
            path: request.path,
            bodyBytes: bodyBytes,
            failureStatus: failureStatus
        ) {
            body()
        }
    }

    static func route(
        _ name: String,
        method: HTTPMethod,
        path: String,
        failureStatus: HTTPStatus = .internalServerError,
        _ body: () throws -> HTTPResponse
    ) -> HTTPResponse {
        trace(
            name,
            method: method,
            path: path,
            bodyBytes: 0,
            failureStatus: failureStatus,
            body
        )
    }

    static func route(
        _ name: String,
        method: HTTPMethod,
        path: String,
        failureStatus: HTTPStatus = .internalServerError,
        _ body: () -> HTTPResponse
    ) -> HTTPResponse {
        trace(
            name,
            method: method,
            path: path,
            bodyBytes: 0,
            failureStatus: failureStatus
        ) {
            body()
        }
    }

    private static func trace(
        _ name: String,
        method: HTTPMethod,
        path: String,
        bodyBytes: Int,
        failureStatus: HTTPStatus,
        _ body: () throws -> HTTPResponse
    ) -> HTTPResponse {
        print(
            "[recv]   \(method.rawValue) \(path) body=\(bodyBytes)b"
        )

        let startedAt = Date()

        do {
            print(
                "[op]     \(name)"
            )

            let response = try body()

            let ms = elapsedMilliseconds(
                since: startedAt
            )

            print(
                "[done]   \(name) -> \(response.status.code) \(ms)ms"
            )

            return response
        } catch {
            let ms = elapsedMilliseconds(
                since: startedAt
            )

            print(
                "[error]  \(name) -> \(error.localizedDescription) \(ms)ms"
            )

            return HTTPResponse(
                status: failureStatus,
                headers: [
                    "Content-Type": "text/plain; charset=utf-8"
                ],
                body: error.localizedDescription
            )
        }
    }

    private static func elapsedMilliseconds(
        since startedAt: Date
    ) -> Int {
        Int(
            (Date().timeIntervalSince(startedAt) * 1000).rounded()
        )
    }
}
