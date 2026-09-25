#!/usr/bin/env python3
"""
generate_menu_soundtracks.py — 15 Legendary Game Menu Soundtracks.
Written from scratch. 100% pure acoustic/analog modeling, zero wobbly pitch-LFO.
Crafted for infinite, seamless, relaxing looping without fatigue or abrupt transitions.

Tracks:
1. ost_menu_velvet_lounge: Velvet Velvet (Midnight Lounge) — Persona 5 (96 BPM)
2. ost_menu_grand_touring: Moon Over the Circuit (Prestige Pavilion) — Gran Turismo (108 BPM)
3. ost_menu_astral_solitude: Quiet Horizons (Meditative Solitude) — Minecraft C418 (72 BPM)
4. ost_menu_dearly_reminiscent: Silver Moon Reflections (Fantasy Prelude) — Kingdom Hearts / FF (84 BPM)
5. ost_menu_cyber_terminal: Neon Grid Terminal (Data Terminal) — Metroid Prime / Cyberpunk (90 BPM)
6. ost_menu_breeze_plaza: Sunshine Plaza (Wii Channel Bossa) — Wii Sports / Mii Plaza (112 BPM)
7. ost_menu_sacred_spring: Spring of Serenity (Fairy Fountain Whispers) — Zelda Fairy Fountain (76 BPM)
8. ost_menu_ancient_sanctum: Sanctum of the Ring (Choral Reverence) — Halo Gregorian Choral (68 BPM)
9. ost_menu_rainy_atrium: Raindrop Atrium (Cozy Afternoon) — Animal Crossing Cozy Rain (80 BPM)
10. ost_menu_chronicle_winds: Winds of Chronos (Timeless Memories) — Chrono Trigger / Cross Folk (88 BPM)
11. ost_menu_subaquatic_drift: Coral Drift (Subaquatic Lullaby) — Donkey Kong Country Aquatic (78 BPM)
12. ost_menu_northern_aurora: Northern Frost (Whiterun Nightfall) — Skyrim Nordic Frost (70 BPM)
13. ost_menu_champions_pavilion: Challenger's Hall (Tournament Fanfare) — Smash Bros Fanfare (128 BPM)
14. ost_menu_orbital_vanguard: Orbital Transit (Starlight Vista) — Mass Effect Galaxy Map (85 BPM)
15. ost_menu_third_strike: Underground Beat (Street Select Lounge) — Street Fighter 3rd Strike (160 BPM)
"""

import os
import math
import struct
import subprocess
import random

SAMPLE_RATE = 44100
OUT_DIR = "godot/assets/audio/music"
os.makedirs(OUT_DIR, exist_ok=True)

FFMPEG_BIN = "/opt/homebrew/bin/ffmpeg"
if not os.path.exists(FFMPEG_BIN):
    FFMPEG_BIN = "ffmpeg"


def note_to_freq(note_str: str) -> float:
    notes = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4,
             'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9,
             'A#': 10, 'Bb': 10, 'B': 11}
    letter = note_str[:-1]
    octave = int(note_str[-1])
    semitone = notes[letter] + (octave + 1) * 12
    return 440.0 * (2.0 ** ((semitone - 69) / 12.0))


def write_ogg_loop(left, right, track_id, total_sec):
    """Applies seamless 0.35s loop crossfade, warm soft limiter, and exports to Ogg Vorbis."""
    total_samples = len(left)
    loop_fade = int(0.35 * SAMPLE_RATE)
    for i in range(loop_fade):
        frac = i / loop_fade
        left[i] = left[i] * frac + left[total_samples - loop_fade + i] * (1.0 - frac)
        right[i] = right[i] * frac + right[total_samples - loop_fade + i] * (1.0 - frac)
        left[total_samples - loop_fade + i] = left[i]
        right[total_samples - loop_fade + i] = right[i]

    max_val = max(max(abs(x) for x in left), max(abs(x) for x in right), 0.001)
    norm_factor = 0.88 / max_val
    for i in range(total_samples):
        left[i] = math.tanh(left[i] * norm_factor)
        right[i] = math.tanh(right[i] * norm_factor)

    wav_path = f"/tmp/{track_id}.wav"
    ogg_path = os.path.join(OUT_DIR, f"{track_id}.ogg")

    with open(wav_path, "wb") as f:
        data_size = total_samples * 4
        f.write(b"RIFF")
        f.write(struct.pack("<I", data_size + 36))
        f.write(b"WAVEfmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 2, SAMPLE_RATE, SAMPLE_RATE * 4, 4, 16))
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        for i in range(total_samples):
            sl = max(-32767, min(32767, int(left[i] * 32767.0)))
            sr = max(-32767, min(32767, int(right[i] * 32767.0)))
            f.write(struct.pack("<hh", sl, sr))

    cmd = [
        FFMPEG_BIN, "-y", "-i", wav_path,
        "-c:a", "vorbis", "-strict", "-2",
        "-q:a", "5", ogg_path
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    if os.path.exists(wav_path):
        os.remove(wav_path)

    sz_kb = os.path.getsize(ogg_path) / 1024.0
    print(f"  [OK] Generated {track_id}.ogg ({total_sec:.1f}s, {sz_kb:.1f} KB)")


# =============================================================================
# SYNTHESIS ENGINES (CLEAN, PHYSICAL ACOUSTIC & ANALOG TIMBRES)
# =============================================================================

def add_rhodes_note(left, right, start_s, dur_s, freq, gain=0.20, pan=0.0):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env_body = math.exp(-t * 2.2) if t > 0.003 else (t / 0.003)
        env_tine = math.exp(-t * 9.0) if t > 0.001 else (t / 0.001)
        f1 = math.sin(2.0 * math.pi * freq * t)
        f2 = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        f3 = 0.12 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        tine = (0.28 * math.sin(2.0 * math.pi * freq * 3.98 * t) +
                0.15 * math.sin(2.0 * math.pi * freq * 7.12 * t)) * env_tine
        sig = math.tanh(((f1 + f2 + f3) * env_body + tine) * 1.25) * gain
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_felt_piano_note(left, right, start_s, dur_s, freq, gain=0.22, pan=0.0):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 1.8) if t > 0.012 else (t / 0.012)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.28 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 2.5)
        h3 = 0.08 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 4.0)
        thud = math.sin(2.0 * math.pi * 75.0 * t) * math.exp(-t * 45.0) * 0.06
        sig = (h1 + h2 + h3 + thud) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_concert_harp_note(left, right, start_s, dur_s, freq, gain=0.20, pan=0.0):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.2) if t > 0.003 else (t / 0.003)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.40 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 4.0)
        h3 = 0.20 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 6.5)
        sig = (h1 + h2 + h3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_nylon_guitar_note(left, right, start_s, dur_s, freq, gain=0.18, pan=-0.2):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.8) if t > 0.004 else (t / 0.004)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        h3 = 0.15 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 8.0)
        sig = (h1 + h2 + h3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_marimba_note(left, right, start_s, dur_s, freq, gain=0.22, pan=0.0):
    """Warm rosewood bar marimba with hollow tube resonator."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 6.5) if t > 0.002 else (t / 0.002)
        bar = math.sin(2.0 * math.pi * freq * t)
        tube = 0.50 * math.sin(2.0 * math.pi * freq * 3.92 * t) * math.exp(-t * 18.0)
        click = math.sin(2.0 * math.pi * 850.0 * t) * math.exp(-t * 45.0) * 0.12
        sig = (bar + tube + click) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_gregorian_choir(left, right, start_s, dur_s, chord_freqs, gain=0.22, pan=0.0):
    """Noble Gregorian monk choral voices (Halo style). Deep solemn vowel resonance."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.4) * min(1.0, (dur_s - t) / 0.5)
        sig_c = 0.0
        for f in chord_freqs:
            v1 = math.sin(2.0 * math.pi * f * t)
            v2 = 0.45 * math.sin(2.0 * math.pi * 2.0 * f * t)
            v3 = 0.25 * math.sin(2.0 * math.pi * 3.0 * f * t)
            # O / U monk chest vowel resonance
            formant = 0.35 * math.sin(2.0 * math.pi * 420.0 * t) * math.exp(-((t * 2.0) % 1.0) * 2.0)
            sig_c += (v1 + v2 + v3 + formant)
        sig = (sig_c / max(1, len(chord_freqs))) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_ukulele_strum(left, right, start_s, chord_freqs, gain=0.20, is_down=True):
    """Hawaiian koa ukulele strum (Animal Crossing style)."""
    num_strings = len(chord_freqs)
    span = 0.012
    for s_idx, f_item in enumerate(chord_freqs):
        freq = note_to_freq(f_item) if isinstance(f_item, str) else f_item
        offset = (s_idx / max(1, num_strings - 1)) * span if is_down else ((num_strings - 1 - s_idx) / max(1, num_strings - 1)) * span
        start_idx = int((start_s + offset) * SAMPLE_RATE)
        num_samples = int(0.7 * SAMPLE_RATE)
        pan = -0.15 + (s_idx / max(1, num_strings - 1)) * 0.3
        l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
        r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
        for i in range(num_samples):
            idx = start_idx + i
            if idx >= len(left):
                break
            t = i / SAMPLE_RATE
            env = math.exp(-t * 6.0) if t > 0.003 else (t / 0.003)
            h1 = math.sin(2.0 * math.pi * freq * t)
            h2 = 0.30 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 7.5)
            sig = (h1 + h2) * (gain / math.sqrt(num_strings)) * env
            left[idx] += sig * l_pan
            right[idx] += sig * r_pan


def add_dulcimer_note(left, right, start_s, dur_s, freq, gain=0.20, pan=0.15):
    """Hammered dulcimer / Nordic zither note (Skyrim Whiterun style)."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5) if t > 0.002 else (t / 0.002)
        wire1 = math.sin(2.0 * math.pi * freq * t)
        wire2 = 0.40 * math.sin(2.0 * math.pi * (freq * 1.002) * t)  # natural dual string detune
        strike = math.sin(2.0 * math.pi * 1200.0 * t) * math.exp(-t * 40.0) * 0.15
        sig = (wire1 + wire2 + strike) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_french_horn(left, right, start_s, dur_s, freq, gain=0.22, pan=0.0):
    """Noble French horn fanfare (Smash Bros style)."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.04) * min(1.0, (dur_s - t) / 0.07)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.50 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        h3 = 0.25 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        sig = (h1 + h2 + h3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_celeste_chime(left, right, start_s, freq, gain=0.16, pan=0.25):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(2.4 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5) if t > 0.002 else (t / 0.002)
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.25 * math.sin(2.0 * math.pi * freq * 2.76 * t) * math.exp(-t * 6.0)
        sig = (b1 + b2) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_muted_trumpet(left, right, start_s, dur_s, freq, gain=0.22, pan=0.15):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.04) * min(1.0, (dur_s - t) / 0.06)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        h3 = 0.65 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        sig = (h1 + h2 + h3) * gain * env * 0.45
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_flute_lead(left, right, start_s, dur_s, freq, gain=0.20, pan=-0.15):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    rng = random.Random(int(start_s * 54321))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.06) * min(1.0, (dur_s - t) / 0.08)
        f1 = math.sin(2.0 * math.pi * freq * t)
        f2 = 0.18 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        breath = (rng.random() * 2.0 - 1.0) * 0.04
        sig = (f1 + f2 + breath) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_analog_pad(left, right, start_s, dur_s, chord_freqs, gain=0.18, pan=0.0):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.15) * min(1.0, (dur_s - t) / 0.20)
        sig_c = 0.0
        for f in chord_freqs:
            s1 = math.sin(2.0 * math.pi * (f * 0.9985) * t)
            s2 = math.sin(2.0 * math.pi * (f * 1.0015) * t)
            sig_c += (s1 + s2)
        sig = (sig_c / max(1, len(chord_freqs))) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_walking_bass(left, right, start_s, dur_s, freq, gain=0.28, pan=0.0):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5) if t > 0.008 else (t / 0.008)
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.40 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        sig = (b1 + b2) * gain * env
        left[idx] += sig
        right[idx] += sig


def add_moog_sub_bass(left, right, start_s, dur_s, freq, gain=0.30):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2.5) if t > 0.01 else (t / 0.01)
        sub = math.sin(2.0 * math.pi * freq * t)
        body = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 4.0)
        sig = math.tanh((sub + body) * 1.3) * gain * env
        left[idx] += sig
        right[idx] += sig


def add_lofi_kick(left, right, start_s, gain=0.28):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.28 * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        f = 50.0 * (1.0 + 0.3 * math.exp(-t * 35.0))
        env = math.exp(-t * 11.0)
        sig = math.sin(2.0 * math.pi * f * t) * gain * env
        left[idx] += sig
        right[idx] += sig


def add_rimshot(left, right, start_s, gain=0.22):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.12 * SAMPLE_RATE)
    rng = random.Random(int(start_s * 9999))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        wood = math.sin(2.0 * math.pi * 380.0 * t) * math.exp(-t * 40.0)
        noise = (rng.random() * 2.0 - 1.0) * math.exp(-t * 60.0)
        sig = (wood * 0.6 + noise * 0.4) * gain
        left[idx] += sig * 0.95
        right[idx] += sig * 1.05


def add_brush_snare(left, right, start_s, gain=0.18):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.25 * SAMPLE_RATE)
    rng = random.Random(int(start_s * 8888))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 14.0) if t > 0.02 else (t / 0.02)
        noise = (rng.random() * 2.0 - 1.0) * env
        sig = noise * gain
        left[idx] += sig * 0.9
        right[idx] += sig * 1.1


def add_ride_cymbal(left, right, start_s, gain=0.15):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.2 * SAMPLE_RATE)
    rng = random.Random(int(start_s * 7777))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.8) if t > 0.003 else (t / 0.003)
        bell = math.sin(2.0 * math.pi * 2850.0 * t) * 0.3
        shimmer = (rng.random() * 2.0 - 1.0) * 0.7
        sig = (bell + shimmer) * gain * env
        left[idx] += sig * 0.7
        right[idx] += sig * 1.2


def add_shaker_hit(left, right, start_s, gain=0.10, is_accent=False):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.08 * SAMPLE_RATE)
    rng = random.Random(int(start_s * 6666))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 45.0)
        noise = (rng.random() * 2.0 - 1.0) * env
        g = gain * 1.4 if is_accent else gain
        sig = noise * g
        left[idx] += sig * 0.8
        right[idx] += sig * 1.0


def add_ocean_waves(left, right, start_s, dur_s, gain=0.08):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    rng = random.Random(int(start_s * 12345))
    val_l, val_r = 0.0, 0.0
    alpha = 0.015
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        swell = math.sin(math.pi * (t / dur_s)) ** 2.0
        val_l += alpha * ((rng.random() * 2.0 - 1.0) * swell - val_l)
        val_r += alpha * ((rng.random() * 2.0 - 1.0) * swell - val_r)
        left[idx] += val_l * gain
        right[idx] += val_r * gain


def add_rain_bed(left, right, start_s, dur_s, gain=0.06):
    """Gentle natural rainfall ambient wash."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    rng = random.Random(int(start_s * 9876))
    val_l, val_r = 0.0, 0.0
    alpha = 0.08
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        val_l += alpha * ((rng.random() * 2.0 - 1.0) - val_l)
        val_r += alpha * ((rng.random() * 2.0 - 1.0) - val_r)
        left[idx] += val_l * gain
        right[idx] += val_r * gain


# =============================================================================
# ORIGINAL 5 MENU TRACKS
# =============================================================================

def compose_velvet_lounge():
    track_id = "ost_menu_velvet_lounge"
    print(f"Generating {track_id} (Persona 5 Acid Jazz Lounge)...")
    bpm = 96.0
    sec_per_beat = 60.0 / bpm
    total_bars = 16
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    chords = [
        {"root": "E2", "rhodes": ["G3", "B3", "D4", "F#4"], "walk": ["E2", "G2", "A2", "Bb2"]},
        {"root": "A1", "rhodes": ["G3", "C#4", "E4", "F#4"], "walk": ["A1", "C#2", "E2", "G2"]},
        {"root": "D2", "rhodes": ["F#3", "A3", "C#4", "E4"], "walk": ["D2", "F#2", "A2", "C3"]},
        {"root": "G1", "rhodes": ["F#3", "B3", "D4", "G4"], "walk": ["G1", "B1", "D2", "E2"]},
        {"root": "C2", "rhodes": ["E3", "G3", "B3", "D4"], "walk": ["C2", "E2", "G2", "A2"]},
        {"root": "F#1", "rhodes": ["E3", "A3", "C4", "E4"], "walk": ["F#1", "A1", "C2", "E2"]},
        {"root": "B1", "rhodes": ["D#3", "A3", "C4", "F#4"], "walk": ["B1", "D#2", "F#2", "A2"]},
        {"root": "E2", "rhodes": ["G3", "B3", "D4", "F#4"], "walk": ["E2", "G2", "B2", "D3"]},
    ]

    trumpet_melody = [
        (4, 0.0, "G4", 1.2), (4, 1.5, "F#4", 0.8), (4, 2.5, "E4", 1.0),
        (5, 0.5, "D4", 1.2), (5, 2.0, "E4", 1.8),
        (6, 0.0, "B4", 1.4), (6, 2.0, "A4", 1.0), (7, 0.0, "G4", 0.9),
        (7, 1.0, "F#4", 0.9), (7, 2.0, "G4", 1.8),
        (12, 0.0, "E5", 1.4), (12, 2.0, "D5", 1.0), (13, 0.0, "B4", 1.2),
        (13, 1.5, "A4", 0.8), (13, 2.5, "G4", 1.2),
        (14, 0.5, "C5", 1.0), (14, 2.0, "B4", 1.2), (15, 0.0, "A4", 0.8),
        (15, 1.0, "G4", 1.0), (15, 2.2, "E4", 2.2),
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat
        for f_note in c_info["rhodes"]:
            f_hz = note_to_freq(f_note)
            add_rhodes_note(left, right, bar_t, sec_per_beat * 2.2, f_hz, gain=0.18, pan=-0.2)
            add_rhodes_note(left, right, bar_t + sec_per_beat * 2.5, sec_per_beat * 1.4, f_hz, gain=0.16, pan=0.2)
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            add_walking_bass(left, right, t_b, sec_per_beat * 0.9, note_to_freq(c_info["walk"][b]), gain=0.28)
            if b == 0:
                add_lofi_kick(left, right, t_b, gain=0.30)
            if b == 2:
                add_lofi_kick(left, right, t_b + sec_per_beat * 0.5, gain=0.24)
            if b in [1, 3]:
                add_rimshot(left, right, t_b, gain=0.22)
            for s in range(4):
                add_shaker_hit(left, right, t_b + s * (sec_per_beat / 4.0), gain=0.09, is_accent=(s == 0))

    for b_idx, beat_offset, n_str, dur in trumpet_melody:
        t_note = b_idx * 4.0 * sec_per_beat + beat_offset * sec_per_beat
        add_muted_trumpet(left, right, t_note, dur, note_to_freq(n_str), gain=0.22, pan=0.15)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_grand_touring():
    track_id = "ost_menu_grand_touring"
    print(f"Generating {track_id} (Gran Turismo Luxury Nu-Jazz)...")
    bpm = 108.0
    sec_per_beat = 60.0 / bpm
    total_bars = 19
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    chords = [
        {"root": "B1", "rhodes": ["D4", "F#4", "A4", "C#5"], "nylon": ["B2", "F#3", "B3", "D4", "F#4"]},
        {"root": "E1", "rhodes": ["D4", "G#4", "B4", "C#5"], "nylon": ["E2", "B2", "E3", "G#3", "D4"]},
        {"root": "A1", "rhodes": ["C#4", "E4", "G#4", "B4"], "nylon": ["A2", "E3", "A3", "C#4", "E4"]},
        {"root": "D2", "rhodes": ["C#4", "F#4", "A4", "D5"], "nylon": ["D3", "A3", "D4", "F#4", "A4"]},
        {"root": "G1", "rhodes": ["B3", "D4", "F#4", "B4"], "nylon": ["G2", "D3", "G3", "B3", "D4"]},
        {"root": "C#2", "rhodes": ["B3", "E4", "G4", "C#5"], "nylon": ["C#3", "G3", "C#4", "E4", "G4"]},
        {"root": "F#1", "rhodes": ["A#3", "E4", "G4", "C#5"], "nylon": ["F#2", "C#3", "F#3", "A#3", "E4"]},
        {"root": "B1", "rhodes": ["D4", "F#4", "A4", "C#5"], "nylon": ["B2", "F#3", "B3", "D4", "F#4"]},
    ]

    flute_melody = [
        (4, 0.0, "F#5", 1.4), (4, 2.0, "E5", 1.0), (5, 0.0, "D5", 1.2), (5, 1.5, "C#5", 0.8), (5, 2.5, "B4", 1.4),
        (6, 0.5, "A4", 1.0), (6, 2.0, "B4", 1.2), (7, 0.0, "C#5", 1.0), (7, 1.5, "D5", 2.2),
        (12, 0.0, "A5", 1.6), (12, 2.0, "G#5", 1.0), (13, 0.0, "F#5", 1.4), (13, 2.0, "E5", 1.2),
        (14, 0.0, "D5", 1.0), (14, 1.5, "E5", 1.0), (14, 2.5, "F#5", 1.4), (15, 0.5, "G#5", 1.2), (15, 2.0, "A5", 2.2),
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat
        for f_note in c_info["rhodes"]:
            add_rhodes_note(left, right, bar_t, sec_per_beat * 1.8, note_to_freq(f_note), gain=0.16, pan=0.2)
            add_rhodes_note(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.8, note_to_freq(f_note), gain=0.14, pan=-0.2)
        for a_idx, n_str in enumerate(c_info["nylon"]):
            add_nylon_guitar_note(left, right, bar_t + a_idx * (sec_per_beat * 0.75), sec_per_beat * 1.2, note_to_freq(n_str), gain=0.18, pan=-0.25)
        b_freq = note_to_freq(c_info["root"])
        add_walking_bass(left, right, bar_t, sec_per_beat * 1.9, b_freq, gain=0.28)
        add_walking_bass(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.9, b_freq * 1.5, gain=0.24)
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            if b in [0, 2]:
                add_lofi_kick(left, right, t_b, gain=0.24)
            if b in [1, 3]:
                add_brush_snare(left, right, t_b, gain=0.18)
            add_ride_cymbal(left, right, t_b + sec_per_beat * 0.5, gain=0.14)

    for b_idx, beat_offset, n_str, dur in flute_melody:
        t_note = b_idx * 4.0 * sec_per_beat + beat_offset * sec_per_beat
        add_flute_lead(left, right, t_note, dur, note_to_freq(n_str), gain=0.20, pan=-0.15)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_astral_solitude():
    track_id = "ost_menu_astral_solitude"
    print(f"Generating {track_id} (Minecraft C418 Felt Piano Ambient)...")
    bpm = 72.0
    sec_per_beat = 60.0 / bpm
    total_bars = 14
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    chords = [
        {"root": "C2", "pad": ["C3", "G3", "B3", "E4"], "piano_arp": ["C3", "G3", "B3", "E4", "G4"]},
        {"root": "A1", "pad": ["A2", "E3", "G3", "C4"], "piano_arp": ["A2", "E3", "G3", "C4", "E4"]},
        {"root": "F1", "pad": ["F2", "C3", "A3", "C4"], "piano_arp": ["F2", "C3", "A3", "C4", "F4"]},
        {"root": "G1", "pad": ["G2", "D3", "G3", "B3"], "piano_arp": ["G2", "D3", "G3", "B3", "D4"]},
    ]

    felt_melody = [
        (0, 1.5, "E5", 2.5), (1, 0.0, "D5", 3.0), (1, 2.5, "B4", 2.2),
        (2, 1.0, "C5", 3.5), (3, 0.0, "G4", 3.0), (3, 2.0, "A4", 2.5),
        (4, 1.0, "E5", 2.8), (4, 3.0, "G5", 2.2), (5, 1.0, "F5", 3.0),
        (6, 0.5, "E5", 2.5), (6, 2.5, "D5", 2.8), (7, 1.0, "C5", 4.0),
        (8, 1.5, "B4", 2.5), (9, 0.5, "C5", 3.0), (9, 2.5, "D5", 2.5),
        (10, 1.0, "E5", 3.5), (11, 0.0, "G4", 3.0), (11, 2.0, "B4", 2.5),
        (12, 1.0, "C5", 4.0), (13, 0.0, "G4", 3.5),
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat
        pad_freqs = [note_to_freq(n) for n in c_info["pad"]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.14)
        add_felt_piano_note(left, right, bar_t, sec_per_beat * 3.5, note_to_freq(c_info["root"]), gain=0.24, pan=-0.1)
        for a_idx, n_str in enumerate(c_info["piano_arp"]):
            add_felt_piano_note(left, right, bar_t + a_idx * (sec_per_beat * 0.7), sec_per_beat * 2.8, note_to_freq(n_str), gain=0.18, pan=0.15)
        if bar % 2 == 1:
            add_celeste_chime(left, right, bar_t + sec_per_beat * 2.5, note_to_freq(c_info["piano_arp"][-1]) * 2.0, gain=0.14, pan=0.28)

    for b_idx, beat_offset, n_str, dur in felt_melody:
        t_note = b_idx * 4.0 * sec_per_beat + beat_offset * sec_per_beat
        add_felt_piano_note(left, right, t_note, dur, note_to_freq(n_str), gain=0.25)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_dearly_reminiscent():
    track_id = "ost_menu_dearly_reminiscent"
    print(f"Generating {track_id} (Kingdom Hearts / Final Fantasy Fantasy Prelude)...")
    bpm = 84.0
    sec_per_beat = 60.0 / bpm
    total_bars = 15
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    chords = [
        {"root": "Bb1", "harp": ["Bb2", "F3", "Bb3", "D4", "F4", "A4", "D5"], "pad": ["F3", "A3", "D4"]},
        {"root": "C2", "harp": ["Bb2", "G3", "C4", "E4", "G4", "C5", "E5"], "pad": ["G3", "C4", "E4"]},
        {"root": "A1", "harp": ["A2", "E3", "A3", "C4", "E4", "G4", "C5"], "pad": ["E3", "A3", "C4"]},
        {"root": "D2", "harp": ["D2", "A2", "D3", "F3", "A3", "D4", "F4"], "pad": ["F3", "A3", "D4"]},
        {"root": "G1", "harp": ["G2", "D3", "G3", "Bb3", "D4", "F4", "Bb4"], "pad": ["G3", "Bb3", "D4"]},
        {"root": "C2", "harp": ["C2", "G2", "C3", "E3", "G3", "Bb3", "E4"], "pad": ["E3", "G3", "C4"]},
        {"root": "F1", "harp": ["F2", "C3", "F3", "A3", "C4", "F4", "A4"], "pad": ["F3", "A3", "C4"]},
        {"root": "F1", "harp": ["F2", "C3", "F3", "A3", "C4", "F4", "A4"], "pad": ["F3", "A3", "C4"]},
    ]

    piano_melody = [
        (0, 2.0, "F5", 1.8), (1, 0.0, "G5", 1.6), (1, 2.0, "A5", 2.2),
        (2, 0.5, "G5", 1.4), (2, 2.0, "F5", 1.4), (3, 0.0, "E5", 2.8),
        (4, 1.5, "D5", 1.8), (5, 0.0, "E5", 1.6), (5, 2.0, "F5", 2.2),
        (6, 0.5, "E5", 1.4), (6, 2.0, "D5", 1.4), (7, 0.0, "C5", 3.0),
        (8, 2.0, "A5", 1.8), (9, 0.0, "Bb5", 1.6), (9, 2.0, "C6", 2.5),
        (10, 0.5, "Bb5", 1.4), (10, 2.0, "A5", 1.4), (11, 0.0, "F5", 3.0),
        (12, 1.5, "G5", 1.8), (13, 0.0, "A5", 2.2), (13, 2.5, "F5", 4.0),
    ]

    for w in range(5):
        add_ocean_waves(left, right, w * 8.5, 7.5, gain=0.07)

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat
        pad_freqs = [note_to_freq(n) for n in c_info["pad"]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.15)
        harp_notes = c_info["harp"]
        for h_step in range(16):
            t_harp = bar_t + h_step * (sec_per_beat / 4.0)
            h_idx = h_step if h_step < len(harp_notes) else (len(harp_notes) * 2 - 2 - h_step)
            h_idx = max(0, min(len(harp_notes) - 1, h_idx))
            add_concert_harp_note(left, right, t_harp, sec_per_beat * 1.5, note_to_freq(harp_notes[h_idx]), gain=0.16, pan=-0.3 + (h_step / 16.0) * 0.6)
        add_felt_piano_note(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(c_info["root"]), gain=0.22, pan=-0.1)

    for b_idx, beat_offset, n_str, dur in piano_melody:
        t_note = b_idx * 4.0 * sec_per_beat + beat_offset * sec_per_beat
        add_felt_piano_note(left, right, t_note, dur, note_to_freq(n_str), gain=0.26, pan=0.05)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_cyber_terminal():
    track_id = "ost_menu_cyber_terminal"
    print(f"Generating {track_id} (Metroid Prime / Cyberpunk Ambient HUD)...")
    bpm = 90.0
    sec_per_beat = 60.0 / bpm
    total_bars = 15
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    chords = [
        {"root": "D1", "pad": ["D3", "A3", "E4", "F4"], "arp": ["D4", "A4", "E5", "F5", "A5"]},
        {"root": "Bb0", "pad": ["Bb2", "F3", "A3", "D4"], "arp": ["Bb3", "F4", "A4", "D5", "F5"]},
        {"root": "G0", "pad": ["G2", "D3", "F3", "Bb3"], "arp": ["G3", "D4", "F4", "Bb4", "D5"]},
        {"root": "A0", "pad": ["A2", "E3", "G3", "C#4"], "arp": ["A3", "E4", "G4", "C#5", "E5"]},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat
        pad_freqs = [note_to_freq(n) for n in c_info["pad"]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.18)
        b_freq = note_to_freq(c_info["root"])
        add_moog_sub_bass(left, right, bar_t, sec_per_beat * 1.8, b_freq, gain=0.32)
        add_moog_sub_bass(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.8, b_freq, gain=0.28)
        arp_notes = c_info["arp"]
        for step in range(16):
            t_arp = bar_t + step * (sec_per_beat / 4.0)
            n_arp = arp_notes[step % len(arp_notes)]
            add_celeste_chime(left, right, t_arp, note_to_freq(n_arp), gain=0.10, pan=-0.35 if (step % 2 == 0) else 0.35)
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            if b in [0, 2]:
                add_lofi_kick(left, right, t_b, gain=0.26)
            if b in [1, 3]:
                add_rimshot(left, right, t_b, gain=0.18)
            add_shaker_hit(left, right, t_b + sec_per_beat * 0.5, gain=0.08)

    write_ogg_loop(left, right, track_id, total_sec)


# =============================================================================
# 10 NEW LEGENDARY MENU SOUNDTRACKS
# =============================================================================

def compose_breeze_plaza():
    """Wii Sports / Wii Shop / Mii Plaza Bossa Nova (112 BPM)."""
    track_id = "ost_menu_breeze_plaza"
    print(f"Generating {track_id} (Wii Plaza Bossa Nova)...")
    bpm = 112.0
    sec_per_beat = 60.0 / bpm
    total_bars = 20
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Cheerful F major Bossa Nova chords: Fmaj7 -> Gm7 -> Am7 -> Bbmaj7 -> C7
    chords = [
        {"root": "F2", "nylon": ["F3", "A3", "C4", "E4"], "marimba_lead": ["A4", "C5", "E5"]},
        {"root": "G2", "nylon": ["G3", "Bb3", "D4", "F4"], "marimba_lead": ["Bb4", "D5", "F5"]},
        {"root": "A2", "nylon": ["A3", "C4", "E4", "G4"], "marimba_lead": ["C5", "E5", "G5"]},
        {"root": "Bb1", "nylon": ["Bb2", "F3", "Bb3", "D4"], "marimba_lead": ["D5", "F5", "A5"]},
    ]

    # Catchy playful marimba melody
    melody = [
        (0, 0.0, "C5", 0.5), (0, 1.0, "A4", 0.5), (0, 2.0, "F4", 0.8), (0, 3.5, "G4", 0.4),
        (1, 0.0, "A4", 0.6), (1, 1.5, "C5", 0.6), (1, 2.5, "D5", 1.2),
        (2, 0.0, "E5", 0.6), (2, 1.0, "C5", 0.5), (2, 2.0, "A4", 0.8), (2, 3.5, "Bb4", 0.4),
        (3, 0.0, "C5", 0.6), (3, 1.5, "G4", 0.6), (3, 2.5, "F4", 1.4),
        (4, 0.0, "C5", 0.5), (4, 1.0, "A4", 0.5), (4, 2.0, "F4", 0.8),
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Bossa rhythm acoustic guitar strum
        for beat in range(4):
            t_b = bar_t + beat * sec_per_beat
            if beat in [0, 1.5, 3]:
                for f_str in c_info["nylon"]:
                    add_nylon_guitar_note(left, right, t_b, sec_per_beat * 0.8, note_to_freq(f_str), gain=0.15, pan=-0.2)

        # 2. Bossa walking bass
        b_freq = note_to_freq(c_info["root"])
        add_walking_bass(left, right, bar_t, sec_per_beat * 1.5, b_freq, gain=0.26)
        add_walking_bass(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.5, b_freq * 1.5, gain=0.22)

        # 3. Light shaker and brush snare
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            if b in [0, 2]:
                add_lofi_kick(left, right, t_b, gain=0.22)
            if b in [1, 3]:
                add_brush_snare(left, right, t_b, gain=0.16)
            add_shaker_hit(left, right, t_b + sec_per_beat * 0.5, gain=0.08)

    # Lead marimba
    for b_idx, beat_offset, n_str, dur in melody:
        for loop_bar in range(b_idx, total_bars, 4):
            t_m = loop_bar * 4.0 * sec_per_beat + beat_offset * sec_per_beat
            add_marimba_note(left, right, t_m, dur, note_to_freq(n_str), gain=0.22, pan=0.15)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_sacred_spring():
    """The Legend of Zelda: Fairy Fountain / Title Screen (76 BPM)."""
    track_id = "ost_menu_sacred_spring"
    print(f"Generating {track_id} (Zelda Fairy Fountain Harp)...")
    bpm = 76.0
    sec_per_beat = 60.0 / bpm
    total_bars = 14
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Sacred harp ascending / descending patterns (Fmaj7 -> Dm7 -> Gm7 -> C7):
    harp_chords = [
        ["F3", "A3", "C4", "E4", "F4", "A4", "C5", "E5", "F5", "E5", "C5", "A4", "F4", "E4", "C4", "A3"],
        ["D3", "F3", "A3", "C4", "D4", "F4", "A4", "C5", "D5", "C5", "A4", "F4", "D4", "C4", "A3", "F3"],
        ["G3", "Bb3", "D4", "F4", "G4", "Bb4", "D5", "F5", "G5", "F5", "D5", "Bb4", "G4", "F4", "D4", "Bb3"],
        ["C3", "E3", "G3", "Bb3", "C4", "E4", "G4", "Bb4", "C5", "Bb4", "G4", "E4", "C4", "Bb3", "G3", "E3"],
    ]

    for bar in range(total_bars):
        c_notes = harp_chords[bar % len(harp_chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Warm String Quartet Bed
        root_f = note_to_freq(c_notes[0])
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, [root_f, root_f * 1.5, root_f * 2.0], gain=0.15)

        # 2. Cascading 16th-note magical harp run
        for step in range(16):
            t_step = bar_t + step * (sec_per_beat / 4.0)
            f_harp = note_to_freq(c_notes[step % len(c_notes)])
            pan = -0.35 + (step / 16.0) * 0.7
            add_concert_harp_note(left, right, t_step, sec_per_beat * 1.8, f_harp, gain=0.20, pan=pan)

        # 3. Soft ocarina / flute accent notes
        if bar % 2 == 0:
            add_flute_lead(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 2.0, note_to_freq(c_notes[8]), gain=0.18, pan=0.0)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_ancient_sanctum():
    """Halo: Combat Evolved / Halo 3 Gregorian Choral Majesty (68 BPM)."""
    track_id = "ost_menu_ancient_sanctum"
    print(f"Generating {track_id} (Halo Gregorian Choral Sanctum)...")
    bpm = 68.0
    sec_per_beat = 60.0 / bpm
    total_bars = 12
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Solemn E minor / D Gregorian modality
    chords = [
        {"choir": ["E3", "B3", "E4", "G4"], "bass": "E1"},
        {"choir": ["D3", "A3", "D4", "F#4"], "bass": "D1"},
        {"choir": ["C3", "G3", "C4", "E4"], "bass": "C1"},
        {"choir": ["B2", "F#3", "B3", "D#4"], "bass": "B0"},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Noble Gregorian Monk Choir
        choir_freqs = [note_to_freq(n) for n in c_info["choir"]]
        add_gregorian_choir(left, right, bar_t, sec_per_beat * 4.2, choir_freqs, gain=0.26, pan=0.0)

        # 2. Resonant sub contrabass pedal
        b_freq = note_to_freq(c_info["bass"])
        add_moog_sub_bass(left, right, bar_t, sec_per_beat * 3.8, b_freq, gain=0.28)

        # 3. Solo cello / strings expressive counterpoint
        t_cello = bar_t + sec_per_beat * 1.5
        add_felt_piano_note(left, right, t_cello, sec_per_beat * 2.5, note_to_freq(c_info["choir"][1]), gain=0.18, pan=-0.2)

        # 4. Somber cathedral drum hit on beat 0
        add_lofi_kick(left, right, bar_t, gain=0.25)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_rainy_atrium():
    """Animal Crossing: New Horizons Rainy Day Ukulele Cafe (80 BPM)."""
    track_id = "ost_menu_rainy_atrium"
    print(f"Generating {track_id} (Animal Crossing Rainy Cafe)...")
    bpm = 80.0
    sec_per_beat = 60.0 / bpm
    total_bars = 14
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Cozy C major ukulele progression: Cmaj7 -> Fmaj7 -> Dm7 -> G7
    chords = [
        {"root": "C2", "ukulele": ["C4", "E4", "G4", "B4"], "bell": "E5"},
        {"root": "F1", "ukulele": ["C4", "F4", "A4", "C5"], "bell": "F5"},
        {"root": "D2", "ukulele": ["D4", "F4", "A4", "C5"], "bell": "D5"},
        {"root": "G1", "ukulele": ["B3", "D4", "F4", "G4"], "bell": "G5"},
    ]

    # Continuous soft rain ambient bed
    add_rain_bed(left, right, 0.0, total_sec, gain=0.07)

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Warm ukulele strumming on 1, 2, 3, 4
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            is_down = (b % 2 == 0)
            add_ukulele_strum(left, right, t_b, c_info["ukulele"], gain=0.18, is_down=is_down)

        # 2. Upright acoustic bass
        b_freq = note_to_freq(c_info["root"])
        add_walking_bass(left, right, bar_t, sec_per_beat * 1.8, b_freq, gain=0.25)
        add_walking_bass(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.8, b_freq * 1.5, gain=0.20)

        # 3. Sweet glockenspiel / music box raindrop bell
        add_celeste_chime(left, right, bar_t + sec_per_beat * 1.5, note_to_freq(c_info["bell"]), gain=0.18, pan=0.2)
        add_celeste_chime(left, right, bar_t + sec_per_beat * 3.0, note_to_freq(c_info["bell"]) * 1.25, gain=0.14, pan=-0.2)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_chronicle_winds():
    """Chrono Trigger / Chrono Cross Timeless Folk (88 BPM)."""
    track_id = "ost_menu_chronicle_winds"
    print(f"Generating {track_id} (Chrono Timeless Memories)...")
    bpm = 88.0
    sec_per_beat = 60.0 / bpm
    total_bars = 16
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Nostalgic D minor / F major progression (Memories of Green / Radical Dreamers style)
    chords = [
        {"root": "D2", "guitar": ["D3", "A3", "D4", "F4", "A4"], "flute": "F5"},
        {"root": "Bb1", "guitar": ["Bb2", "F3", "Bb3", "D4", "F4"], "flute": "D5"},
        {"root": "C2", "guitar": ["C3", "G3", "C4", "E4", "G4"], "flute": "E5"},
        {"root": "A1", "guitar": ["A2", "E3", "A3", "C#4", "E4"], "flute": "A5"},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Warm accordion / string pad swell
        pad_freqs = [note_to_freq(n) for n in c_info["guitar"][:3]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.16)

        # 2. 12-string fingerpicked acoustic guitar arpeggios
        for s_idx, note_s in enumerate(c_info["guitar"]):
            t_s = bar_t + s_idx * (sec_per_beat * 0.7)
            add_nylon_guitar_note(left, right, t_s, sec_per_beat * 1.5, note_to_freq(note_s), gain=0.20, pan=-0.2)

        # 3. Flute / recorder nostalgic melody
        t_flute = bar_t + sec_per_beat * 1.5
        add_flute_lead(left, right, t_flute, sec_per_beat * 2.2, note_to_freq(c_info["flute"]), gain=0.22, pan=0.2)

        # 4. Soft deep bass note
        add_walking_bass(left, right, bar_t, sec_per_beat * 3.5, note_to_freq(c_info["root"]), gain=0.26)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_subaquatic_drift():
    """Donkey Kong Country: Aquatic Ambience (78 BPM)."""
    track_id = "ost_menu_subaquatic_drift"
    print(f"Generating {track_id} (DKC Aquatic Ambience)...")
    bpm = 78.0
    sec_per_beat = 60.0 / bpm
    total_bars = 14
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Dreamy aquatic chords: Ebmaj9 -> Cm9 -> Fm9 -> Bb13
    chords = [
        {"root": "Eb1", "pad": ["Eb3", "Bb3", "D4", "F4", "G4"], "marimba": ["G4", "Bb4", "D5"]},
        {"root": "C1", "pad": ["C3", "G3", "Bb3", "D4", "Eb4"], "marimba": ["Eb4", "G4", "Bb4"]},
        {"root": "F1", "pad": ["F3", "C4", "Eb4", "G4", "Ab4"], "marimba": ["Ab4", "C5", "Eb5"]},
        {"root": "Bb0", "pad": ["Bb2", "F3", "Ab3", "C4", "D4"], "marimba": ["D4", "F4", "Ab4"]},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Warm submerged analog pad
        pad_freqs = [note_to_freq(n) for n in c_info["pad"]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.20)

        # 2. Deep sub-aquatic bass pulse
        b_freq = note_to_freq(c_info["root"])
        add_moog_sub_bass(left, right, bar_t, sec_per_beat * 3.5, b_freq, gain=0.30)

        # 3. Soft marimba water droplet arpeggios
        for m_idx, m_note in enumerate(c_info["marimba"]):
            t_m = bar_t + m_idx * (sec_per_beat * 1.2)
            add_marimba_note(left, right, t_m, sec_per_beat * 1.8, note_to_freq(m_note), gain=0.20, pan=-0.25 + m_idx * 0.25)

        # 4. Underwater bubbling celeste drops
        add_celeste_chime(left, right, bar_t + sec_per_beat * 2.5, note_to_freq(c_info["marimba"][-1]) * 2.0, gain=0.14, pan=0.3)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_northern_aurora():
    """Skyrim: Whiterun / Secunda Nordic Frost Dulcimer (70 BPM)."""
    track_id = "ost_menu_northern_aurora"
    print(f"Generating {track_id} (Skyrim Whiterun Dulcimer)...")
    bpm = 70.0
    sec_per_beat = 60.0 / bpm
    total_bars = 13
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Secunda modality: Dm -> C -> Bb -> Am
    chords = [
        {"root": "D2", "pad": ["D3", "A3", "F4"], "dulcimer": ["D4", "F4", "A4", "D5"]},
        {"root": "C2", "pad": ["C3", "G3", "E4"], "dulcimer": ["C4", "E4", "G4", "C5"]},
        {"root": "Bb1", "pad": ["Bb2", "F3", "D4"], "dulcimer": ["Bb3", "D4", "F4", "Bb4"]},
        {"root": "A1", "pad": ["A2", "E3", "C4"], "dulcimer": ["A3", "C4", "E4", "A4"]},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Somber Nordic string pad
        pad_freqs = [note_to_freq(n) for n in c_info["pad"]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.18)

        # 2. Resonant hammered dulcimer arpeggios
        for d_idx, d_note in enumerate(c_info["dulcimer"]):
            t_d = bar_t + d_idx * (sec_per_beat * 0.9)
            add_dulcimer_note(left, right, t_d, sec_per_beat * 2.2, note_to_freq(d_note), gain=0.22, pan=0.15)

        # 3. Solitary cello note on root
        add_felt_piano_note(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(c_info["root"]), gain=0.25, pan=-0.15)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_champions_pavilion():
    """Super Smash Bros Main Menu / Tournament Fanfare (128 BPM)."""
    track_id = "ost_menu_champions_pavilion"
    print(f"Generating {track_id} (Smash Bros Tournament Fanfare)...")
    bpm = 128.0
    sec_per_beat = 60.0 / bpm
    total_bars = 22
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Heroic fanfare in Bb major: Bb -> F/A -> Gm -> Eb -> F
    chords = [
        {"root": "Bb1", "brass": ["Bb3", "D4", "F4"], "fanfare": "F4"},
        {"root": "A1", "brass": ["A3", "C4", "F4"], "fanfare": "A4"},
        {"root": "G1", "brass": ["G3", "Bb3", "D4"], "fanfare": "Bb4"},
        {"root": "Eb1", "brass": ["G3", "Bb3", "Eb4"], "fanfare": "C5"},
        {"root": "F1", "brass": ["A3", "C4", "F4"], "fanfare": "D5"},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Driving staccato orchestral strings
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            for f_b in c_info["brass"]:
                add_concert_harp_note(left, right, t_b, sec_per_beat * 0.4, note_to_freq(f_b), gain=0.16, pan=-0.2)
                add_concert_harp_note(left, right, t_b + sec_per_beat * 0.5, sec_per_beat * 0.4, note_to_freq(f_b), gain=0.14, pan=0.2)

        # 2. Heroic French horn fanfare
        add_french_horn(left, right, bar_t, sec_per_beat * 2.2, note_to_freq(c_info["fanfare"]), gain=0.24, pan=0.1)
        add_french_horn(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.8, note_to_freq(c_info["fanfare"]) * 1.25, gain=0.22, pan=-0.1)

        # 3. Driving march percussion
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            if b in [0, 2]:
                add_lofi_kick(left, right, t_b, gain=0.30)
            if b in [1, 3]:
                add_rimshot(left, right, t_b, gain=0.24)
            add_ride_cymbal(left, right, t_b + sec_per_beat * 0.5, gain=0.12)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_orbital_vanguard():
    """Mass Effect / Mirror's Edge Galaxy Map Ambient (85 BPM)."""
    track_id = "ost_menu_orbital_vanguard"
    print(f"Generating {track_id} (Mass Effect Galaxy Map Ambient)...")
    bpm = 85.0
    sec_per_beat = 60.0 / bpm
    total_bars = 15
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Space ambient progression: Fmaj9 -> G6 -> Am9 -> Em7
    chords = [
        {"root": "F1", "pad": ["F3", "C4", "E4", "A4"], "chimes": ["C5", "E5", "A5"]},
        {"root": "G1", "pad": ["G3", "D4", "E4", "B4"], "chimes": ["D5", "E5", "B5"]},
        {"root": "A1", "pad": ["A3", "E4", "G4", "C5"], "chimes": ["E5", "G5", "C6"]},
        {"root": "E1", "pad": ["E3", "B3", "D4", "G4"], "chimes": ["B4", "D5", "G5"]},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Warm Roland Juno space pad
        pad_freqs = [note_to_freq(n) for n in c_info["pad"]]
        add_analog_pad(left, right, bar_t, sec_per_beat * 4.2, pad_freqs, gain=0.20)

        # 2. Deep Moog sub-bass pulse
        b_freq = note_to_freq(c_info["root"])
        add_moog_sub_bass(left, right, bar_t, sec_per_beat * 3.5, b_freq, gain=0.30)

        # 3. Sparkling zero-gravity glass chimes
        for c_idx, c_note in enumerate(c_info["chimes"]):
            t_c = bar_t + c_idx * (sec_per_beat * 1.25)
            add_celeste_chime(left, right, t_c, note_to_freq(c_note), gain=0.16, pan=-0.3 + c_idx * 0.3)

    write_ogg_loop(left, right, track_id, total_sec)


def compose_third_strike():
    """Street Fighter III: 3rd Strike Character Select DnB / Liquid Funk (160 BPM)."""
    track_id = "ost_menu_third_strike"
    print(f"Generating {track_id} (SF3 Liquid DnB Lounge)...")
    bpm = 160.0
    sec_per_beat = 60.0 / bpm
    total_bars = 28
    total_sec = total_bars * 4.0 * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Cool Shibuya 90s acid jazz progression: Gm9 -> C13 -> Fmaj9 -> Bbmaj7
    chords = [
        {"root": "G1", "rhodes": ["Bb3", "D4", "F4", "A4"], "sub": "G1"},
        {"root": "C2", "rhodes": ["Bb3", "E4", "A4", "D5"], "sub": "C2"},
        {"root": "F1", "rhodes": ["A3", "C4", "E4", "G4"], "sub": "F1"},
        {"root": "Bb1", "rhodes": ["A3", "D4", "F4", "C5"], "sub": "Bb1"},
    ]

    for bar in range(total_bars):
        c_info = chords[bar % len(chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Warm jazzy Rhodes comping
        for f_note in c_info["rhodes"]:
            add_rhodes_note(left, right, bar_t, sec_per_beat * 1.5, note_to_freq(f_note), gain=0.16, pan=-0.2)
            add_rhodes_note(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.5, note_to_freq(f_note), gain=0.15, pan=0.2)

        # 2. 808 Sub-bass bounce
        b_freq = note_to_freq(c_info["sub"])
        add_moog_sub_bass(left, right, bar_t, sec_per_beat * 1.8, b_freq, gain=0.32)
        add_moog_sub_bass(left, right, bar_t + sec_per_beat * 2.5, sec_per_beat * 1.2, b_freq * 1.25, gain=0.28)

        # 3. Fast Liquid DnB breakbeat (160 BPM: kick on 1, snare on 2 and 4, syncopated ghost snares)
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            if b == 0:
                add_lofi_kick(left, right, t_b, gain=0.30)
            if b == 2:
                add_lofi_kick(left, right, t_b + sec_per_beat * 0.75, gain=0.26)
            if b in [1, 3]:
                add_rimshot(left, right, t_b, gain=0.24)
            # Ghost snare
            if b == 2:
                add_rimshot(left, right, t_b + sec_per_beat * 0.5, gain=0.12)
            # Rapid 16th shakers
            for s in range(4):
                add_shaker_hit(left, right, t_b + s * (sec_per_beat / 4.0), gain=0.08)

    write_ogg_loop(left, right, track_id, total_sec)


# =============================================================================
# MAIN ORCHESTRATION ENTRY POINT
# =============================================================================

def main():
    print("=" * 72)
    print("GENERATING 10 NEW LEGENDARY GAME MENU SOUNDTRACKS")
    print("=" * 72)
    compose_breeze_plaza()
    compose_sacred_spring()
    compose_ancient_sanctum()
    compose_rainy_atrium()
    compose_chronicle_winds()
    compose_subaquatic_drift()
    compose_northern_aurora()
    compose_champions_pavilion()
    compose_orbital_vanguard()
    compose_third_strike()
    print("=" * 72)
    print("ALL 10 NEW MENU SOUNDTRACKS GENERATED SUCCESSFULLY!")
    print("=" * 72)


if __name__ == "__main__":
    main()
