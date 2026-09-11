package com.example.pomodoro_timer

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen lock-screen-aware Activity displayed when a Pomodoro session finishes.
 * Wakes the screen and shows over lockscreen with "🍅 TIME'S UP" and "STOP ALARM".
 */
class AlarmActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure activity wakes up the device and displays over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val completedPhase = intent.getStringExtra("completedPhase") ?: "WORK"
        val nextPhase = intent.getStringExtra("nextPhase") ?: "Short Break"

        // Build modern UI programmatically
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#121212")) // Sleek Dark Background
            setPadding(48, 48, 48, 48)
        }

        // 🍅 Tomato Icon Emoji
        val emojiView = TextView(this).apply {
            text = "🍅"
            textSize = 72f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }
        rootLayout.addView(emojiView)

        // "TIME'S UP!" Title
        val titleView = TextView(this).apply {
            text = "TIME'S UP!"
            textSize = 34f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }
        rootLayout.addView(titleView)

        // Completed Session subtitle
        val subtitleView = TextView(this).apply {
            val phaseUpper = completedPhase.uppercase()
            text = "$phaseUpper COMPLETE"
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.parseColor("#FF6B6B")) // Vibrant coral/red
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 8)
        }
        rootLayout.addView(subtitleView)

        // Next Phase hint
        val nextView = TextView(this).apply {
            text = "Up Next: $nextPhase"
            textSize = 16f
            setTextColor(Color.parseColor("#A0A0A0"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }
        rootLayout.addView(nextView)

        // STOP ALARM Button
        val stopButton = Button(this).apply {
            text = "STOP ALARM"
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(Color.WHITE)
            isAllCaps = true
            setPadding(32, 24, 32, 24)

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 48f
                setColor(Color.parseColor("#E53935")) // Strong Red
            }
            background = bg

            setOnClickListener {
                stopAlarmAndDismiss()
            }
        }

        val btnParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            setMargins(48, 0, 48, 0)
        }
        rootLayout.addView(stopButton, btnParams)

        setContentView(rootLayout)
    }

    private fun stopAlarmAndDismiss() {
        // 1. Stop audio & vibration
        AlarmAudioPlayer.stopAlarm(this)

        // 2. Clear Alarm Notification
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.cancel(TimerForegroundService.ALARM_NOTIFICATION_ID)

        // 3. Mark alarm ringing as false in SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.isAlarmRinging", false).apply()

        // 4. Notify running foreground service if active
        val stopAlarmIntent = Intent(this, TimerForegroundService::class.java).apply {
            action = TimerForegroundService.ACTION_STOP_ALARM
        }
        startService(stopAlarmIntent)

        // 5. Open MainActivity to bring user into app seamlessly
        val appIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(appIntent)

        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Even if back is pressed, stop the alarm
        stopAlarmAndDismiss()
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }
}
