#!/usr/bin/env python3
"""
generate_hyori_ittai.py — Epic Sung Vocal Anthem inspired by "Hyori Ittai" (Hunter x Hunter Ending).
154 BPM, D minor / F major, furious 12-string acoustic guitar strumming, soaring strings,
heavy orchestral brass stabs, driving rock/taiko percussion, and passionate dual-vocal harmony.

100% Organic, Warm, Cinematic Sound.
ABSOLUTELY ZERO PITCH MODULATION / LFO / VIBRATO (Rock-Solid Pitch Stability).
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


def apply_warm_lowpass(samples, cutoff_hz=3400.0):
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    val = 0.0
    for i, s in enumerate(samples):
        val += alpha * (s - val)
        out[i] = val
    return out


# =============================================================================
# PHYSICAL ACOUSTIC & VOCAL ENGINES (ZERO PITCH MODULATION / LFO)
# =============================================================================

def add_acoustic_strum(left, right, start_s, dur_s, chord_freqs, gain=0.22, is_down=True):
    """
    Furious 12-string acoustic guitar strumming (Yuzu folk-rock signature).
    Strum spread 15ms across strings. Warm wooden soundboard resonance.
    """
    num_strings = len(chord_freqs)
    strum_span = 0.015
    for s_idx, freq_item in enumerate(chord_freqs):
        freq = note_to_freq(freq_item) if isinstance(freq_item, str) else freq_item
        offset = (s_idx / max(1, num_strings - 1)) * strum_span if is_down else ((num_strings - 1 - s_idx) / max(1, num_strings - 1)) * strum_span
        start_idx = int((start_s + offset) * SAMPLE_RATE)
        num_samples = int(dur_s * SAMPLE_RATE)
        pan = -0.25 + (s_idx / max(1, num_strings - 1)) * 0.5
        l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
        r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

        for i in range(num_samples):
            idx = start_idx + i
            if idx >= len(left):
                break
            t = i / SAMPLE_RATE
            env = math.exp(-t * 4.8) if t > 0.005 else (t / 0.005)
            h1 = math.sin(2.0 * math.pi * freq * t)
            h2 = 0.32 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 6.5)
            h3 = 0.12 * math.sin(2.0 * math.pi * 3.0 * freq * t) * math.exp(-t * 10.0)
            # 12-string octave sparkle
            h_oct = 0.15 * math.sin(2.0 * math.pi * 2.0 * freq * t) if freq < 300.0 else 0.0
            sig = (h1 + h2 + h3 + h_oct) * (gain / math.sqrt(num_strings)) * env
            left[idx] += sig * l_pan
            right[idx] += sig * r_pan


def add_soaring_violin(left, right, start_s, dur_s, freq, gain=0.20, pan=0.2):
    """Dramatic soaring violin melody / countermelody. 100% steady pitch (ZERO vibrato)."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.05) * min(1.0, (dur_s - t) / 0.08)
        v1 = math.sin(2.0 * math.pi * freq * t)
        v2 = 0.28 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        v3 = 0.08 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        v4 = 0.03 * math.sin(2.0 * math.pi * 4.0 * freq * t)
        sig = (v1 + v2 + v3 + v4) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_orchestral_brass_stab(left, right, start_s, dur_s, chord_freqs, gain=0.24, pan=0.0):
    """Epic French Horn & Trombone orchestral power stab."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.02) * math.exp(-t * 2.8)
        sig_c = 0.0
        for f in chord_freqs:
            b1 = math.sin(2.0 * math.pi * f * t)
            b2 = 0.40 * math.sin(2.0 * math.pi * 2.0 * f * t)
            b3 = 0.15 * math.sin(2.0 * math.pi * 3.0 * f * t)
            sig_c += (b1 + b2 + b3)
        sig = (sig_c / len(chord_freqs)) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_punchy_bass(left, right, start_s, dur_s, freq, gain=0.28, pan=-0.15):
    """Punchy shonen rock bassline. Low-end drive and tight body."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 4.0) if t > 0.008 else (t / 0.008)
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.38 * math.sin(2.0 * math.pi * 2.0 * freq * t) * math.exp(-t * 6.0)
        body = 0.18 * math.sin(2.0 * math.pi * 88.0 * t) * math.exp(-t * 8.0)
        sig = (b1 + b2 + body) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


def add_rock_kick(left, right, start_s, gain=0.34):
    """Punchy rock kick drum downbeat."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.35 * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        f = 54.0 * (1.0 + 0.35 * math.exp(-t * 40.0))
        env = math.exp(-t * 9.0)
        sig = math.sin(2.0 * math.pi * f * t) * gain * env
        left[idx] += sig
        right[idx] += sig


def add_rock_snare(left, right, start_s, gain=0.28):
    """Snappy acoustic snare strike with wooden rim crack."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.28 * SAMPLE_RATE)
    rng = random.Random(int(start_s * 1000))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        # Body tone at 195 Hz + crisp noise snap
        body = math.sin(2.0 * math.pi * 195.0 * t) * math.exp(-t * 18.0)
        noise = (rng.random() * 2.0 - 1.0) * math.exp(-t * 24.0)
        sig = (body * 0.6 + noise * 0.7) * gain
        left[idx] += sig
        right[idx] += sig


def add_crash_cymbal(left, right, start_s, gain=0.20):
    """Bright acoustic crash cymbal at major phrase downbeats."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.8 * SAMPLE_RATE)
    rng = random.Random(int(start_s * 777))
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2.5) if t > 0.005 else (t / 0.005)
        # Metallic shimmer frequencies
        m1 = math.sin(2.0 * math.pi * 1420.0 * t)
        m2 = math.sin(2.0 * math.pi * 2150.0 * t)
        noise = rng.random() * 2.0 - 1.0
        sig = (noise * 0.6 + (m1 + m2) * 0.2) * gain * env
        left[idx] += sig * 0.8
        right[idx] += sig * 1.0


def add_shonen_vocal_syllable(left, right, start_s, dur_s, freq, vowel="a", gain=0.25, pan=0.0):
    """
    Passionate Japanese Shonen anime vocal chant (Yuzu Hyori Ittai style).
    Lead tenor voice. Rock-solid pitch (ZERO vibrato/LFO), rich acoustic vocal formants.
    """
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    # Formant frequencies for shonen tenor
    vowel_formants = {
        "a": (800.0, 1250.0, 2600.0),
        "o": (500.0, 900.0, 2400.0),
        "e": (550.0, 1850.0, 2600.0),
        "i": (320.0, 2200.0, 2900.0),
        "u": (350.0, 800.0, 2300.0),
    }
    f1, f2, f3 = vowel_formants.get(vowel.lower(), (800.0, 1250.0, 2600.0))

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        # Envelope: punchy vocal onset with natural breath tail
        env = min(1.0, t / 0.035) * min(1.0, (dur_s - t) / 0.05)
        # Rock-solid steady fundamental and warm harmonic series
        h1 = math.sin(2.0 * math.pi * freq * t)
        h2 = 0.50 * math.sin(2.0 * math.pi * 2.0 * freq * t)
        h3 = 0.30 * math.sin(2.0 * math.pi * 3.0 * freq * t)
        h4 = 0.15 * math.sin(2.0 * math.pi * 4.0 * freq * t)

        # Formant resonance coloring
        formant = (
            0.35 * math.sin(2.0 * math.pi * f1 * t) +
            0.20 * math.sin(2.0 * math.pi * f2 * t) +
            0.10 * math.sin(2.0 * math.pi * f3 * t)
        ) * math.exp(-((t * 8.0) % 1.0) * 2.0)

        sig = (h1 + h2 + h3 + h4 + formant * 0.35) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


# =============================================================================
# HYORI ITTAI COMPOSITION (154 BPM, D MINOR / F MAJOR)
# =============================================================================

def compose_hyori_ittai():
    print("Generating ost_hyori_ittai_vocal...")
    bpm = 154.0
    sec_per_beat = 60.0 / bpm
    # 28 bars of 4/4 at 154 BPM = 112 beats (~43.64s) or 29 bars = 116 beats (~45.19s)
    total_beats = 116
    total_sec = total_beats * sec_per_beat
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Hyori Ittai Structure:
    # Part A: Dramatic Verse (Bars 0-11) in D minor
    # Part B: Soaring Chorus Explosion (Bars 12-28) in F major / D minor
    verse_chords = [
        {"root": "D2", "guitar": ["D3", "A3", "D4", "F4", "A4"], "brass": ["D3", "F3", "A3"]},   # Dm
        {"root": "Bb1", "guitar": ["Bb2", "F3", "Bb3", "D4", "F4"], "brass": ["Bb2", "D3", "F3"]}, # Bb
        {"root": "C2", "guitar": ["C3", "G3", "C4", "E4", "G4"], "brass": ["C3", "E3", "G3"]},   # C
        {"root": "F1", "guitar": ["F2", "C3", "F3", "A3", "C4"], "brass": ["F2", "A2", "C3"]},   # F
        {"root": "C2", "guitar": ["E2", "G2", "C3", "E3", "G3"], "brass": ["E2", "G2", "C3"]},   # C/E
        {"root": "D2", "guitar": ["D3", "A3", "D4", "F4", "A4"], "brass": ["D3", "F3", "A3"]},   # Dm
        {"root": "G1", "guitar": ["G2", "D3", "G3", "Bb3", "D4"], "brass": ["G2", "Bb2", "D3"]}, # Gm
        {"root": "A1", "guitar": ["A2", "E3", "A3", "C#4", "E4"], "brass": ["A2", "C#3", "E3"]}, # A7
    ]

    chorus_chords = [
        {"root": "Bb1", "guitar": ["Bb2", "F3", "Bb3", "D4", "F4"], "brass": ["Bb2", "D3", "F3"]}, # Bb
        {"root": "C2", "guitar": ["C3", "G3", "C4", "E4", "G4"], "brass": ["C3", "E3", "G3"]},   # C
        {"root": "A1", "guitar": ["A2", "E3", "A3", "C4", "E4"], "brass": ["A2", "C3", "E3"]},   # Am
        {"root": "D2", "guitar": ["D3", "A3", "D4", "F4", "A4"], "brass": ["D3", "F3", "A3"]},   # Dm
        {"root": "G1", "guitar": ["G2", "D3", "G3", "Bb3", "D4"], "brass": ["G2", "Bb2", "D3"]}, # Gm
        {"root": "A1", "guitar": ["A2", "E3", "A3", "C#4", "E4"], "brass": ["A2", "C#3", "E3"]}, # A7
        {"root": "D2", "guitar": ["D3", "A3", "D4", "F4", "A4"], "brass": ["D3", "F3", "A3"]},   # Dm
        {"root": "D2", "guitar": ["D3", "A3", "D4", "F4", "A4"], "brass": ["D3", "F3", "A3"]},   # Dm
    ]

    # Vocal melody lines (Hyori Ittai motif):
    # Verse: D4 - F4 - E4 - D4 - C4 - D4 - F4 - E4
    verse_melody = [
        ("D4", "a", 0.75), ("F4", "o", 0.75), ("E4", "e", 0.75), ("D4", "a", 0.75),
        ("C4", "i", 0.75), ("D4", "a", 0.75), ("F4", "o", 0.75), ("E4", "e", 1.2),
    ]
    # Chorus: F4 - G4 - A4 - A4 - G4 - F4 - E4 - D4 - F4 - E4 - D4
    chorus_melody = [
        ("F4", "o", 0.6), ("G4", "e", 0.6), ("A4", "a", 0.9), ("A4", "i", 0.6),
        ("G4", "o", 0.6), ("F4", "a", 0.6), ("E4", "e", 0.6), ("D4", "a", 0.9),
        ("G4", "o", 0.6), ("F4", "a", 0.6), ("E4", "e", 0.6), ("D4", "a", 1.4),
    ]

    for bar in range(29):
        is_chorus = (bar >= 12)
        bar_t = bar * 4.0 * sec_per_beat
        c_list = chorus_chords if is_chorus else verse_chords
        c_info = c_list[bar % len(c_list)]

        # 1. Crash Cymbal on section start and major turns (bars 0, 12, 20)
        if bar in [0, 12, 20]:
            add_crash_cymbal(left, right, bar_t, gain=0.24)

        # 2. Driving Rock / Taiko Drum Groove
        for b in range(4):
            t_beat = bar_t + b * sec_per_beat
            # Kick on beats 1 and 3 (plus syncopated 3.5 in chorus)
            if b in [0, 2]:
                add_rock_kick(left, right, t_beat, gain=0.32)
            if is_chorus and b == 2:
                add_rock_kick(left, right, t_beat + sec_per_beat * 0.5, gain=0.26)
            # Snappy Snare on beats 2 and 4
            if b in [1, 3]:
                add_rock_snare(left, right, t_beat, gain=0.28)

        # 3. Furious 12-String Acoustic Guitar Strumming (16th notes: 16 strums per bar)
        for s in range(16):
            t_strum = bar_t + s * (sec_per_beat / 4.0)
            is_down = (s % 2 == 0)
            g_gain = 0.24 if (s % 4 == 0) else 0.16
            add_acoustic_strum(left, right, t_strum, sec_per_beat * 0.6, c_info["guitar"], gain=g_gain, is_down=is_down)

        # 4. Driving Walking Bassline
        for b in range(4):
            t_b = bar_t + b * sec_per_beat
            b_freq = note_to_freq(c_info["root"])
            # Octave step on beat 3
            if b == 2:
                b_freq *= 2.0
            add_punchy_bass(left, right, t_b, sec_per_beat * 0.9, b_freq, gain=0.28)

        # 5. Epic Orchestral Brass Stabs (bars 0, 4, 8, 12, 16, 20, 24)
        if bar % 2 == 0:
            b_freqs = [note_to_freq(n) for n in c_info["brass"]]
            add_orchestral_brass_stab(left, right, bar_t, sec_per_beat * 1.8, b_freqs, gain=0.26, pan=0.0)

        # 6. Soaring Violin Countermelody
        for p in range(4):
            t_v = bar_t + p * sec_per_beat
            v_note = c_info["guitar"][p % len(c_info["guitar"])]
            add_soaring_violin(left, right, t_v, sec_per_beat * 0.85, note_to_freq(v_note), gain=0.18, pan=0.25)

        # 7. SUNG VOCAL ANTHEM (Lead Tenor + 2nd Voice Harmony)
        if bar >= 2:
            m_list = chorus_melody if is_chorus else verse_melody
            m_entry = m_list[(bar * 2) % len(m_list)]
            lead_pitch = note_to_freq(m_entry[0])
            # Lead vocal
            add_shonen_vocal_syllable(left, right, bar_t, m_entry[2], lead_pitch, vowel=m_entry[1], gain=0.28, pan=0.0)
            # Second vocal harmony (in major/minor 3rd or 5th)
            harm_pitch = lead_pitch * 1.5  # Perfect fifth
            add_shonen_vocal_syllable(left, right, bar_t, m_entry[2], harm_pitch, vowel=m_entry[1], gain=0.18, pan=-0.2)

            # Second syllable on beat 2.5
            m_entry2 = m_list[(bar * 2 + 1) % len(m_list)]
            lead_pitch2 = note_to_freq(m_entry2[0])
            add_shonen_vocal_syllable(left, right, bar_t + sec_per_beat * 2.0, m_entry2[2], lead_pitch2, vowel=m_entry2[1], gain=0.28, pan=0.0)
            add_shonen_vocal_syllable(left, right, bar_t + sec_per_beat * 2.0, m_entry2[2], lead_pitch2 * 1.5, vowel=m_entry2[1], gain=0.18, pan=0.2)

    # Crossfade & export
    total_samples = len(left)
    left = apply_warm_lowpass(left, cutoff_hz=3400.0)
    right = apply_warm_lowpass(right, cutoff_hz=3400.0)

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

    wav_path = "/tmp/ost_hyori_ittai_vocal.wav"
    ogg_path = os.path.join(OUT_DIR, "ost_hyori_ittai_vocal.ogg")

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
    print(f"  [OK] Generated ost_hyori_ittai_vocal.ogg ({total_sec:.1f}s, {sz_kb:.1f} KB)")


if __name__ == "__main__":
    compose_hyori_ittai()
