#!/usr/bin/env python3
"""
generate_automata_soundtracks_part3.py — 5 Additional Pure NieR: Automata OST Tracks.
Maximum Variety: Ruined Carnival (138 BPM), 6/8 Celtic Pastoral Forest (96 BPM),
Subterranean Dark Ambient (72 BPM), Fast Flamenco Battle Duel (144 BPM), Serene Ocean Lullaby (84 BPM).

100% Organic, Warm, Cinematic Acoustic Sound.
ABSOLUTELY ZERO PITCH MODULATION / LFO / VIBRATO.
ABSOLUTELY ZERO SAWTOOTH OR HARSH SYNTH WAVES.
ROCK-SOLID ACOUSTIC PITCH STABILITY.
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


def apply_warm_lowpass(samples, cutoff_hz=3200.0):
    """Gentle 1-pole lowpass filter to remove any harsh digital highs or whistling."""
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    val = 0.0
    for i, s in enumerate(samples):
        val += alpha * (s - val)
        out[i] = val
    return out


def write_ogg_file(left, right, track_id, total_sec):
    total_samples = len(left)

    # Master warm analog lowpass filter
    left = apply_warm_lowpass(left, cutoff_hz=3200.0)
    right = apply_warm_lowpass(right, cutoff_hz=3200.0)

    # 45-second seamless loop crossfade
    loop_fade = int(0.35 * SAMPLE_RATE)
    for i in range(loop_fade):
        frac = i / loop_fade
        left[i] = left[i] * frac + left[total_samples - loop_fade + i] * (1.0 - frac)
        right[i] = right[i] * frac + right[total_samples - loop_fade + i] * (1.0 - frac)
        left[total_samples - loop_fade + i] = left[i]
        right[total_samples - loop_fade + i] = right[i]

    # Warm analog soft-clipping saturation
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
# ROCK-SOLID ACOUSTIC PHYSICAL INSTRUMENTS (ZERO PITCH MODULATION / LFO)
# =============================================================================

def add_pure_marimba(left, right, start_s, freq, gain=0.22, pan=0.0):
    """Acoustic wooden marimba bar strike. Warm rosewood resonance with zero vibrato."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.9 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 6.5) if t > 0.003 else (t / 0.003)
        # Rosewood bar harmonics: fundamental + 4.0x overtone
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.25 * math.sin(2.0 * math.pi * 4.0 * freq * t) * math.exp(-t * 14.0)
        woody_click = 0.12 * math.sin(2.0 * math.pi * 780.0 * t) * math.exp(-t * 40.0)
        sig = (h1 + h2 + woody_click) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_upright_bass_pizz(left, right, start_s, freq, gain=0.28, pan=-0.2):
    """Plucked upright double bass note. Round acoustic body resonance, rock-solid pitch."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.4 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5) if t > 0.008 else (t / 0.008)
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        body = 0.20 * math.sin(2.0 * math.pi * 92.0 * t) * math.exp(-t * 6.0)
        sig = (b1 + b2 + body) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_wooden_pipe(left, right, start_s, dur_s, freq, gain=0.20, pan=0.15):
    """Pastoral wooden transverse flute / pipe. Breathy pure acoustic tone, ZERO vibrato."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.08) * min(1.0, (dur_s - t) / 0.12)
        # Pure unmodulated air column
        p1 = math.sin(2.0 * math.pi * freq * t)
        p2 = 0.18 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        p3 = 0.05 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        sig = (p1 + p2 + p3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_pastoral_lute(left, right, start_s, dur_s, freq, gain=0.22, pan=-0.15):
    """Rustic Renaissance lute / Celtic bouzouki plucked string."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.2) if t > 0.006 else (t / 0.006)
        l1 = math.sin(2.0 * math.pi * freq * t)
        l2 = 0.28 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        l3 = 0.08 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 8.0)
        sig = (l1 + l2 + l3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_bodhran(left, right, start_s, freq=68.0, gain=0.28, pan=0.0):
    """Deep Celtic bodhran hand drum strike. Mellow round skin bounce."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.55 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        f = freq * (1.0 + 0.22 * math.exp(-t * 30.0))
        env = math.exp(-t * 6.0)
        sig = math.sin(2.0 * math.pi * f * t) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_contrabass_drone(left, right, start_s, dur_s, freq=43.65, gain=0.25, pan=-0.25):
    """Subterranean acoustic double bass bowed sub-drone. 100% rock-solid pitch."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.4) * min(1.0, (dur_s - t) / 0.4)
        c1 = math.sin(2.0 * math.pi * freq * t)
        c2 = 0.32 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        c3 = 0.12 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        sig = (c1 + c2 + c3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_singing_bowl(left, right, start_s, freq=280.0, gain=0.20, pan=0.25):
    """Acoustic bronze Tibetan singing bowl / meditation chime. Pure sustained tone."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(4.5 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 0.7) if t > 0.02 else (t / 0.02)
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.22 * math.sin(2.0 * math.pi * 2.76 * freq * t) * math.exp(-t * 0.9)
        b3 = 0.08 * math.sin(2.0 * math.pi * 5.4 * freq * t) * math.exp(-t * 1.5)
        sig = (b1 + b2 + b3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_temple_block(left, right, start_s, freq=440.0, gain=0.18, pan=0.0):
    """Hollow wooden temple block click for sparse subterranean ritual pacing."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.25 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 22.0)
        sig = math.sin(2.0 * math.pi * freq * t) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_flamenco_guitar(left, right, start_s, dur_s, freq, gain=0.24, pan=0.1):
    """Crisp Spanish nylon flamenco guitar pluck with biting soundboard punch."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.8) if t > 0.005 else (t / 0.005)
        g1 = math.sin(2.0 * math.pi * freq * t)
        g2 = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.5)
        g3 = 0.12 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 9.0)
        body = 0.15 * math.sin(2.0 * math.pi * 125.0 * t) * math.exp(-t * 12.0)
        sig = (g1 + g2 + g3 + body) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_cajon(left, right, start_s, is_bass=True, gain=0.28, pan=0.0):
    """Flamenco wooden cajon drum. Deep bass thump or crisp high wooden slap."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.35 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        if is_bass:
            f = 65.0 * (1.0 + 0.30 * math.exp(-t * 35.0))
            env = math.exp(-t * 8.0)
            sig = math.sin(2.0 * math.pi * f * t) * gain * env
        else:
            # Wooden high slap with snappy wood resonance
            env = math.exp(-t * 18.0)
            w1 = math.sin(2.0 * math.pi * 420.0 * t)
            w2 = 0.4 * math.sin(2.0 * math.pi * 840.0 * t)
            sig = (w1 + w2) * gain * 0.85 * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_concert_harp(left, right, start_s, freq, gain=0.20, pan=0.2):
    """Cascading concert harp note. Lush, pure, unmodulated plucked tone."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(2.0 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2.4) if t > 0.005 else (t / 0.005)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.20 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 4.0)
        h3 = 0.06 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 7.0)
        sig = (h1 + h2 + h3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_grand_piano(left, right, start_s, dur_s, freq, gain=0.25, pan=0.0):
    """Concert Grand Piano with dark felt damping. Steady pure pitch."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 1.5) if t > 0.010 else (t / 0.010)
        p1 = math.sin(2.0 * math.pi * freq * t)
        p2 = 0.38 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 2.4)
        p3 = 0.10 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 4.2)
        sig = (p1 + p2 + p3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_acoustic_cello(left, right, start_s, dur_s, freq, gain=0.24, pan=-0.25):
    """Warm acoustic cello tone. Steady fundamental, zero vibrato."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.15) * min(1.0, (dur_s - t) / 0.18)
        c1 = math.sin(2.0 * math.pi * freq * t)
        c2 = 0.26 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        c3 = 0.06 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        sig = (c1 + c2 + c3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_celesta(left, right, start_s, freq, gain=0.16, pan=0.25):
    """Gentle celesta / music box chime (warm mid register)."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.2 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5) if t > 0.006 else (t / 0.006)
        c1 = math.sin(2.0 * math.pi * freq * t)
        c2 = 0.14 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        sig = (c1 + c2) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


# =============================================================================
# THE 5 COMPOSITIONS
# =============================================================================

def compose_carnival_of_illusions():
    """
    Track 58: ost_carnival_of_illusions (138 BPM, A minor / C major, 4/4)
    Mood: Eerie, nostalgic mechanical amusement park in ruins.
    Marimba staccato arpeggios + walking upright bass pizz + offbeat guitar + celesta.
    """
    print("Generating ost_carnival_of_illusions...")
    bpm = 138.0
    sec_per_beat = 60.0 / bpm
    total_beats = 104  # 26 bars (~45.21s)
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Progression: Am - F - C - G (Playful syncopated carnival loop)
    prog = [
        {"root": "A2", "arp": ["A3", "C4", "E4", "A4", "E4", "C4", "A3", "E4"], "bass": ["A2", "C3", "E3", "G3"]},
        {"root": "F2", "arp": ["F3", "A3", "C4", "F4", "C4", "A3", "F3", "C4"], "bass": ["F2", "A2", "C3", "E3"]},
        {"root": "C2", "arp": ["C3", "E3", "G3", "C4", "G3", "E3", "C3", "G3"], "bass": ["C2", "E2", "G2", "B2"]},
        {"root": "G2", "arp": ["G2", "B2", "D3", "G3", "D3", "B2", "G2", "B2"], "bass": ["G2", "B2", "D3", "F#3"]},
    ]

    for bar in range(26):
        p_info = prog[bar % 4]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Acoustic Rosewood Marimba running arpeggios (8th notes)
        for p in range(8):
            t_m = bar_t + p * (sec_per_beat / 2.0)
            n_str = p_info["arp"][p % len(p_info["arp"])]
            add_pure_marimba(left, right, t_m, note_to_freq(n_str), gain=0.20, pan=((p % 2) * 0.3 - 0.15))

        # 2. Walking Upright Bass Pizzicato (quarter notes)
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            n_bass = p_info["bass"][b]
            add_pure_upright_bass_pizz(left, right, t_b, note_to_freq(n_bass), gain=0.26, pan=-0.2)

        # 3. Offbeat acoustic guitar chords (beats 2 and 4)
        for ob in [1, 3]:
            t_ob = bar_t + ob * sec_per_beat
            for n_chord in p_info["arp"][:3]:
                add_pure_pastoral_lute(left, right, t_ob, 0.4, note_to_freq(n_chord), gain=0.14, pan=0.2)

        # 4. Carnival Celesta / Music Box melody accents
        if bar >= 4 and bar % 2 == 0:
            add_pure_celesta(left, right, bar_t + sec_per_beat * 1.5, note_to_freq("E5"), gain=0.15, pan=0.3)
            add_pure_celesta(left, right, bar_t + sec_per_beat * 3.5, note_to_freq("C5"), gain=0.14, pan=-0.3)

    write_ogg_file(left, right, "ost_carnival_of_illusions", total_sec)


def compose_verdant_whispers():
    """
    Track 59: ost_verdant_whispers (96 BPM, D Dorian, 6/8 compound meter)
    Mood: Forgotten emerald forest castle / pastoral sanctuary.
    Rustic acoustic lute 6/8 picking + wooden transverse pipe + bodhran pulse + warm cello.
    """
    print("Generating ost_verdant_whispers...")
    bpm = 96.0
    sec_per_eighth = (60.0 / bpm) / 2.0  # In 6/8, each eighth note is the pulse
    # 28 bars of 6/8 = 168 eighth notes (~52.5s -> let's take 24 bars = 144 eighths = 45.0s)
    total_eighths = 144  # exactly 45.0 seconds at 96 BPM!
    total_sec = total_eighths * sec_per_eighth
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # 6/8 Progression in D Dorian: Dm - C - G - Dm (4 bars per cycle)
    chords_68 = [
        {"root": "D2", "lute": ["D3", "A3", "D4", "F4", "D4", "A3"], "pipe": "F4"},
        {"root": "C2", "lute": ["C3", "G3", "C4", "E4", "C4", "G3"], "pipe": "E4"},
        {"root": "G2", "lute": ["G2", "D3", "G3", "B3", "G3", "D3"], "pipe": "D4"},
        {"root": "D2", "lute": ["D3", "A3", "D4", "F4", "D4", "A3"], "pipe": "A4"},
    ]

    for bar in range(24):
        c_info = chords_68[bar % len(chords_68)]
        bar_t = bar * 6.0 * sec_per_eighth

        # 1. Bodhran Hand Drum (Pulse on eighth 1 and 4: ONE-two-three TWO-two-three)
        add_pure_bodhran(left, right, bar_t, freq=65.0, gain=0.28, pan=-0.1)
        add_pure_bodhran(left, right, bar_t + 3.0 * sec_per_eighth, freq=78.0, gain=0.20, pan=0.1)

        # 2. Rustic Lute 6/8 rolling arpeggio (6 eighth notes)
        for e in range(6):
            t_e = bar_t + e * sec_per_eighth
            n_str = c_info["lute"][e]
            add_pure_pastoral_lute(left, right, t_e, 0.7, note_to_freq(n_str), gain=0.20, pan=((e % 2) * 0.3 - 0.15))

        # 3. Warm Cello bass tone (sustained across bar)
        add_pure_acoustic_cello(left, right, bar_t, sec_per_eighth * 5.6, note_to_freq(c_info["root"]), gain=0.24, pan=-0.3)

        # 4. Wooden Transverse Pipe / Flute melody line (steady unmodulated breath)
        if bar >= 4 and bar % 2 == 0:
            add_pure_wooden_pipe(left, right, bar_t + sec_per_eighth * 1.0, sec_per_eighth * 4.5, note_to_freq(c_info["pipe"]), gain=0.22, pan=0.2)

    write_ogg_file(left, right, "ost_verdant_whispers", total_sec)


def compose_abyssal_silence():
    """
    Track 60: ost_abyssal_silence (72 BPM, F minor, 4/4)
    Mood: Dark, profound subterranean abyss / alien vessel silence.
    Contrabass sub-drone (F1 43.6Hz) + felt piano sparse chords + Tibetan singing bowl + temple blocks.
    """
    print("Generating ost_abyssal_silence...")
    bpm = 72.0
    sec_per_beat = 60.0 / bpm
    total_beats = 54  # 13.5 bars (~45.0s)
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Modal cycle: Fm - Db - Bbm - C (sparse 2-bar or 1-bar voicings)
    ambient_chords = [
        {"root_freq": 43.65, "piano": ["F2", "C3", "Ab3", "C4"]},  # Fm (F1 fundamental)
        {"root_freq": 34.65, "piano": ["Db2", "Ab2", "F3", "Ab3"]}, # Db (Db1)
        {"root_freq": 58.27, "piano": ["Bb1", "F2", "Db3", "F3"]},  # Bbm
        {"root_freq": 65.41, "piano": ["C2", "G2", "E3", "G3"]},    # C maj
    ]

    for bar in range(13):
        a_info = ambient_chords[bar % len(ambient_chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Deep Contrabass Bowed Sub-Drone (F1/Db1, completely steady rock-solid pitch)
        add_pure_contrabass_drone(left, right, bar_t, sec_per_beat * 4.0, freq=a_info["root_freq"], gain=0.28, pan=-0.25)

        # 2. Sparse Felt Grand Piano Chords (Note on downbeat with long natural room decay)
        for idx_p, n_p in enumerate(a_info["piano"]):
            t_offset = bar_t + idx_p * 0.04  # gentle acoustic arpeggiation roll
            add_pure_grand_piano(left, right, t_offset, sec_per_beat * 3.8, note_to_freq(n_p), gain=0.22, pan=((idx_p - 1.5) * 0.15))

        # 3. Bronze Singing Bowl resonance (bars 0, 4, 8, 12)
        if bar % 4 == 0:
            add_pure_singing_bowl(left, right, bar_t + sec_per_beat * 1.0, freq=280.0, gain=0.22, pan=0.3)

        # 4. Wooden Temple Block pacing clicks
        add_pure_temple_block(left, right, bar_t + sec_per_beat * 2.0, freq=380.0, gain=0.16, pan=-0.1)
        add_pure_temple_block(left, right, bar_t + sec_per_beat * 3.5, freq=520.0, gain=0.14, pan=0.15)

    write_ogg_file(left, right, "ost_abyssal_silence", total_sec)


def compose_dance_of_the_blade():
    """
    Track 61: ost_dance_of_the_blade (144 BPM, E Phrygian / E minor, 4/4)
    Mood: High-tempo breathless acoustic duel / sword dance.
    Spanish flamenco nylon guitar rasgueado & running riffs + driving cello ostinato + cajon polyrhythm.
    """
    print("Generating ost_dance_of_the_blade...")
    bpm = 144.0
    sec_per_beat = 60.0 / bpm
    total_beats = 108  # 27 bars (~45.0s)
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Andalusian / Phrygian Cadence: Em - F - G - F
    flamenco_bars = [
        {"root": "E2", "riff": ["E3", "G3", "B3", "E4", "B3", "G3", "F3", "D#3"]},
        {"root": "F2", "riff": ["F3", "A3", "C4", "F4", "C4", "A3", "G3", "F3"]},
        {"root": "G2", "riff": ["G3", "B3", "D4", "G4", "D4", "B3", "A3", "G3"]},
        {"root": "F2", "riff": ["F3", "A3", "C4", "F4", "C4", "A3", "G3", "F3"]},
    ]

    for bar in range(27):
        f_info = flamenco_bars[bar % 4]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Flamenco Cajon Drumming
        # Downbeat kick + slap on beats 2 & 4 + ghost note on 3.5
        add_pure_cajon(left, right, bar_t, is_bass=True, gain=0.30, pan=-0.05)
        add_pure_cajon(left, right, bar_t + sec_per_beat * 1.0, is_bass=False, gain=0.24, pan=0.1)
        add_pure_cajon(left, right, bar_t + sec_per_beat * 2.0, is_bass=True, gain=0.22, pan=-0.05)
        add_pure_cajon(left, right, bar_t + sec_per_beat * 3.0, is_bass=False, gain=0.26, pan=0.1)
        add_pure_cajon(left, right, bar_t + sec_per_beat * 3.5, is_bass=False, gain=0.16, pan=-0.1)

        # 2. Rapid Flamenco Nylon Guitar Riffs (8th notes)
        for p in range(8):
            t_p = bar_t + p * (sec_per_beat / 2.0)
            n_str = f_info["riff"][p]
            add_pure_flamenco_guitar(left, right, t_p, 0.45, note_to_freq(n_str), gain=0.22, pan=((p % 2) * 0.25 - 0.12))

        # 3. Driving Cello Ostinato Bassline
        add_pure_acoustic_cello(left, right, bar_t, sec_per_beat * 1.8, note_to_freq(f_info["root"]), gain=0.26, pan=-0.25)
        add_pure_acoustic_cello(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.8, note_to_freq(f_info["root"]), gain=0.24, pan=-0.25)

        # 4. Staccato Grand Piano Chord Accents (bars 8+)
        if bar >= 8:
            add_pure_grand_piano(left, right, bar_t, sec_per_beat * 0.8, note_to_freq(f_info["riff"][0]), gain=0.18, pan=-0.2)
            add_pure_grand_piano(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 0.8, note_to_freq(f_info["riff"][2]), gain=0.16, pan=0.2)

    write_ogg_file(left, right, "ost_dance_of_the_blade", total_sec)


def compose_cradle_of_waves():
    """
    Track 62: ost_cradle_of_waves (84 BPM, G major, 4/4)
    Mood: Serene, peaceful ocean lullaby along the flooded ruins shoreline.
    Cascading concert harp arpeggios + warm acoustic guitar harmonics + singing cello + celesta.
    """
    print("Generating ost_cradle_of_waves...")
    bpm = 84.0
    sec_per_beat = 60.0 / bpm
    total_beats = 64  # 16 bars (~45.71s)
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Pentatonic Lullaby Progression: G - Em - C - D
    lullaby_chords = [
        {"root": "G2", "harp": ["G3", "B3", "D4", "G4", "B4", "D5", "B4", "G4"], "cello": "B3"},
        {"root": "E2", "harp": ["E3", "G3", "B3", "E4", "G4", "B4", "G4", "E4"], "cello": "G3"},
        {"root": "C2", "harp": ["C3", "E3", "G3", "C4", "E4", "G4", "E4", "C4"], "cello": "E4"},
        {"root": "D2", "harp": ["D3", "F#3", "A3", "D4", "F#4", "A4", "F#4", "D4"], "cello": "D4"},
    ]

    for bar in range(16):
        l_info = lullaby_chords[bar % 4]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Cascading Concert Harp Arpeggios (Gentle ocean wave pattern)
        for h in range(8):
            t_h = bar_t + h * (sec_per_beat / 2.0)
            n_harp = l_info["harp"][h]
            add_pure_concert_harp(left, right, t_h, note_to_freq(n_harp), gain=0.20, pan=((h % 4) - 1.5) * 0.18)

        # 2. Singing Acoustic Cello Melody (Warm sustained legato)
        add_pure_acoustic_cello(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(l_info["root"]), gain=0.24, pan=-0.3)
        add_pure_acoustic_cello(left, right, bar_t + sec_per_beat * 1.5, sec_per_beat * 2.2, note_to_freq(l_info["cello"]), gain=0.20, pan=0.1)

        # 3. Gentle Acoustic Guitar Harmonics on beat 1 and 3
        add_pure_pastoral_lute(left, right, bar_t, sec_per_beat * 1.8, note_to_freq(l_info["harp"][3]), gain=0.16, pan=-0.2)
        add_pure_pastoral_lute(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 1.8, note_to_freq(l_info["harp"][5]), gain=0.14, pan=0.2)

        # 4. Soft Celesta Drops (bars 4+)
        if bar >= 4 and bar % 2 == 0:
            add_pure_celesta(left, right, bar_t + sec_per_beat * 1.0, note_to_freq("D5"), gain=0.14, pan=0.3)
            add_pure_celesta(left, right, bar_t + sec_per_beat * 3.0, note_to_freq("G4"), gain=0.12, pan=-0.25)

    write_ogg_file(left, right, "ost_cradle_of_waves", total_sec)


def main():
    print("=== NieR: Automata Suite Part 3 Generator (Maximum Variety, Pure Acoustic) ===")
    compose_carnival_of_illusions()
    compose_verdant_whispers()
    compose_abyssal_silence()
    compose_dance_of_the_blade()
    compose_cradle_of_waves()
    print("=== All 5 Automata Suite Part 3 tracks generated successfully! ===")


if __name__ == "__main__":
    main()
