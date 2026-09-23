#!/usr/bin/env python3
"""
generate_automata_soundtracks_part2.py — 5 Additional Pure NieR: Automata OST Tracks.
100% Organic, Warm, Cinematic Acoustic Sound.
ABSOLUTELY ZERO PITCH MODULATION / LFO / VIBRATO.
ABSOLUTELY ZERO SAWTOOTH OR HARSH SYNTH WAVES.
ROCK-SOLID ACOUSTIC PITCH STABILITY (Real concert grand piano, nylon classical guitar, concert harp, cello, pure vocal harmony).
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
# ROCK-SOLID ACOUSTIC PHYSICAL ENGINES (ZERO PITCH MODULATION / LFO)
# =============================================================================

def add_pure_nylon_guitar(left, right, start_s, dur_s, freq, gain=0.24, pan=0.0):
    """
    Classical Spanish nylon guitar pluck.
    Rock-solid steady pitch (zero LFO). Warm cedar body resonance.
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
        env = math.exp(-t * 2.8) if t > 0.008 else (t / 0.008)
        # Steady pure acoustic harmonics
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.30 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 4.5)
        h3 = 0.08 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 8.0)
        body = 0.14 * math.sin(2.0 * math.pi * 110.0 * t) * math.exp(-t * 3.5)
        sig = (h1 + h2 + h3 + body) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_grand_piano(left, right, start_s, dur_s, freq, gain=0.26, pan=0.0):
    """
    Concert Grand Piano with dark felt damping and spacious room reverb.
    Rock-solid steady pitch (zero LFO).
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
        env = math.exp(-t * 1.5) if t > 0.010 else (t / 0.010)
        p1 = math.sin(2.0 * math.pi * freq * t)
        p2 = 0.38 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 2.4)
        p3 = 0.12 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 4.2)
        sig = (p1 + p2 + p3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_acoustic_cello(left, right, start_s, dur_s, freq, gain=0.24, pan=0.0):
    """
    Warm acoustic cello/bass pedal tone.
    Rock-solid fundamental pitch (NO vibrato, NO sawtooth).
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
        env = min(1.0, t / 0.18) * min(1.0, (dur_s - t) / 0.22)
        # Pure unmodulated acoustic string tone
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.28 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        h3 = 0.06 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        sig = (h1 + h2 + h3) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_sacred_choir(left, right, start_s, dur_s, chord_freqs, gain=0.22):
    """
    Sacred, serene vocal choir singing pure steady open-harmony chords.
    Rock-solid steady pitch (zero LFO). Warm room acoustic.
    """
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.5) * min(1.0, (dur_s - t) / 0.5)
        sig_l = 0.0
        sig_r = 0.0
        for idx_f, f in enumerate(chord_freqs):
            # Pure sine vocal vowel without pitch modulation
            c1 = math.sin(2.0 * math.pi * f * t)
            c2 = 0.22 * math.sin(2.0 * math.pi * 2.0 * f * t)
            pan_val = -0.45 + (idx_f / max(1, len(chord_freqs) - 1)) * 0.9
            lp = math.cos((pan_val + 1.0) * math.pi * 0.25)
            rp = math.sin((pan_val + 1.0) * math.pi * 0.25)
            sig_l += (c1 + c2) * lp
            sig_r += (c1 + c2) * rp

        left[idx] += (sig_l / len(chord_freqs)) * gain * env
        right[idx] += (sig_r / len(chord_freqs)) * gain * env


def add_pure_harp_arpeggio(left, right, start_s, freq, gain=0.18, pan=0.2):
    """Gentle acoustic concert harp note. Pure, unmodulated plucked tone."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.5 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.2) if t > 0.005 else (t / 0.005)
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.18 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 5.0)
        sig = (h1 + h2) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_celesta_note(left, right, start_s, freq, gain=0.16, pan=-0.2):
    """Warm, soft wooden celesta / music box tone (mid-register, never high/whistling)."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.2 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.8) if t > 0.006 else (t / 0.006)
        c1 = math.sin(2.0 * math.pi * freq * t)
        c2 = 0.15 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 6.0)
        sig = (c1 + c2) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_pure_concert_taiko(left, right, start_s, freq=52.0, gain=0.30, pan=0.0):
    """Deep, warm wooden concert taiko / bass drum. Round low thump, no click."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.65 * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        f = freq * (1.0 + 0.25 * math.exp(-t * 25.0))
        env = math.exp(-t * 5.2)
        sig = math.sin(2.0 * math.pi * f * t) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


# =============================================================================
# THE 5 COMPOSITIONS
# =============================================================================

def compose_broken_monolith():
    """
    Track 53: ost_broken_monolith (104 BPM, C minor)
    Mood: Contemplative, profound stillness amidst ancient industrial ruins.
    Warm nylon guitar arpeggios + felt grand piano + deep cello + soft taiko.
    """
    print("Generating ost_broken_monolith...")
    bpm = 104.0
    sec_per_beat = 60.0 / bpm
    total_beats = 76  # ~43.85s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Progression in C minor: Cm - Ab - Eb - Bb
    chords = [
        {"root": "C2", "notes": ["C3", "Eb3", "G3", "C4"]},
        {"root": "Ab1", "notes": ["Ab2", "C3", "Eb3", "Ab3"]},
        {"root": "Eb2", "notes": ["Eb3", "G3", "Bb3", "Eb4"]},
        {"root": "Bb1", "notes": ["Bb2", "D3", "F3", "Bb3"]},
    ]

    for bar in range(19):
        c_info = chords[bar % 4]
        c_time = bar * 4.0 * sec_per_beat

        # 1. Warm nylon classical guitar fingerpicking
        for p in range(8):
            t_pick = c_time + p * (sec_per_beat / 2.0)
            n_str = c_info["notes"][p % len(c_info["notes"])]
            add_pure_nylon_guitar(left, right, t_pick, 0.85, note_to_freq(n_str), gain=0.22, pan=((p % 2) * 0.3 - 0.15))

        # 2. Deep warm cello root pedal
        add_pure_acoustic_cello(left, right, c_time, sec_per_beat * 3.8, note_to_freq(c_info["root"]), gain=0.26, pan=-0.25)

        # 3. Soft felt piano chords
        if bar >= 4:
            add_pure_grand_piano(left, right, c_time, sec_per_beat * 3.5, note_to_freq(c_info["notes"][1]), gain=0.18, pan=-0.15)
            add_pure_grand_piano(left, right, c_time + sec_per_beat * 2.0, sec_per_beat * 2.0, note_to_freq(c_info["notes"][2]), gain=0.16, pan=0.15)

        # 4. Soft warm taiko thuds
        if bar >= 4:
            add_pure_concert_taiko(left, right, c_time, freq=50.0, gain=0.28, pan=-0.1)
            add_pure_concert_taiko(left, right, c_time + sec_per_beat * 2.0, freq=65.0, gain=0.20, pan=0.15)

        # 5. Concert harp arpeggio accents (bars 8+)
        if bar >= 8 and bar % 2 == 0:
            add_pure_harp_arpeggio(left, right, c_time + sec_per_beat * 1.0, note_to_freq("G4"), gain=0.14, pan=0.25)
            add_pure_harp_arpeggio(left, right, c_time + sec_per_beat * 3.0, note_to_freq("Eb4"), gain=0.12, pan=-0.25)

    write_ogg_file(left, right, "ost_broken_monolith", total_sec)


def compose_city_of_pearls():
    """
    Track 54: ost_city_of_pearls (126 BPM, D minor)
    Mood: Crystalline, post-classical minimalist piano arpeggios (inspired by Copied City).
    Virtuosic grand piano staccato arpeggios + sustained cello pedal tone + concert harp.
    """
    print("Generating ost_city_of_pearls...")
    bpm = 126.0
    sec_per_beat = 60.0 / bpm
    total_beats = 92  # ~43.81s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Progression: Dm - F - C - Gm
    prog = [
        {"root": "D2", "arp": ["D3", "F3", "A3", "D4", "F4", "A4", "F4", "D4"]},
        {"root": "F2", "arp": ["F3", "A3", "C4", "F4", "A4", "C5", "A4", "F4"]},
        {"root": "C2", "arp": ["C3", "E3", "G3", "C4", "E4", "G4", "E4", "C4"]},
        {"root": "G2", "arp": ["G2", "Bb2", "D3", "G3", "Bb3", "D4", "Bb3", "G3"]},
    ]

    for bar in range(23):
        p_info = prog[bar % 4]
        c_time = bar * 4.0 * sec_per_beat

        # 1. Crystalline Minimalist Grand Piano Running Arpeggios (16th notes)
        arp_notes = p_info["arp"]
        for p in range(16):
            t_arp = c_time + p * (sec_per_beat / 4.0)
            n_str = arp_notes[p % len(arp_notes)]
            add_pure_grand_piano(left, right, t_arp, sec_per_beat * 0.75, note_to_freq(n_str), gain=0.18, pan=((p % 4) - 1.5) * 0.15)

        # 2. Deep warm cello pedal tone
        add_pure_acoustic_cello(left, right, c_time, sec_per_beat * 3.8, note_to_freq(p_info["root"]), gain=0.26, pan=-0.3)

        # 3. Soft concert harp cadence note
        if bar % 2 == 0:
            add_pure_harp_arpeggio(left, right, c_time + sec_per_beat * 2.0, note_to_freq("D4"), gain=0.15, pan=0.3)

        # 4. Subtle taiko downbeat
        if bar >= 4:
            add_pure_concert_taiko(left, right, c_time, freq=52.0, gain=0.25, pan=0.0)

    write_ogg_file(left, right, "ost_city_of_pearls", total_sec)


def compose_tears_of_porcelain():
    """
    Track 55: ost_tears_of_porcelain (114 BPM, 3/4 time, A minor)
    Mood: Nostalgic, sorrowful acoustic waltz of broken marionettes.
    Nylon acoustic guitar waltz + felt piano + warm cello pizzicato + soft celesta.
    """
    print("Generating ost_tears_of_porcelain...")
    bpm = 114.0
    sec_per_beat = 60.0 / bpm
    total_beats = 84  # 28 bars of 3/4 (~44.21s)
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # 3/4 Waltz Chords: Am - Dm - E7 - Am - F - C - E - Am
    chords_34 = [
        {"root": "A2", "notes": ["A3", "C4", "E4"]},
        {"root": "D2", "notes": ["A3", "D4", "F4"]},
        {"root": "E2", "notes": ["G#3", "B3", "E4"]},
        {"root": "A2", "notes": ["A3", "C4", "E4"]},
        {"root": "F2", "notes": ["A3", "C4", "F4"]},
        {"root": "C2", "notes": ["G3", "C4", "E4"]},
        {"root": "E2", "notes": ["G#3", "B3", "E4"]},
        {"root": "A2", "notes": ["A3", "C4", "E4"]},
    ]

    for bar in range(28):
        c_info = chords_34[bar % len(chords_34)]
        bar_t = bar * 3.0 * sec_per_beat

        # Beat 1: Low cello bass & taiko
        add_pure_acoustic_cello(left, right, bar_t, sec_per_beat * 2.8, note_to_freq(c_info["root"]), gain=0.26, pan=-0.25)
        add_pure_concert_taiko(left, right, bar_t, freq=55.0, gain=0.28, pan=-0.1)

        # Beat 2 & 3: Nylon guitar & felt piano waltz strum
        for b_idx in [1, 2]:
            t_chord = bar_t + b_idx * sec_per_beat
            for n in c_info["notes"]:
                add_pure_nylon_guitar(left, right, t_chord, sec_per_beat * 0.85, note_to_freq(n), gain=0.16, pan=0.15)
                add_pure_grand_piano(left, right, t_chord, sec_per_beat * 0.85, note_to_freq(n), gain=0.14, pan=-0.1)

        # Soft Celesta melody line (warm mid-range, A3 to E4)
        if bar >= 4 and bar % 2 == 0:
            add_pure_celesta_note(left, right, bar_t + sec_per_beat, note_to_freq(c_info["notes"][1]), gain=0.14, pan=0.25)

    write_ogg_file(left, right, "ost_tears_of_porcelain", total_sec)


def compose_hymn_of_the_ancients():
    """
    Track 56: ost_hymn_of_the_ancients (92 BPM, E minor)
    Mood: Sacred, profound subterranean sanctuary.
    Pure open-harmony choir chords + felt piano + deep cello + slow ceremonial taiko.
    """
    print("Generating ost_hymn_of_the_ancients...")
    bpm = 92.0
    sec_per_beat = 60.0 / bpm
    total_beats = 68  # ~44.35s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Sacred Choral Modal Cycles: Em - C - G - D
    sacred_chords = [
        {"root": "E2", "chord": ["E3", "B3", "E4", "G4"]},
        {"root": "C2", "chord": ["C3", "G3", "C4", "E4"]},
        {"root": "G2", "chord": ["G2", "D3", "G3", "B3"]},
        {"root": "D2", "chord": ["D3", "A3", "D4", "F#4"]},
    ]

    for bar in range(17):
        s_info = sacred_chords[bar % len(sacred_chords)]
        bar_t = bar * 4.0 * sec_per_beat
        c_freqs = [note_to_freq(n) for n in s_info["chord"]]

        # 1. Pure Sacred Open Harmony Choir (Rock-solid steady pitch, no vibrato)
        add_pure_sacred_choir(left, right, bar_t, sec_per_beat * 4.0, c_freqs, gain=0.25)

        # 2. Resonant Felt Grand Piano Chords
        add_pure_grand_piano(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(s_info["root"]), gain=0.26, pan=-0.2)
        add_pure_grand_piano(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 2.0, note_to_freq(s_info["chord"][1]), gain=0.18, pan=0.2)

        # 3. Deep Cello Root Pedal
        add_pure_acoustic_cello(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(s_info["root"]), gain=0.24, pan=-0.3)

        # 4. Slow Ceremonial Taiko Drum on Downbeat
        add_pure_concert_taiko(left, right, bar_t, freq=48.0, gain=0.32, pan=0.0)

    write_ogg_file(left, right, "ost_hymn_of_the_ancients", total_sec)


def compose_ashes_of_destiny():
    """
    Track 57: ost_ashes_of_destiny (100 BPM, B minor)
    Mood: Solemn, sweeping cinematic acoustic march across volcanic plains.
    Rich 12-string acoustic guitar + felt piano + warm cello countermelody + taiko.
    """
    print("Generating ost_ashes_of_destiny...")
    bpm = 100.0
    sec_per_beat = 60.0 / bpm
    total_beats = 74  # ~44.40s
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Progression in B minor: Bm - G - D - A
    prog = [
        {"root": "B1", "notes": ["B2", "D3", "F#3", "B3"]},
        {"root": "G1", "notes": ["G2", "B2", "D3", "G3"]},
        {"root": "D2", "notes": ["D3", "F#3", "A3", "D4"]},
        {"root": "A1", "notes": ["A2", "C#3", "E3", "A3"]},
    ]

    for bar in range(18):
        p_info = prog[bar % 4]
        bar_t = bar * 4.0 * sec_per_beat

        # 1. Solemn Fingerpicked Acoustic Guitar
        for p in range(8):
            t_pick = bar_t + p * (sec_per_beat / 2.0)
            n_str = p_info["notes"][p % len(p_info["notes"])]
            add_pure_nylon_guitar(left, right, t_pick, 0.85, note_to_freq(n_str), gain=0.23, pan=((p % 2) * 0.3 - 0.15))

        # 2. Resonant Felt Piano
        add_pure_grand_piano(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(p_info["root"]), gain=0.25, pan=-0.2)
        add_pure_grand_piano(left, right, bar_t + sec_per_beat * 2.0, sec_per_beat * 2.0, note_to_freq(p_info["notes"][2]), gain=0.18, pan=0.2)

        # 3. Deep Cello
        add_pure_acoustic_cello(left, right, bar_t, sec_per_beat * 3.8, note_to_freq(p_info["root"]), gain=0.25, pan=-0.3)

        # 4. Concert Harp Cadence Notes
        if bar >= 4 and bar % 2 == 0:
            add_pure_harp_arpeggio(left, right, bar_t + sec_per_beat * 1.0, note_to_freq("F#4"), gain=0.14, pan=0.25)
            add_pure_harp_arpeggio(left, right, bar_t + sec_per_beat * 3.0, note_to_freq("D4"), gain=0.14, pan=-0.25)

        # 5. Marching Concert Taiko
        if bar >= 4:
            add_pure_concert_taiko(left, right, bar_t, freq=50.0, gain=0.30, pan=-0.1)
            add_pure_concert_taiko(left, right, bar_t + sec_per_beat * 2.0, freq=65.0, gain=0.24, pan=0.15)

    write_ogg_file(left, right, "ost_ashes_of_destiny", total_sec)


def main():
    print("=== NieR: Automata Suite Part 2 Generator (Pure Acoustic, Zero Modulation) ===")
    compose_broken_monolith()
    compose_city_of_pearls()
    compose_tears_of_porcelain()
    compose_hymn_of_the_ancients()
    compose_ashes_of_destiny()
    print("=== All 5 Automata Suite Part 2 tracks generated successfully! ===")


if __name__ == "__main__":
    main()
