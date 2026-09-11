import 'dart:async';
import 'package:flutter/services.dart';

class NativeTimerService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.pomodorotimer/timer');
  static const EventChannel _eventChannel = EventChannel('com.example.pomodorotimer/events');

  Stream<Map<String, dynamic>>? _eventStream;

  Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  Future<bool> startTimer({
    required String phase,
    required int durationSeconds,
    required bool autoStartBreaks,
    required bool autoStartWork,
    required bool vibrationEnabled,
    required String selectedAlarmSound,
    required int currentCycle,
    required int totalCycles,
    required int completedPomodorosToday,
  }) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('startTimer', {
        'phase': phase,
        'durationSeconds': durationSeconds,
        'autoStartBreaks': autoStartBreaks,
        'autoStartWork': autoStartWork,
        'vibrationEnabled': vibrationEnabled,
        'selectedAlarmSound': selectedAlarmSound,
        'currentCycle': currentCycle,
        'totalCycles': totalCycles,
        'completedPomodorosToday': completedPomodorosToday,
      });
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> pauseTimer() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('pauseTimer');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> resumeTimer() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('resumeTimer');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> resetTimer() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('resetTimer');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> skipSession() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('skipSession');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> stopAlarm() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('stopAlarm');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> previewSound(String sound) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('previewSound', {'sound': sound});
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> stopPreview() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('stopPreview');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTimerState() async {
    try {
      final res = await _methodChannel.invokeMethod<Map>('getTimerState');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } on PlatformException catch (_) {}
    return null;
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('canScheduleExactAlarms');
      return res ?? true;
    } on PlatformException catch (_) {
      return true;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestExactAlarmPermission');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
