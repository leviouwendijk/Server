import Darwin
import Foundation
import HTTP
import Network
import Server

enum SecurityNetworkHarnessError: Error, Sendable {
    case listenerDidNotBecomeReady
    case listenerHasNoPort
    case serverListenerFailed(String)
    case connectionDidNotBecomeReady
    case sendFailed
}

final class SecurityOneShot<Value: Sendable>: @unchecked Sendable {
    private enum State {
        case pending
        case waiting(CheckedContinuation<Value, Never>)
        case resolved(Value)
    }

    private let lock = NSLock()
    private var state: State = .pending

    @discardableResult
    func resolve(
        _ value: Value
    ) -> Bool {
        let continuation: CheckedContinuation<Value, Never>?

        lock.lock()

        switch state {
        case .pending:
            state = .resolved(value)
            continuation = nil

        case .waiting(let waiting):
            state = .resolved(value)
            continuation = waiting

        case .resolved:
            lock.unlock()
            return false
        }

        lock.unlock()

        continuation?.resume(
            returning: value
        )

        return true
    }

    func wait() async -> Value {
        await withCheckedContinuation { continuation in
            lock.lock()

            switch state {
            case .pending:
                state = .waiting(
                    continuation
                )
                lock.unlock()

            case .resolved(let value):
                lock.unlock()

                continuation.resume(
                    returning: value
                )

            case .waiting:
                lock.unlock()

                fatalError(
                    "SecurityOneShot supports one waiter"
                )
            }
        }
    }

    func wait(
        timeout: TimeInterval,
        fallback: Value
    ) async -> Value {
        Task { [weak self] in
            await securityTestDelay(
                timeout
            )

            self?.resolve(
                fallback
            )
        }

        return await wait()
    }

    var isResolved: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        if case .resolved = state {
            return true
        }

        return false
    }
}

final class SecurityTestConnection: @unchecked Sendable {
    private final class ReceiveBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(
            _ chunk: Data
        ) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func text() -> String {
            lock.lock()

            let snapshot = data

            lock.unlock()

            return String(
                decoding: snapshot,
                as: UTF8.self
            )
        }
    }

    private let connection: NWConnection
    private let queue: DispatchQueue

    init(
        host: String = "127.0.0.1",
        port: UInt16
    ) {
        self.connection = NWConnection(
            host: NWEndpoint.Host(
                host
            ),
            port: NWEndpoint.Port(
                rawValue: port
            )!,
            using: .tcp
        )

        self.queue = DispatchQueue(
            label: "server-security-connection-\(UUID().uuidString)"
        )
    }

    func start(
        timeout: TimeInterval = 1
    ) async -> Bool {
        let result = SecurityOneShot<Bool>()

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                result.resolve(
                    true
                )

            case .failed(_),
                 .cancelled:
                result.resolve(
                    false
                )

            default:
                break
            }
        }

        connection.start(
            queue: queue
        )

        let ready = await result.wait(
            timeout: timeout,
            fallback: false
        )

        if !ready {
            connection.cancel()
        }

        return ready
    }

    func send(
        _ raw: String,
        timeout: TimeInterval = 1
    ) async -> Bool {
        let result = SecurityOneShot<Bool>()

        connection.send(
            content: Data(
                raw.utf8
            ),
            completion: .contentProcessed { error in
                result.resolve(
                    error == nil
                )
            }
        )

        return await result.wait(
            timeout: timeout,
            fallback: false
        )
    }

    func receive(
        until predicate: @escaping @Sendable (String) -> Bool,
        timeout: TimeInterval = 1
    ) async -> String? {
        let result = SecurityOneShot<String?>()
        let buffer = ReceiveBuffer()

        receiveNext(
            buffer: buffer,
            result: result,
            predicate: predicate
        )

        Task { [weak self] in
            await securityTestDelay(
                timeout
            )

            let text = buffer.text()

            if result.resolve(
                text.isEmpty
                    ? nil
                    : text
            ) {
                self?.connection.cancel()
            }
        }

        return await result.wait()
    }

    func cancel() {
        connection.cancel()
    }

    private func receiveNext(
        buffer: ReceiveBuffer,
        result: SecurityOneShot<String?>,
        predicate: @escaping @Sendable (String) -> Bool
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self] data, _, isComplete, error in
            guard let self else {
                result.resolve(
                    nil
                )

                return
            }

            if let data,
               !data.isEmpty {
                buffer.append(
                    data
                )
            }

            let text = buffer.text()

            if predicate(
                text
            ) {
                result.resolve(
                    text
                )

                return
            }

            if error != nil || isComplete {
                result.resolve(
                    text.isEmpty
                        ? nil
                        : text
                )

                return
            }

            guard !result.isResolved else {
                return
            }

            self.receiveNext(
                buffer: buffer,
                result: result,
                predicate: predicate
            )
        }
    }
}

struct SecurityTestServer: Sendable {
    let engine: ServerEngine
    let port: UInt16

    static func start(
        host: String = "127.0.0.1",
        maxConnections: Int? = nil,
        limits: ServerLimits = .default,
        timeouts: ServerTimeouts = .default,
        activityCallback: HTTPActivityCallback? = nil,
        routes: [Route]
    ) async throws -> Self {
        let config = ServerConfig(
            name: "servtest-security",
            port: 0,
            host: host,
            logLevel: .error,
            maxConnections: maxConnections,
            limits: limits,
            timeouts: timeouts
        )

        let router = Router(
            routes: routes,
            methods: config.security.methods,
            json: config.json
        )

        let engine = ServerEngine(
            config: config,
            router: router,
            activityCallback: activityCallback
        )

        try await engine.start()

        let deadline = Date().addingTimeInterval(
            1
        )

        while !(await engine.listenerIsReady) {
            if let failure =
                await engine.listenerFailureDescription {
                await engine.stop()

                throw SecurityNetworkHarnessError.serverListenerFailed(
                    failure
                )
            }

            guard Date() < deadline else {
                await engine.stop()

                throw SecurityNetworkHarnessError.listenerDidNotBecomeReady
            }

            await securityTestDelay(
                0.01
            )
        }

        guard let port =
            await engine.listenerBoundPort
        else {
            await engine.stop()

            throw SecurityNetworkHarnessError.listenerHasNoPort
        }

        return Self(
            engine: engine,
            port: port
        )
    }

    func stop() async {
        await engine.stop()

        await securityTestDelay(
            0.025
        )
    }

    static func reservePort() async throws -> UInt16 {
        let listener = try NWListener(
            using: .tcp,
            on: NWEndpoint.Port(
                rawValue: 0
            )!
        )

        let queue = DispatchQueue(
            label: "server-security-port-\(UUID().uuidString)"
        )

        let ready = SecurityOneShot<Bool>()

        listener.newConnectionHandler = { connection in
            connection.cancel()
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.resolve(
                    true
                )

            case .failed(_),
                 .cancelled:
                ready.resolve(
                    false
                )

            default:
                break
            }
        }

        listener.start(
            queue: queue
        )

        guard await ready.wait(
            timeout: 1,
            fallback: false
        ) else {
            listener.cancel()

            throw SecurityNetworkHarnessError.listenerDidNotBecomeReady
        }

        guard let port = listener.port else {
            listener.cancel()

            throw SecurityNetworkHarnessError.listenerHasNoPort
        }

        let rawValue = port.rawValue

        listener.cancel()

        await securityTestDelay(
            0.025
        )

        return rawValue
    }
}

final class SecurityTestPeer: @unchecked Sendable {
    private let listener: NWListener
    private let queue: DispatchQueue
    private let payloads: [Data]
    private let interPayloadDelay: TimeInterval

    private let lock = NSLock()
    private var connections: [NWConnection] = []

    private(set) var port: UInt16 = 0

    private init(
        listener: NWListener,
        queue: DispatchQueue,
        payloads: [Data],
        interPayloadDelay: TimeInterval
    ) {
        self.listener = listener
        self.queue = queue
        self.payloads = payloads
        self.interPayloadDelay = max(
            0,
            interPayloadDelay
        )
    }

    static func start(
        payload: Data
    ) async throws -> SecurityTestPeer {
        try await start(
            payloads: [
                payload
            ]
        )
    }

    static func start(
        payloads: [Data],
        interPayloadDelay: TimeInterval = 0.025
    ) async throws -> SecurityTestPeer {
        let listener = try NWListener(
            using: .tcp,
            on: NWEndpoint.Port(
                rawValue: 0
            )!
        )

        let queue = DispatchQueue(
            label: "server-security-peer-\(UUID().uuidString)"
        )

        let peer = SecurityTestPeer(
            listener: listener,
            queue: queue,
            payloads: payloads,
            interPayloadDelay: interPayloadDelay
        )

        let ready = SecurityOneShot<Bool>()

        listener.newConnectionHandler = { [weak peer] connection in
            peer?.accept(
                connection
            )
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.resolve(
                    true
                )

            case .failed(_),
                 .cancelled:
                ready.resolve(
                    false
                )

            default:
                break
            }
        }

        listener.start(
            queue: queue
        )

        guard await ready.wait(
            timeout: 1,
            fallback: false
        ) else {
            listener.cancel()

            throw SecurityNetworkHarnessError
                .listenerDidNotBecomeReady
        }

        guard let port = listener.port else {
            listener.cancel()

            throw SecurityNetworkHarnessError
                .listenerHasNoPort
        }

        peer.port = port.rawValue

        return peer
    }

    func stop() {
        listener.cancel()

        lock.lock()

        let active =
            connections

        connections.removeAll()

        lock.unlock()

        for connection in active {
            connection.cancel()
        }
    }

    private func accept(
        _ connection: NWConnection
    ) {
        lock.lock()

        connections.append(
            connection
        )

        lock.unlock()

        connection.start(
            queue: queue
        )

        sendPayload(
            at: 0,
            on: connection
        )
    }

    private func sendPayload(
        at index: Int,
        on connection: NWConnection
    ) {
        guard index < payloads.count else {
            return
        }

        connection.send(
            content: payloads[index],
            completion: .contentProcessed { [weak self] error in
                guard let self,
                      error == nil
                else {
                    return
                }

                let next =
                    index + 1

                guard next < self.payloads.count else {
                    return
                }

                if self.interPayloadDelay == 0 {
                    self.sendPayload(
                        at: next,
                        on: connection
                    )

                    return
                }

                self.queue.asyncAfter(
                    deadline:
                        .now() + self.interPayloadDelay
                ) { [weak self] in
                    self?.sendPayload(
                        at: next,
                        on: connection
                    )
                }
            }
        )
    }
}

enum SecurityNetworkHarness {
    static var nonLoopbackIPv4: String? {
        Host.current().addresses.first { address in
            address.contains(".")
                && !address.hasPrefix("127.")
                && address != "0.0.0.0"
        }
    }
}

enum SecurityStandardOutput {
    static func capture(
        _ operation: @escaping @Sendable () async -> Void
    ) async -> String {
        fflush(
            nil
        )

        let saved = dup(
            STDOUT_FILENO
        )

        guard saved >= 0 else {
            await operation()

            return ""
        }

        let pipe = Pipe()

        let writeDescriptor =
            pipe.fileHandleForWriting.fileDescriptor

        guard dup2(
            writeDescriptor,
            STDOUT_FILENO
        ) >= 0 else {
            close(
                saved
            )

            await operation()

            return ""
        }

        await operation()

        fflush(
            nil
        )

        _ = dup2(
            saved,
            STDOUT_FILENO
        )

        close(
            saved
        )

        pipe.fileHandleForWriting.closeFile()

        let data =
            pipe.fileHandleForReading.readDataToEndOfFile()

        pipe.fileHandleForReading.closeFile()

        return String(
            decoding: data,
            as: UTF8.self
        )
    }
}

func securityTestDelay(
    _ interval: TimeInterval
) async {
    let nanoseconds = UInt64(
        max(
            0,
            interval
        ) * 1_000_000_000
    )

    try? await Task.sleep(
        nanoseconds: nanoseconds
    )
}
