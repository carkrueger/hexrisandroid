import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hexris/main.dart';
import 'package:hexris/utils/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<Map<Object?, Object?>> styles;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    styles = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
            styles.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // MaterialApp sets SystemUiOverlayStyle.light for dark themes on every
  // build, which has an opaque black navigation bar. The app's own style must
  // win, or Android 12-14 shows a black bar below the game.
  testWidgets('keeps the system bars transparent after MaterialApp builds', (
    tester,
  ) async {
    await tester.pumpWidget(const HexrisApp(initialHighScore: 0));
    await tester.pump();

    expect(styles, isNotEmpty);
    final applied = styles.last;
    expect(applied['systemNavigationBarColor'], 0x00000000);
    expect(applied['statusBarColor'], 0x00000000);
    expect(applied['systemNavigationBarContrastEnforced'], isFalse);
    expect(applied['statusBarIconBrightness'], 'Brightness.light');
    expect(applied['systemNavigationBarIconBrightness'], 'Brightness.light');
  });
}
