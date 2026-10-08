// SPDX-License-Identifier: Apache-2.0

/// Help text for `long-press`, shared by the macOS cross-platform command and
/// the Android one the Linux build registers, so their `--help` cannot drift.
public enum LongPressHelp {
    public static let abstract = "Long-press an element by alias, selector, or coordinate (default hold 0.8s)."
    public static let discussion = """
        Sugar over `sim-use tap --duration <seconds>` with `--duration`
        defaulting to 0.8s, the standard threshold that triggers
        long-press recognisers on both iOS and Android (above
        `UILongPressGestureRecognizer.minimumPressDuration` and
        `ViewConfiguration.getLongPressTimeout()`). Useful for
        chat-bubble action menus, launcher icon popups, and any UI
        where the action-press distinction matters.

        Targeting is identical to `tap` — same alias / selector /
        coordinate forms, same precedence, same describe-ui cache.
        See `sim-use tap --help` for the full workflow walkthrough;
        every targeting form documented there works here, just with
        a longer default hold.

        Examples:
          sim-use describe-ui                                         # populate the outline cache
          sim-use long-press @5                                       # 0.8s hold on outline entry 5
          sim-use long-press '#3'                                     # long-press the 3rd cell of the dominant list
          sim-use long-press --label "Photos"                         # exact AXLabel
          sim-use long-press --label-contains "メキシコ" --element-type Button   # substring + type filter
          sim-use long-press --label-regex '^[0-9]{1,2}:[0-9]{2}(\\s(AM|PM))?$'   # anchored regex (timestamp labels)
          sim-use long-press -x 540 -y 1268 --duration 1.2            # custom hold, raw coordinates
        """
    public static let alias = "Shortcut alias for the element to long-press. `@N` selects the N-th entry of the most recent `describe-ui` snapshot; `#N` selects the N-th cell of the dominant detected list; `#N@M` selects the N-th cell of the M-th list (1-indexed, M=1 = dominant); `#<id>` resolves an AXUniqueId via the live AX tree. Exclusive with --point/-x/-y and --id/--label/--value."
    public static let duration = "How long to hold the touch in seconds. Defaults to 0.8 — clears the OS long-press threshold on both iOS (~0.5s) and Android (~0.5s) with margin. Increase if a stubborn recogniser needs more time; values above 10s are rejected."
}
