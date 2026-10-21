# Android release

## Binary

- Display name: Hexris
- Application ID: `com.hexris.hexris` (same as the iOS bundle ID)
- Version: from `pubspec.yaml` (`version: x.y.z+N` → versionName `x.y.z`, versionCode `N`)
- Minimum Android version: 12 (API 31)
- Target / compile SDK: 36
- Devices: phones and tablets (portrait-locked below 600dp shortest side,
  free rotation on tablets and unfolded foldables)
- Permissions: none (debug and profile builds add `INTERNET` for the Flutter
  tooling only)

## Toolchain

The build is pinned to **Flutter 3.41.9** (stable, Dart 3.11). The F-Droid
recipe below pins the same version. When upgrading Flutter, change it in all
three places: here, `FLUTTER_VERSION` in `tool/setup_android_env.sh`, and the
`srclibs` line of the recipe (plus `.github/workflows/android.yml`).

| Component | Version |
| --- | --- |
| Flutter | 3.41.9 |
| JDK | 17 or newer |
| Android Gradle Plugin | 8.11.1 |
| Kotlin Gradle Plugin | 2.2.20 |
| Gradle | 8.14 |
| Android platform / build-tools | 36 / 36.0.0 |
| NDK | 28.2.13676358 (only used to strip native libraries) |

On a fresh Linux machine, `tool/setup_android_env.sh` installs all of this
(JDK, Flutter, Android SDK, and an emulator plus phone and tablet AVDs when
`/dev/kvm` is available). It is safe to re-run. Afterwards:

```bash
source ~/.hexris-android-env
```

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release        # sideloading, F-Droid
flutter build appbundle --release  # Google Play, if ever needed
```

Artifacts:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

Without `android/key.properties` the release APK is **unsigned**. That is
intended: F-Droid builds from source and signs with its own key. An unsigned
APK cannot be installed; sign it (see below) or use `flutter run --release`
for testing, which signs with the debug key.

Quick checks on the APK (build-tools on PATH):

```bash
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | head -5
# expect: package: name='com.hexris.hexris' ... minSdkVersion:'31' targetSdkVersion:'36'
apkanalyzer dex packages build/app/outputs/flutter-apk/app-release.apk \
  | grep -E 'com\.google\.android\.(gms|play)' && echo "proprietary deps found!"
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i dependencies \
  && echo "dependency metadata blob found!"
```

`.github/workflows/android.yml` runs all of the above on every push, plus
emulator checks on an API 31 phone, an API 36 phone and an API 36 tablet.

## Signing local builds (optional)

GitHub releases are signed by the release workflow (see "Releases"). To build
a release-signed APK locally, for example to test an update over an
installed release, use the same release key:

1. Create the key once with `tool/create_release_keystore.sh` (see "Release
   signing key"), or use the existing `hexris-release.jks`. Keep it outside
   the repo.

2. Create `android/key.properties` (gitignored, as are `*.jks` and
   `*.keystore`):

   ```properties
   storeFile=/home/you/hexris-release.jks
   storePassword=...
   keyAlias=hexris
   keyPassword=...
   ```

   A relative `storeFile` is resolved against `android/app/`.

3. `flutter build apk --release` now produces a signed APK.

Losing the keystore means you can never update an installed APK signed with
it, so back it up.

## Versioning

- Bump the `+N` build number in `pubspec.yaml` for **every** release; Android
  rejects updates whose versionCode isn't higher than the installed one. The
  iOS build number comes from the same field.
- Add a changelog for each versionCode:
  `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt` (max 500
  characters).
- Each release is tagged `vX.Y.Z` (matching the `x.y.z` in `pubspec.yaml`);
  the release workflow creates the tag when it publishes. F-Droid uses
  `UpdateCheckMode: Tags` to find new versions.

## Releases

Releases are published by `.github/workflows/release.yml`. On every push to
`main` it reads the version from `pubspec.yaml`; if there is no GitHub
release for `vX.Y.Z` yet, it checks that the changelog for the versionCode
exists, runs `flutter analyze` and `flutter test`, builds the release APK,
signs it with the release key, verifies it (package, SDK levels, no Google
dependencies, signed with the release key's certificate) and publishes a
release with `hexris-X.Y.Z.apk` and `SHA256SUMS`, which creates the
`vX.Y.Z` tag. Once the release exists, pushes to `main` build nothing.

To ship a new version:

1. Bump `version:` in `pubspec.yaml`, e.g. `1.2.0+2` to `1.2.1+3` (the build
   number must always increase).
2. Add `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`; it
   becomes the release notes.
3. Merge to `main`. The release appears under *Releases* about 15 minutes
   later; the latest one is always at
   `https://github.com/carkrueger/hexrisandroid/releases/latest`.

Pushing a `vX.Y.Z` tag that matches `pubspec.yaml`, or running the workflow
by hand (*Actions > Release > Run workflow*), also publishes.

### Release signing key

Every release is signed with the same key. Android only installs an update
signed with the key of the installed app, so this key must never change or
get lost. The workflow refuses to publish without it.

Create it once, on your own machine (needs a JDK for `keytool`, `openssl`,
and the GitHub CLI logged in to this repository):

```bash
tool/create_release_keystore.sh            # writes ~/hexris-release.jks
```

The script creates a 4096-bit RSA key (alias `hexris`, valid for 10,000
days), prints its certificate fingerprint, and stores it as these repository
secrets (*Settings > Secrets and variables > Actions*):

| Secret | Value |
| --- | --- |
| `HEXRIS_KEYSTORE_BASE64` | `openssl base64 -A -in hexris-release.jks` |
| `HEXRIS_KEYSTORE_PASSWORD` | the keystore password |
| `HEXRIS_KEY_ALIAS` | `hexris` |
| `HEXRIS_KEY_PASSWORD` | the key password (same as the keystore's for PKCS12) |

Back up `hexris-release.jks` and its password outside the repository, e.g. in
a password manager. To reuse an existing keystore, set the four secrets by
hand.

Each release's notes list the signing certificate's SHA-256, so downloads can
be checked with `apksigner verify --print-certs hexris-X.Y.Z.apk`. The
`Android` CI workflow builds once more with a throwaway key through the same
`android/key.properties` path, so a broken signing setup shows up before a
release.

## Store metadata

F-Droid reads the listing from `fastlane/metadata/android/en-US/` in this
repo: `title.txt`, `short_description.txt` (max 80 characters),
`full_description.txt`, `changelogs/`, and `images/` (`icon.png`,
`phoneScreenshots/`, `tenInchScreenshots/`).

Screenshots are PNGs captured from a device or emulator:

```bash
adb exec-out screencap -p > fastlane/metadata/android/en-US/images/phoneScreenshots/1.png
```

Use a phone for `phoneScreenshots/` and a 10" tablet (e.g. the Pixel Tablet
AVD) for `tenInchScreenshots/`. The CI workflow saves emulator screenshots
that can be used as a starting point.

The launcher icon is generated by `tool/generate_icon_sources.py` (adaptive
foreground, monochrome themed icon, legacy mipmaps). `dart run
flutter_launcher_icons` regenerates the Android resources from the same
source images in `assets/icon/`.

## F-Droid submission (later)

Before submitting:

- [ ] The repository needs a `LICENSE` file with an F-Droid-accepted
      free-software license. There is none yet, so F-Droid would reject the
      app. Put the matching SPDX ID in the recipe below.
- [ ] Release tag `v1.2.0` (or later) exists.
- [ ] Phone and tablet screenshots are committed.
- [ ] `fdroid scanner` finds nothing (optional local check, e.g. with the
      `registry.gitlab.com/fdroid/docker-executable-fdroidserver` image).

Draft recipe for a merge request to
[fdroiddata](https://gitlab.com/fdroid/fdroiddata), as
`metadata/com.hexris.hexris.yml`:

```yaml
Categories:
  - Games
License: MIT  # TODO: must match the LICENSE file that is still to be added
SourceCode: https://github.com/carkrueger/hexrisandroid
IssueTracker: https://github.com/carkrueger/hexrisandroid/issues

AutoName: Hexris

RepoType: git
Repo: https://github.com/carkrueger/hexrisandroid.git

Builds:
  - versionName: 1.2.0
    versionCode: 2
    commit: v1.2.0
    output: build/app/outputs/flutter-apk/app-release.apk
    srclibs:
      - flutter@3.41.9
    rm:
      - ios
      - macos
      - web
    prebuild:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter config --no-analytics
      - $$flutter$$/bin/flutter pub get
    scandelete:
      - .pub-cache
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - $$flutter$$/bin/flutter build apk --release

AutoUpdateMode: Version
UpdateCheckMode: Tags
UpdateCheckData: pubspec.yaml|version:\s.+\+(\d+)|.|version:\s(.+)\+
CurrentVersion: 1.2.0
CurrentVersionCode: 2
```

## Device checklist

Run before each release, on emulators or devices:

- **API 31 phone:** launches, splash and adaptive icon appear, stays in
  portrait when the device is rotated.
- **API 36 phone:** edge-to-edge insets are right; nothing under the notch or
  gesture bar.
- **Tablet (e.g. Pixel Tablet):** portrait uses the normal layout; landscape
  shows the board with the tray in a side panel. Drag pieces onto every board
  edge in both orientations; the dragged piece matches the board cell size.
- **Foldable:** fold and unfold mid-game; the game is kept and the layout
  switches.
- **Split-screen** on the tablet.
- **Game state:** back out, kill the app, relaunch: the game and high score
  are restored.
- **Sound:** play music in another app and place pieces: the music keeps
  playing. With sound and haptics turned off, both stay silent.
- **Physical device** (if available): haptic strength per event, audio
  latency.
