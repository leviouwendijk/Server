import Foundation
import HTTP
import Server

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ServerLiveBenchmarkOptions: Sendable {
    let paths: [String]
    let method: HTTPMethod
    let body: String?
    let headers: [String: String]
    let requests: Int
    let concurrency: Int
    let timeout: TimeInterval
}

enum ServerLiveBenchmark {
    private struct Target: Sendable {
        let path: String
        let url: URL
    }

    private struct Sample: Sendable {
        let path: String
        let latencyMilliseconds: Double
        let status: Int?
        let error: String?
    }

    static func run(
        config: ServerConfig,
        baseURL: URL,
        options: ServerLiveBenchmarkOptions,
        selfHosted: Bool
    ) async -> Bool {
        if selfHosted {
            return await runSelfHosted(
                config: config,
                options: options
            )
        }

        return await runAgainst(
            baseURL: baseURL,
            options: options,
            source: "external",
            serverMaximumConnections: nil
        )
    }

    private static func runSelfHosted(
        config: ServerConfig,
        options: ServerLiveBenchmarkOptions
    ) async -> Bool {
        do {
            let process = ServerProcess(
                config: config,
                routes: try routes(),
                activity: nil
            )

            try await process.engine.start()

            guard await waitForReady(
                process.engine
            ) else {
                await process.engine.stop()

                print(
                    "benchmark server failed to become ready"
                )

                return false
            }

            guard let port =
                await process.engine.listenerBoundPort,
                let baseURL = URL(
                    string: "http://\(config.host):\(port)"
                )
            else {
                await process.engine.stop()

                print(
                    "benchmark server did not expose a bound port"
                )

                return false
            }

            let result = await runAgainst(
                baseURL: baseURL,
                options: options,
                source: "self-hosted",
                serverMaximumConnections: config.maxConnections
            )

            await process.engine.stop()

            return result
        } catch {
            print(
                "benchmark setup failed: \(error.localizedDescription)"
            )

            return false
        }
    }

    private static func waitForReady(
        _ engine: ServerEngine
    ) async -> Bool {
        let deadline =
            Date().addingTimeInterval(
                2
            )

        while Date() < deadline {
            if await engine.listenerIsReady {
                return true
            }

            if let failure =
                await engine.listenerFailureDescription
            {
                print(
                    "benchmark listener failed: \(failure)"
                )

                return false
            }

            try? await Task.sleep(
                for: .milliseconds(
                    10
                )
            )
        }

        return false
    }

    private static func runAgainst(
        baseURL: URL,
        options: ServerLiveBenchmarkOptions,
        source: String,
        serverMaximumConnections: Int?
    ) async -> Bool {
        guard let targets = targets(
            baseURL: baseURL,
            paths: options.paths
        ) else {
            print(
                "benchmark contains an invalid request path"
            )

            return false
        }

        let configuration =
            URLSessionConfiguration.ephemeral

        configuration.httpMaximumConnectionsPerHost =
            options.concurrency

        configuration.timeoutIntervalForRequest =
            options.timeout

        configuration.timeoutIntervalForResource =
            options.timeout

        configuration.requestCachePolicy =
            .reloadIgnoringLocalCacheData

        configuration.urlCache = nil
        configuration.httpCookieStorage = nil

        let session = URLSession(
            configuration: configuration
        )

        print(
            "ServerLive Benchmark"
        )

        print(
            "===================="
        )

        print(
            ""
        )

        print(
            "source: \(source)"
        )

        print(
            "base: \(baseURL.absoluteString)"
        )

        print(
            "method: \(options.method.rawValue)"
        )

        print(
            "paths: \(options.paths.joined(separator: ", "))"
        )

        print(
            "requests: \(options.requests)"
        )

        print(
            "concurrency: \(options.concurrency)"
        )

        print(
            "timeout: \(format(options.timeout))s"
        )

        if source == "self-hosted" {
            if let serverMaximumConnections {
                print(
                    "server max connections: \(serverMaximumConnections)"
                )
            } else {
                print(
                    "server max connections: unbounded"
                )
            }
        }

        print(
            ""
        )

        let workerCount = min(
            options.concurrency,
            options.requests
        )

        let startedAt =
            Date()

        var samples: [Sample] = []

        samples.reserveCapacity(
            options.requests
        )

        await withTaskGroup(
            of: [Sample].self
        ) { group in
            for worker in 0..<workerCount {
                group.addTask {
                    var local: [Sample] = []

                    var requestIndex =
                        worker

                    while requestIndex < options.requests {
                        let target =
                            targets[
                                requestIndex
                                    % targets.count
                            ]

                        let sample =
                            await request(
                                target: target,
                                session: session,
                                options: options
                            )

                        local.append(
                            sample
                        )

                        requestIndex +=
                            workerCount
                    }

                    return local
                }
            }

            for await local in group {
                samples.append(
                    contentsOf: local
                )
            }
        }

        let duration =
            Date().timeIntervalSince(
                startedAt
            )

        session.finishTasksAndInvalidate()

        printSummary(
            samples: samples,
            duration: duration
        )

        return true
    }

    private static func request(
        target: Target,
        session: URLSession,
        options: ServerLiveBenchmarkOptions
    ) async -> Sample {
        var request = URLRequest(
            url: target.url
        )

        request.httpMethod =
            options.method.rawValue

        request.timeoutInterval =
            options.timeout

        for header in options.headers {
            request.setValue(
                header.value,
                forHTTPHeaderField: header.key
            )
        }

        if let body = options.body {
            request.httpBody =
                Data(
                    body.utf8
                )
        }

        let startedAt =
            Date()

        do {
            let (_, response) =
                try await session.data(
                    for: request
                )

            let latency =
                Date().timeIntervalSince(
                    startedAt
                ) * 1000

            guard let response =
                response as? HTTPURLResponse
            else {
                return Sample(
                    path: target.path,
                    latencyMilliseconds: latency,
                    status: nil,
                    error: "non-HTTP response"
                )
            }

            return Sample(
                path: target.path,
                latencyMilliseconds: latency,
                status: response.statusCode,
                error: nil
            )
        } catch {
            let latency =
                Date().timeIntervalSince(
                    startedAt
                ) * 1000

            return Sample(
                path: target.path,
                latencyMilliseconds: latency,
                status: nil,
                error: error.localizedDescription
            )
        }
    }

    private static func targets(
        baseURL: URL,
        paths: [String]
    ) -> [Target]? {
        let base: URL

        if baseURL.absoluteString.hasSuffix(
            "/"
        ) {
            base = baseURL
        } else {
            guard let normalized = URL(
                string: "\(baseURL.absoluteString)/"
            ) else {
                return nil
            }

            base = normalized
        }

        var result: [Target] = []

        result.reserveCapacity(
            paths.count
        )

        for path in paths {
            let relative =
                path.hasPrefix("/")
                ? String(
                    path.dropFirst()
                )
                : path

            guard let url = URL(
                string: relative,
                relativeTo: base
            )?.absoluteURL
            else {
                return nil
            }

            result.append(
                Target(
                    path: path,
                    url: url
                )
            )
        }

        return result
    }

    private static func printSummary(
        samples: [Sample],
        duration: TimeInterval
    ) {
        let networkFailures =
            samples.filter {
                $0.status == nil
            }.count

        let httpFailures =
            samples.filter {
                guard let status =
                    $0.status
                else {
                    return false
                }

                return !(200..<400).contains(
                    status
                )
            }.count

        var statusCounts: [Int: Int] = [:]

        for sample in samples {
            if let status = sample.status {
                statusCounts[
                    status,
                    default: 0
                ] += 1
            }
        }

        var errorCounts: [String: Int] = [:]

        for sample in samples {
            if let error = sample.error {
                errorCounts[
                    error,
                    default: 0
                ] += 1
            }
        }

        let latencies =
            samples
                .map(
                    \.latencyMilliseconds
                )
                .sorted()

        let requestsPerSecond =
            Double(
                samples.count
            )
            / max(
                duration,
                0.000_001
            )

        print(
            "===================="
        )

        print(
            ""
        )

        print(
            "duration: \(format(duration))s"
        )

        print(
            "requests/sec: \(format(requestsPerSecond))"
        )

        print(
            "network failures: \(networkFailures)"
        )

        print(
            "HTTP failures: \(httpFailures)"
        )

        print(
            ""
        )

        print(
            "status:"
        )

        for status in statusCounts.keys.sorted() {
            print(
                "    \(status): \(statusCounts[status] ?? 0)"
            )
        }

        if !errorCounts.isEmpty {
            print(
                ""
            )

            print(
                "errors:"
            )

            for error in errorCounts.keys.sorted() {
                print(
                    "    \(errorCounts[error] ?? 0)  \(error)"
                )
            }
        }

        guard let minimum =
            latencies.first,
            let maximum =
                latencies.last
        else {
            return
        }

        print(
            ""
        )

        print(
            "latency ms:"
        )

        print(
            "    min: \(format(minimum))"
        )

        print(
            "    p50: \(format(percentile(0.50, values: latencies)))"
        )

        print(
            "    p95: \(format(percentile(0.95, values: latencies)))"
        )

        print(
            "    p99: \(format(percentile(0.99, values: latencies)))"
        )

        print(
            "    max: \(format(maximum))"
        )
    }

    private static func percentile(
        _ percentile: Double,
        values: [Double]
    ) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        let position =
            Double(
                values.count - 1
            )
            * percentile

        let index = Int(
            position.rounded(
                .toNearestOrAwayFromZero
            )
        )

        return values[
            min(
                index,
                values.count - 1
            )
        ]
    }

    private static func format(
        _ value: Double
    ) -> String {
        String(
            format: "%.2f",
            value
        )
    }
}
