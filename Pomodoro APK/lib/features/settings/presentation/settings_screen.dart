import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/pomodoro_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/audio_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AudioService _audioService = AudioService();
  bool _isPlayingPreview = false;

  bool _isIgnoringBattery = false;
  bool _canExactAlarm = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final nativeService = ref.read(nativeTimerServiceProvider);
    final battery = await nativeService.isIgnoringBatteryOptimizations();
    final exact = await nativeService.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _isIgnoringBattery = battery;
        _canExactAlarm = exact;
      });
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  void _previewSound(String sound) async {
    setState(() => _isPlayingPreview = true);
    await _audioService.previewSound(sound);
  }

  void _stopPreview() async {
    await _audioService.stopPreview();
    setState(() => _isPlayingPreview = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final pomodoroNotifier = ref.read(pomodoroProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Timer Durations Section
          _buildSectionHeader(context, 'TIMER DURATIONS'),
          const SizedBox(height: 8),

          _buildDurationCard(
            context: context,
            title: 'Work Duration',
            value: settings.workDurationMinutes,
            min: 1,
            max: 120,
            activeColor: AppColors.workPrimary,
            onChanged: (val) {
              settingsNotifier.updateWorkDuration(val);
              pomodoroNotifier.updateSettings(settings.copyWith(workDurationMinutes: val));
            },
          ),
          const SizedBox(height: 12),

          _buildDurationCard(
            context: context,
            title: 'Short Break Duration',
            value: settings.shortBreakDurationMinutes,
            min: 1,
            max: 60,
            activeColor: AppColors.shortBreakPrimary,
            onChanged: (val) {
              settingsNotifier.updateShortBreakDuration(val);
              pomodoroNotifier.updateSettings(settings.copyWith(shortBreakDurationMinutes: val));
            },
          ),
          const SizedBox(height: 12),

          _buildDurationCard(
            context: context,
            title: 'Long Break Duration',
            value: settings.longBreakDurationMinutes,
            min: 1,
            max: 60,
            activeColor: AppColors.longBreakPrimary,
            onChanged: (val) {
              settingsNotifier.updateLongBreakDuration(val);
              pomodoroNotifier.updateSettings(settings.copyWith(longBreakDurationMinutes: val));
            },
          ),
          const SizedBox(height: 12),

          _buildDurationCard(
            context: context,
            title: 'Cycles Before Long Break',
            value: settings.cyclesBeforeLongBreak,
            min: 1,
            max: 12,
            unit: 'cycles',
            activeColor: Colors.amber.shade700,
            onChanged: (val) {
              settingsNotifier.updateCycles(val);
              pomodoroNotifier.updateSettings(settings.copyWith(cyclesBeforeLongBreak: val));
            },
          ),
          const SizedBox(height: 28),

          // 2. Behavior Section
          _buildSectionHeader(context, 'BEHAVIOR'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-start Breaks', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Start break immediately when work session ends'),
                  value: settings.autoStartBreaks,
                  onChanged: (val) => settingsNotifier.toggleAutoStartBreaks(val),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Auto-start Work Sessions', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Start work session immediately when break ends'),
                  value: settings.autoStartWork,
                  onChanged: (val) => settingsNotifier.toggleAutoStartWork(val),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Vibrate on Alarm', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Vibrate phone continuously when session completes'),
                  value: settings.vibrationEnabled,
                  onChanged: (val) => settingsNotifier.toggleVibration(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 3. Alarm Sounds Section
          _buildSectionHeader(context, 'ALARM SOUND'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RadioGroup<String>(
                groupValue: settings.selectedAlarmSound,
                onChanged: (val) {
                  if (val != null) {
                    settingsNotifier.selectAlarmSound(val);
                    _previewSound(val);
                  }
                },
                child: Column(
                  children: [
                    for (final sound in ['classic', 'digital', 'bell', 'soft', 'alarm'])
                      RadioListTile<String>(
                        title: Text(
                          sound[0].toUpperCase() + sound.substring(1),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        value: sound,
                        secondary: _isPlayingPreview && settings.selectedAlarmSound == sound
                            ? IconButton(
                                icon: const Icon(Icons.stop_circle_rounded, color: AppColors.error),
                                onPressed: _stopPreview,
                                tooltip: 'Stop Preview',
                              )
                            : IconButton(
                                icon: const Icon(Icons.volume_up_rounded),
                                onPressed: () => _previewSound(sound),
                                tooltip: 'Play Preview',
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 4. Appearance Section
          _buildSectionHeader(context, 'APPEARANCE'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) {
                      settingsNotifier.updateTheme(set.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 5. Background & Battery Optimization Section
          _buildSectionHeader(context, 'BACKGROUND EXECUTION'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isIgnoringBattery ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: _isIgnoringBattery ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isIgnoringBattery
                            ? 'Battery Optimization: Unrestricted'
                            : 'Battery Optimization: Restricted',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To ensure timers and alarms ring reliably when your screen is locked or the app is minimized, allow background activity. Some manufacturers (Samsung, Xiaomi, Oppo) aggressively freeze background apps.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.battery_saver),
                        label: const Text('Allow Background Activity'),
                        onPressed: () async {
                          final native = ref.read(nativeTimerServiceProvider);
                          await native.requestIgnoreBatteryOptimizations();
                          _checkPermissions();
                        },
                      ),
                      if (!_canExactAlarm)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.alarm),
                          label: const Text('Enable Exact Alarms'),
                          onPressed: () async {
                            final native = ref.read(nativeTimerServiceProvider);
                            await native.requestExactAlarmPermission();
                            _checkPermissions();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required BuildContext context,
    required String title,
    required int value,
    required int min,
    required int max,
    required Color activeColor,
    required ValueChanged<int> onChanged,
    String unit = 'min',
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$value $unit',
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                ),
                Expanded(
                  child: Slider(
                    value: value.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    activeColor: activeColor,
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
