import Foundation
import Server

@main
struct App {
    static func main() async {
        do {
            let command = try ServerLiveCommand.parse(
                Array(
                    CommandLine.arguments.dropFirst()
                )
            )

            switch command.mode {
            case .serve:
                let process = ServerProcess(
                    config: command.config,
                    routes: try routes(),
                    logger: logger,
                    activity: activity
                )

                await logger?.log(
                    "servlive serving on http://\(command.config.host):\(command.config.port)",
                    level: .info
                )

                await process.run()

            case .test:
                let ok = await ServerLiveClient.run(
                    config: command.config,
                    baseURL: command.baseURL
                )

                Foundation.exit(
                    ok ? 0 : 1
                )
            }
        } catch ServerLiveCommandError.helpRequested {
            print(
                ServerLiveCommandError.usage
            )

            Foundation.exit(0)
        } catch {
            printError(
                error.localizedDescription
            )

            Foundation.exit(2)
        }
    }

    private static func printError(
        _ message: String
    ) {
        let text = message.hasSuffix("\n") ? message : "\(message)\n"

        FileHandle.standardError.write(
            Data(
                text.utf8
            )
        )
    }
}
