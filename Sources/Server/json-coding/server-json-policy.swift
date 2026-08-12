import Primitives

public struct ServerJSONPolicy:
    Sendable,
    Hashable
{
    public let decodeTo: Casing?
    public let encodeAs: Casing?
    public let separators: Separators

    public init(
        decodeTo: Casing? = nil,
        encodeAs: Casing? = nil,
        separators: Separators = .common
    ) {
        self.decodeTo = decodeTo
        self.encodeAs = encodeAs
        self.separators = separators
    }

    public var coding: JSONCoding {
        .casing(
            decodeTo: decodeTo,
            encodeAs: encodeAs,
            separators: separators
        )
    }

    public static let passthrough = Self()
    public static let `default` = passthrough
}
