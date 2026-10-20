# Plan: Android port of Hexris (Android 12+, phones and tablets, F-Droid ready)

## Context

Hexris is a Flutter app (`lib/`, Dart SDK ^3.11) that currently ships only for iOS, with macOS and web scaffolding. There is no `android/` folder. The game is pure Flutter: it uses CustomPainter rendering and only three plugins, `provider`, `shared_preferences` and `audioplayers`. That means the port is mostly about adding the Android target and adapting it to Android, not rewriting the game.

Goals:
- Native Android build, `minSdk 31` (Android 12) and `targetSdk/compileSdk 36`.
- Works on phones and tablets. Tablets get a real landscape layout, because Android 16 ignores portrait locks on screens 600dp and wider for apps targeting SDK 36.
- Application ID `com.hexris.hexris`, the same as iOS.
- Structured so it can be submitted to F-Droid later: it builds from source, has no proprietary dependencies, signing is optional, and the store metadata lives in the repo.

The plan is first saved as `plan.md` in the repo root. Development runs on a Claude cloud runner (Linux).

## Step 0 – Toolchain (Claude cloud runner, Linux)

Add a setup script, `tool/setup_android_env.sh`, so any runner session can rebuild the environment. It needs network access for the downloads, and it should skip steps that are already installed.
1. Install JDK 17 or newer (for example `openjdk-17-jdk-headless`).
2. Clone Flutter stable, pinned to an exact tag that ships Dart ≥ 3.11, into `$HOME/flutter`, and put it on PATH. Run `flutter config --no-analytics` and `flutter precache --android`.
3. Download Android `cmdline-tools` to `$ANDROID_HOME`. Use `sdkmanager` to install `platform-tools`, `platforms;android-36` and `build-tools;36.0.0`. Accept the licenses with `yes | flutter doctor --android-licenses`.
4. Emulator, only if the runner exposes `/dev/kvm`: install `emulator` and `system-images;android-36;google_apis;x86_64`, then create a headless phone AVD and a Pixel Tablet AVD. Without KVM, device testing moves to the manual checks in Verification.
5. Record the pinned Flutter version in `docs/android-release.md`. F-Droid's build recipe will pin the same version.

## Step 1 – Generate the Android project

- Run `flutter create --platforms=android --org com.hexris --project-name hexris .` in the repo root. This adds `android/` only and leaves the existing `lib/`, `test/` and `ios/` alone. It also adds the `android` entry to `.metadata`.
- In `android/app/build.gradle.kts`:
  - Set `applicationId = "com.hexris.hexris"`, `minSdk = 31`, `targetSdk = 36`, `compileSdk = 36`. Leave versionCode/versionName coming from `pubspec.yaml` (`flutter.versionCode`).
  - Add `dependenciesInfo { includeInApk = false; includeInBundle = false }`. This removes the Google-encrypted dependency blob, which F-Droid rejects.
  - Make the release `signingConfig` optional. Read `android/key.properties` if it exists (it is gitignored), and otherwise build unsigned. F-Droid signs builds itself, so the build must not require a keystore.
  - Enable R8 minify and resource shrinking for release. Add `-dontwarn com.google.android.play.core.**` to `proguard-rules.pro` so the engine's compile-only Play Core references are stripped rather than failing the build.
- `.gitignore`: add `android/key.properties`, `*.jks` and `*.keystore`. The template's `android/.gitignore` covers `local.properties` and `.gradle`.

## Step 2 – Manifest, theme, icon, splash

In `android/app/src/main/AndroidManifest.xml`:
- Set `android:label="Hexris"`.
- Set `android:enableOnBackInvokedCallback="true"` for predictive back. The game is already saved on `paused`/`detached` in `lib/main.dart`.
- Keep `resizeableActivity` at its default of true for split-screen and foldables. Add no `screenOrientation` attribute; orientation is handled in Dart (Step 3).
- Add no permissions. Haptics go through `View.performHapticFeedback` and need none, and there is no networking.

App icon:
- Add `flutter_launcher_icons` as a dev dependency (MIT, build-time only). Generate legacy mipmaps plus an adaptive icon and an Android 13 monochrome icon.
- Use the existing `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` as the source. The foreground needs to be padded to the adaptive-icon safe zone. The background uses `GameColors.background` from `lib/utils/colors.dart`.

Android 12+ splash screen:
- In `res/values/styles.xml` and `res/values-night/styles.xml`, set `windowSplashScreenBackground` to the game background color and `windowSplashScreenAnimatedIcon` to the launcher foreground. This matches the dark iOS launch screen.

## Step 3 – Dart changes for Android and tablets

**`lib/main.dart`: orientation policy.** Replace the unconditional `portraitUp` lock with a size-based policy:
- If the shortest side is under 600dp, lock to portrait (phones).
- Otherwise allow all orientations (tablets and unfolded foldables).

Put this in a small helper, for example `lib/utils/orientation_policy.dart`. Call it once at startup from `PlatformDispatcher.instance.views.first`, and again from `_HexrisAppState.didChangeMetrics()` so it updates when a foldable is folded or unfolded. This also lets iPads rotate, which matches the existing `UISupportedInterfaceOrientations~ipad`.

**`lib/main.dart`: system UI.** Use `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` with transparent bars and light icons. SDK 35+ enforces edge-to-edge anyway, and `GameScreen` already wraps everything in `SafeArea`.

**`lib/widgets/game_screen.dart`: responsive layout.** Inside the existing `LayoutBuilder`, choose the layout from the constraints, not from the device type, so a phone in split-screen also works.
- **Tall** (current behaviour, unchanged): a Column of HeaderBar, board and tray.
- **Wide** (`maxWidth > maxHeight * 1.1`, constant in `lib/utils/constants.dart`):
  - HeaderBar runs along the top.
  - Below it is a Row: the board (Expanded) on the left, and a side panel about 180–220dp wide on the right with the 3 tray pieces stacked vertically and the Undo button.
- Compute `cellSize` from the area the board actually gets in each layout. Today it uses a hard-coded `maxHeight - 250` reserve. The value must still match what `HexGridWidget` and `SquareGridWidget` compute internally. Both use `min(maxWidth, maxHeight)` of their box, so pass the same box dimensions. This keeps drag feedback the same size as the board cells.

**`lib/widgets/piece_tray.dart`:** add an `Axis direction` parameter (default horizontal). It builds a `Flex` instead of a fixed `Row` with height 160, so the wide layout can stack pieces vertically. `DraggablePieceWidget` needs no change.

**`lib/utils/feedback_service.dart`:**
- Set a global `AudioContext` at init so the sound effects mix with other audio instead of taking audio focus. By default audioplayers on Android would pause the user's music on every piece placement. Use `AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)` with a game usage type.
- Switch the player to `PlayerMode.lowLatency` (SoundPool), which suits the short wav files in `assets/sounds/`.
- These are global settings, so they apply to iOS too. Confirm on iOS that the sounds still play.

`shared_preferences` needs no change; it uses SharedPreferences on Android.

## Step 4 – Tests

- Keep `test/classic_rules_test.dart`. `test/widget_test.dart` should keep passing.
- Add `test/layout_test.dart`. Use `tester.view.physicalSize` / `devicePixelRatio` to pump `HexrisApp` at phone portrait (e.g. 411×891), tablet portrait (800×1280) and tablet landscape (1280×800).
- At each size, check that there is no overflow and that the tray and board both render. In landscape, also check that the tray pieces are arranged vertically.
- Add a unit test for the orientation-policy helper covering 599dp and 600dp.

## Step 5 – F-Droid readiness (in repo)

- Add Fastlane metadata, which F-Droid reads from the source repo:
  - Text files under `fastlane/metadata/android/en-US/`: `title.txt`, `short_description.txt` and `full_description.txt`, adapted from `app_store_info.txt`. Drop the "tetris" keyword wording.
  - `changelogs/<versionCode>.txt`.
  - Under `images/`: `icon.png`, plus `phoneScreenshots/` and `tenInchScreenshots/`. Capture them with `adb exec-out screencap` if the runner has an emulator. Otherwise leave the folders with a README and capture the screenshots later from a device.
- Add `docs/android-release.md`, styled like `docs/app-store-submission.md`. It covers:
  - the pinned Flutter version and the build commands;
  - the optional keystore setup;
  - the versionCode rules: bump the `+N` part of `pubspec.yaml` for every release, and tag releases `vX.Y.Z` for F-Droid's `UpdateCheckMode: Tags`;
  - a draft `fdroiddata` recipe (`metadata/com.hexris.hexris.yml`) for submitting later. The recipe uses `srclibs: flutter@<pinned>`, `rm: [ios, macos, web]`, `flutter pub get`, `flutter build apk --release`, and output `build/app/outputs/flutter-apk/app-release.apk`.
- `PRIVACY_POLICY.md` already says the app collects no data and makes no network access, so it needs no change. Mention Android in the README "Building" section.

## Critical files

- New: `plan.md` (this plan), `tool/setup_android_env.sh`, `android/**` (generated), `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/proguard-rules.pro`, `lib/utils/orientation_policy.dart`, `test/layout_test.dart`, `fastlane/metadata/android/en-US/**`, `docs/android-release.md`
- Modified: `lib/main.dart`, `lib/widgets/game_screen.dart`, `lib/widgets/piece_tray.dart`, `lib/utils/feedback_service.dart`, `lib/utils/constants.dart`, `pubspec.yaml` (dev dependency and icon config), `.gitignore`, `README.md`

## Verification

1. `flutter analyze` and `flutter test` pass, including the new layout tests.
2. `flutter build apk --release` succeeds with no `key.properties` present, as F-Droid would build it. Check the APK with `aapt2 dump badging` for `sdkVersion:'31'`, `targetSdkVersion:'36'` and package `com.hexris.hexris`.
3. Dependency scan:
   - List the APK's DEX classes (`apkanalyzer dex packages`) and confirm there are no `com.google.android.gms` or `com.google.android.play` packages.
   - Confirm there is no `META-INF/*DEPENDENCIES*` blob.
   - Optionally run `fdroid scanner` from the fdroidserver Docker image.
Steps 1–3 run on the cloud runner. If the runner has KVM, step 4 can run there on the headless AVDs, driven with `adb` and screenshots. Otherwise the release APK is attached to the PR and you run step 4 on a local emulator or device.

4. Device checks:
   - **API 31 phone:** the app launches, the splash and adaptive icon appear, and it stays portrait-locked.
   - **API 36 phone:** edge-to-edge insets are correct, with no overlap at the notch or gesture bar.
   - **Pixel Tablet:** check portrait, then rotate to landscape and confirm the side-panel layout. Drag pieces onto every board edge in both modes and check that the drag feedback matches the cell size.
   - **Foldable:** fold and unfold mid-game; the state is kept and the layout switches.
   - **Split-screen** on the tablet.
   - **Game state and sound:**
     - Back-gesture out, kill the app, relaunch: the saved game and high score are restored.
     - Play music in another app and place pieces: the music keeps playing.
     - Turn sound and haptics off: both stay silent.
5. On a physical Android 12+ device if one is available: haptic strength per event and audio latency.
6. Regression (needs a Mac, so it can't run on the runner): run the iOS build on an iPhone and an iPad simulator. iPad now rotates and uses the wide layout, and the sounds still play.
