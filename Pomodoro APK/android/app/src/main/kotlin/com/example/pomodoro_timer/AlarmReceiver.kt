package com.example.pomodoro_timer

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * BroadcastReceiver triggered by Android AlarmManager.setExactAndAllowWhileIdle().
 * Ensures guaranteed execution even when device is in deep Doze mode or screen is locked.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "AlarmReceiver"
        const val ACTION_ALARM_TRIGGER = "com.example.pomodoro_timer.ALARM_TRIGGER"
        const val ALARM_REQ_CODE = 9001

        fun scheduleExactAlarm(context: Context, triggerAtMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQ_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
                Log.d(TAG, "Exact alarm scheduled for $triggerAtMillis (${(triggerAtMillis - System.currentTimeMillis()) / 1000}s from now)")
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException: SCHEDULE_EXACT_ALARM permission may not be granted", e)
                // Fallback to non-exact set if exact permission denied
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        }

        fun cancelExactAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQ_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Exact alarm cancelled")
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "onReceive triggered with action: ${intent?.action}")

        // Acquire a temporary 10-second WakeLock to guarantee completion
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "PomodoroTimer:AlarmWakeLock"
        )
        wakeLock?.acquire(10_000L)

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Verify that the timer was actually running
            val isRunning = prefs.getBoolean("flutter.isRunning", false)
            val isPaused = prefs.getBoolean("flutter.isPaused", false)
            val sessionEndsAt = prefs.getLong("flutter.sessionEndsAt", 0L)
            val now = System.currentTimeMillis()

            // If session was paused, reset, or not reached yet (with 2 sec tolerance), skip
            if (!isRunning || isPaused) {
                Log.d(TAG, "Alarm fired but timer is not running or is paused. Ignoring.")
                return
            }

            val currentPhase = prefs.getString("flutter.phase", "work") ?: "work"
            var currentCycle = prefs.getLong("flutter.currentCycle", 0L).toInt()
            val totalCycles = prefs.getLong("flutter.totalCycles", 4L).toInt()
            var completedToday = prefs.getLong("flutter.completedPomodorosToday", 0L).toInt()

            val soundName = prefs.getString("flutter.selectedAlarmSound", "classic")
            val vibration = prefs.getBoolean("flutter.vibrationEnabled", true)

            val autoStartBreaks = prefs.getBoolean("flutter.autoStartBreaks", false)
            val autoStartWork = prefs.getBoolean("flutter.autoStartWork", false)

            // Determine next phase and stats
            val nextPhase: String
            var autoStartNext = false

            if (currentPhase == "work") {
                completedToday++
                currentCycle++
                if (currentCycle >= totalCycles) {
                    nextPhase = "longBreak"
                } else {
                    nextPhase = "shortBreak"
                }
                autoStartNext = autoStartBreaks
            } else {
                if (currentPhase == "longBreak") {
                    currentCycle = 0
                }
                nextPhase = "work"
                autoStartNext = autoStartWork
            }

            val nextDurationMinutes = when (nextPhase) {
                "shortBreak" -> prefs.getLong("flutter.shortBreakDurationMinutes", 5L)
                "longBreak" -> prefs.getLong("flutter.longBreakDurationMinutes", 15L)
                else -> prefs.getLong("flutter.workDurationMinutes", 25L)
            }
            val nextDurationSeconds = nextDurationMinutes * 60L

            // Persist updated state
            prefs.edit()
                .putString("flutter.phase", nextPhase)
                .putLong("flutter.currentCycle", currentCycle.toLong())
                .putLong("flutter.completedPomodorosToday", completedToday.toLong())
                .putBoolean("flutter.isRunning", autoStartNext)
                .putBoolean("flutter.isPaused", false)
                .putLong("flutter.remainingSeconds", nextDurationSeconds)
                .putBoolean("flutter.isAlarmRinging", true)
                .apply()

            // 1. Play continuous alarm audio on STREAM_ALARM and loop vibration
            AlarmAudioPlayer.playAlarm(context, soundName, vibration)

            // 2. Post full-screen alarm notification with Stop Alarm action
            showAlarmNotification(context, currentPhase, nextPhase)

            // 3. Launch full-screen lockscreen activity
            val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                putExtra("completedPhase", currentPhase)
                putExtra("nextPhase", when (nextPhase) {
                    "shortBreak" -> "Short Break"
                    "longBreak" -> "Long Break"
                    else -> "Work Session"
                })
            }
            try {
                context.startActivity(fullScreenIntent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch AlarmActivity directly", e)
            }

            // 4. Notify Flutter UI if app is alive
            MainActivity.broadcastEvent("alarmTriggered", mapOf(
                "completedPhase" to currentPhase,
                "nextPhase" to nextPhase,
                "currentCycle" to currentCycle,
                "completedToday" to completedToday
            ))

        } catch (e: Exception) {
            Log.e(TAG, "Error in AlarmReceiver execution", e)
        } finally {
            if (wakeLock?.isHeld == true) {
                wakeLock.release()
            }
        }
    }

    private fun showAlarmNotification(context: Context, completedPhase: String, nextPhase: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val nextFormatted = when (nextPhase) {
            "shortBreak" -> "Short Break"
            "longBreak" -> "Long Break"
            else -> "Work"
        }

        // Full Screen Intent
        val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("completedPhase", completedPhase)
            putExtra("nextPhase", nextFormatted)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            2001,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Action: Stop Alarm
        val stopAlarmIntent = Intent(context, TimerForegroundService::class.java).apply {
            action = TimerForegroundService.ACTION_STOP_ALARM
        }
        val stopAlarmPendingIntent = PendingIntent.getService(
            context,
            2002,
            stopAlarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, TimerForegroundService.CHANNEL_ALARM_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🍅 TIME'S UP! ${completedPhase.uppercase()} COMPLETE")
            .setContentText("Up next: $nextFormatted. Tap to stop alarm.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "STOP ALARM", stopAlarmPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        notificationManager.notify(TimerForegroundService.ALARM_NOTIFICATION_ID, notification)
    }
}
