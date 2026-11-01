package com.oria.child

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "oria.capture/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startForegroundService(Intent(this, CaptureService::class.java))
                        result.success(null)
                    }
                    "start_screen" -> {
                        val intent = Intent(this, CaptureService::class.java).apply {
                            action = CaptureService.ACTION_START_SCREEN
                        }
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, CaptureService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra("trigger_screen_capture", false) == true) {
            Handler(Looper.getMainLooper()).postDelayed({
                finish()
            }, 8000)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("trigger_screen_capture", false)) {
            Handler(Looper.getMainLooper()).postDelayed({
                finish()
            }, 8000)
        }
    }
}