import HTTP

enum ServerRouteExecution {
    enum Outcome: Sendable {
        case completed(
            RouteResult
        )

        case timedOut
    }

    static func observe(
        router: Router,
        request: HTTPRequest,
        timeout: Duration?
    ) async -> Outcome {
        guard let timeout else {
            return .completed(
                await router.observed(
                    request
                )
            )
        }

        let pair =
            AsyncStream<Outcome>.makeStream(
                bufferingPolicy: .bufferingOldest(
                    1
                )
            )

        let stream =
            pair.stream

        let continuation =
            pair.continuation

        let routeTask = Task {
            let result =
                await router.observed(
                    request
                )

            continuation.yield(
                .completed(
                    result
                )
            )
        }

        let timeoutTask = Task {
            do {
                try await Task.sleep(
                    for: timeout
                )
            } catch {
                return
            }

            continuation.yield(
                .timedOut
            )
        }

        var iterator =
            stream.makeAsyncIterator()

        let outcome =
            await iterator.next()
            ?? .timedOut

        continuation.finish()

        routeTask.cancel()
        timeoutTask.cancel()

        return outcome
    }
}
