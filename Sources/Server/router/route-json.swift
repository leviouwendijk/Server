import Primitives

public extension Route {
    func json(
        _ policy: ServerJSONPolicy
    ) -> Route {
        var copy = self
        copy.jsonPolicy = policy
        return copy
    }

    func json(
        decodeTo: Casing? = nil,
        encodeAs: Casing? = nil,
        separators: Separators = .common
    ) -> Route {
        json(
            ServerJSONPolicy(
                decodeTo: decodeTo,
                encodeAs: encodeAs,
                separators: separators
            )
        )
    }
}

public extension Array where Element == Route {
    func json(
        _ policy: ServerJSONPolicy
    ) -> [Route] {
        map {
            $0.json(
                policy
            )
        }
    }

    func json(
        decodeTo: Casing? = nil,
        encodeAs: Casing? = nil,
        separators: Separators = .common
    ) -> [Route] {
        map {
            $0.json(
                decodeTo: decodeTo,
                encodeAs: encodeAs,
                separators: separators
            )
        }
    }
}
