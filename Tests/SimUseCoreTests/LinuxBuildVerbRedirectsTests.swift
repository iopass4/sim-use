// SPDX-License-Identifier: Apache-2.0
import SimUseCore
import Testing

@Test func linuxVerbDiagnostics() {
    let excluded = [
        ["ios"], ["ios-device"], ["record-video"], ["stream-video"], ["viewer"], ["init"],
        ["android", "record-video"], ["android", "stream-video"],
    ]
    for command in excluded {
        let message = LinuxBuildVerbRedirects.message(for: command + ["--device", "emulator-5554"])
        #expect(message?.contains("`sim-use \(command.joined(separator: " "))`") == true)
        #expect(message?.contains("not available in the Linux build (Android only)") == true)
    }
    let available = [
        ["app-state"], ["long-press"], ["tap"], ["--help"], ["unknown"], [],
        ["android"], ["android", "init"], ["android", "tap"], ["android", "--help"],
    ]
    for arguments in available {
        #expect(LinuxBuildVerbRedirects.message(for: arguments) == nil)
    }
    #expect(LinuxBuildVerbRedirects.message(for: ["init"])?.contains("Copy skills/sim-use/ by hand") == true)
    #expect(LinuxBuildVerbRedirects.message(for: ["android", "record-video"])?.contains("video capture") == true)
}
