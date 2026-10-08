// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import AndroidBackend

/// `adb forward` listens on the machine running the adb server, so the
/// bridge host follows `ADB_SERVER_SOCKET` when that server is remote
/// (e.g. WSL talking to the Windows host's adb), or
/// `ANDROID_ADB_SERVER_ADDRESS` when `ADB_SERVER_SOCKET` is unset, matching adb.
/// `SIM_USE_BRIDGE_HOST` is an explicit override.
@Suite("BridgeConnection.resolveBridgeHost")
struct BridgeHostTests {
    @Test("No adb server override → loopback")
    func defaultIsLoopback() {
        #expect(BridgeConnection.resolveBridgeHost(environment: [:]) == "127.0.0.1")
    }

    @Test("Local adb server sockets stay on loopback", arguments: [
        "tcp:5037",
        "tcp:localhost:5037",
        "tcp:127.0.0.1:5037",
        "tcp:[::1]:5037",
        "localfilesystem:/tmp/adb.sock",
        "",
    ])
    func localServerIsLoopback(socket: String) {
        #expect(BridgeConnection.resolveBridgeHost(environment: ["ADB_SERVER_SOCKET": socket]) == "127.0.0.1")
    }

    @Test("Remote adb server → its host")
    func remoteServerHost() {
        let env = ["ADB_SERVER_SOCKET": "tcp:172.20.64.1:5037"]
        #expect(BridgeConnection.resolveBridgeHost(environment: env) == "172.20.64.1")
    }

    @Test("Remote IPv6 adb server keeps its brackets")
    func remoteIPv6ServerHost() {
        let env = ["ADB_SERVER_SOCKET": "tcp:[fd00::1]:5037"]
        #expect(BridgeConnection.resolveBridgeHost(environment: env) == "[fd00::1]")
    }

    @Test("SIM_USE_BRIDGE_HOST wins over ADB_SERVER_SOCKET")
    func explicitOverrideWins() {
        let env = ["SIM_USE_BRIDGE_HOST": "10.0.0.7", "ADB_SERVER_SOCKET": "tcp:172.20.64.1:5037"]
        #expect(BridgeConnection.resolveBridgeHost(environment: env) == "10.0.0.7")
    }

    @Test("A bare IPv6 override is bracketed")
    func bareIPv6OverrideIsBracketed() {
        #expect(BridgeConnection.resolveBridgeHost(environment: ["SIM_USE_BRIDGE_HOST": "fd00::7"]) == "[fd00::7]")
    }

    @Test("ADDRESS selects the bridge host", arguments: [
        ("192.0.2.10", "192.0.2.10"),
        ("adb.example.test", "adb.example.test"),
        ("fd00::1", "[fd00::1]"),
        ("fe80::1%eth0", "[fe80::1%25eth0]"),
        ("localhost", "127.0.0.1"),
        ("127.0.0.1", "127.0.0.1"),
        ("::1", "127.0.0.1"),
        ("", "127.0.0.1"),
    ])
    func addressHost(address: String, expected: String) {
        for port in [nil, "5038"] as [String?] {
            var environment = ["ANDROID_ADB_SERVER_ADDRESS": address]
            environment["ANDROID_ADB_SERVER_PORT"] = port
            #expect(BridgeConnection.resolveBridgeHost(environment: environment) == expected)
        }
    }

    @Test("Socket overrides ADDRESS", arguments: [
        ("tcp:192.0.2.20:5037", "192.0.2.20"),
        ("tcp:5037", "127.0.0.1"),
        ("localfilesystem:/tmp/adb.sock", "127.0.0.1"),
    ])
    func socketOverridesAddress(socket: String, expected: String) {
        #expect(BridgeConnection.resolveBridgeHost(environment: [
            "ANDROID_ADB_SERVER_ADDRESS": "192.0.2.10",
            "ADB_SERVER_SOCKET": socket,
        ]) == expected)
    }

    @Test("Explicit host overrides ADDRESS")
    func explicitOverridesAddress() {
        #expect(BridgeConnection.resolveBridgeHost(environment: [
            "ANDROID_ADB_SERVER_ADDRESS": "192.0.2.10",
            "SIM_USE_BRIDGE_HOST": "192.0.2.30",
        ]) == "192.0.2.30")
    }

    @Test("Every resolved host forms a valid bridge URL", arguments: [
        ["ADB_SERVER_SOCKET": "tcp:172.20.64.1:5037"],
        ["ADB_SERVER_SOCKET": "tcp:[fd00::1]:5037"],
        ["ADB_SERVER_SOCKET": "tcp:[fe80::1%eth0]:5037"],
        ["SIM_USE_BRIDGE_HOST": "fe80::1%eth0"],
    ])
    func resolvedHostFormsURL(environment: [String: String]) {
        let host = BridgeConnection.resolveBridgeHost(environment: environment)
        #expect(URL(string: "http://\(host):8080/ping") != nil, "host \(host)")
    }
}
