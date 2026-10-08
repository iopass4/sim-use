// SPDX-License-Identifier: Apache-2.0
import SimUseCore

/// Rejects iOS identifiers on Android commands that take the shared
/// cross-platform flag surface, before they reach adb.
enum AndroidCommandDeviceValidation {
    static func requireAndroid(serial: String, verb: String) throws {
        guard !PlatformRouter.looksLikeIOSSim(serial),
              !PlatformRouter.looksLikePhysicalIOSDevice(serial) else {
            throw CLIError(errorDescription: "\(verb) in the Android backend drives Android only; pass an adb serial.")
        }
    }
}
