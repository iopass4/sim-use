// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Diagnostics for commands excluded from the Android-only Linux build.
public enum LinuxBuildVerbRedirects {
    private static let videoCaptureHint = "Use the macOS build for video capture."
    private static let videoStreamingHint = "Use the macOS build for video streaming."

    /// Keyed by command path: the macOS build also offers the video verbs
    /// under `sim-use android`, which would otherwise fail on Linux with an
    /// "Unknown option" error from the `android` namespace.
    private static let hints: [[String]: String] = [
        ["ios"]: "The Linux build drives Android only.",
        ["ios-device"]: "The Linux build drives Android only.",
        ["record-video"]: videoCaptureHint,
        ["stream-video"]: videoStreamingHint,
        ["viewer"]: "Use the macOS build for the Viewer.",
        ["init"]: "Copy skills/sim-use/ by hand to install the skill; use `sim-use android init` to set up an Android device.",
        ["android", "record-video"]: videoCaptureHint,
        ["android", "stream-video"]: videoStreamingHint,
    ]

    /// Returns the diagnostic for `arguments` (the command line without the
    /// executable) when they name an excluded command, else `nil`.
    public static func message(for arguments: [String]) -> String? {
        for length in [2, 1] where arguments.count >= length {
            let command = Array(arguments.prefix(length))
            if let hint = hints[command] {
                let name = command.joined(separator: " ")
                return "Error: `sim-use \(name)` is not available in the Linux build (Android only).\nHint: \(hint)\n"
            }
        }
        return nil
    }
}
