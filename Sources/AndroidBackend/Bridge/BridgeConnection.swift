// SPDX-License-Identifier: Apache-2.0
import Foundation
import SimUseCore

/// Where this process's bridge traffic goes: the adb server that owns
/// the `adb forward`, and the host that forward listens on.
///
/// Both come from the environment (`ADB_SERVER_SOCKET` and friends, which
/// `adb` itself reads, plus `SIM_USE_BRIDGE_HOST`), so two invocations
/// for the same serial can target different adb servers. Anything cached
/// per serial — a persisted `BridgeSession`, a warm daemon — is only
/// valid for the connection it was created under; `identity` is what
/// those caches record and compare.
public struct BridgeConnection: Equatable, Sendable {
    /// The canonical adb server `adb` will talk to: the
    /// `ADB_SERVER_SOCKET` spec, else `ANDROID_ADB_SERVER_ADDRESS` /
    /// `ANDROID_ADB_SERVER_PORT`, else the local server on port 5037.
    public let adbServer: String
    /// Host the bridge's forwarded port is reached on.
    public let bridgeHost: String

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        func value(_ key: String) -> String? {
            guard let raw = environment[key], !raw.isEmpty else { return nil }
            return raw
        }
        if let socket = value("ADB_SERVER_SOCKET") {
            adbServer = Self.normalizeAdbServer(socket)
        } else if value("ANDROID_ADB_SERVER_ADDRESS") != nil || value("ANDROID_ADB_SERVER_PORT") != nil {
            adbServer = Self.normalizeAdbServer("tcp:\(value("ANDROID_ADB_SERVER_ADDRESS") ?? "localhost"):\(value("ANDROID_ADB_SERVER_PORT") ?? "5037")")
        } else {
            adbServer = Self.normalizeAdbServer("default")
        }
        bridgeHost = Self.resolveBridgeHost(environment: environment)
    }

    /// Equal adb servers need equal identities so switching equivalent specs
    /// neither restarts the daemon nor orphans a forward.
    static func normalizeAdbServer(_ spec: String) -> String {
        if spec == "default" { return "tcp:localhost:5037" }
        guard spec.hasPrefix("tcp:") else { return spec }
        let rest = spec.dropFirst(4)
        let host: String
        let portText: String
        if let separator = rest.lastIndex(of: ":") {
            host = String(rest[..<separator])
            portText = String(rest[rest.index(after: separator)...])
        } else {
            host = "localhost"
            portText = String(rest)
        }
        guard !portText.isEmpty, portText.allSatisfy({ $0.isASCII && $0.isNumber }),
              let port = Int(portText), (1...65535).contains(port), !host.isEmpty else { return spec }
        let bare = (host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host).lowercased()
        let canonicalHost: String
        if ["localhost", "127.0.0.1", "::1"].contains(bare) {
            canonicalHost = "localhost"
        } else if bare.contains(":") {
            canonicalHost = "[\(bare)]"
        } else {
            canonicalHost = bare
        }
        return "tcp:\(canonicalHost):\(port)"
    }

    /// `adb forward tcp:0 tcp:8080` opens its local socket on the machine
    /// running the **adb server**, which is only this machine when the
    /// server is local. When `ADB_SERVER_SOCKET` points at a remote server
    /// (`tcp:<host>:<port>` — e.g. WSL using the Windows host's adb so USB
    /// devices stay visible), the forward listens over there and loopback
    /// has nothing behind it, so the bridge host follows that server.
    /// `ANDROID_ADB_SERVER_ADDRESS` selects the host when no socket is set.
    /// `SIM_USE_BRIDGE_HOST` overrides both. The result is ready to
    /// interpolate into a URL authority: IPv6 hosts come back bracketed,
    /// with any zone id's `%` escaped.
    static func resolveBridgeHost(environment: [String: String]) -> String {
        let loopback = "127.0.0.1"
        let host: String
        if let explicit = environment["SIM_USE_BRIDGE_HOST"], !explicit.isEmpty {
            host = explicit
        } else if let socket = environment["ADB_SERVER_SOCKET"], !socket.isEmpty {
            guard socket.hasPrefix("tcp:") else { return loopback }
            // "tcp:<port>" is a local server; only "tcp:<host>:<port>" is remote.
            let rest = socket.dropFirst("tcp:".count)
            guard let separator = rest.lastIndex(of: ":") else { return loopback }
            host = String(rest[..<separator])
        } else if let address = environment["ANDROID_ADB_SERVER_ADDRESS"], !address.isEmpty {
            host = address
        } else {
            return loopback
        }
        let bare = host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host
        if bare.isEmpty || bare == "localhost" || bare == "127.0.0.1" || bare == "::1" {
            return loopback
        }
        guard bare.contains(":") else { return bare }
        return "[\(bare.replacingOccurrences(of: "%", with: "%25"))]"
    }

    /// Stable string recorded by persisted sessions and reported by
    /// daemons; equal identities mean the same adb server and bridge host.
    public var identity: String {
        "adb=\(adbServer) host=\(bridgeHost)"
    }

    /// The connection identity a per-device daemon for `udid` depends on:
    /// none for iOS simulator and device UDIDs, the adb connection for
    /// everything else. Scoping is decided by excluding iOS shapes rather
    /// than by `PlatformRouter.looksLikeAndroid`, whose heuristic rejects
    /// real adb serials (wireless-debugging mDNS serials exceed its
    /// 32-character cap) that still reach a daemon. Entry points install
    /// this as `DaemonClient.connectionIdentityProvider`.
    public static func daemonConnectionIdentity(
        udid: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let trimmed = udid.trimmingCharacters(in: .whitespacesAndNewlines)
        if PlatformRouter.looksLikeIOSSim(trimmed) || PlatformRouter.looksLikePhysicalIOSDevice(trimmed) {
            return nil
        }
        return BridgeConnection(environment: environment).identity
    }
}
