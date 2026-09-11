import os
import math
import wave
import struct

def generate_tone(filename, duration, sample_rate, wave_func):
    num_samples = int(duration * sample_rate)
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1) # mono
        wav.setsampwidth(2) # 16-bit
        wav.setframerate(sample_rate)
        for i in range(num_samples):
            t = i / sample_rate
            sample = wave_func(t, duration)
            sample = max(-1.0, min(1.0, sample))
            int_val = int(sample * 32767.0)
            wav.writeframes(struct.pack('<h', int_val))

def classic_wave(t, dur):
    # Pulsing ringing bell (twin bell mechanical chime)
    burst = 1.0 if (t % 0.12) < 0.08 else 0.0
    mod = math.sin(2 * math.pi * 15 * t)
    return 0.7 * burst * (math.sin(2 * math.pi * 850 * t) + 0.5 * math.sin(2 * math.pi * 1250 * t)) * (0.8 + 0.2 * mod)

def digital_wave(t, dur):
    # Beep beep beep beep
    cycle = t % 0.5
    is_beep = 1.0 if cycle < 0.15 else 0.0
    return 0.7 * is_beep * math.sin(2 * math.pi * 2200 * t)

def bell_wave(t, dur):
    # Meditative bell strike with harmonic decay
    cycle = t % 1.5
    decay = math.exp(-3.0 * cycle)
    s = math.sin(2 * math.pi * 528 * cycle) + 0.5 * math.sin(2 * math.pi * 1056 * cycle) + 0.25 * math.sin(2 * math.pi * 1584 * cycle)
    return 0.8 * decay * s

def soft_wave(t, dur):
    # Gentle arpeggio chime (C - E - G - B)
    notes = [523.25, 659.25, 783.99, 987.77]
    idx = int((t % 1.6) / 0.4)
    note_t = (t % 0.4)
    freq = notes[min(idx, 3)]
    decay = math.exp(-4.0 * note_t)
    return 0.6 * decay * (math.sin(2 * math.pi * freq * note_t) + 0.3 * math.sin(2 * math.pi * freq * 2 * note_t))

def alarm_wave(t, dur):
    # Urgent alternating two-tone alarm
    cycle = t % 0.6
    freq = 900 if cycle < 0.3 else 1200
    return 0.75 * math.sin(2 * math.pi * freq * t)

dirs = [
    r"d:\Ayush\Pomodoro APK\assets\audio",
    r"d:\Ayush\Pomodoro APK\android\app\src\main\res\raw"
]

for d in dirs:
    os.makedirs(d, exist_ok=True)

generators = {
    "classic.wav": classic_wave,
    "digital.wav": digital_wave,
    "bell.wav": bell_wave,
    "soft.wav": soft_wave,
    "alarm.wav": alarm_wave,
}

for name, func in generators.items():
    for d in dirs:
        filepath = os.path.join(d, name)
        generate_tone(filepath, duration=3.0, sample_rate=44100, wave_func=func)
        print(f"Generated {filepath}")

print("All audio files successfully generated!")
