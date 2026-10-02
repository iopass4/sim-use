// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Diagnostics for commands excluded from the Android-only Linux build.
public enum LinuxBuildVerbRedirects {
    private static let hints: [String: String] = [
        "ios": "The Linux build drives Android only.",
        "ios-device": "The Linux build drives Android only.",
        "record-video": "Use the macOS build for video capture.",
        "stream-video": "Use the macOS build for video streaming.",
        "viewer": "Use the macOS build for the Viewer.",
        "init": "Copy skills/sim-use/ by hand to install the skill; use `sim-use android init` to set up an Android device.",
    ]

    public static func message(for verb: String) -> String? {
        guard let hint = hints[verb] else { return nil }
        return "Error: `sim-use \(verb)` is not available in the Linux build (Android only).\nHint: \(hint)\n"
    }
}
