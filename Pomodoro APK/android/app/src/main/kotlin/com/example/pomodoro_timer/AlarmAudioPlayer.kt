package com.example.pomodoro_timer

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.CombinedVibration
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Handles continuous looping alarm audio on STREAM_ALARM (or USAGE_ALARM)
 * and synchronized looping vibration.
 */
object AlarmAudioPlayer {
    private const val TAG = "AlarmAudioPlayer"
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var vibrator: Vibrator? = null

    @Synchronized
    fun playAlarm(context: Context, soundName: String?, vibrationEnabled: Boolean) {
        stopAlarm(context) // Ensure any existing alarm playback is stopped first

        Log.d(TAG, "Starting alarm playback: sound=$soundName, vibration=$vibrationEnabled")

        try {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

            // 1. Request audio focus with ALARM usage
            requestAudioFocus()

            // 2. Setup MediaPlayer
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true

                // Resolve sound source
                val sound = soundName?.lowercase()?.trim() ?: "classic"
                val rawResId = when (sound) {
                    "classic" -> R.raw.classic
                    "digital" -> R.raw.digital
                    "bell" -> R.raw.bell
                    "soft" -> R.raw.soft
                    "alarm" -> R.raw.alarm
                    else -> null
                }

                if (rawResId != null) {
                    val afd = context.resources.openRawResourceFd(rawResId)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                } else if (sound.startsWith("content://") || sound.startsWith("file://") || sound.startsWith("/")) {
                    val uri = Uri.parse(sound)
                    setDataSource(context, uri)
                } else {
                    // Fallback to classic
                    val afd = context.resources.openRawResourceFd(R.raw.classic)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                }

                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing alarm audio, falling back to classic raw sound", e)
            try {
                mediaPlayer?.release()
                mediaPlayer = MediaPlayer.create(context, R.raw.classic).apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    start()
                }
            } catch (fallbackEx: Exception) {
                Log.e(TAG, "Fallback audio playback failed", fallbackEx)
            }
        }

        // 3. Setup Vibration
        if (vibrationEnabled) {
            startVibration(context)
        }
    }

    private fun startVibration(context: Context) {
        try {
            val pattern = longArrayOf(0, 800, 400, 800, 400) // delay, vibe, pause, vibe, pause
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibrator = vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, 0) // 0 means loop continuously
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting vibration", e)
        }
    }

    @Synchronized
    fun stopAlarm(context: Context) {
        Log.d(TAG, "Stopping alarm playback and vibration")
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
            }
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing MediaPlayer", e)
        }

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping vibrator", e)
        }

        abandonAudioFocus()
    }

    private fun requestAudioFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val playbackAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(playbackAttributes)
                .build()

            audioFocusRequest?.let { am.requestAudioFocus(it) }
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun abandonAudioFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
    }
}
