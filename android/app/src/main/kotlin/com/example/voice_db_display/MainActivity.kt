package com.example.voice_db_display

import io.flutter.embedding.android.FlutterActivity

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.voice_db_display/getdB"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getNativeString") {
                result.success(stringFromJNI())
            } else {
                result.notImplemented()
            }
        }
    }

    private external fun stringFromJNI(): String

    companion object {
        init {
            System.loadLibrary("getdB")
        }
    }
}
