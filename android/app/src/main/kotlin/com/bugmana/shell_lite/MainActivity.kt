package com.bugmana.shell_lite

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bugmana.shell_lite/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "sdkInt") result.success(Build.VERSION.SDK_INT)
                else result.notImplemented()
            }
    }
}
