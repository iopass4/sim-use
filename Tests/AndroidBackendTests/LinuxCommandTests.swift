// SPDX-License-Identifier: Apache-2.0
import AndroidBackend
import ArgumentParser
import Foundation
import SimUseCore
import Testing

@Suite("Linux Android command surfaces")
struct LinuxCommandTests {
    @Test func longPressDefaultsAndFlags() throws {
        let defaults = try AndroidLongPressCommand.parse(["@5", "--device", "emulator-5554"])
        #expect(defaults.duration == 0.8)
        #expect(defaults.alias == "@5")
        let command = try AndroidLongPressCommand.parse([
            "--label-contains", "foo", "--element-type", "Button", "--frame", "minY=0.5r",
            "--duration", "1.2", "--pre-delay", "0.1", "--post-delay", "0.2",
            "--wait-timeout", "1", "--poll-interval", "0.5", "--fingers", "2",
            "--finger-distance", "30", "--device", "emulator-5554", "--json",
        ])
        #expect(command.duration == 1.2)
        #expect(command.timing.preDelay == 0.1)
        #expect(command.multiTouch.fingers == 2)
        #expect(command.jsonOutput)
    }

    @Test func longPressRejectsInvalidArguments() {
        for argv in [
            ["@1", "--label", "foo"], ["-x", "1"], ["--label", "a", "--duration", "11"],
            ["--label", "a", "--pre-delay", "11"], ["--label", "a", "--post-delay", "11"],
            ["--label", "a", "--wait-timeout=-1"],
            ["--label", "a", "--wait-timeout", "1", "--poll-interval", "0"],
            ["--label", "a", "--fingers", "3"],
        ] {
            #expect(throws: (any Error).self) { _ = try AndroidLongPressCommand.parse(argv) }
        }
    }

    @Test func appStateFlags() throws {
        let defaults = try AndroidAppStateCommand.parse([])
        #expect(!defaults.reset)
        #expect(defaults.bundleId == nil)
        var command = try AndroidAppStateCommand.parse([
            "--device", "emulator-5554", "--bundle-id", "com.example", "--reset", "--json",
        ])
        try command.resolveDeferredArguments()
        #expect(command.simulatorUDIDForDaemon == "emulator-5554")
        #expect(command.bundleId == "com.example")
        #expect(command.reset && command.jsonOutput && command.managesLivenessState)
    }

    /// Resolve deferred device arguments without executing or contacting a device.
    private func resolutionFailure<C: SimUseExecutableCommand>(
        _ type: C.Type, _ argv: [String]
    ) throws -> String? {
        var command = try type.parse(argv)
        do {
            try command.resolveDeferredArguments()
            return nil
        } catch {
            return type.message(for: error)
        }
    }

    @Test func missingDeviceRequiresADBSerial() throws {
        let messages = [
            try resolutionFailure(AndroidLongPressCommand.self, ["@1"]),
            try resolutionFailure(AndroidAppStateCommand.self, []),
        ]
        for message in messages {
            #expect(message?.contains("Pass --device <serial>") == true)
            #expect(message?.contains("simctl") == false)
        }
    }

    @Test func bothCommandsRejectIOSIdentifiers() throws {
        for serial in ["9CD7C6E7-45B3-4E59-BBF2-4D12A9457CD0", "00008130-00066D2A10EB8D3A"] {
            // Both flag spellings must reach the same deferred validation.
            for flag in ["--device", "--udid"] {
                #expect(try resolutionFailure(
                    AndroidLongPressCommand.self, ["@1", flag, serial]
                ) == "long-press in the Android backend drives Android only; pass an adb serial.")
                #expect(try resolutionFailure(
                    AndroidAppStateCommand.self, [flag, serial]
                ) == "app-state in the Android backend drives Android only; pass an adb serial.")
            }
        }
    }

    @Test func bothCommandsAcceptMDNSSerial() throws {
        let serial = "adb-R5CT1234567-AbCdEf._adb-tls-connect._tcp"
        for flag in ["--device", "--udid"] {
            var longPress = try AndroidLongPressCommand.parse(["@1", flag, serial])
            var appState = try AndroidAppStateCommand.parse([flag, serial])
            try longPress.resolveDeferredArguments()
            try appState.resolveDeferredArguments()
            #expect(longPress.simulatorUDIDForDaemon == serial)
            #expect(appState.simulatorUDIDForDaemon == serial)
        }
    }

    @Test func longPressJSONShape() throws {
        let result = try JSONDecoder().decode(AndroidLongPressCommand.ExecutionResult.self, from: Data("{\"x\":1.5,\"y\":2.5}".utf8))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(String(decoding: try encoder.encode(result), as: UTF8.self) == "{\"x\":1.5,\"y\":2.5}")
        let command = try AndroidLongPressCommand.parse(["@1"])
        #expect(command.format(result).stdout == "✓ Long-press at (1.5, 2.5) completed successfully\n")
    }
}
