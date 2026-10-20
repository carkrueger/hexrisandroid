#!/usr/bin/env bash
# Automated part of the device checklist in docs/android-release.md, run on an
# emulator by .github/workflows/android.yml. Takes screenshots and dumps state
# into OUT_DIR for a human (or Claude) to review; fails only on hard errors
# (install failure, crash, app not in the foreground).
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

adb shell getprop ro.build.version.sdk >"$OUT/sdk.txt"
adb shell wm size >"$OUT/wm-size.txt"
adb shell wm density >"$OUT/wm-density.txt"
log "API $(tr -d '\r' <"$OUT/sdk.txt"), $(tr -d '\r' <"$OUT/wm-size.txt"), $(tr -d '\r' <"$OUT/wm-density.txt")"

# Physical size and density, for the drag coordinates below.
read -r W H < <(tr -d '\r' <"$OUT/wm-size.txt" | sed -n 's/.*: \([0-9]*\)x\([0-9]*\).*/\1 \2/p' | tail -1)
DENS=$(tr -d '\r' <"$OUT/wm-density.txt" | sed -n 's/.*: \([0-9]*\).*/\1/p' | tail -1)
DP=$(awk "BEGIN {print $DENS / 160}")
px() { awk "BEGIN {printf \"%d\", $1 * $DP}"; }

adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb logcat -c

log "install"
adb install -r "$APK" >"$OUT/install.txt" 2>&1 || { fail "install"; cat "$OUT/install.txt"; exit 1; }
adb shell dumpsys package "$PKG" | grep -E 'versionCode|versionName|minSdk|targetSdk' >"$OUT/package.txt"

log "cold start"
adb shell am start -n "$ACTIVITY" >/dev/null
sleep 0.6
shot 01-splash
sleep 8
shot 02-portrait
foreground_ok || fail "app not in foreground after launch"

# Drag the first tray piece onto the board (tall layout: tray is a 160dp strip
# 16dp above the bottom inset; pieces are spread evenly across the width).
NAV=$(px 48)
TRAY_Y=$((H - NAV - $(px 96)))
log "drag piece from ($((W / 4)),$TRAY_Y) to ($((W / 2)),$((H * 45 / 100)))"
adb shell input swipe $((W / 4)) "$TRAY_Y" $((W / 2)) $((H * 45 / 100)) 1500
sleep 2
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

log "rotate to landscape"
adb shell settings put system user_rotation 1
sleep 4
shot 05-landscape
adb shell dumpsys window | grep -iE 'mCurrentRotation|mRotation=' | head -3 >"$OUT/rotation-landscape.txt"
adb shell dumpsys activity activities | grep -iE 'requestedOrientation|mOrientation' | head -5 \
  >"$OUT/requested-orientation.txt" || true

if [ "$FORM" = "tablet" ]; then
  # Wide layout: the tray is a vertical side panel on the right.
  read -r LW LH <<<"$H $W"
  PANEL_X=$((LW - $(px 16) - $(px 100)))
  log "landscape drag from ($PANEL_X,$((LH / 3))) to ($((LW * 40 / 100)),$((LH / 2)))"
  adb shell input swipe "$PANEL_X" $((LH / 3)) $((LW * 40 / 100)) $((LH / 2)) 1500
  sleep 2
  shot 06-landscape-after-move
fi

adb shell settings put system user_rotation 0
sleep 3
shot 07-back-to-portrait
foreground_ok || fail "app not in foreground at the end"

adb logcat -d >"$OUT/logcat.txt"
if grep -qE "FATAL EXCEPTION|Fatal signal|ANR in $PKG" "$OUT/logcat.txt"; then
  fail "crash or ANR in logcat"
fi
grep -iE "flutter|audioplayers|$PKG" "$OUT/logcat.txt" | grep -iE 'error|exception|E/' | head -50 \
  >"$OUT/logcat-errors.txt" || true

log "done, status $status"
exit $status
