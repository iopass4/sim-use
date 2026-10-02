// SPDX-License-Identifier: Apache-2.0
import ArgumentParser
import Foundation
import SimUseCore

/// Android implementation shared by the Linux root and macOS forwarder.
public struct AndroidLongPressCommand: SimUseExecutableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "long-press",
        abstract: LongPressHelp.abstract,
        discussion: LongPressHelp.discussion
    )

    @Argument(help: ArgumentHelp(
        LongPressHelp.alias,
        valueName: "alias"
    ))
    public var alias: String?

    @OptionGroup public var targeting: TapTargetingOptions

    @Option(
        name: .customLong("duration"),
        help: ArgumentHelp(
            LongPressHelp.duration
        )
    )
    public var duration: Double = 0.8

    @OptionGroup public var timing: TapTimingOptions

    @OptionGroup public var multiTouch: MultiTouchOptions

    @OptionGroup public var device: AndroidDeviceOptions

    @OptionGroup public var json: JSONOutputOptions

    public var jsonOutput: Bool { json.enabled }

    public mutating func resolveDeferredArguments() throws {
        try device.resolve()
        try AndroidCommandDeviceValidation.requireAndroid(serial: device.resolved, verb: "long-press")
    }

    public var simulatorUDIDForDaemon: String? { device.resolved }

    /// Android emits only the x/y keys of the iOS tap result, as doubles.
    public struct ExecutionResult: Codable {
        public let x: Double
        public let y: Double
    }

    /// Same shared group validators as `Tap` / `IOSSimTapCommand` —
    /// same selector / coordinate / delay constraints apply, and the
    /// duration default (0.8) is in the [0, 10] range so the validator
    /// accepts it. ArgumentParser does not auto-validate nested option
    /// groups, so these explicit calls are load-bearing
    /// (`TapValidationParityTests` pins that every surface makes them).
    public func validate() throws {
        try targeting.validate(alias: alias)
        try timing.validate()
        try TapTimingOptions.validateDuration(duration)
        try multiTouch.validate()
    }

    public init() {}

    public func execute() async throws -> ExecutionResult {
        try Self.performLongPress(
            serial: device.resolved, alias: alias, targeting: targeting,
            duration: duration, multiTouch: multiTouch
        )
    }

    public func format(_ result: ExecutionResult) -> CommandOutput {
        .line("✓ Long-press at (\(result.x), \(result.y)) completed successfully")
    }

    /// Preserve the existing Android path: timing flags are validated by
    /// the command but do not introduce delays or selector polling here.
    public static func performLongPress(
        serial: String,
        alias: String?,
        targeting: TapTargetingOptions,
        duration: Double,
        multiTouch: MultiTouchOptions
    ) throws -> ExecutionResult {
        let frameFilter: SelectorFrameFilter? = {
            guard !targeting.frameSpecs.isEmpty else { return nil }
            return (try? SelectorFrameFilter(specs: targeting.frameSpecs))
        }()
        let selector = AndroidSelector(
            id: targeting.elementID,
            label: targeting.elementLabel,
            labelContains: targeting.labelContains,
            labelRegex: targeting.labelRegex,
            value: targeting.elementValue,
            valueContains: nil,
            valueRegex: nil,
            elementType: targeting.elementType,
            frame: frameFilter
        )
        let explicit = try TapCoordinateResolver.resolve(x: targeting.pointX, y: targeting.pointY, point: targeting.point)
        let result = try AndroidTapCommand.performTap(
            udid: serial,
            alias: alias,
            x: explicit.map { Int($0.x.rounded()) },
            y: explicit.map { Int($0.y.rounded()) },
            selector: selector,
            duration: duration,
            multiTouch: multiTouch
        )
        return ExecutionResult(x: Double(result.x), y: Double(result.y))
    }
}
