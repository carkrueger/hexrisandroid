#!/usr/bin/env bash
# Automated part of the device checklist in docs/android-release.md, run on an
# emulator by .github/workflows/android.yml. Takes screenshots and dumps state
# into OUT_DIR for a human (or Claude) to review; fails on hard errors (install
# failure, crash, app not in the foreground, wrong orientation behaviour).
#
# Usage: tool/ci/device_checks.sh APK OUT_DIR phone|tablet
set -uo pipefail

APK="$1"
OUT="$2"
FORM="$3"
PKG=com.hexris.hexris
ACTIVITY="$PKG/.MainActivity"
mkdir -p "$OUT"
status=0

log() { echo "== $*" | tee -a "$OUT/checks.log"; }
shot() { adb exec-out screencap -p >"$OUT/$1.png"; log "screenshot $1.png"; }
fail() { log "FAIL: $*"; status=1; }

foreground_ok() {
  adb shell dumpsys activity activities | grep -E 'topResumedActivity|mResumedActivity' \
    | grep -q "$PKG"
}

# Current display size in pixels, after rotation ("W H"). Tablets such as the
# Pixel Tablet are landscape at rotation 0, so this can't be derived from
# `wm size` and the requested rotation.
current_size() {
  adb shell dumpsys window displays | tr -d '\r' \
    | sed -n 's/.* cur=\([0-9]*\)x\([0-9]*\).*/\1 \2/p' | head -1
}

adb shell getprop ro.build.version.sdk >"$OUT/sdk.txt"
adb shell wm size >"$OUT/wm-size.txt"
adb shell wm density >"$OUT/wm-density.txt"
log "API $(tr -d '\r' <"$OUT/sdk.txt"), $(tr -d '\r' <"$OUT/wm-size.txt"), $(tr -d '\r' <"$OUT/wm-density.txt")"

DENS=$(tr -d '\r' <"$OUT/wm-density.txt" | sed -n 's/.*: \([0-9]*\).*/\1/p' | tail -1)
DP=$(awk "BEGIN {print $DENS / 160}")
px() { awk "BEGIN {printf \"%d\", $1 * $DP}"; }

# Drags the first tray piece onto the middle of the board, using the layout
# GameScreen picks for the current size (LayoutConstants in
# lib/utils/constants.dart).
drag_first_piece() {
  local W H
  read -r W H < <(current_size)
  if [ "$W" -gt $((H * 11 / 10)) ]; then
    # Wide: board on the left, side panel (22% of the width, 180-220dp) with
    # the pieces stacked vertically on the right, 16dp from the edge.
    local panel
    panel=$(awk "BEGIN {w = $W / $DP * 0.22; if (w < 180) w = 180; if (w > 220) w = 220; print w}")
    local from_x=$((W - $(px 16) - $(px "$panel / 2")))
    local from_y=$((H * 30 / 100))
    local to_x=$(($(px 16) + (W - $(px "$panel") - $(px 48)) / 2))
    local to_y=$((H * 55 / 100))
    log "wide layout ${W}x${H}: drag ($from_x,$from_y) -> ($to_x,$to_y)"
  else
    # Tall: the tray is a 160dp strip 16dp above the bottom inset, pieces
    # spread evenly across the width.
    local from_x=$((W / 4))
    local from_y=$((H - $(px 48) - $(px 96)))
    local to_x=$((W / 2))
    local to_y=$((H * 45 / 100))
    log "tall layout ${W}x${H}: drag ($from_x,$from_y) -> ($to_x,$to_y)"
  fi
  adb shell input swipe "$from_x" "$from_y" "$to_x" "$to_y" 1500
  sleep 2
}

# Taps the on-screen element whose text or content description is $1, found
# through the accessibility tree (Flutter exposes its semantics to it).
tap_text() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  local xy
  xy=$(adb exec-out cat /sdcard/ui.xml | python3 -c '
import re, sys, xml.etree.ElementTree as ET
want = sys.argv[1]
for n in ET.parse(sys.stdin).iter("node"):
    label = (n.get("text") or "") + "\n" + (n.get("content-desc") or "")
    if any(part.strip() == want for part in label.split("\n")):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds")))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
' "$1")
  if [ -z "$xy" ]; then
    log "tap '$1': not found"
    return 1
  fi
  log "tap '$1' at $xy"
  # shellcheck disable=SC2086
  adb shell input tap $xy
  sleep 1.5
}

is_portrait() {
  local W H
  read -r W H < <(current_size)
  [ "$H" -gt "$W" ]
}

adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb logcat -c

log "install"
adb install -r "$APK" >"$OUT/install.txt" 2>&1 || { fail "install"; cat "$OUT/install.txt"; exit 1; }
adb shell dumpsys package "$PKG" | grep -E 'versionCode|versionName|minSdk|targetSdk' >"$OUT/package.txt"

log "cold start"
adb shell am start -n "$ACTIVITY" >/dev/null
# A few frames over the first seconds, to catch the system splash screen.
for i in 1 2 3; do
  sleep 0.4
  shot "01-splash-$i"
done
sleep 6
shot 02-start
foreground_ok || fail "app not in foreground after launch"
read -r W0 H0 < <(current_size)
log "natural orientation: ${W0}x${H0}"

drag_first_piece
shot 03-after-move

log "back out, kill, relaunch: game should be restored"
adb shell input keyevent KEYCODE_BACK
sleep 2
adb shell am force-stop "$PKG"
sleep 1
adb shell am start -n "$ACTIVITY" >/dev/null
sleep 8
shot 04-restored
foreground_ok || fail "app not in foreground after relaunch"

log "help: Settings > How to Play"
if tap_text "Settings" && tap_text "How to Play"; then
  shot 04a-help
  read -r W H < <(current_size)
  adb shell input swipe $((W / 2)) $((H * 70 / 100)) $((W / 2)) $((H * 30 / 100)) 400
  sleep 1
  shot 04b-help-scrolled
  tap_text "Got it" || adb shell input keyevent KEYCODE_BACK
else
  fail "could not open the help dialog"
  adb shell input keyevent KEYCODE_BACK
fi
sleep 1
foreground_ok || { fail "app left after closing help"; adb shell am start -n "$ACTIVITY" >/dev/null; sleep 6; }

log "request rotation by 90 degrees"
adb shell settings put system user_rotation 1
sleep 4
shot 05-rotated
read -r W1 H1 < <(current_size)
log "size after rotation request: ${W1}x${H1}"
adb shell dumpsys activity activities | grep -iE 'requestedOrientation|mOrientation' | head -5 \
  >"$OUT/requested-orientation.txt" || true
if [ "$FORM" = "phone" ]; then
  # Phones are locked to portrait (lib/utils/orientation_policy.dart).
  is_portrait || fail "phone rotated to landscape; it should stay portrait"
else
  # Tablets rotate freely.
  [ "$W1" = "$H0" ] && [ "$H1" = "$W0" ] || fail "tablet did not rotate"
fi

drag_first_piece
shot 06-rotated-after-move

adb shell settings put system user_rotation 0
sleep 3
shot 07-back-to-rotation-0
foreground_ok || fail "app not in foreground at the end"

adb logcat -d >"$OUT/logcat.txt"
if grep -qE "FATAL EXCEPTION|Fatal signal|ANR in $PKG" "$OUT/logcat.txt"; then
  fail "crash or ANR in logcat"
fi
grep -iE "flutter|audioplayers|$PKG" "$OUT/logcat.txt" | grep -iE 'error|exception|E/' | head -50 \
  >"$OUT/logcat-errors.txt" || true

log "done, status $status"
exit $status
