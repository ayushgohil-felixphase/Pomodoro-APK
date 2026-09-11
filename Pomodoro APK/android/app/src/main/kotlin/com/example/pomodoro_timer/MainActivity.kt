package com.example.pomodoro_timer

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity connecting Flutter Riverpod state with Android native services.
 * Implements MethodChannel for commands and EventChannel for real-time background events.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val METHOD_CHANNEL_NAME = "com.example.pomodorotimer/timer"
        private const val EVENT_CHANNEL_NAME = "com.example.pomodorotimer/events"

        private var eventSink: EventChannel.EventSink? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        /**
         * Broadcast an event from background receivers or services directly to Flutter UI.
         */
        fun broadcastEvent(eventName: String, data: Map<String, Any?>?) {
            val payload = HashMap<String, Any?>().apply {
                put("event", eventName)
                if (data != null) {
                    putAll(data)
                }
            }
            mainHandler.post {
                try {
                    eventSink?.success(payload)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to broadcast event to Flutter: ${e.message}")
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Setup MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        // 2. Setup EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "Flutter EventChannel stream connected")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "Flutter EventChannel stream cancelled")
                }
            }
        )
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        when (call.method) {
            "startTimer" -> {
                val phase = call.argument<String>("phase") ?: "work"
                val durationSeconds = (call.argument<Number>("durationSeconds") ?: (25 * 60)).toLong()
                val autoStartBreaks = call.argument<Boolean>("autoStartBreaks") ?: false
                val autoStartWork = call.argument<Boolean>("autoStartWork") ?: false
                val vibrationEnabled = call.argument<Boolean>("vibrationEnabled") ?: true
                val selectedAlarmSound = call.argument<String>("selectedAlarmSound") ?: "classic"
                val currentCycle = (call.argument<Number>("currentCycle") ?: 0).toInt()
                val totalCycles = (call.argument<Number>("totalCycles") ?: 4).toInt()
                val completedToday = (call.argument<Number>("completedPomodorosToday") ?: 0).toInt()

                val now = System.currentTimeMillis()
                val endsAt = now + (durationSeconds * 1000L)

                prefs.edit()
                    .putString("flutter.phase", phase)
                    .putBoolean("flutter.isRunning", true)
                    .putBoolean("flutter.isPaused", false)
                    .putLong("flutter.sessionStartedAt", now)
                    .putLong("flutter.sessionEndsAt", endsAt)
                    .putLong("flutter.remainingSeconds", durationSeconds)
                    .putLong("flutter.currentCycle", currentCycle.toLong())
                    .putLong("flutter.totalCycles", totalCycles.toLong())
                    .putLong("flutter.completedPomodorosToday", completedToday.toLong())
                    .putBoolean("flutter.autoStartBreaks", autoStartBreaks)
                    .putBoolean("flutter.autoStartWork", autoStartWork)
                    .putBoolean("flutter.vibrationEnabled", vibrationEnabled)
                    .putString("flutter.selectedAlarmSound", selectedAlarmSound)
                    .putBoolean("flutter.isAlarmRinging", false)
                    .apply()

                // Schedule Exact Alarm
                AlarmReceiver.scheduleExactAlarm(this, endsAt)

                // Start Native Foreground Service
                val serviceIntent = Intent(this, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }

                result.success(true)
            }

            "pauseTimer" -> {
                val serviceIntent = Intent(this, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_PAUSE
                }
                startService(serviceIntent)
                result.success(true)
            }

            "resumeTimer" -> {
                val serviceIntent = Intent(this, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_RESUME
                }
                startService(serviceIntent)
                result.success(true)
            }

            "resetTimer" -> {
                val serviceIntent = Intent(this, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_RESET
                }
                startService(serviceIntent)
                result.success(true)
            }

            "skipSession" -> {
                val serviceIntent = Intent(this, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_SKIP
                }
                startService(serviceIntent)
                result.success(true)
            }

            "stopAlarm" -> {
                val serviceIntent = Intent(this, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_STOP_ALARM
                }
                startService(serviceIntent)
                result.success(true)
            }

            "previewSound" -> {
                val sound = call.argument<String>("sound") ?: "classic"
                AlarmAudioPlayer.playAlarm(this, sound, false)
                result.success(true)
            }

            "stopPreview" -> {
                AlarmAudioPlayer.stopAlarm(this)
                result.success(true)
            }

            "getTimerState" -> {
                val stateMap = hashMapOf<String, Any?>(
                    "phase" to prefs.getString("flutter.phase", "work"),
                    "isRunning" to prefs.getBoolean("flutter.isRunning", false),
                    "isPaused" to prefs.getBoolean("flutter.isPaused", false),
                    "sessionStartedAt" to prefs.getLong("flutter.sessionStartedAt", 0L),
                    "sessionEndsAt" to prefs.getLong("flutter.sessionEndsAt", 0L),
                    "remainingSeconds" to prefs.getLong("flutter.remainingSeconds", 25L * 60L),
                    "currentCycle" to prefs.getLong("flutter.currentCycle", 0L).toInt(),
                    "totalCycles" to prefs.getLong("flutter.totalCycles", 4L).toInt(),
                    "completedPomodorosToday" to prefs.getLong("flutter.completedPomodorosToday", 0L).toInt(),
                    "isAlarmRinging" to prefs.getBoolean("flutter.isAlarmRinging", false),
                    "selectedAlarmSound" to prefs.getString("flutter.selectedAlarmSound", "classic"),
                    "vibrationEnabled" to prefs.getBoolean("flutter.vibrationEnabled", true)
                )
                result.success(stateMap)
            }

            "canScheduleExactAlarms" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                    result.success(alarmManager?.canScheduleExactAlarms() ?: false)
                } else {
                    result.success(true)
                }
            }

            "requestExactAlarmPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening exact alarm settings", e)
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            }

            "isIgnoringBatteryOptimizations" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                    result.success(isIgnoring)
                } else {
                    result.success(true)
                }
            }

            "requestIgnoreBatteryOptimizations" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error requesting ignore battery optimization", e)
                        openBatterySettings()
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
            }

            "openBatteryOptimizationSettings" -> {
                openBatterySettings()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun openBatterySettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open battery optimization settings", e)
            try {
                val appDetailIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(appDetailIntent)
            } catch (ignored: Exception) {}
        }
    }
}
