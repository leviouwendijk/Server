import Foundation
import Processes
import TestFlowsProcesses

func serverProcessFixture(
    startupTimeout: Duration = .seconds(5)
) -> ProcessFixture<ServerProcessFixtureReady> {
    let readinessPrefix =
        "@@testflows.ready "

    return ProcessFixture(
        process: ProcessSessionSpecification(
            executable: .path(
                serverTestExecutablePath()
            ),
            arguments: [
                "--server-fixture-child",
            ]
        ),
        readiness: ProcessFixtureReadiness { line in
            guard line.stream == .stdout else {
                return nil
            }

            guard line.value.hasPrefix(readinessPrefix) else {
                return nil
            }

            let payload = line.value.dropFirst(
                readinessPrefix.count
            )

            return try JSONDecoder().decode(
                ServerProcessFixtureReady.self,
                from: Data(
                    payload.utf8
                )
            )
        },
        startupTimeout: startupTimeout
    )
}

private func serverTestExecutablePath() -> String {
    let argument = CommandLine.arguments[0]

    guard !argument.hasPrefix("/") else {
        return argument
    }

    return URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath,
        isDirectory: true
    )
    .appendingPathComponent(
        argument
    )
    .standardizedFileURL
    .path
}
