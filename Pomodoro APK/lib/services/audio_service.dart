import 'native_timer_service.dart';

class AudioService {
  final NativeTimerService _nativeService;
  String? _currentlyPlaying;

  AudioService([NativeTimerService? nativeService])
      : _nativeService = nativeService ?? NativeTimerService();

  String? get currentlyPlaying => _currentlyPlaying;

  Future<void> previewSound(String soundName) async {
    _currentlyPlaying = soundName;
    await _nativeService.previewSound(soundName);
  }

  Future<void> stopPreview() async {
    _currentlyPlaying = null;
    await _nativeService.stopPreview();
  }

  void dispose() {
    stopPreview();
  }
}
