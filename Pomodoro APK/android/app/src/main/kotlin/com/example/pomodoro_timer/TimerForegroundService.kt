package com.example.pomodoro_timer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Native Android Foreground Service for the Pomodoro Timer.
 * Maintains an ongoing notification with current session state, MM:SS countdown,
 * and quick-action buttons (Pause, Resume, Skip, Reset).
 *
 * Uses foregroundServiceType="specialUse" compliant with Android 14+ requirements.
 */
class TimerForegroundService : Service() {

    companion object {
        const val TAG = "TimerFGS"
        const val TIMER_NOTIFICATION_ID = 1001
        const val ALARM_NOTIFICATION_ID = 1002

        const val CHANNEL_TIMER_ID = "pomodoro_timer_channel"
        const val CHANNEL_ALARM_ID = "pomodoro_alarm_channel"

        const val ACTION_START = "com.example.pomodoro_timer.ACTION_START"
        const val ACTION_PAUSE = "com.example.pomodoro_timer.ACTION_PAUSE"
        const val ACTION_RESUME = "com.example.pomodoro_timer.ACTION_RESUME"
        const val ACTION_RESET = "com.example.pomodoro_timer.ACTION_RESET"
        const val ACTION_SKIP = "com.example.pomodoro_timer.ACTION_SKIP"
        const val ACTION_STOP_SERVICE = "com.example.pomodoro_timer.ACTION_STOP_SERVICE"
        const val ACTION_STOP_ALARM = "com.example.pomodoro_timer.ACTION_STOP_ALARM"

        var isServiceRunning = false
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var updateRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        createNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        Log.d(TAG, "onStartCommand action: $action")

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        when (action) {
            ACTION_START -> {
                startTimerForeground()
                startTicker()
            }
            ACTION_PAUSE -> {
                handlePause(prefs)
            }
            ACTION_RESUME -> {
                handleResume(prefs)
            }
            ACTION_RESET -> {
                handleReset(prefs)
            }
            ACTION_SKIP -> {
                handleSkip(prefs)
            }
            ACTION_STOP_ALARM -> {
                AlarmAudioPlayer.stopAlarm(this)
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                notificationManager?.cancel(ALARM_NOTIFICATION_ID)
                prefs.edit().putBoolean("flutter.isAlarmRinging", false).apply()
                MainActivity.broadcastEvent("alarmStopped", null)
            }
            ACTION_STOP_SERVICE -> {
                stopTicker()
                stopForeground(true)
                stopSelf()
            }
        }

        return START_STICKY
    }

    private fun startTimerForeground() {
        val notification = buildTimerNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                TIMER_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(TIMER_NOTIFICATION_ID, notification)
        }
    }

    private fun startTicker() {
        stopTicker()
        updateRunnable = object : Runnable {
            override fun run() {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isRunning = prefs.getBoolean("flutter.isRunning", false)
                val isPaused = prefs.getBoolean("flutter.isPaused", false)

                if (isRunning && !isPaused) {
                    val sessionEndsAt = prefs.getLong("flutter.sessionEndsAt", 0L)
                    val now = System.currentTimeMillis()
                    val remainingSeconds = Math.max(0L, (sessionEndsAt - now + 999L) / 1000L)

                    prefs.edit().putLong("flutter.remainingSeconds", remainingSeconds).apply()

                    // Broadcast tick to Flutter if app is foregrounded
                    MainActivity.broadcastEvent("tick", mapOf("remainingSeconds" to remainingSeconds))

                    if (remainingSeconds <= 0L) {
                        // Timer completed, let AlarmReceiver handle it or trigger directly
                        val alarmIntent = Intent(applicationContext, AlarmReceiver::class.java).apply {
                            this.action = AlarmReceiver.ACTION_ALARM_TRIGGER
                        }
                        sendBroadcast(alarmIntent)
                        stopTicker()
                        return
                    }
                }

                // Update notification UI
                updateNotification()
                handler.postDelayed(this, 1000L)
            }
        }
        handler.post(updateRunnable!!)
    }

    private fun stopTicker() {
        updateRunnable?.let { handler.removeCallbacks(it) }
        updateRunnable = null
    }

    private fun handlePause(prefs: android.content.SharedPreferences) {
        val sessionEndsAt = prefs.getLong("flutter.sessionEndsAt", 0L)
        val now = System.currentTimeMillis()
        val remaining = Math.max(0L, (sessionEndsAt - now + 999L) / 1000L)

        // Cancel the scheduled exact alarm while paused
        AlarmReceiver.cancelExactAlarm(this)

        prefs.edit()
            .putBoolean("flutter.isRunning", true)
            .putBoolean("flutter.isPaused", true)
            .putLong("flutter.remainingSeconds", remaining)
            .apply()

        MainActivity.broadcastEvent("stateChanged", mapOf("isPaused" to true, "remainingSeconds" to remaining))
        updateNotification()
    }

    private fun handleResume(prefs: android.content.SharedPreferences) {
        val remaining = prefs.getLong("flutter.remainingSeconds", 25L * 60L)
        val now = System.currentTimeMillis()
        val newEndsAt = now + (remaining * 1000L)

        prefs.edit()
            .putBoolean("flutter.isRunning", true)
            .putBoolean("flutter.isPaused", false)
            .putLong("flutter.sessionStartedAt", now)
            .putLong("flutter.sessionEndsAt", newEndsAt)
            .apply()

        // Reschedule exact alarm for newEndsAt
        AlarmReceiver.scheduleExactAlarm(this, newEndsAt)

        MainActivity.broadcastEvent("stateChanged", mapOf(
            "isPaused" to false,
            "sessionEndsAt" to newEndsAt,
            "remainingSeconds" to remaining
        ))
        updateNotification()
    }

    private fun handleReset(prefs: android.content.SharedPreferences) {
        AlarmReceiver.cancelExactAlarm(this)
        stopTicker()

        val workMinutes = prefs.getLong("flutter.workDurationMinutes", 25L)
        val resetSeconds = workMinutes * 60L

        prefs.edit()
            .putString("flutter.phase", "work")
            .putBoolean("flutter.isRunning", false)
            .putBoolean("flutter.isPaused", false)
            .putLong("flutter.remainingSeconds", resetSeconds)
            .putLong("flutter.sessionStartedAt", 0L)
            .putLong("flutter.sessionEndsAt", 0L)
            .putBoolean("flutter.isAlarmRinging", false)
            .apply()

        AlarmAudioPlayer.stopAlarm(this)
        MainActivity.broadcastEvent("stateChanged", mapOf("action" to "reset"))

        stopForeground(true)
        stopSelf()
    }

    private fun handleSkip(prefs: android.content.SharedPreferences) {
        AlarmReceiver.cancelExactAlarm(this)
        stopTicker()
        AlarmAudioPlayer.stopAlarm(this)

        val currentPhase = prefs.getString("flutter.phase", "work") ?: "work"
        var currentCycle = prefs.getLong("flutter.currentCycle", 0L).toInt()
        val totalCycles = prefs.getLong("flutter.totalCycles", 4L).toInt()

        val nextPhase = if (currentPhase == "work") {
            currentCycle++
            if (currentCycle >= totalCycles) "longBreak" else "shortBreak"
        } else {
            if (currentPhase == "longBreak") currentCycle = 0
            "work"
        }

        val nextDurationMinutes = when (nextPhase) {
            "shortBreak" -> prefs.getLong("flutter.shortBreakDurationMinutes", 5L)
            "longBreak" -> prefs.getLong("flutter.longBreakDurationMinutes", 15L)
            else -> prefs.getLong("flutter.workDurationMinutes", 25L)
        }

        val nextDurationSeconds = nextDurationMinutes * 60L

        prefs.edit()
            .putString("flutter.phase", nextPhase)
            .putLong("flutter.currentCycle", currentCycle.toLong())
            .putBoolean("flutter.isRunning", false)
            .putBoolean("flutter.isPaused", false)
            .putLong("flutter.remainingSeconds", nextDurationSeconds)
            .putLong("flutter.sessionStartedAt", 0L)
            .putLong("flutter.sessionEndsAt", 0L)
            .putBoolean("flutter.isAlarmRinging", false)
            .apply()

        MainActivity.broadcastEvent("stateChanged", mapOf(
            "phase" to nextPhase,
            "currentCycle" to currentCycle,
            "remainingSeconds" to nextDurationSeconds
        ))

        stopForeground(true)
        stopSelf()
    }

    private fun updateNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.notify(TIMER_NOTIFICATION_ID, buildTimerNotification())
    }

    private fun buildTimerNotification(): Notification {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val phase = prefs.getString("flutter.phase", "work") ?: "work"
        val isPaused = prefs.getBoolean("flutter.isPaused", false)
        val remainingSeconds = prefs.getLong("flutter.remainingSeconds", 0L)

        val minutes = remainingSeconds / 60
        val seconds = remainingSeconds % 60
        val formattedTime = String.format("%02d:%02d", minutes, seconds)

        val phaseLabel = when (phase) {
            "work" -> "Work"
            "shortBreak" -> "Short Break"
            "longBreak" -> "Long Break"
            else -> "Pomodoro"
        }

        val contentText = if (isPaused) {
            "$phaseLabel (Paused) • $formattedTime remaining"
        } else {
            "$phaseLabel • $formattedTime remaining"
        }

        // Tap notification -> open MainActivity
        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val appPendingIntent = PendingIntent.getActivity(
            this, 0, appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_TIMER_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🍅 Pomodoro Timer")
            .setContentText(contentText)
            .setContentIntent(appPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)

        // Add Actions: Pause/Resume, Skip, Reset
        if (isPaused) {
            val resumeIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_RESUME }
            val resumePendingIntent = PendingIntent.getService(
                this, 1, resumeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_media_play, "Resume", resumePendingIntent)
        } else {
            val pauseIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_PAUSE }
            val pausePendingIntent = PendingIntent.getService(
                this, 2, pauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(android.R.drawable.ic_media_pause, "Pause", pausePendingIntent)
        }

        val skipIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_SKIP }
        val skipPendingIntent = PendingIntent.getService(
            this, 3, skipIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        builder.addAction(android.R.drawable.ic_media_next, "Skip", skipPendingIntent)

        val resetIntent = Intent(this, TimerForegroundService::class.java).apply { action = ACTION_RESET }
        val resetPendingIntent = PendingIntent.getService(
            this, 4, resetIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        builder.addAction(android.R.drawable.ic_menu_revert, "Reset", resetPendingIntent)

        return builder.build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Timer channel (Low importance for smooth ticking without sound)
            val timerChannel = NotificationChannel(
                CHANNEL_TIMER_ID,
                "Pomodoro Active Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows the active timer countdown and quick controls"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }

            // Alarm channel (High importance for session end alarms)
            val alarmChannel = NotificationChannel(
                CHANNEL_ALARM_ID,
                "Pomodoro Session Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Fires high-priority alarms when a Pomodoro session completes"
                setShowBadge(true)
                enableVibration(true)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            notificationManager.createNotificationChannel(timerChannel)
            notificationManager.createNotificationChannel(alarmChannel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        stopTicker()
    }
}
