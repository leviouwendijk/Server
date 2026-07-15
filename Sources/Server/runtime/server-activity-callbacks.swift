import HTTP

public enum ServerActivityCallbacks {
    public static func combine(
        _ callbacks: HTTPActivityCallback?...
    ) -> HTTPActivityCallback? {
        combine(
            callbacks
        )
    }

    public static func combine(
        _ callbacks: [HTTPActivityCallback?]
    ) -> HTTPActivityCallback? {
        let active = callbacks.compactMap {
            $0
        }

        guard !active.isEmpty else {
            return nil
        }

        return { event in
            for callback in active {
                callback(
                    event
                )
            }
        }
    }
}
