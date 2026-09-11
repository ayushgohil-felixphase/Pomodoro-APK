package com.example.pomodoro_timer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Recovers scheduled exact alarms after device reboot.
 * Ensures the Pomodoro session remains active and resilient even across system restarts.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED &&
            intent?.action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        Log.d(TAG, "Device booted. Checking if Pomodoro session needs restoration...")

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isRunning = prefs.getBoolean("flutter.isRunning", false)
        val isPaused = prefs.getBoolean("flutter.isPaused", false)
        val sessionEndsAt = prefs.getLong("flutter.sessionEndsAt", 0L)
        val now = System.currentTimeMillis()

        if (isRunning && !isPaused && sessionEndsAt > 0L) {
            if (now < sessionEndsAt) {
                Log.d(TAG, "Session still active. Rescheduling exact alarm for $sessionEndsAt and starting foreground service.")
                AlarmReceiver.scheduleExactAlarm(context, sessionEndsAt)

                val serviceIntent = Intent(context, TimerForegroundService::class.java).apply {
                    action = TimerForegroundService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } else {
                Log.d(TAG, "Session expired while device was rebooted. Triggering alarm now.")
                val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_ALARM_TRIGGER
                }
                context.sendBroadcast(alarmIntent)
            }
        }
    }
}
