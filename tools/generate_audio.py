from __future__ import annotations

import math
import os
import random
import struct
import wave


ROOT = os.path.dirname(os.path.dirname(__file__))
AUDIO_DIR = os.path.join(ROOT, "audio")
SAMPLE_RATE = 22050
MASTER_GAIN = 0.72


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def sine(phase: float) -> float:
    return math.sin(phase * math.tau)


def triangle(phase: float) -> float:
    return 4.0 * abs(phase - math.floor(phase + 0.5)) - 1.0


def saw(phase: float) -> float:
    return 2.0 * (phase - math.floor(phase + 0.5))


def noise() -> float:
    return random.uniform(-1.0, 1.0)


def envelope(t: float, duration: float, attack: float, decay: float, sustain: float, release: float) -> float:
    if t < 0.0 or t > duration:
        return 0.0
    if attack > 0.0 and t < attack:
        return t / attack
    t -= attack
    if decay > 0.0 and t < decay:
        return 1.0 + (sustain - 1.0) * (t / decay)
    sustain_time = max(0.0, duration - attack - decay - release)
    if t < decay + sustain_time:
        return sustain
    t -= decay + sustain_time
    if release > 0.0 and t < release:
        return sustain * (1.0 - t / release)
    return 0.0


def write_wav(name: str, samples: list[float]) -> None:
    path = os.path.join(AUDIO_DIR, name)
    with wave.open(path, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            value = int(clamp(sample * MASTER_GAIN, -1.0, 1.0) * 32767)
            frames.extend(struct.pack("<h", value))
        wav_file.writeframes(frames)


def render(duration: float, fn) -> list[float]:
    frame_count = int(duration * SAMPLE_RATE)
    samples: list[float] = []
    for index in range(frame_count):
        t = index / SAMPLE_RATE
        samples.append(clamp(fn(t), -1.0, 1.0))
    return samples


def shot_sound() -> list[float]:
    duration = 0.12
    def synth(t: float) -> float:
        freq = 920.0 - 380.0 * (t / duration)
        phase = t * freq
        env = envelope(t, duration, 0.002, 0.03, 0.28, 0.05)
        return (0.72 * triangle(phase) + 0.14 * noise()) * env
    return render(duration, synth)


def hit_sound() -> list[float]:
    duration = 0.10
    def synth(t: float) -> float:
        freq = 240.0 + 160.0 * (1.0 - t / duration)
        env = envelope(t, duration, 0.001, 0.02, 0.15, 0.05)
        return (0.58 * noise() + 0.32 * sine(t * freq)) * env
    return render(duration, synth)


def enemy_death_sound() -> list[float]:
    duration = 0.22
    def synth(t: float) -> float:
        freq = 320.0 - 180.0 * (t / duration)
        env = envelope(t, duration, 0.002, 0.04, 0.24, 0.12)
        return (0.5 * saw(t * freq) + 0.28 * noise()) * env
    return render(duration, synth)


def hurt_sound() -> list[float]:
    duration = 0.18
    def synth(t: float) -> float:
        freq = 170.0 - 70.0 * (t / duration)
        env = envelope(t, duration, 0.003, 0.05, 0.18, 0.08)
        return (0.62 * saw(t * freq) + 0.18 * noise()) * env
    return render(duration, synth)


def pickup_sound() -> list[float]:
    duration = 0.16
    def synth(t: float) -> float:
        env = envelope(t, duration, 0.002, 0.03, 0.36, 0.05)
        tone_a = sine(t * 1046.5)
        tone_b = sine(t * 1318.5)
        return (0.48 * tone_a + 0.34 * tone_b) * env
    return render(duration, synth)


def upgrade_sound() -> list[float]:
    duration = 0.42
    notes = [523.25, 659.25, 783.99]
    def synth(t: float) -> float:
        total = 0.0
        for idx, note in enumerate(notes):
            offset = idx * 0.08
            if t >= offset:
                local = t - offset
                env = envelope(local, duration - offset, 0.003, 0.05, 0.3, 0.12)
                total += sine(local * note) * env
        return total * 0.45
    return render(duration, synth)


def ui_click_sound() -> list[float]:
    duration = 0.09
    def synth(t: float) -> float:
        env = envelope(t, duration, 0.001, 0.02, 0.22, 0.03)
        return (0.75 * triangle(t * 760.0) + 0.12 * noise()) * env
    return render(duration, synth)


def charge_sound() -> list[float]:
    duration = 0.42
    def synth(t: float) -> float:
        freq = 200.0 + 260.0 * (t / duration)
        env = envelope(t, duration, 0.01, 0.08, 0.45, 0.06)
        return (0.46 * saw(t * freq) + 0.16 * noise()) * env
    return render(duration, synth)


def ray_sound() -> list[float]:
    duration = 0.34
    def synth(t: float) -> float:
        freq = 540.0 + 180.0 * math.sin(t * 12.0)
        env = envelope(t, duration, 0.01, 0.06, 0.48, 0.08)
        return (0.4 * sine(t * freq) + 0.32 * triangle(t * (freq * 1.5))) * env
    return render(duration, synth)


def end_sound() -> list[float]:
    duration = 0.55
    notes = [392.0, 523.25, 659.25]
    def synth(t: float) -> float:
        total = 0.0
        for idx, note in enumerate(notes):
            env = envelope(t, duration, 0.004, 0.08, 0.32, 0.18)
            total += sine(t * note) * env * (0.42 if idx == 0 else 0.28)
        return total
    return render(duration, synth)


def menu_loop() -> list[float]:
    duration = 8.0
    chord_steps = [(0.0, [220.0, 277.18, 329.63]), (2.0, [196.0, 246.94, 293.66]), (4.0, [220.0, 277.18, 329.63]), (6.0, [174.61, 220.0, 261.63])]
    def synth(t: float) -> float:
        total = 0.0
        for start, notes in chord_steps:
            if start <= t < start + 2.05:
                local = t - start
                env = envelope(local, 2.0, 0.12, 0.35, 0.44, 0.35)
                for note in notes:
                    total += sine(local * note) * 0.16 * env
                total += sine(local * (notes[0] * 0.5)) * 0.09 * env
        shimmer = sine(t * 0.35) * 0.02 + sine(t * 0.6) * 0.015
        return total + shimmer
    return render(duration, synth)


def run_loop() -> list[float]:
    duration = 8.0
    bass_notes = [110.0, 110.0, 123.47, 146.83]
    pulse_times = [i * 0.5 for i in range(16)]
    def synth(t: float) -> float:
        total = 0.0
        bar = int(t // 2.0) % len(bass_notes)
        base = bass_notes[bar]
        total += sine(t * base) * 0.12
        total += sine(t * base * 2.0) * 0.05
        for pulse in pulse_times:
            if pulse <= t < pulse + 0.2:
                local = t - pulse
                env = envelope(local, 0.2, 0.002, 0.04, 0.18, 0.05)
                total += triangle(local * (base * 4.0)) * 0.16 * env
        total += noise() * 0.01
        return total
    return render(duration, synth)


def main() -> None:
    os.makedirs(AUDIO_DIR, exist_ok=True)
    random.seed(42)
    sounds = {
        "player_shot.wav": shot_sound(),
        "enemy_hit.wav": hit_sound(),
        "enemy_death.wav": enemy_death_sound(),
        "player_hurt.wav": hurt_sound(),
        "xp_collect.wav": pickup_sound(),
        "upgrade_pick.wav": upgrade_sound(),
        "ui_click.wav": ui_click_sound(),
        "enemy_charge.wav": charge_sound(),
        "enemy_ray.wav": ray_sound(),
        "run_end.wav": end_sound(),
        "menu_loop.wav": menu_loop(),
        "run_loop.wav": run_loop(),
    }
    for name, samples in sounds.items():
        write_wav(name, samples)
        print(f"generated {name}")


if __name__ == "__main__":
    main()
