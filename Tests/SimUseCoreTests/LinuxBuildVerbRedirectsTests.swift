// SPDX-License-Identifier: Apache-2.0
import SimUseCore
import Testing

@Test func linuxVerbDiagnostics() {
    for verb in ["ios", "ios-device", "record-video", "stream-video", "viewer", "init"] {
        let message = LinuxBuildVerbRedirects.message(for: verb)
        #expect(message?.contains("`sim-use \(verb)`") == true)
        #expect(message?.contains("not available in the Linux build (Android only)") == true)
    }
    for verb in ["app-state", "long-press", "android", "tap", "--help", "unknown"] {
        #expect(LinuxBuildVerbRedirects.message(for: verb) == nil)
    }
    #expect(LinuxBuildVerbRedirects.message(for: "init")?.contains("Copy skills/sim-use/ by hand") == true)
}
