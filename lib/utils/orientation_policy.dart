import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constants.dart';

/// Chooses the allowed screen orientations from the screen size.
///
/// Phones (shortest side under 600 logical pixels) are locked to portrait.
/// Tablets and unfolded foldables may rotate freely and get the wide layout in
/// landscape. Android 16 ignores portrait locks on screens 600dp and wider for
/// apps targeting SDK 36, so tablets must support landscape anyway; iPad's
/// Info.plist already allows every orientation.
class OrientationPolicy {
  OrientationPolicy._();

  static List<DeviceOrientation>? _applied;

  /// The orientations to allow for a screen of [logicalSize].
  ///
  /// An empty list means "no restriction": the platform default, which on
  /// Android follows the sensor and the user's rotation lock, and on iOS uses
  /// the orientations from Info.plist.
  static List<DeviceOrientation> orientationsFor(ui.Size logicalSize) {
    if (logicalSize.shortestSide < LayoutConstants.tabletShortestSide) {
      return const [DeviceOrientation.portraitUp];
    }
    return const [];
  }

  /// Applies the policy for [view] (by default the app's main view).
  ///
  /// Call at startup and from [WidgetsBindingObserver.didChangeMetrics], so the
  /// policy follows a foldable being folded or unfolded. Does nothing until the
  /// view has a size, and skips the platform call when nothing changed.
  static Future<void> apply([ui.FlutterView? view]) async {
    view ??= _mainView();
    if (view == null || view.physicalSize.isEmpty) return;

    final orientations =
        orientationsFor(view.physicalSize / view.devicePixelRatio);
    if (_applied != null && listEquals(_applied, orientations)) return;
    _applied = orientations;
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } catch (e) {
      // E.g. no platform implementation (tests, unsupported desktop targets).
      // The orientation is a nicety; never let it break the app.
      _applied = null;
      debugPrint('OrientationPolicy: could not set orientations: $e');
    }
  }

  /// Forgets the last applied value. For tests only.
  @visibleForTesting
  static void reset() => _applied = null;

  static ui.FlutterView? _mainView() {
    final dispatcher = ui.PlatformDispatcher.instance;
    return dispatcher.implicitView ??
        (dispatcher.views.isEmpty ? null : dispatcher.views.first);
  }
}
