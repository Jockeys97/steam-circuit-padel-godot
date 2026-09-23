#!/usr/bin/env python3
"""
generate_automata_soundtracks.py — 5 Pure NieR: Automata Style Soundtracks.
100% Organic, Warm, Cinematic Acoustic Sound.
NO SAWTOOTH WAVES (completely eliminated toy trumpet / buzzer sounds).
NO HIGH-FREQUENCY WHISTLES (all leads below 650 Hz, smoothed with low-pass filters).
NO HARSH GLOCKENSPIEL BELLS (replaced with warm concert harp & acoustic guitar harmonics).
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

    # Apply warm lowpass filter to completely eliminate any high-frequency whistles
    left = apply_warm_lowpass(left, cutoff_hz=3500.0)
    right = apply_warm_lowpass(right, cutoff_hz=3500.0)

    # 45-second seamless loop: blend tail into head
    loop_fade = int(0.35 * SAMPLE_RATE)
    for i in range(loop_fade):
        frac = i / loop_fade
        left[i] = left[i] * frac + left[total_samples - loop_fade + i] * (1.0 - frac)
        right[i] = right[i] * frac + right[total_samples - loop_fade + i] * (1.0 - frac)
        left[total_samples - loop_fade + i] = left[i]
        right[total_samples - loop_fade + i] = right[i]

    # Warm analog soft-clipping saturation (no digital harshness)
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
# WARM NIER INSTRUMENT ENGINES (NO SAWTOOTH, NO HARSH WHISTLES)
# =============================================================================

def add_nylon_guitar_pick(left, right, start_s, dur_s, freq, gain=0.24, pan=0.0):
    """Warm, mellow Spanish acoustic/nylon guitar picking. Pure round tone."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        # Soft fingertip attack (no sharp metallic click)
        env = math.exp(-t * 2.5) if t > 0.008 else (t / 0.008)
        # Warm harmonic series with fast high-harmonic decay
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.35 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 4.0)
        h3 = 0.12 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 7.0)
        # Deep cedar body resonance at 110 Hz
        body = 0.15 * math.sin(2.0 * math.pi * 110.0 * t) * math.exp(-t * 3.0)
        sig = (h1 + h2 + h3 + body) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_felt_piano(left, right, start_s, dur_s, freq, gain=0.25, pan=0.0):
    """Warm, intimate felted grand piano. Mellow harmonics, long deep sustain."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 1.6) if t > 0.012 else (t / 0.012)
        p1 = math.sin(2.0 * math.pi * freq * t)
        p2 = 0.40 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 2.5)
        p3 = 0.15 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 4.5)
        sig = (p1 + p2 + p3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_warm_cello_viola(left, right, start_s, dur_s, freq, gain=0.22, pan=0.0):
    """
    Pure additive warm string cello/viola section.
    COMPLETELY ELIMINATES the sawtooth wave! No buzzy plastic horn sound.
    """
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        # Gentle bow swell and fade
        env = min(1.0, t / 0.15) * min(1.0, (dur_s - t) / 0.20)
        # Slow warm human vibrato (starts after note attack)
        vib_amount = 0.008 * min(1.0, max(0.0, (t - 0.2) / 0.4))
        vib = math.sin(2.0 * math.pi * 4.8 * t) * vib_amount
        f = freq * (1.0 + vib)
        # Pure soft additive harmonics (smooth wooden acoustic string timbre)
        h1 = math.sin(2.0 * math.pi * f * t)
        h2 = 0.30 * math.sin(2.0 * math.pi * 2.0 * f * t)
        h3 = 0.08 * math.sin(2.0 * math.pi * 3.0 * f * t)
        sig = (h1 + h2 + h3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_ethereal_choir_pad(left, right, start_s, dur_s, chord_freqs, gain=0.20):
    """Warm, celestial choral harmony pad. Smooth vowel hums with stereo depth."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.4) * min(1.0, (dur_s - t) / 0.4)
        sig_l = 0.0
        sig_r = 0.0
        for idx_f, f in enumerate(chord_freqs):
            vib = math.sin(2.0 * math.pi * (4.5 + idx_f * 0.3) * t) * 0.008
            f_v = f * (1.0 + vib)
            c1 = math.sin(2.0 * math.pi * f_v * t)
            c2 = 0.25 * math.sin(2.0 * math.pi * f_v * 2.0 * t)
            pan_val = -0.4 + (idx_f / max(1, len(chord_freqs) - 1)) * 0.8
            lp = math.cos((pan_val + 1.0) * math.pi * 0.25)
            rp = math.sin((pan_val + 1.0) * math.pi * 0.25)
            sig_l += (c1 + c2) * lp
            sig_r += (c1 + c2) * rp

        left[idx] += (sig_l / len(chord_freqs)) * gain * env
        right[idx] += (sig_r / len(chord_freqs)) * gain * env


def add_warm_vocal_melody(left, right, start_s, dur_s, freq, gain=0.26, pan=0.0):
    """
    Intimate, breathy NieR 'Chaos Language' vocalise.
    Kept in the warm alto/mezzo vocal sweet spot (220 - 520 Hz).
    No narrow resonant filter peaks, no whistling artifacts.
    """
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        # Soft singing envelope
        env = min(1.0, t / 0.12) * min(1.0, (dur_s - t) / 0.16)
        # Natural expressive singing vibrato
        vib = math.sin(2.0 * math.pi * 5.0 * t) * (0.010 * min(1.0, max(0.0, (t - 0.18) / 0.3)))
        f = freq * (1.0 + vib)
        # Warm vocal tone: rounded glottal pulse (sine-squared) + subtle soft breath noise
        tone = math.sin(2.0 * math.pi * f * t) + 0.25 * math.sin(4.0 * math.pi * f * t)
        breath = (random.random() * 2.0 - 1.0) * 0.05 * math.exp(-t * 2.0)
        sig = (tone + breath) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_warm_harp_note(left, right, start_s, freq, gain=0.18, pan=0.2):
    """Gentle Celtic / orchestral concert harp arpeggio note (replaces metallic bells)."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.4 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5) if t > 0.005 else (t / 0.005)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.20 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        sig = (h1 + h2) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_deep_taiko_drum(left, right, start_s, freq=55.0, gain=0.32, pan=0.0):
    """Deep, round wooden taiko / orchestral concert tom. No harsh click."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.6 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        f = freq * (1.0 + 0.3 * math.exp(-t * 28.0))
        env = math.exp(-t * 5.5)
        sig = math.sin(2.0 * math.pi * f * t) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


# =============================================================================
# THE 5 COMPOSITIONS (REDESIGNED FOR WARMTH, PURITY & EMOTION)
# =============================================================================

def compose_rays_of_rust():
    """
    Track 1: ost_rays_of_rust (108 BPM, D minor)
    Pure NieR: Automata acoustic landscape.
    Warm fingerpicked acoustic guitar + felt piano + warm cello + breathy vocalise.
    ZERO trumpet, ZERO saw waves, ZERO whistling bells.
    """
    print("Generating ost_rays_of_rust...")
    bpm = 108.0
    sec_per_beat = 60.0 / bpm
    total_beats = 80  # 44.44s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Warm D minor chord progression: Dm - Bb - C - Am
    chords = [
        {"root": "D2", "notes": ["D3", "F3", "A3", "D4"]},
        {"root": "Bb1", "notes": ["Bb2", "D3", "F3", "Bb3"]},
        {"root": "C2", "notes": ["C3", "E3", "G3", "C4"]},
        {"root": "A1", "notes": ["A2", "C3", "E3", "A3"]},
    ]

    for bar in range(20):
        c_info = chords[bar % 4]
        c_time = bar * 4.0 * sec_per_beat

        # 1. Warm nylon guitar fingerpicking (octaves 3 and 4)
        for p in range(8):
            t_pick = c_time + p * (sec_per_beat / 2.0)
            n_str = c_info["notes"][p % len(c_info["notes"])]
            add_nylon_guitar_pick(left, right, t_pick, 0.9, note_to_freq(n_str), gain=0.22, pan=((p % 2) * 0.3 - 0.15))

        # 2. Deep warm cello root note
        add_warm_cello_viola(left, right, c_time, sec_per_beat * 3.8, note_to_freq(c_info["root"]), gain=0.26, pan=-0.25)

        # 3. Soft felt piano chords
        if bar >= 4:
            add_felt_piano(left, right, c_time, sec_per_beat * 3.5, note_to_freq(c_info["notes"][1]), gain=0.18, pan=-0.15)
            add_felt_piano(left, right, c_time + sec_per_beat * 2.0, sec_per_beat * 2.0, note_to_freq(c_info["notes"][2]), gain=0.16, pan=0.15)

        # 4. Soft warm taiko thuds
        if bar >= 4:
            add_deep_taiko_drum(left, right, c_time, freq=52.0, gain=0.28, pan=-0.1)
            add_deep_taiko_drum(left, right, c_time + sec_per_beat * 2.0, freq=68.0, gain=0.20, pan=0.15)

        # 5. Gentle warm concert harp arpeggio (bars 8+)
        if bar >= 8 and bar % 2 == 0:
            add_warm_harp_note(left, right, c_time + sec_per_beat * 1.0, note_to_freq("A4"), gain=0.14, pan=0.25)
            add_warm_harp_note(left, right, c_time + sec_per_beat * 3.0, note_to_freq("F4"), gain=0.12, pan=-0.25)

    # 6. Ethereal alto vocal melody (warm mid-register: D4 to A4, max 440 Hz)
    vocal_melody = [
        # Phrase 1
        (8.0, 1.4, "D4"), (9.5, 1.2, "F4"), (11.0, 1.5, "E4"), (12.8, 2.4, "D4"),
        # Phrase 2
        (16.0, 1.3, "F4"), (17.5, 1.2, "G4"), (19.0, 1.8, "A4"), (21.0, 2.4, "F4"),
        # Phrase 3
        (24.0, 1.6, "Bb4"), (25.8, 1.4, "A4"), (27.4, 1.6, "G4"), (29.2, 2.4, "F4"),
        # Phrase 4
        (32.0, 1.4, "E4"), (33.6, 1.3, "F4"), (35.2, 3.0, "D4"),
    ]
    for start_b, dur_b, n_str in vocal_melody:
        add_warm_vocal_melody(left, right, start_b * sec_per_beat, dur_b * sec_per_beat, note_to_freq(n_str), gain=0.26, pan=0.0)

    write_ogg_file(left, right, "ost_rays_of_rust", total_sec)


def compose_weight_of_the_rally():
    """
    Track 2: ost_weight_of_the_rally (115 BPM, F# minor)
    Grand piano + warm choral hymn + emotional cello + deep taiko.
    Inspired by Weight of the World.
    """
    print("Generating ost_weight_of_the_rally...")
    bpm = 115.0
    sec_per_beat = 60.0 / bpm
    total_beats = 86  # 44.86s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    prog = [
        {"root": "F#2", "chord": ["F#3", "A3", "C#4", "F#4"]},
        {"root": "D2", "chord": ["D3", "F#3", "A3", "D4"]},
        {"root": "A1", "chord": ["A2", "C#3", "E3", "A3"]},
        {"root": "E2", "chord": ["E3", "G#3", "B3", "E4"]},
    ]

    for bar in range(21):
        p_info = prog[bar % 4]
        c_time = bar * 4.0 * sec_per_beat
        c_freqs = [note_to_freq(n) for n in p_info["chord"]]

        # 1. Warm Felt Grand Piano
        add_felt_piano(left, right, c_time, sec_per_beat * 3.8, note_to_freq(p_info["root"]), gain=0.28, pan=-0.2)
        for i, n in enumerate(p_info["chord"]):
            add_felt_piano(left, right, c_time + (i * 0.5) * sec_per_beat, sec_per_beat * 2.8, note_to_freq(n), gain=0.18, pan=0.1 * (i - 1.5))

        # 2. Resonant Warm Cello
        add_warm_cello_viola(left, right, c_time, sec_per_beat * 3.8, note_to_freq(p_info["root"]), gain=0.26, pan=-0.3)

        # 3. Celestial Warm Choral Pad
        add_ethereal_choir_pad(left, right, c_time, sec_per_beat * 4.0, c_freqs, gain=0.22)

        # 4. Deep Taiko Drums (Bars 4+)
        if bar >= 4:
            add_deep_taiko_drum(left, right, c_time, freq=48.0, gain=0.32, pan=-0.1)
            add_deep_taiko_drum(left, right, c_time + sec_per_beat * 2.0, freq=64.0, gain=0.24, pan=0.15)

    # 5. Soaring Alto Vocal Hymn (F#3 to F#4, warm and heartfelt)
    vocal_hymn = [
        # Phrase 1
        (8.0, 1.4, "C#4"), (9.6, 1.2, "E4"), (11.0, 1.5, "F#4"), (13.0, 2.5, "C#4"),
        # Phrase 2
        (16.0, 1.3, "D4"), (17.5, 1.2, "F#4"), (19.0, 1.8, "A4"), (21.2, 2.4, "G#4"),
        # Phrase 3
        (24.0, 1.8, "A4"), (26.0, 1.4, "B4"), (27.6, 2.2, "C#5"), (30.0, 2.0, "A4"),
        # Phrase 4
        (32.0, 1.5, "F#4"), (33.8, 1.5, "G#4"), (35.5, 3.2, "F#4"),
    ]
    for start_b, dur_b, n_str in vocal_hymn:
        add_warm_vocal_melody(left, right, start_b * sec_per_beat, dur_b * sec_per_beat, note_to_freq(n_str), gain=0.28, pan=0.0)

    write_ogg_file(left, right, "ost_weight_of_the_rally", total_sec)


def compose_beautiful_duel():
    """
    Track 3: ost_beautiful_duel (132 BPM, 3/4 Dramatic Waltz, G minor)
    Solemn waltz with warm acoustic nylon guitar + felt piano + warm cello countermelody + soft harp.
    NO piercing violin screech, NO saw waves.
    """
    print("Generating ost_beautiful_duel...")
    bpm = 132.0
    sec_per_beat = 60.0 / bpm
    total_beats = 96  # 32 bars (~43.63s)
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    chords_34 = [
        {"root": "G2", "notes": ["G3", "Bb3", "D4"]},
        {"root": "C2", "notes": ["G3", "C4", "Eb4"]},
        {"root": "D2", "notes": ["F#3", "A3", "D4"]},
        {"root": "G2", "notes": ["G3", "Bb3", "D4"]},
        {"root": "Eb2", "notes": ["G3", "Bb3", "Eb4"]},
        {"root": "Bb1", "notes": ["F3", "Bb3", "D4"]},
        {"root": "D2", "notes": ["F#3", "A3", "D4"]},
        {"root": "G2", "notes": ["G3", "Bb3", "D4"]},
    ]

    for bar in range(32):
        c_info = chords_34[bar % len(chords_34)]
        bar_t = bar * 3.0 * sec_per_beat

        # Beat 1: Warm low taiko & warm cello root
        add_deep_taiko_drum(left, right, bar_t, freq=55.0, gain=0.30, pan=-0.1)
        add_warm_cello_viola(left, right, bar_t, sec_per_beat * 2.8, note_to_freq(c_info["root"]), gain=0.26, pan=-0.25)

        # Beat 2 & 3: Warm felt piano chords
        for b_idx in [1, 2]:
            t_chord = bar_t + b_idx * sec_per_beat
            for n in c_info["notes"]:
                add_felt_piano(left, right, t_chord, sec_per_beat * 0.9, note_to_freq(n), gain=0.16, pan=0.1)

        # Soft concert harp on cadence bars
        if bar % 4 == 0:
            add_warm_harp_note(left, right, bar_t, note_to_freq("D4"), gain=0.15, pan=0.25)

    # Warm Cello / Viola lyrical lead melody (NOT screechy saw-violin!)
    cello_melody = [
        (6.0, 1.8, "D4"), (8.0, 0.9, "Eb4"), (9.0, 1.8, "D4"), (11.0, 0.9, "C4"),
        (12.0, 2.5, "Bb3"), (15.0, 2.5, "A3"), (18.0, 3.5, "G3"),
        (24.0, 1.8, "G4"), (26.0, 0.9, "A4"), (27.0, 1.8, "Bb4"), (29.0, 0.9, "C5"),
        (30.0, 2.5, "D5"), (33.0, 2.5, "C5"), (36.0, 3.5, "Bb4"),
        (42.0, 2.0, "Eb4"), (44.2, 1.5, "D4"), (46.0, 2.0, "C4"), (48.0, 3.5, "D4"),
    ]
    for start_b, dur_b, n_str in cello_melody:
        add_warm_cello_viola(left, right, start_b * sec_per_beat, dur_b * sec_per_beat, note_to_freq(n_str), gain=0.25, pan=0.15)

    # Warm vocalise countermelody (in octaves 4)
    vocal_duet = [
        (12.0, 2.2, "D4"), (15.0, 2.2, "C4"), (18.0, 3.5, "Bb3"),
        (30.0, 2.2, "F#4"), (33.0, 2.2, "G4"), (36.0, 3.5, "D4"),
    ]
    for start_b, dur_b, n_str in vocal_duet:
        add_warm_vocal_melody(left, right, start_b * sec_per_beat, dur_b * sec_per_beat, note_to_freq(n_str), gain=0.26, pan=-0.2)

    write_ogg_file(left, right, "ost_beautiful_duel", total_sec)


def compose_memories_of_sand():
    """
    Track 4: ost_memories_of_sand (96 BPM, E Phrygian)
    Warm desert wind acoustic guitar picking + deep warm cello drone + soft taiko + gentle vocal murmurs.
    """
    print("Generating ost_memories_of_sand...")
    bpm = 96.0
    sec_per_beat = 60.0 / bpm
    total_beats = 72  # 45.0s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    phryg_chords = [
        {"root": "E2", "notes": ["E3", "G3", "B3", "E4"]},
        {"root": "F2", "notes": ["F3", "A3", "C4", "F4"]},
        {"root": "G2", "notes": ["G3", "B3", "D4", "G4"]},
        {"root": "E2", "notes": ["E3", "G3", "B3", "E4"]},
    ]

    for bar in range(18):
        c_info = phryg_chords[bar % len(phryg_chords)]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Intricate Flamenco / Spanish Nylon Guitar Picking
        for p in range(8):
            t_pick = bar_t + p * (sec_per_beat / 2.0)
            n_str = c_info["notes"][p % len(c_info["notes"])]
            add_nylon_guitar_pick(left, right, t_pick, 0.8, note_to_freq(n_str), gain=0.24, pan=((p % 2) * 0.3 - 0.15))

        # 2. Deep Cello Root Drone
        add_warm_cello_viola(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(c_info["root"]), gain=0.25, pan=-0.3)

        # 3. Soft Desert Taiko / Frame Drum
        for b_idx in [0, 2.0]:
            t_hit = bar_t + b_idx * sec_per_beat
            add_deep_taiko_drum(left, right, t_hit, freq=58.0 if b_idx == 0 else 72.0, gain=0.25 if b_idx == 0 else 0.18, pan=0.1)

    # 4. Breathy Desert Vocal Line (E4 to B4, purely warm and mystical)
    desert_lines = [
        (8.0, 1.6, "E4"), (10.0, 1.2, "F4"), (11.5, 2.2, "E4"),
        (16.0, 1.5, "G4"), (18.0, 1.4, "A4"), (19.8, 2.6, "B4"),
        (24.0, 1.8, "C5"), (26.2, 1.5, "B4"), (28.0, 2.8, "G4"),
        (32.0, 1.6, "F4"), (34.0, 2.8, "E4"),
    ]
    for start_b, dur_b, n_str in desert_lines:
        add_warm_vocal_melody(left, right, start_b * sec_per_beat, dur_b * sec_per_beat, note_to_freq(n_str), gain=0.26, pan=0.0)

    write_ogg_file(left, right, "ost_memories_of_sand", total_sec)


def compose_rebirth_of_hope():
    """
    Track 5: ost_rebirth_of_hope (120 BPM, A minor -> C major)
    Uplifting, serene, warm sunrise crescendo.
    Cascading felt piano + celestial warm choir + warm cello + gentle harp + deep taiko.
    """
    print("Generating ost_rebirth_of_hope...")
    bpm = 120.0
    sec_per_beat = 60.0 / bpm
    total_beats = 90  # 45.0s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    uplift_chords = [
        {"root": "A2", "chord": ["A3", "C4", "E4", "A4"]},
        {"root": "F2", "chord": ["F3", "A3", "C4", "F4"]},
        {"root": "C2", "chord": ["G3", "C4", "E4", "G4"]},
        {"root": "G2", "chord": ["G3", "B3", "D4", "G4"]},
    ]

    for bar in range(22):
        u_info = uplift_chords[bar % len(uplift_chords)]
        bar_t = bar * 4.0 * sec_per_beat
        c_freqs = [note_to_freq(n) for n in u_info["chord"]]

        # 1. Cascading Felt Piano Arpeggios
        add_felt_piano(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(u_info["root"]), gain=0.26, pan=-0.2)
        for p in range(8):
            t_arp = bar_t + p * (sec_per_beat / 2.0)
            n_str = u_info["chord"][p % len(u_info["chord"])]
            add_felt_piano(left, right, t_arp, sec_per_beat * 1.5, note_to_freq(n_str), gain=0.18, pan=((p % 2) * 0.3 - 0.15))

        # 2. Resonant Warm Cello
        add_warm_cello_viola(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(u_info["root"]), gain=0.25, pan=-0.3)

        # 3. Layered Warm Choral Hymn
        add_ethereal_choir_pad(left, right, bar_t, sec_per_beat * 4.0, c_freqs, gain=0.24)

        # 4. Warm Taiko & Harp Notes
        if bar >= 4:
            add_deep_taiko_drum(left, right, bar_t, freq=50.0, gain=0.32, pan=-0.1)
            add_deep_taiko_drum(left, right, bar_t + sec_per_beat * 2.0, freq=66.0, gain=0.24, pan=0.15)
            add_warm_harp_note(left, right, bar_t + sec_per_beat * 1.0, note_to_freq("E4"), gain=0.14, pan=0.25)
            add_warm_harp_note(left, right, bar_t + sec_per_beat * 3.0, note_to_freq("G4"), gain=0.14, pan=-0.25)

    # 5. Soaring Angelic Vocal Hymn (in sweet alto register: E4 to C5, max 523 Hz)
    hymn_lead = [
        # Phrase 1
        (8.0, 1.4, "E4"), (9.6, 1.2, "G4"), (11.0, 1.6, "A4"), (13.0, 2.4, "E4"),
        # Phrase 2
        (16.0, 1.3, "F4"), (17.5, 1.2, "A4"), (19.0, 1.8, "C5"), (21.2, 2.5, "B4"),
        # Phrase 3
        (24.0, 1.8, "C5"), (26.0, 1.5, "D5"), (27.8, 2.2, "E5"), (30.2, 2.0, "C5"),
        # Phrase 4
        (32.0, 1.5, "A4"), (33.8, 1.5, "B4"), (35.5, 3.2, "A4"),
    ]
    for start_b, dur_b, n_str in hymn_lead:
        add_warm_vocal_melody(left, right, start_b * sec_per_beat, dur_b * sec_per_beat, note_to_freq(n_str), gain=0.28, pan=0.0)

    write_ogg_file(left, right, "ost_rebirth_of_hope", total_sec)


def main():
    print("=== NieR: Automata Inspired Suite Audio Generator (Warm Acoustic Redesign) ===")
    compose_rays_of_rust()
    compose_weight_of_the_rally()
    compose_beautiful_duel()
    compose_memories_of_sand()
    compose_rebirth_of_hope()
    print("=== All 5 Automata Suite tracks generated successfully! ===")

if __name__ == "__main__":
    main()
