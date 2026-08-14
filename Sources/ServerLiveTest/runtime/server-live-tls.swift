import Server

enum ServerLiveTLS {
    static func run() async -> Bool {
        let host = "example.com"

        print("ServerLive TLS Check")
        print("====================")
        print("")
        print("host: \(host):443")
        print("transport: TCP")
        print("security: TLS")
        print("")

        let client = HTTPClient(
            config: HTTPClientConfig(
                host: host,
                port: 443,
                transport: .tcp(
                    security: .tls()
                ),
                timeout: 5,
                debug: false
            )
        )

        do {
            let response = try await client.get(
                "/"
            )

            let statusOK =
                response.status.code == 200

            let bodyOK =
                response.body.contains(
                    "Example Domain"
                )

            guard statusOK,
                  bodyOK
            else {
                print(
                    "fail  servlive.tls.system-trust  \(response.status.code)"
                )

                print(
                    "      expected 200 response containing Example Domain"
                )

                return false
            }

            print(
                "pass  servlive.tls.system-trust  \(response.status.code)"
            )

            print("")
            print("====================")
            print("pass 1/1 ok, 1 passed")

            return true
        } catch {
            print(
                "fail  servlive.tls.system-trust"
            )

            print(
                "      \(error.localizedDescription)"
            )

            print("")
            print("====================")
            print("fail 1/1 failed, 0 passed")

            return false
        }
    }
}
