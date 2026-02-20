package com.xesstechlink.face_recognization

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for notification handling if needed
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app_notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialMessage" -> {
                    // Handle initial message if needed
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
