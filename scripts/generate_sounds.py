#!/usr/bin/env python3
"""Synthesise the bundled notification tones as 16-bit PCM WAV files.

iOS accepts .wav / .aiff / .caf (linear PCM) for notification sounds, up to 30
seconds. These are generated rather than sourced so the repo carries no licensed
audio. Run from the repo root:

    python3 scripts/generate_sounds.py

Output: DeskBreak/Resources/Sounds/*.wav
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.join("DeskBreak", "Resources", "Sounds")
PEAK = 0.82


def envelope(t, duration, attack=0.004, decay=None):
    """Fast attack, exponential decay, with a short fade at the very end so the
    file never terminates on a non-zero sample (which clicks)."""
    if t < attack:
        amp = t / attack
    else:
        tau = decay if decay is not None else duration / 4.0
        amp = math.exp(-(t - attack) / tau)
    fade = 0.01
    if t > duration - fade:
        amp *= max(0.0, (duration - t) / fade)
    return amp


def tone(samples, start, duration, partials, decay=None, gain=1.0):
    """Add a struck-note: a set of (frequency_multiplier, amplitude) partials
    under one shared decay envelope."""
    offset = int(start * SAMPLE_RATE)
    count = int(duration * SAMPLE_RATE)
    for i in range(count):
        index = offset + i
        if index >= len(samples):
            break
        t = i / SAMPLE_RATE
        amp = envelope(t, duration, decay=decay) * gain
        value = 0.0
        for freq, weight in partials:
            value += weight * math.sin(2 * math.pi * freq * t)
        samples[index] += amp * value


def glide(samples, start, duration, f_start, f_end, gain=1.0):
    """Add a pitch-falling blip — the water-drop shape."""
    offset = int(start * SAMPLE_RATE)
    count = int(duration * SAMPLE_RATE)
    phase = 0.0
    for i in range(count):
        index = offset + i
        if index >= len(samples):
            break
        t = i / SAMPLE_RATE
        progress = t / duration
        freq = f_start * ((f_end / f_start) ** progress)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        samples[index] += envelope(t, duration, decay=duration / 3.0) * gain * math.sin(phase)


def buffer(seconds):
    return [0.0] * int(seconds * SAMPLE_RATE)


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = PEAK / peak
    frames = bytearray()
    for sample in samples:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, sample * scale)) * 32767))
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print("%-14s %6.2f s  %6.1f KB" % (name, len(samples) / SAMPLE_RATE, len(frames) / 1024))


def chime():
    s = buffer(1.4)
    for start, freq in ((0.0, 1046.50), (0.28, 783.99)):
        tone(s, start, 1.1, [(freq, 1.0), (freq * 2.0, 0.32), (freq * 3.0, 0.10)], decay=0.30)
    return s


def marimba():
    s = buffer(1.0)
    for i, freq in enumerate((523.25, 659.25, 783.99)):
        tone(s, i * 0.13, 0.55, [(freq, 1.0), (freq * 4.0, 0.30), (freq * 9.8, 0.08)], decay=0.11)
    return s


def drop():
    s = buffer(0.9)
    glide(s, 0.0, 0.13, 1500.0, 480.0, gain=1.0)
    tone(s, 0.10, 0.70, [(620.0, 1.0), (1240.0, 0.22)], decay=0.13, gain=0.55)
    return s


def bell():
    s = buffer(2.6)
    f = 880.0
    tone(s, 0.0, 2.5,
         [(f, 1.0), (f * 2.00, 0.45), (f * 2.76, 0.30), (f * 5.40, 0.14), (f * 8.93, 0.06)],
         decay=0.62)
    return s


def bowl():
    s = buffer(3.6)
    f = 432.0
    tone(s, 0.0, 3.5,
         [(f, 1.0), (f * 1.80, 0.38), (f * 2.90, 0.18), (f * 4.10, 0.07)],
         decay=1.15)
    return s


def ping():
    s = buffer(0.7)
    tone(s, 0.0, 0.6, [(2093.00, 1.0), (4186.00, 0.18)], decay=0.14)
    return s


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, generator in (
        ("chime.wav", chime),
        ("marimba.wav", marimba),
        ("drop.wav", drop),
        ("bell.wav", bell),
        ("bowl.wav", bowl),
        ("ping.wav", ping),
    ):
        write(name, generator())


if __name__ == "__main__":
    main()
