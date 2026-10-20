import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexris/utils/orientation_policy.dart';

void main() {
  group('OrientationPolicy.orientationsFor', () {
    test('locks phones (shortest side 599) to portrait', () {
      expect(OrientationPolicy.orientationsFor(const Size(599, 1000)), [
        DeviceOrientation.portraitUp,
      ]);
      // Same phone held sideways: the shortest side decides, not the width.
      expect(OrientationPolicy.orientationsFor(const Size(1000, 599)), [
        DeviceOrientation.portraitUp,
      ]);
    });

    test('lets tablets (shortest side 600) rotate freely', () {
      expect(OrientationPolicy.orientationsFor(const Size(600, 1000)), isEmpty);
      expect(OrientationPolicy.orientationsFor(const Size(1000, 600)), isEmpty);
    });

    test('typical devices', () {
      // Pixel 8 phone.
      expect(OrientationPolicy.orientationsFor(const Size(411, 914)), [
        DeviceOrientation.portraitUp,
      ]);
      // Pixel Tablet.
      expect(
        OrientationPolicy.orientationsFor(const Size(1280, 800)),
        isEmpty,
      );
      // Pixel Fold, unfolded inner screen.
      expect(OrientationPolicy.orientationsFor(const Size(841, 701)), isEmpty);
    });
  });

  group('OrientationPolicy.apply', () {
    late List<Object?> calls;

    setUp(() {
      OrientationPolicy.reset();
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') {
              calls.add(call.arguments);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('follows the view size and skips unchanged updates', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 2;

      // Folded: phone-sized.
      tester.view.physicalSize = const Size(599 * 2, 1000 * 2);
      await OrientationPolicy.apply(tester.view);
      // Unchanged size: no second platform call.
      await OrientationPolicy.apply(tester.view);
      // Unfolded: tablet-sized.
      tester.view.physicalSize = const Size(600 * 2, 1000 * 2);
      await OrientationPolicy.apply(tester.view);

      expect(calls, [
        ['DeviceOrientation.portraitUp'],
        <String>[],
      ]);
    });

    testWidgets('waits until the view has a size', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = Size.zero;
      await OrientationPolicy.apply(tester.view);
      expect(calls, isEmpty);
    });
  });
}
