public protocol ServerContract {
    associatedtype Request:
        Requestable

    associatedtype Response:
        Returnable
}
