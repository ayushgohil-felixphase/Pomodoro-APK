# ⏱️ Pomodoro Timer - Android & Flutter

A production-grade, background-resilient Pomodoro Timer application built with **Flutter (3.47+)**, **Riverpod 3**, and **Android Native Kotlin**.

Engineered to guarantee exact alarms and persistent countdowns even under Android Doze mode, background process termination, and device reboots.

---

## 🌟 Key Features

- **Bulletproof Background Service**: Uses an Android native `ForegroundService` with an ongoing notification displaying live countdown (`mm:ss`) and action buttons (**Pause**, **Resume**, **Skip**, **Reset**).
- **Exact Alarms & Deep Sleep Awakening**: Scheduled using `AlarmManager.setExactAndAllowWhileIdle()` with high-priority `RTC_WAKEUP`.
- **Lockscreen-Aware Full-Screen Alarm UI**: Custom native `AlarmActivity` turns on the display over lockscreens (`setShowWhenLocked(true)`, `setTurnScreenOn(true)`).
- **High-Priority Audio & Haptics**: Uses `AudioAttributes.USAGE_ALARM` (`STREAM_ALARM`) to bypass silent media volume, accompanied by looping synchronized vibration pulses.
- **Process Death & Reboot Resilience**: Session end timestamps are stored in `SharedPreferences`. If Android terminates the app or the phone restarts, session state is calculated mathematically with zero drift.
- **Material 3 Dynamic UI**: Custom canvas circular timer, dark/light theme toggle, customizable session durations (1–120 minutes), and 7-day productivity statistics bar chart.

---

## 🚀 Step-by-Step Guide for Reviewers

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ recommended; built with Flutter 3.47.3 / Dart 3.13.3)
- Android SDK (API 34+ platform and tools)
- Java / JDK 17 or Android Studio JBR
- Android phone or emulator (Android 7.0 / API 24+)

---

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd pomodoro-timer
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Automated Tests
Verify all 11 unit tests covering state immutability, duration boundaries, and timestamp recovery:
```bash
flutter test
```

### 4. Run Code Analysis
Confirm zero lints, warnings, or errors:
```bash
flutter analyze
```

### 5. Run on Connected Device or Emulator
Connect your Android phone via USB (with USB Debugging enabled) or start an emulator:
```bash
flutter run
```

### 6. Build Debug APK
To assemble the standalone debug APK:
```bash
flutter build apk --debug
```
The compiled APK will be located at:
```
build/app/outputs/flutter-apk/app-debug.apk
```

---

## 📱 How to Verify APK Features (Testing Checklist)

### Test 1: In-App Timer & Controls
1. Launch the app.
2. Tap **Start**. Verify the circular progress ring smoothly animates and time counts down.
3. Tap **Pause** $\to$ timer pauses. Tap **Resume** $\to$ countdown resumes.
4. Tap **Skip** $\to$ smoothly transitions to Short Break.

### Test 2: Background Notification & Controls
1. Start a timer and press the **Home button** or switch to another app.
2. Pull down the Android notification shade:
   - Verify the persistent **"Pomodoro Timer"** notification shows the session name and live countdown.
   - Tap the **Pause** action button directly in the notification $\to$ verify timer pauses.
   - Tap **Resume** $\to$ verify timer resumes.

### Test 3: Lockscreen Awakening & Exact Alarm
1. In **Settings**, set Work duration to **1 minute** for testing.
2. Start the timer and lock your phone screen (press power button).
3. Wait for the 1 minute to elapse:
   - Verify the screen wakes up automatically.
   - Verify the native full-screen **Alarm Screen** appears over the lockscreen.
   - Verify loud looping alarm sound and vibration play.
   - Tap **"STOP ALARM"** $\to$ alarm silences and screen unlocks/dismisses.

### Test 4: Process Kill Recovery
1. Start a 5-minute timer.
2. Note the remaining time (e.g., 4:30).
3. Force stop the app or swipe it away from Android Recents.
4. Wait 30 seconds and reopen the app.
5. Verify the timer shows 4:00 (exact time elapsed calculated without drift).

### Test 5: Battery Optimization Whitelisting
1. On the main screen, check the **"Battery Optimization"** banner.
2. Tap the banner to open the system prompt to request exclusion from Android battery restrictions.

---

## 🏗️ Architecture & Native Implementation

| Feature | Android Native Implementation |
|---|---|
| **Foreground Service** | `android/app/src/main/kotlin/.../TimerForegroundService.kt` |
| **Exact Alarm Receiver** | `android/app/src/main/kotlin/.../AlarmReceiver.kt` |
| **Lockscreen UI** | `android/app/src/main/kotlin/.../AlarmActivity.kt` |
| **Alarm Sound & Vibration** | `android/app/src/main/kotlin/.../AlarmAudioPlayer.kt` |
| **Reboot Rescheduling** | `android/app/src/main/kotlin/.../BootReceiver.kt` |
| **Flutter Native Bridge** | `android/app/src/main/kotlin/.../MainActivity.kt` |

---

## ⚙️ Device-Specific Background Settings (OEM Tips)

Some manufacturers (Xiaomi/HyperOS, OnePlus, Huawei, Samsung) aggressively terminate background processes:
- **Auto-start**: Allow "Pomodoro Timer" in device auto-start settings.
- **Battery Saver**: Set app battery usage to "Unrestricted" / "No restrictions".
- **Lock Screen Permissions**: Ensure "Show on Lock screen" and "Display pop-up windows" are enabled in App Permissions.
