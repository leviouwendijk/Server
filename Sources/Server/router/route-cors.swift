import HTTP

public extension Route {
    /// Attach CORS middleware and admit synthetic OPTIONS requests for this route.
    ///
    /// This keeps `.allow(.options)` as router admission, while making the
    /// intended CORS pairing explicit at the call site.
    func cors(
        _ middleware: CORSMiddleware
    ) -> Route {
        self
            .use(middleware)
            .allow(.options)
    }
}

public extension Array where Element == Route {
    /// Attach CORS middleware and admit synthetic OPTIONS requests for each route.
    func cors(
        _ middleware: CORSMiddleware
    ) -> [Route] {
        map {
            $0.cors(middleware)
        }
    }
}

public extension GroupWithMiddleware {
    /// Attach CORS middleware and admit synthetic OPTIONS requests for each grouped route.
    func cors(
        _ middleware: CORSMiddleware
    ) -> [Route] {
        routes.cors(middleware)
    }
}
