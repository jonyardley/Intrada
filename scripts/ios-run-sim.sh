#!/usr/bin/env bash
# Build the native iOS app, launch it on a simulator, and screenshot.
# Assumes the Xcode project + generated packages already exist (the `ios-run`
# just recipe runs `_ios-sync` + xcodegen first). Reused by CI in A5.
#
# Usage: scripts/ios-run-sim.sh [screenshot-path]
set -euo pipefail

cd "$(dirname "$0")/../ios"

APP_ID="com.intrada.native"
DD="build/dd"
SHOT="${1:-/tmp/intrada-native.png}"
mkdir -p "$(dirname "$SHOT")"

# Pick a simulator deterministically (the old `devs[-1]` depended on JSON
# ordering, so device/arch drifted between machines — #854). Prefer the device
# CI pins (overridable via SIM_DEVICE) on the highest installed iOS; fall back
# to the newest available iPhone. Stable udid tie-break keeps repeated runs
# identical.
SIM_DEVICE="${SIM_DEVICE:-iPhone 16}"
UDID=$(xcrun simctl list devices available --json | python3 -c "
import json, re, sys
want = sys.argv[1]
runtimes = json.load(sys.stdin)['devices']
def ver(key):
    m = re.search(r'iOS-(\d+)-(\d+)', key)
    return (int(m.group(1)), int(m.group(2))) if m else (-1, -1)
cands = [
    (dev['name'] == want, ver(key), dev['udid'])
    for key, devices in runtimes.items() if 'iOS' in key
    for dev in devices if 'iPhone' in dev['name']
]
print(max(cands)[2] if cands else '')
" "$SIM_DEVICE")
if [ -z "$UDID" ]; then
    echo "✗ No iPhone simulator available (Xcode → Settings → Platforms → iOS)" >&2
    exit 1
fi

# Wait for the boot to finish: an install landing while SpringBoard is still
# starting leaves the app refusing every launch as "Busy" (#1648).
xcrun simctl bootstatus "$UDID" -b

# REUSE_BUILD=1 reuses an existing build/dd .app (e.g. CI, right after the
# snapshot-test step already built it) — avoids a second xcodebuild. Local
# `just ios-run` leaves it unset and always builds fresh.
if [ -z "${REUSE_BUILD:-}" ]; then
    echo "building…"
    xcodebuild -project Intrada.xcodeproj -scheme Intrada -sdk iphonesimulator \
        -destination "id=$UDID" -derivedDataPath "$DD" -configuration Debug \
        build CODE_SIGNING_ALLOWED=NO >/tmp/ios-build.log 2>&1 || {
        echo "✗ build failed:" >&2
        grep -E "error:" /tmp/ios-build.log | tail -20 >&2
        exit 1
    }
fi

APP=$(find "$DD/Build/Products" -name "Intrada.app" -type d | head -1)
[ -n "$APP" ] || { echo "✗ no Intrada.app in $DD (build first)" >&2; exit 1; }
xcrun simctl install "$UDID" "$APP"
# Seed the core's demo dataset so the screenshot shows a populated app.
# Override with SEED=0 to launch against the empty/real-data state.
LAUNCH_ARGS=()
[ "${SEED:-1}" = "1" ] && LAUNCH_ARGS+=(--seed-sample-data)
# `${arr[@]+...}` guards the empty-array case under `set -u` on bash 3.2 (macOS).
xcrun simctl launch "$UDID" "$APP_ID" "${LAUNCH_ARGS[@]+"${LAUNCH_ARGS[@]}"}" >/dev/null
sleep 3
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null
echo "✓ launched on $UDID — screenshot: $SHOT"
