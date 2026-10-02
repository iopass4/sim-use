// SPDX-License-Identifier: Apache-2.0
import Foundation
import SimUseCore
import Testing

@Suite("AppState — result building")
struct AppStateReportTests {

    private func snap(_ pairs: [Int: String]) -> AppSnapshot { AppSnapshot(appsByPid: pairs) }

    @Test("Lists live apps sorted by bundle id; no query when bundle-id absent")
    func listsAppsSorted() {
        let result = AppStateReport.buildResult(
            platform: "ios",
            snapshot: snap([100: "com.x", 50: "a.b"]),
            bundleId: nil,
            didReset: false
        )
        #expect(result.platform == "ios")
        #expect(result.apps == [AppStateReport.AppProcess(bundleId: "a.b", pid: 50),
                                AppStateReport.AppProcess(bundleId: "com.x", pid: 100)])
        #expect(result.query == nil)
        #expect(result.didReset == false)
    }

    @Test("A queried, live bundle reports running")
    func queriedRunning() {
        let result = AppStateReport.buildResult(
            platform: "android",
            snapshot: snap([100: "com.example.app"]),
            bundleId: "com.example.app",
            didReset: false
        )
        #expect(result.query == AppStateReport.AppStateQuery(bundleId: "com.example.app", state: "running"))
    }

    @Test("A queried, absent bundle reports not_running")
    func queriedNotRunning() {
        let result = AppStateReport.buildResult(
            platform: "ios",
            snapshot: snap([:]),
            bundleId: "com.example.app",
            didReset: false
        )
        #expect(result.query == AppStateReport.AppStateQuery(bundleId: "com.example.app", state: "not_running"))
    }

    @Test("didReset flag is propagated")
    func resetFlag() {
        let result = AppStateReport.buildResult(platform: "ios", snapshot: snap([:]), bundleId: nil, didReset: true)
        #expect(result.didReset == true)
    }
}
@Test func appStateTextFormatting() {
    let empty = AppStateReport.buildResult(platform: "android", snapshot: AppSnapshot(appsByPid: [:]), bundleId: "missing", didReset: true)
    #expect(AppStateReport.format(empty).stdout == "missing: not_running\nNo tracked app processes running.\nCrash-detection baseline reset.\n")
    let live = AppStateReport.buildResult(platform: "android", snapshot: AppSnapshot(appsByPid: [12: "app"]), bundleId: nil, didReset: false)
    #expect(AppStateReport.format(live).stdout == "Running apps (1):\n  app  pid=12\n")
}
