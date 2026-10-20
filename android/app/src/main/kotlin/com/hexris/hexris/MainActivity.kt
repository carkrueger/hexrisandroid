package com.hexris.hexris

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Lay the Flutter view out behind the navigation bar too. Flutter's
        // SystemUiMode.edgeToEdge only sets the legacy SYSTEM_UI_FLAG_LAYOUT_*
        // flags, and on Android 12-14 with 3-button navigation the window
        // still kept the view above the bar, which then showed as an opaque
        // black strip. Android 15+ enforces this for targetSdk 35+ anyway.
        // The game keeps its content inside a SafeArea.
        window.setDecorFitsSystemWindows(false)
        super.onCreate(savedInstanceState)
    }
}
