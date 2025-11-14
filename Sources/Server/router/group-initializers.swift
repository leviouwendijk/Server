import Foundation

public func group(
    _ prefix: String...,
    @GroupBuilder builder: () -> [Route]
) -> [Route] {
    let prefixPath = prefix.joined(separator: "/")
    
    return builder().map { route in
        // Prepend prefix to each route's path
        let newPath: String
        if route.path == "/" {
            newPath = "/" + prefixPath
        } else {
            newPath = "/" + prefixPath + route.path
        }
        
        return Route(
            method: route.method,
            path: newPath,
            handler: route.handler
        )
    }
}
