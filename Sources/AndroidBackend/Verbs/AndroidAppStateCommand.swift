// SPDX-License-Identifier: Apache-2.0
import ArgumentParser
import Foundation
import SimUseCore

/// Android implementation shared by the Linux root and macOS forwarder.
public struct AndroidAppStateCommand: SimUseExecutableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "app-state",
        abstract: AppStateHelp.abstract
    )

    @OptionGroup public var device: AndroidDeviceOptions

    @Option(
        name: .customLong("bundle-id"),
        help: ArgumentHelp(
            AppStateHelp.bundleId,
            valueName: "id"
        )
    )
    public var bundleId: String?

    @Flag(
        name: .customLong("reset"),
        help: ArgumentHelp(AppStateHelp.reset)
    )
    public var reset: Bool = false

    @OptionGroup public var json: JSONOutputOptions

    public var jsonOutput: Bool { json.enabled }

    public var simulatorUDIDForDaemon: String? { device.resolved }

    public var managesLivenessState: Bool { true }

    public mutating func resolveDeferredArguments() throws {
        try device.resolve()
        try AndroidCommandDeviceValidation.requireAndroid(serial: device.resolved, verb: "app-state")
    }

    public init() {}

    public typealias ExecutionResult = AppStateReport.ExecutionResult

    public func execute() async throws -> ExecutionResult {
        try Self.performAppState(serial: device.resolved, bundleId: bundleId, reset: reset)
    }

    public static func performAppState(
        serial: String,
        bundleId: String?,
        reset: Bool
    ) throws -> ExecutionResult {
        guard let snapshot = AndroidProcessLister.appSnapshot(serial: serial) else {
            throw CLIError(errorDescription:
                "Could not read the running-process list from \(serial). " +
                "The device may be busy, mid-boot, or disconnected — retry in a moment.")
        }
        if reset {
            DaemonDispatch.processTracker.reset(to: snapshot, now: Date())
        }
        return AppStateReport.buildResult(
            platform: "android", snapshot: snapshot, bundleId: bundleId, didReset: reset
        )
    }

    public func format(_ result: ExecutionResult) -> CommandOutput {
        AppStateReport.format(result)
    }
}
