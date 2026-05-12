import HTTP
import Server
import Loggers

let config = ServerConfig(
    name: "servlive",
    port: 49161,
    host: "127.0.0.1",
    logLevel: .info,
    limits: .init(
        content: .standardJSONAPI,
        headers: .requestDefault
    ),
    security: .default
)

let logger = try? StandardLogger(
    name: config.name,
    minimumLevel: config.logLevel,
    writeMode: .reset()
)

// let activity: HTTPActivityCallback? = try? ServerActivityLog.files(
//     minimumLevel: config.logLevel
// )
let activity: HTTPActivityCallback? = ServerLiveTrace.activity
