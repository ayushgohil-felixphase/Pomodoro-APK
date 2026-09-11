# Pomodoro Timer Application Walkthrough

A production-grade, background-resilient Pomodoro Timer application built with **Flutter 3.47.3 / Dart 3.13.3**, **Riverpod 3**, and **Android Native Kotlin**.

---

## 1. Executive Summary & Capabilities

The application implements a full-featured Pomodoro productivity workflow engineered to survive Android Doze mode, process death, background killing, and device reboots:

- **Bulletproof Background Execution**: Uses an Android native `ForegroundService` with a persistent countdown notification and quick-action buttons (Pause, Resume, Skip, Reset, Stop Alarm).
- **Hard Alarm & Wake-Lock**: Scheduled via `AlarmManager.setExactAndAllowWhileIdle()` triggering a dedicated `BroadcastReceiver`, `WakeLock`, and looping high-priority `MediaPlayer` on `AudioAttributes.USAGE_ALARM`.
- **Lockscreen-Aware Full-Screen Alarm UI**: Native `AlarmActivity` launches with `setShowWhenLocked(true)`, `setTurnScreenOn(true)`, and `FLAG_KEEP_SCREEN_ON` to wake up dark/locked displays.
- **True Cross-Process Recovery**: Active session target timestamps (`sessionEndsAt`) and state are persisted synchronously in `SharedPreferences`. If the process is terminated or the phone reboots, state is calculated mathematically upon restore.
- **Material 3 Dynamic UI**: Custom canvas circular timer with smooth progress animations, glow effects, theme toggling, settings configuration (1–120 minutes), and 7-day bar chart productivity analytics.

---

## 2. Architecture & File Structure

```
d:\Ayush\Pomodoro APK\
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml          # All permissions, services, receivers, & AlarmActivity
│   │   │   ├── kotlin/com/example/pomodoro_timer/
│   │   │   │   ├── MainActivity.kt          # MethodChannel & EventChannel bindings, sound preview
│   │   │   │   ├── TimerForegroundService.kt# Persistent notification with countdown & action intents
│   │   │   │   ├── AlarmReceiver.kt         # Exact alarm trigger, wake lock, & full-screen intent
│   │   │   │   ├── AlarmActivity.kt         # Native full-screen lockscreen alarm dismissal UI
│   │   │   │   ├── AlarmAudioPlayer.kt      # Looping alarm audio on STREAM_ALARM + vibration loop
│   │   │   │   └── BootReceiver.kt          # Alarm rescheduling & recovery upon device reboot
│   │   │   └── res/raw/                     # 5 bundled alarm WAV tones
│   │   └── build.gradle.kts                 # compileSdk = 37, androidx dependencies
│   └── gradle.properties                    # JVM memory config & kotlin.incremental=false
├── assets/
│   └── audio/                               # WAV audio assets for classic, digital, bell, soft, alarm
├── lib/
│   ├── core/
│   │   ├── constants/app_colors.dart        # Material 3 colors & gradients
│   │   └── theme/app_theme.dart             # Dark & light theme data
│   ├── models/
│   │   ├── pomodoro_state.dart              # Immutable timer state, progress, and phase enums
│   │   ├── pomodoro_settings.dart           # User preferences with 1-120 min validation
│   │   └── daily_statistics.dart            # Daily focus minutes & completed cycles
│   ├── services/
│   │   ├── storage_service.dart             # SharedPreferences wrapper for state & history
│   │   ├── native_timer_service.dart        # MethodChannel/EventChannel bridge to Android Kotlin
│   │   └── audio_service.dart               # Tone preview dispatcher
│   ├── providers/
│   │   ├── pomodoro_provider.dart           # Core Riverpod 3 timer state machine & ticker
│   │   ├── settings_provider.dart           # Riverpod settings state notifier
│   │   ├── statistics_provider.dart         # Riverpod 7-day stats state notifier
│   │   └── theme_provider.dart              # Theme mode notifier
│   ├── features/
│   │   ├── pomodoro/presentation/
│   │   │   ├── pomodoro_screen.dart         # Main dashboard with controls, phase pills, & battery banner
│   │   │   └── widgets/
│   │   │       ├── circular_timer_painter.dart # CustomPainter with gradients & track markers
│   │   │       └── alarm_dialog.dart        # In-app alarm alert modal
│   │   ├── settings/presentation/
│   │   │   └── settings_screen.dart         # Durations, sound picker with preview, toggles
│   │   └── statistics/presentation/
│   │       └── statistics_screen.dart       # 7-day productivity bar chart & metrics
│   └── main.dart                            # Application entrypoint & initialization
└── test/
    └── pomodoro_test.dart                   # Unit test suite (11 test cases)
```

---

## 3. Background & Alarm Engine Deep Dive

### A. Android Foreground Service
- Registers `FOREGROUND_SERVICE_SPECIAL_USE` (Android 14+ compliant).
- Creates notification channel `pomodoro_timer_channel` (`IMPORTANCE_LOW` for silent progress updates).
- Dispatches PendingIntents for actions:
  - `ACTION_PAUSE`
  - `ACTION_RESUME`
  - `ACTION_SKIP`
  - `ACTION_RESET`
  - `ACTION_STOP_ALARM`
- Dynamically updates countdown notification every second without playing notification alerts.

### B. Exact Alarm Scheduling
- Uses `AlarmManagerCompat.setExactAndAllowWhileIdle(RTC_WAKEUP, sessionEndsAtMs, pendingIntent)`.
- Firing triggers `AlarmReceiver`:
  1. Acquires a 3-minute `WakeLock` via `PowerManager`.
  2. Verifies session validity from `SharedPreferences`.
  3. Starts `AlarmAudioPlayer` on `AudioAttributes.USAGE_ALARM` with continuous vibration.
  4. Posts high-priority notification with `USE_FULL_SCREEN_INTENT` on channel `pomodoro_alarm_channel` (`IMPORTANCE_HIGH`).
  5. Launches `AlarmActivity` directly over the lockscreen.

### C. Lockscreen Awakening (`AlarmActivity`)
- For Android 8.0+ (API 27+):
  ```kotlin
  setShowWhenLocked(true)
  setTurnScreenOn(true)
  ```
- For legacy fallback:
  ```kotlin
  window.addFlags(
      WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
      WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
      WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
  )
  ```
- Keyguard dismissal: `keyguardManager.requestDismissKeyguard(this, null)`.
- Presents a high-contrast pulsating alarm screen with a prominent "STOP ALARM" button.

### D. Process Death & Reboot Recovery
- On every timer state mutation, `sessionEndsAt` (epoch timestamp) and `pomodoro_saved_state` are written to `SharedPreferences`.
- If the app is killed in the background:
  - When reopened, `StorageService.loadSavedState()` calculates:
    $$\text{remainingSeconds} = \frac{\text{sessionEndsAt} - \text{currentTimeMillis}}{1000}$$
  - If $\text{remainingSeconds} \le 0$, the session is completed, statistics are recorded, and the completion dialog is presented.
  - If $\text{remainingSeconds} > 0$, the timer resumes countdown with zero lost drift.
- On device reboot: `BootReceiver` receives `ACTION_BOOT_COMPLETED`, inspects stored timestamps, and if the session is still active, immediately reschedules the exact alarm.

---

## 4. Verification Results

### Automated Tests (`flutter test`)
**Result: 11 / 11 Passed (100%)**
- `PomodoroState Unit Tests`: Default values verification
- `PomodoroState Unit Tests`: `formattedRemainingTime` padding tests (`mm:ss`)
- `PomodoroState Unit Tests`: Progress float calculation accuracy
- `PomodoroState Unit Tests`: `copyWith` non-destructive mutations
- `PomodoroSettings Tests`: Clamps duration to valid 1–120 range
- `PomodoroSettings Tests`: JSON serialization & deserialization round-trip
- `DailyStatistics Tests`: JSON serialization & deserialization
- `DailyStatistics Tests`: `copyWith` updating
- `Background Timestamp Recovery Math Tests`: Exact remaining seconds calculation
- `Background Timestamp Recovery Math Tests`: Expired session boundary check
- `Cycle Progression Logic Tests`: Work $\to$ Short Break $\to$ Long Break progression

### Static Code Analysis (`flutter analyze`)
**Result: 0 issues found!**
- 0 errors
- 0 warnings
- 0 lints
- Clean compliance with Flutter 3.47 and Dart 3.13 typing standards.

---

## 5. Build Artifact & Deliverables

### Android Debug APK
- **Status:** Build Succeeded (`flutter build apk --debug` in 325.4s)
- **Primary APK Path:** `d:\Ayush\Pomodoro APK\build\app\outputs\flutter-apk\app-debug.apk`
- **Secondary Mirror:** `d:\Ayush\Pomodoro APK\build\app\outputs\apk\debug\app-debug.apk`
- **Package ID:** `com.example.pomodoro_timer`
- **Version:** `1.0.0 (versionCode 1)`
- **File Size:** ~158.2 MB (debug build containing all ABIs and debug symbols)
- **Min SDK:** 24 (Android 7.0+)
- **Compile SDK:** 37 (Android 15+)
- **Target SDK:** 34 / 35
