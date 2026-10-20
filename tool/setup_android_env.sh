#!/usr/bin/env bash
# Sets up a Linux machine (e.g. a Claude cloud runner) to build the Hexris
# Android app. Safe to re-run: every step is skipped when already installed.
#
# Needs outbound network access to:
#   github.com                (Flutter SDK)
#   storage.googleapis.com    (Flutter engine artifacts, Dart SDK)
#   dl.google.com             (Android command-line tools, SDK packages)
#   pub.dev                   (Dart packages)
#   services.gradle.org, maven.google.com, repo.maven.apache.org,
#   plugins.gradle.org        (Gradle and Android build dependencies)
#
# Usage:
#   tool/setup_android_env.sh
#   source "$HOME/.hexris-android-env"   # in every new shell
#
# Overridable environment variables:
#   FLUTTER_VERSION   pinned Flutter tag (keep in sync with docs/android-release.md)
#   FLUTTER_HOME      where Flutter is cloned        (default: $HOME/flutter)
#   ANDROID_HOME      where the Android SDK lives    (default: $HOME/android-sdk)
#   CMDLINE_TOOLS_BUILD  build number of the cmdline-tools zip on dl.google.com
#   SKIP_EMULATOR=1   don't install the emulator or create AVDs even with KVM

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.9}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
CMDLINE_TOOLS_BUILD="${CMDLINE_TOOLS_BUILD:-13114758}"

ANDROID_PLATFORM="platforms;android-36"
ANDROID_BUILD_TOOLS="build-tools;36.0.0"
# Matches flutter.ndkVersion for Flutter 3.41 (AGP uses it to strip native libs).
ANDROID_NDK="ndk;28.2.13676358"
EMULATOR_IMAGE="system-images;android-36;google_apis;x86_64"

ENV_FILE="$HOME/.hexris-android-env"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

sudo_if_needed() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# --- 1. JDK 17+ --------------------------------------------------------------
java_major() {
  java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print v[1]; exit}'
}

if command -v java >/dev/null 2>&1 && [ "$(java_major)" -ge 17 ]; then
  log "JDK $(java_major) already installed"
else
  log "Installing OpenJDK 17"
  sudo_if_needed apt-get update -qq
  sudo_if_needed apt-get install -y -qq openjdk-17-jdk-headless unzip curl git
fi
for tool in unzip curl git; do
  command -v "$tool" >/dev/null 2>&1 || {
    sudo_if_needed apt-get update -qq
    sudo_if_needed apt-get install -y -qq "$tool"
  }
done

# --- 2. Flutter (pinned tag) -------------------------------------------------
if [ -d "$FLUTTER_HOME/.git" ]; then
  current="$(git -C "$FLUTTER_HOME" describe --tags --exact-match 2>/dev/null || true)"
  if [ "$current" != "$FLUTTER_VERSION" ]; then
    log "Switching Flutter from '${current:-unknown}' to $FLUTTER_VERSION"
    git -C "$FLUTTER_HOME" fetch --depth 1 origin "refs/tags/$FLUTTER_VERSION:refs/tags/$FLUTTER_VERSION"
    git -C "$FLUTTER_HOME" checkout --quiet "$FLUTTER_VERSION"
  else
    log "Flutter $FLUTTER_VERSION already installed"
  fi
else
  log "Cloning Flutter $FLUTTER_VERSION into $FLUTTER_HOME"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
export PATH="$FLUTTER_HOME/bin:$PATH"

# --- 3. Android SDK ----------------------------------------------------------
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

if [ -x "$SDKMANAGER" ]; then
  log "Android cmdline-tools already installed"
else
  log "Installing Android cmdline-tools ($CMDLINE_TOOLS_BUILD)"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/cmdline-tools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
fi
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

log "Accepting Android SDK licenses"
yes | "$SDKMANAGER" --licenses >/dev/null || true

packages=(platform-tools "$ANDROID_PLATFORM" "$ANDROID_BUILD_TOOLS" "$ANDROID_NDK")

# --- 4. Emulator (only with hardware acceleration) ---------------------------
HAVE_KVM=0
if [ "${SKIP_EMULATOR:-0}" = "1" ]; then
  log "SKIP_EMULATOR=1: skipping emulator"
elif [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  HAVE_KVM=1
  packages+=(emulator "$EMULATOR_IMAGE")
else
  log "No usable /dev/kvm: skipping emulator. Use the manual device checks in docs/android-release.md."
fi

missing=()
for p in "${packages[@]}"; do
  dir="$ANDROID_HOME/${p//;//}"
  [ -d "$dir" ] || missing+=("$p")
done
if [ "${#missing[@]}" -gt 0 ]; then
  log "Installing SDK packages: ${missing[*]}"
  "$SDKMANAGER" --install "${missing[@]}"
else
  log "SDK packages already installed"
fi

# --- Flutter configuration ---------------------------------------------------
log "Configuring Flutter"
flutter config --no-analytics >/dev/null
flutter --disable-analytics >/dev/null 2>&1 || true
flutter config --android-sdk "$ANDROID_HOME" >/dev/null
flutter precache --android
yes | flutter doctor --android-licenses >/dev/null || true

if [ "$HAVE_KVM" -eq 1 ]; then
  AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
  create_avd() {
    local name="$1" device="$2"
    if "$AVDMANAGER" list avd -c | grep -qx "$name"; then
      log "AVD $name already exists"
    else
      log "Creating AVD $name ($device)"
      echo no | "$AVDMANAGER" create avd --name "$name" \
        --package "$EMULATOR_IMAGE" --device "$device"
    fi
  }
  create_avd hexris_phone pixel_8
  create_avd hexris_tablet pixel_tablet
  cat <<'EOF'

Start an emulator headless with, for example:
  emulator -avd hexris_tablet -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect &
  adb wait-for-device
EOF
fi

# --- Persist the environment -------------------------------------------------
cat >"$ENV_FILE" <<EOF
export FLUTTER_HOME="$FLUTTER_HOME"
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:\$PATH"
EOF

log "Done"
flutter --version
echo
echo "Run 'source $ENV_FILE' in new shells to put flutter and the SDK on PATH."
