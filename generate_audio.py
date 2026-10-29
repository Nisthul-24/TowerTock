#!/usr/bin/env python3
"""
generate_audio.py — Procedurally synthesizes TowerTock sound effects as WAV files.
Run from the towertock project root:
    python generate_audio.py

Requires no external libraries (uses Python standard library only).
Output: assets/audio/*.wav files suitable for Godot import.
"""

import struct
import math
import os
import wave

OUTPUT_DIR = os.path.join("assets", "audio")
SAMPLE_RATE = 44100

def make_wav(filename: str, samples: list[float], sample_rate: int = SAMPLE_RATE) -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, filename)
    clamped = [max(-1.0, min(1.0, s)) for s in samples]
    int_samples = [int(s * 32767) for s in clamped]

    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        data = struct.pack(f'<{len(int_samples)}h', *int_samples)
        wf.writeframes(data)
    print(f"  Created: {filepath}")

def sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)

def envelope(t: float, duration: float, attack: float = 0.01, release: float = 0.1) -> float:
    if t < attack:
        return t / attack
    if t > duration - release:
        return (duration - t) / release
    return 1.0

def make_tone(freq: float, duration: float, amp: float = 0.6, detune: float = 0.0) -> list[float]:
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, duration)
        s = sine(freq + detune * sine(3.0, t), t) * amp * env
        samples.append(s)
    return samples

def fade(samples: list[float], fade_in: int = 100, fade_out: int = 500) -> list[float]:
    result = samples[:]
    for i in range(min(fade_in, len(result))):
        result[i] *= i / fade_in
    for i in range(min(fade_out, len(result))):
        idx = len(result) - 1 - i
        result[idx] *= i / fade_out
    return result

def mix(a: list[float], b: list[float]) -> list[float]:
    length = max(len(a), len(b))
    result = [0.0] * length
    for i, s in enumerate(a):
        result[i] += s
    for i, s in enumerate(b):
        result[i] += s
    return result

# ── Sound Effects ──────────────────────────────────────────────

def gen_button_click():
    n = int(SAMPLE_RATE * 0.08)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 880.0 * (1.0 - t * 6.0)
        env = max(0.0, 1.0 - t * 18.0)
        samples.append(sine(freq, t) * 0.5 * env)
    make_wav("sfx_button_click.wav", fade(samples, 0, 200))

def gen_release():
    n = int(SAMPLE_RATE * 0.15)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 400.0 + 200.0 * (1.0 - t / 0.15)
        env = max(0.0, 1.0 - t / 0.12)
        samples.append(sine(freq, t) * 0.4 * env)
    make_wav("sfx_release.wav", fade(samples, 50, 300))

def gen_land():
    n = int(SAMPLE_RATE * 0.25)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Low thud
        freq_low = 80.0 * (1.0 - t * 2.0)
        env = max(0.0, 1.0 - t * 5.0)
        noise = (hash(i * 7919) % 1000 / 500.0 - 1.0) * 0.1
        s = (sine(max(40.0, freq_low), t) * 0.5 + noise) * env
        samples.append(s)
    make_wav("sfx_land.wav", fade(samples, 10, 400))

def gen_perfect():
    # Pleasant ascending chord
    s1 = make_tone(523.25, 0.5, 0.35)  # C5
    s2 = make_tone(659.25, 0.5, 0.30)  # E5
    s3 = make_tone(783.99, 0.5, 0.25)  # G5
    combined = mix(mix(s1, s2), s3)
    make_wav("sfx_perfect.wav", fade(combined, 100, 2000))

def gen_combo():
    s1 = make_tone(440.0, 0.18, 0.4)
    s2 = make_tone(554.37, 0.18, 0.35)
    # s2 starts 80ms later
    offset = int(SAMPLE_RATE * 0.08)
    padded = [0.0] * offset + s2
    combined = mix(s1, padded[:int(SAMPLE_RATE * 0.26)])
    make_wav("sfx_combo.wav", fade(combined, 50, 800))

def gen_miss():
    n = int(SAMPLE_RATE * 0.4)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 200.0 - 150.0 * (t / 0.4)
        env = max(0.0, 1.0 - t * 3.0)
        samples.append(sine(freq, t) * 0.5 * env)
    make_wav("sfx_miss.wav", fade(samples, 50, 800))

def gen_game_over():
    # Descending minor arpeggio
    notes = [392.0, 349.23, 311.13, 261.63]
    all_samples = []
    for freq in notes:
        tone = make_tone(freq, 0.35, 0.4)
        all_samples.extend(tone)
    make_wav("sfx_game_over.wav", fade(all_samples, 100, 3000))

def gen_revive():
    # Triumphant ascending
    notes = [523.25, 659.25, 783.99, 1046.5]
    all_samples = []
    for freq in notes:
        tone = make_tone(freq, 0.2, 0.4)
        all_samples.extend(tone)
    make_wav("sfx_revive.wav", fade(all_samples, 100, 2000))

def gen_music_placeholder():
    """Simple repeating bass loop as placeholder music."""
    # 4-bar loop of a simple melody
    notes = [
        (261.63, 0.5), (293.66, 0.25), (329.63, 0.25),
        (349.23, 0.5), (392.00, 0.5),
        (261.63, 0.25), (329.63, 0.25), (392.00, 0.5), (440.00, 0.5),
    ]
    loop_samples = []
    for freq, dur in notes:
        tone = make_tone(freq, dur, 0.2)
        loop_samples.extend(tone)
    # Repeat 4 times for ~8 second loop
    all_samples = loop_samples * 4
    make_wav("music_main.wav", fade(all_samples, 1000, 5000))

if __name__ == "__main__":
    print("Generating TowerTock audio assets...")
    gen_button_click()
    gen_release()
    gen_land()
    gen_perfect()
    gen_combo()
    gen_miss()
    gen_game_over()
    gen_revive()
    gen_music_placeholder()
    print("Done! Import these WAV files into Godot.")
    print("Note: Convert OGG paths in audio_manager.gd to .wav for testing,")
    print("      or import WAVs and let Godot handle the conversion.")
