#!/usr/bin/env bash
# Machine-wide advisory lock serialising iOS Simulator test runs (#1622).
# CoreSimulatorService and SpringBoard are machine-global, so two
# xcodebuild/XCTest runs against DISTINCT simulator devices can still crash
# each other's XCUITests (#1192, measured in #1621) — this lock is the sole
# busy signal now. It replaces check-sim-free.sh's "any booted simulator"
# heuristic, which false-positived on a leftover-but-idle sim nobody shut
# down after an earlier run: a booted device no longer means anything by
# itself, only holding this lock does.
#
# A second caller WAITS rather than refusing outright, since the wait is
# short relative to the cost of an aborted gate and a manual restart
# (#1622). `mkdir` is the lock primitive (atomic on every filesystem this
# runs on) rather than `flock`, which macOS does not ship.
#
# Usage, from a caller that traps EXIT to release:
#   source scripts/ios-sim-lock.sh
#   ios_sim_lock_acquire
#   trap ios_sim_lock_release EXIT
#
# IOS_SIM_LOCK_DIR and IOS_SIM_LOCK_TIMEOUT override the path and wait (in
# seconds) — both for tests, so this can be exercised without a 900s wait.

IOS_SIM_LOCK_DIR="${IOS_SIM_LOCK_DIR:-/tmp/intrada-ios-test.lock}"
IOS_SIM_LOCK_TIMEOUT="${IOS_SIM_LOCK_TIMEOUT:-900}"

ios_sim_lock_acquire() {
    local waited=0 announced=0 holder
    while ! mkdir "$IOS_SIM_LOCK_DIR" 2>/dev/null; do
        holder="$(cat "$IOS_SIM_LOCK_DIR/holder" 2>/dev/null || echo "another session")"
        # A crashed holder (kill -9, a yanked machine) never runs its EXIT
        # trap, so a dead PID means the lock is stale, not held.
        if [ -f "$IOS_SIM_LOCK_DIR/pid" ] \
            && ! kill -0 "$(cat "$IOS_SIM_LOCK_DIR/pid" 2>/dev/null || echo 0)" 2>/dev/null; then
            echo "⚠ stale iOS simulator lock ($holder, holder process gone) — clearing it" >&2
            rm -rf "$IOS_SIM_LOCK_DIR"
            continue
        fi
        if [ "$waited" -ge "$IOS_SIM_LOCK_TIMEOUT" ]; then
            echo "✗ timed out after ${IOS_SIM_LOCK_TIMEOUT}s waiting for the iOS simulator lock, held by $holder" >&2
            return 1
        fi
        if [ "$announced" = 0 ]; then
            echo "… waiting for the iOS simulator lock, held by $holder" >&2
            announced=1
        fi
        sleep 5
        waited=$((waited + 5))
    done
    pwd > "$IOS_SIM_LOCK_DIR/holder"
    echo "$$" > "$IOS_SIM_LOCK_DIR/pid"
}

ios_sim_lock_release() {
    rm -rf "$IOS_SIM_LOCK_DIR"
}
