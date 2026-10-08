// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Shared app-state result mapping and formatting for macOS and Linux/Android
/// commands, keeping their JSON representation identical.
public enum AppStateReport {
    public struct AppProcess: Codable, Equatable {
        public let bundleId: String
        public let pid: Int

        public init(bundleId: String, pid: Int) {
            self.bundleId = bundleId
            self.pid = pid
        }
    }

    public struct AppStateQuery: Codable, Equatable {
        public let bundleId: String
        /// "running" | "not_running". Liveness only — the
        /// foreground-vs-background distinction needs foreground info the
        /// lightweight probe does not carry and is left to describe-ui.
        public let state: String

        public init(bundleId: String, state: String) {
            self.bundleId = bundleId
            self.state = state
        }
    }

    public struct ExecutionResult: Codable, Equatable {
        public let platform: String
        public let apps: [AppProcess]
        public let query: AppStateQuery?
        public let didReset: Bool
    }

    /// Pure snapshot → result mapping. Exposed for tests.
    public static func buildResult(
        platform: String,
        snapshot: AppSnapshot,
        bundleId: String?,
        didReset: Bool
    ) -> ExecutionResult {
        let apps = snapshot.appsByPid
            .map { AppProcess(bundleId: $0.value, pid: $0.key) }
            .sorted { $0.bundleId < $1.bundleId }
        let query: AppStateQuery? = bundleId.map { id in
            let state: String
            switch snapshot.liveness(ofBundleId: id) {
            case .alive: state = "running"
            case .dead: state = "not_running"
            }
            return AppStateQuery(bundleId: id, state: state)
        }
        return ExecutionResult(platform: platform, apps: apps, query: query, didReset: didReset)
    }

    public static func format(_ result: ExecutionResult) -> CommandOutput {
        var lines: [String] = []
        if let query = result.query {
            lines.append("\(query.bundleId): \(query.state)")
        }
        if result.apps.isEmpty {
            lines.append("No tracked app processes running.")
        } else {
            lines.append("Running apps (\(result.apps.count)):")
            for app in result.apps {
                lines.append("  \(app.bundleId)  pid=\(app.pid)")
            }
        }
        if result.didReset {
            lines.append("Crash-detection baseline reset.")
        }
        return .lines(lines)
    }
}

/// Help text for `app-state`, shared like `LongPressHelp`.
public enum AppStateHelp {
    public static let abstract = "Report which apps are running on the device; --reset re-baselines crash detection."
    public static let bundleId = "Report running|not_running for this bundle id / package only."
    public static let reset = "Re-baseline crash detection to the current process set and clear any pending crash signal. Use after intentionally relaunching the app, attaching to an already-running app, or accepting a crash."
}
