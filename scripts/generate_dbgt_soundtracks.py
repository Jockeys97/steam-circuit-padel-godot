#!/usr/bin/env python3
"""
generate_dbgt_soundtracks.py — 5 COMPLETELY DISTINCT Dragon Ball GT Inspired OSTs.
Captures the nostalgic, melodic 90s Anime J-Pop / J-Rock sound of DBGT:

1. ost_dbgt_dan_dan_vocal: SUNG VOCAL ANTHEM (132 BPM, C maj) - The legendary "DAN DAN Kokoro Hikareteku"
   sung with real melodic notes, DX7 Rhodes piano, acoustic 16th strums, and brass stabs!
2. ost_dbgt_dont_you_see_vocal: SUNG VOCAL BALLAD (118 BPM, E maj) - Nostalgic ZARD-style J-Rock ballad
   with emotional vocal melodies, fretless bass, and soaring guitar leads.
3. ost_dbgt_grand_tour: INSTRUMENTAL SYNTH-ROCK (140 BPM, D maj) - Cosmic spaceship journey with Dragon Radar pulses.
4. ost_dbgt_super_saiyan_4: INSTRUMENTAL SYMPHONIC METAL & SHAKUHACHI (156 BPM, D min) - Primal Golden Ape awakening.
5. ost_dbgt_sabitsuita_machine_gun: INSTRUMENTAL 90s POP-PUNK (168 BPM, G maj) - Fast, energetic WANDS-style anime ending.

All tracks feature 45.0s duration and continuous looping crossfade!
"""

import os
import math
import struct
import subprocess
import random

SAMPLE_RATE = 44100
OUT_DIR = "godot/assets/audio/music"
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


def write_ogg_file(left, right, track_id, total_sec):
    """Applies seamless looping crossfade (0.18s), soft limiter, and exports to Ogg Vorbis."""
    total_samples = len(left)
    loop_fade = int(0.18 * SAMPLE_RATE)
    
    # Seamless loop envelope: blend tail into head so wrap-around has 0 click
    for i in range(loop_fade):
        frac = i / loop_fade
        left[i] = left[i] * frac + left[total_samples - loop_fade + i] * (1.0 - frac)
        right[i] = right[i] * frac + right[total_samples - loop_fade + i] * (1.0 - frac)
        left[total_samples - loop_fade + i] = left[i]
        right[total_samples - loop_fade + i] = right[i]

    # Normalization & soft saturation
    max_val = max(max(abs(x) for x in left), max(abs(x) for x in right), 0.001)
    norm_factor = 0.92 / max_val
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


def read_wav_mono(path):
    if not os.path.exists(path):
        return []
    with open(path, 'rb') as f:
        data = f.read()
    d_idx = data.find(b'data')
    if d_idx == -1:
        return []
    d_len = struct.unpack_from('<I', data, d_idx + 4)[0]
    raw_samples = data[d_idx + 8 : d_idx + 8 + d_len]
    n_samples = len(raw_samples) // 2
    return [struct.unpack_from('<h', raw_samples, i * 2)[0] / 32768.0 for i in range(n_samples)]


def get_vocal_phrase(name: str, voice: str, rate: int, text: str, semitones: int = 0):
    """Generates speech vocal performance with pitch adjustment."""
    raw_path = f"/tmp/vox_{name}.wav"
    cmd = ["say", "-v", voice, "-r", str(rate), "--data-format=LEI16@44100", "-o", raw_path, text]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    if semitones == 0:
        return read_wav_mono(raw_path)

    out_path = f"/tmp/vox_{name}_p{semitones}.wav"
    factor = 2.0 ** (semitones / 12.0)
    new_rate = int(44100 * factor)
    tempo = 1.0 / factor
    cmd_shift = [
        FFMPEG_BIN, "-y", "-i", raw_path,
        "-af", f"asetrate={new_rate},atempo={tempo}",
        "-ar", "44100", out_path
    ]
    subprocess.run(cmd_shift, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return read_wav_mono(out_path)


def mix_vocal_phrase(left, right, vocal_samples, start_s, gain=0.48, pan=0.0, drive=1.35, delay_send=0.30):
    """Mixes a vocal performance with warm analog drive, stereo panning, and studio stereo delay."""
    if not vocal_samples:
        return
    start_idx = int(start_s * SAMPLE_RATE)
    delay_samples = int(0.228 * SAMPLE_RATE) # 8th note delay at 132 BPM
    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i, s in enumerate(vocal_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        driven = math.tanh(s * drive) * gain
        left[idx] += driven * l_pan
        right[idx] += driven * r_pan

        d_idx = idx + delay_samples
        if d_idx < len(left):
            left[d_idx] += driven * delay_send * r_pan
            right[d_idx] += driven * delay_send * l_pan


# =============================================================================
# MELODIC SINGING SYNTHESIS (REAL PITCHED MUSICAL NOTES WITH VIBRATO)
# =============================================================================

def add_sung_melody_note(left, right, start_s, dur_s, freq, vowel="ah", gain=0.28, pan=0.0):
    """
    Synthesizes a pure melodic singing note on an exact musical frequency.
    Features:
    - 5.2 Hz vocal vibrato
    - Human formant resonance filters (open J-Pop vocal timbre)
    - Smooth vocal attack and decay envelope
    """
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    formants = [(800, 90, 1.0), (1250, 110, 0.6), (2700, 140, 0.35), (3500, 180, 0.15)]
    filters = []
    for f_c, bw, a in formants:
        r = math.exp(-math.pi * bw / SAMPLE_RATE)
        theta = 2.0 * math.pi * f_c / SAMPLE_RATE
        a1 = -2.0 * r * math.cos(theta)
        a2 = r * r
        b0 = (1.0 - r) * math.sin(theta) * a
        filters.append({"a1": a1, "a2": a2, "b0": b0, "y1": 0.0, "y2": 0.0})

    l_pan = math.cos((pan + 1.0) * math.pi * 0.25)
    r_pan = math.sin((pan + 1.0) * math.pi * 0.25)

    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.06) * min(1.0, (dur_s - t) / 0.08)
        vib = 0.022 * min(1.0, max(0.0, (t - 0.08) / 0.18)) * math.sin(2.0 * math.pi * 5.2 * t)
        cur_f = freq * (1.0 + vib)
        phase = (t * cur_f) % 1.0
        glottal = math.sin(math.pi * phase / 0.6) ** 2 if phase < 0.6 else -0.3 * math.exp(-(phase - 0.6) * 10.0)
        breath = (random.random() * 2.0 - 1.0) * 0.05

        vox = 0.0
        for flt in filters:
            y = flt["b0"] * (glottal + breath) - flt["a1"] * flt["y1"] - flt["a2"] * flt["y2"]
            flt["y2"] = flt["y1"]
            flt["y1"] = y
            vox += y

        sig = math.tanh(vox * 1.6) * gain * env
        left[idx] += sig * l_pan
        right[idx] += sig * r_pan


# =============================================================================
# 90s J-POP / J-ROCK INSTRUMENT ENGINES
# =============================================================================

def add_dx7_rhodes_piano(left, right, start_s, dur_s, freq, gain=0.22):
    """Classic 90s Yamaha DX7 / Rhodes electric piano with crystalline bell FM sparkle."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 2.8) if t > 0.005 else (t / 0.005)
        # FM modulation index decays faster for bright bell chime
        bell_mod = math.sin(2.0 * math.pi * freq * 14.0 * t) * math.exp(-t * 12.0) * 1.8
        mod2 = math.sin(2.0 * math.pi * freq * 1.0 * t) * math.exp(-t * 3.5) * 0.5
        carrier = math.sin(2.0 * math.pi * freq * t + bell_mod + mod2)
        warmth = math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.35 * math.exp(-t * 4.0)
        sig = (carrier * 0.75 + warmth) * gain * env
        left[idx] += sig
        right[idx] += sig * 0.95


def add_acoustic_strum(left, right, start_s, dur_s, chord_freqs, gain=0.20):
    """16th-note steel-string acoustic guitar strum with staggered string picking."""
    for str_idx, freq in enumerate(chord_freqs):
        s_time = start_s + str_idx * 0.012 # 12ms rake across strings
        start_idx = int(s_time * SAMPLE_RATE)
        num_samples = int(dur_s * SAMPLE_RATE)
        for i in range(num_samples):
            idx = start_idx + i
            if idx >= len(left):
                break
            t = i / SAMPLE_RATE
            env = math.exp(-t * 7.5) if t > 0.004 else (t / 0.004)
            pick = (random.random() * 2.0 - 1.0) * math.exp(-t * 180.0) * 0.35
            h1 = math.sin(2.0 * math.pi * freq * t)
            h2 = math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.4
            h3 = math.sin(2.0 * math.pi * freq * 3.0 * t) * 0.2
            sig = (h1 + h2 + h3 + pick) * gain * env
            left[idx] += sig * 0.95
            right[idx] += sig * 1.05


def add_jpop_lead_guitar(left, right, start_s, dur_s, freq, gain=0.24, vibrato=True):
    """Singing 90s J-Pop melodic electric guitar with warm tube overdrive and chorus."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.03) * min(1.0, (dur_s - t) / 0.06)
        vib = 0.015 * math.sin(2.0 * math.pi * 5.5 * t) if (vibrato and t > 0.12) else 0.0
        f = freq * (1.0 + vib)
        saw1 = 2.0 * ((t * f) % 1.0) - 1.0
        saw2 = 2.0 * ((t * f * 1.0025 + 0.1) % 1.0) - 1.0 # Chorus detune
        raw = saw1 * 0.55 + saw2 * 0.45
        driven = math.tanh(raw * 2.8) * gain * env
        left[idx] += driven * 0.92
        right[idx] += driven * 1.04


def add_jpop_brass_stab(left, right, start_s, dur_s, freq, gain=0.26):
    """Punchy 90s brass section stab (trumpet/sax) with bright bite."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.025) * min(1.0, (dur_s - t) / 0.04)
        b1 = math.sin(2.0 * math.pi * freq * t)
        b2 = 0.65 * math.sin(2.0 * math.pi * freq * 2.0 * t)
        b3 = 0.4 * math.sin(2.0 * math.pi * freq * 3.0 * t)
        b4 = 0.25 * math.sin(2.0 * math.pi * freq * 4.0 * t)
        sig = math.tanh((b1 + b2 + b3 + b4) * 1.8) * gain * env
        left[idx] += sig
        right[idx] += sig * 0.98


def add_melodic_pop_bass(left, right, start_s, dur_s, freq, gain=0.30):
    """Warm melodic 90s J-Pop electric fingerstyle bass with round low-end."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 4.5) if t > 0.01 else (t / 0.01)
        sub = math.sin(2.0 * math.pi * freq * t) * 0.75
        harm2 = math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.35
        pluck = math.sin(2.0 * math.pi * 450.0 * t) * math.exp(-t * 60.0) * 0.2
        sig = (sub + harm2 + pluck) * gain * env
        left[idx] += sig
        right[idx] += sig


def add_shakuhachi_flute(left, right, start_s, dur_s, freq, gain=0.26):
    """Breathy Japanese bamboo flute (Shakuhachi) with organic vibrato and breath noise."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = min(1.0, t / 0.10) * min(1.0, (dur_s - t) / 0.12)
        vib = 0.028 * math.sin(2.0 * math.pi * 4.8 * t) if t > 0.15 else 0.0
        f = freq * (1.0 + vib)
        sine = math.sin(2.0 * math.pi * f * t)
        h2 = 0.3 * math.sin(2.0 * math.pi * f * 2.0 * t)
        breath = (random.random() * 2.0 - 1.0) * 0.18 * math.exp(-t * 1.5)
        sig = (sine + h2 + breath) * gain * env
        left[idx] += sig * 0.96
        right[idx] += sig * 1.04


def add_cosmic_synth_arp(left, right, start_s, dur_s, freq, gain=0.20):
    """Bright sparkling synth arpeggio for Grand Tour."""
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(dur_s * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 10.0) if t > 0.005 else (t / 0.005)
        saw = 2.0 * ((t * freq) % 1.0) - 1.0
        pulse = 1.0 if ((t * freq * 2.0) % 1.0) > 0.5 else -1.0
        sig = (saw * 0.6 + pulse * 0.4) * gain * env
        left[idx] += sig * 1.05
        right[idx] += sig * 0.95


def add_radar_beep(left, right, start_s, gain=0.18):
    """Iconic Dragon Radar double beep sound effect."""
    for dt, f in [(0.0, 1850.0), (0.12, 2450.0)]:
        start_idx = int((start_s + dt) * SAMPLE_RATE)
        num_samples = int(0.08 * SAMPLE_RATE)
        for i in range(num_samples):
            idx = start_idx + i
            if idx >= len(left):
                break
            t = i / SAMPLE_RATE
            sig = math.sin(2.0 * math.pi * f * t) * math.exp(-t * 35.0) * gain
            left[idx] += sig
            right[idx] += sig


def add_kick(left, right, start_s, gain=0.38):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.30 * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        f = 50.0 + 85.0 * math.exp(-t * 32.0)
        sig = math.sin(2.0 * math.pi * f * t) * math.exp(-t * 6.5) * gain
        left[idx] += sig
        right[idx] += sig


def add_snare(left, right, start_s, gain=0.30):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(0.25 * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        body = math.sin(2.0 * math.pi * 210.0 * t) * math.exp(-t * 25.0)
        noise = (random.random() * 2.0 - 1.0) * math.exp(-t * 14.0)
        sig = (body * 0.45 + noise * 0.55) * gain
        left[idx] += sig
        right[idx] += sig * 0.95


def add_hihat(left, right, start_s, gain=0.15, is_open=False):
    start_idx = int(start_s * SAMPLE_RATE)
    decay = 18.0 if is_open else 95.0
    num_samples = int((0.35 if is_open else 0.08) * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        n = (random.random() * 2.0 - 1.0) * math.exp(-t * decay)
        sig = n * gain
        left[idx] += sig * 0.9
        right[idx] += sig * 1.1


def add_crash(left, right, start_s, gain=0.35):
    start_idx = int(start_s * SAMPLE_RATE)
    num_samples = int(1.5 * SAMPLE_RATE)
    for i in range(num_samples):
        idx = start_idx + i
        if idx >= len(left):
            break
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.2)
        n = (random.random() * 2.0 - 1.0)
        sig = n * gain * env
        left[idx] += sig
        right[idx] += sig * 0.95


# =============================================================================
# 1. DAN DAN KOKORO HIKARETEKU (SUNG VOCAL J-POP ANTHEM)
# =============================================================================

def compose_dan_dan_vocal():
    """
    1. ost_dbgt_dan_dan_vocal (132 BPM, C major):
    THE SUNG J-POP / J-ROCK ANTHEM OF DRAGON BALL GT!
    - Melodic singing with pitched notes (G4, E4, D4, C4, A4)
    - Japanese lyrics: "Dan Dan kokoro hikarete 'ku... sono mabushii egao ni... zutto soba ni ite hoshii!"
    - Acoustic guitar 16th strumming, DX7 electric piano chords, punchy brass hits, melodic bass.
    - Seamless 45.0s loop crossfade!
    """
    total_sec = 45.0
    track_id = "ost_dbgt_dan_dan_vocal"
    print(f"  -> Composing 1/5: {track_id} (DAN DAN Kokoro Hikareteku - Sung Vocal Anthem)...")
    bpm = 132
    beat_sec = 60.0 / bpm
    bar_sec = beat_sec * 4.0
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    print("     [Vox] Synthesizing melodic singing lines (Kyoko J-Pop Lead & Harmonies)...")
    v_intro = get_vocal_phrase("dandan_intro", "Kyoko", 130, "だんだん心魅かれてく")
    v_verse1 = get_vocal_phrase("dandan_v1", "Kyoko", 140, "その眩しい笑顔に 果てない暗闇から飛び出そう")
    v_chorus = get_vocal_phrase("dandan_ch", "Kyoko", 135, "だんだん心魅かれてく この星の希望のかけら")
    v_chorus_harm = get_vocal_phrase("dandan_ch_h", "Kyoko", 135, "だんだん心魅かれてく この星の希望のかけら", semitones=7)
    v_call = get_vocal_phrase("dandan_call", "Kyoko", 140, "ずっとそばにいてほしい Hold my hand")
    v_climax = get_vocal_phrase("dandan_cli", "Kyoko", 138, "愛と勇気と誇りを持って 闘うよ")

    # INTRO (0:00 - 3.63s): Acapella singing lead + acoustic guitar chord + wind chimes
    add_dx7_rhodes_piano(left, right, 0.1, 3.2, note_to_freq("C4"), gain=0.25)
    add_acoustic_strum(left, right, 0.2, 2.5, [note_to_freq(n) for n in ["C3", "G3", "C4", "E4"]], gain=0.28)
    mix_vocal_phrase(left, right, v_intro, 0.4, gain=0.62, pan=0.0, drive=1.15, delay_send=0.35)
    # Melodic singing sustained notes backing
    add_sung_melody_note(left, right, 0.5, 0.9, note_to_freq("G4"), vowel="ah", gain=0.22)
    add_sung_melody_note(left, right, 1.4, 0.8, note_to_freq("E4"), vowel="oh", gain=0.20)
    add_sung_melody_note(left, right, 2.2, 1.2, note_to_freq("D4"), vowel="ee", gain=0.22)

    # Progression in C major: C - G - Am - F (Bars 2-10), F - G - Em - Am (Chorus Bars 10-18)
    chords_verse = [
        [note_to_freq(n) for n in ["C3", "G3", "C4", "E4"]],
        [note_to_freq(n) for n in ["G2", "D3", "G3", "B3"]],
        [note_to_freq(n) for n in ["A2", "E3", "A3", "C4"]],
        [note_to_freq(n) for n in ["F2", "C3", "F3", "A3"]]
    ]
    bass_roots = ["C2", "G1", "A1", "F1"]

    add_crash(left, right, 2.0 * bar_sec, gain=0.42)

    for bar in range(2, 25):
        b_time = bar * bar_sec
        if b_time >= total_sec:
            break
        chord = chords_verse[bar % 4]
        b_root = note_to_freq(bass_roots[bar % 4])

        # 90s Pop-Rock Drum groove
        add_kick(left, right, b_time, gain=0.40)
        add_kick(left, right, b_time + 2.0 * beat_sec, gain=0.38)
        add_kick(left, right, b_time + 2.75 * beat_sec, gain=0.30)
        add_snare(left, right, b_time + 1.0 * beat_sec, gain=0.32)
        add_snare(left, right, b_time + 3.0 * beat_sec, gain=0.32)
        for h in range(8):
            add_hihat(left, right, b_time + h * 0.5 * beat_sec, gain=0.14, is_open=(h == 4))

        # Acoustic guitar 16th strumming on every beat
        for beat in range(4):
            add_acoustic_strum(left, right, b_time + beat * beat_sec, beat_sec * 0.9, chord, gain=0.22)

        # DX7 Rhodes Piano chords on downbeat and upbeat
        add_dx7_rhodes_piano(left, right, b_time, beat_sec * 1.8, chord[2], gain=0.20)
        add_dx7_rhodes_piano(left, right, b_time + 1.5 * beat_sec, beat_sec * 1.5, chord[3], gain=0.18)

        # Melodic walking bass
        add_melodic_pop_bass(left, right, b_time, beat_sec * 0.8, b_root, gain=0.32)
        add_melodic_pop_bass(left, right, b_time + 1.5 * beat_sec, beat_sec * 0.5, b_root * 1.25, gain=0.26)
        add_melodic_pop_bass(left, right, b_time + 2.0 * beat_sec, beat_sec * 0.8, b_root, gain=0.32)
        add_melodic_pop_bass(left, right, b_time + 3.5 * beat_sec, beat_sec * 0.45, b_root * 1.5, gain=0.26)

        # J-Pop Brass stabs in the chorus (Bar 10 onward)
        if bar >= 10:
            add_jpop_brass_stab(left, right, b_time, beat_sec * 0.5, note_to_freq("G4"), gain=0.24)
            add_jpop_brass_stab(left, right, b_time + 2.0 * beat_sec, beat_sec * 0.5, note_to_freq("C5"), gain=0.24)

        # Electric guitar lead counterpoint
        if bar >= 6:
            lead_n = note_to_freq("E5") if bar % 2 == 0 else note_to_freq("G5")
            add_jpop_lead_guitar(left, right, b_time + 2.0 * beat_sec, beat_sec * 1.6, lead_n, gain=0.22)

    # SUNG VOCAL PERFORMANCE TIMELINE
    # Bar 2: Verse 1
    mix_vocal_phrase(left, right, v_verse1, 2.0 * bar_sec, gain=0.55, pan=-0.1, drive=1.2, delay_send=0.30)
    add_sung_melody_note(left, right, 2.0 * bar_sec, 2.0, note_to_freq("E4"), vowel="ah", gain=0.20)
    add_sung_melody_note(left, right, 4.0 * bar_sec, 2.5, note_to_freq("G4"), vowel="oh", gain=0.22)

    # Bar 8: Chorus Hook (DAN DAN KOKORO HIKARETEKU)
    mix_vocal_phrase(left, right, v_chorus, 8.0 * bar_sec, gain=0.58, pan=0.0, drive=1.25, delay_send=0.35)
    mix_vocal_phrase(left, right, v_chorus_harm, 8.0 * bar_sec, gain=0.42, pan=0.3, drive=1.2, delay_send=0.30)
    add_sung_melody_note(left, right, 8.0 * bar_sec, 1.2, note_to_freq("G4"), vowel="ah", gain=0.25)
    add_sung_melody_note(left, right, 8.0 * bar_sec + 1.2, 1.0, note_to_freq("A4"), vowel="oh", gain=0.25)
    add_sung_melody_note(left, right, 8.0 * bar_sec + 2.2, 1.5, note_to_freq("C5"), vowel="ee", gain=0.26)

    # Bar 14: Second half of chorus
    mix_vocal_phrase(left, right, v_call, 14.0 * bar_sec, gain=0.56, pan=-0.15, drive=1.2, delay_send=0.32)
    add_sung_melody_note(left, right, 14.0 * bar_sec, 2.0, note_to_freq("A4"), vowel="ah", gain=0.22)
    add_sung_melody_note(left, right, 16.0 * bar_sec, 2.0, note_to_freq("G4"), vowel="ee", gain=0.24)

    # Bar 18: Grand Climax
    mix_vocal_phrase(left, right, v_climax, 18.0 * bar_sec, gain=0.58, pan=0.0, drive=1.3, delay_send=0.35)
    add_sung_melody_note(left, right, 18.0 * bar_sec, 1.8, note_to_freq("C5"), vowel="ah", gain=0.26)
    add_sung_melody_note(left, right, 20.0 * bar_sec, 2.5, note_to_freq("D5"), vowel="oh", gain=0.26)

    write_ogg_file(left, right, track_id, total_sec)


# =============================================================================
# 2. DON'T YOU SEE! (SUNG J-ROCK NOSTALGIC BALLAD - ZARD STYLE)
# =============================================================================

def compose_dont_you_see_vocal():
    """
    2. ost_dbgt_dont_you_see_vocal (118 BPM, E major / C# minor):
    THE SUNG J-ROCK NOSTALGIC BALLAD (ZARD style)!
    - Intimate, emotional female vocal singing: "Don't you see! Kagayaku yume o shinjite itai..."
    - Rhodes electric piano chords, fretless bass, warm guitar leads.
    - Seamless 45.0s loop crossfade!
    """
    total_sec = 45.0
    track_id = "ost_dbgt_dont_you_see_vocal"
    print(f"  -> Composing 2/5: {track_id} (Don't You See! - Sung Vocal Ballad)...")
    bpm = 118
    beat_sec = 60.0 / bpm
    bar_sec = beat_sec * 4.0
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    print("     [Vox] Synthesizing nostalgic ballad singing lines...")
    v_intro = get_vocal_phrase("dys_intro", "Kyoko", 125, "Don't you see! 輝く夢を")
    v_verse = get_vocal_phrase("dys_verse", "Kyoko", 125, "信じていたい どんなに離れていても 心は繋がっている")
    v_chorus = get_vocal_phrase("dys_chorus", "Kyoko", 125, "Don't you see! あの雲を越えて 遠い空を探しに行くよ")
    v_chorus_h = get_vocal_phrase("dys_chorus_h", "Kyoko", 125, "Don't you see! あの雲を越えて 遠い空を探しに行くよ", semitones=7)
    v_outro = get_vocal_phrase("dys_outro", "Kyoko", 120, "Never let you go... いつまでも")

    # INTRO (0:00 - 4.07s, Bars 0-2): Rhodes electric piano + intimate sung vocal
    f_e3 = note_to_freq("E3")
    f_b3 = note_to_freq("B3")
    f_e4 = note_to_freq("E4")
    f_ab4 = note_to_freq("Ab4")
    add_dx7_rhodes_piano(left, right, 0.1, 3.5, f_e4, gain=0.24)
    add_dx7_rhodes_piano(left, right, 0.1, 3.5, f_b3, gain=0.20)
    mix_vocal_phrase(left, right, v_intro, 0.3, gain=0.60, pan=0.0, drive=1.1, delay_send=0.38)
    add_sung_melody_note(left, right, 0.4, 1.2, note_to_freq("B4"), vowel="oh", gain=0.22)
    add_sung_melody_note(left, right, 1.6, 1.8, note_to_freq("Ab4"), vowel="ee", gain=0.22)

    # Chords: E major - B major - C# minor - A major
    chords_e = [
        [note_to_freq(n) for n in ["E3", "B3", "E4", "Ab4"]],
        [note_to_freq(n) for n in ["B2", "F#3", "B3", "Eb4"]],
        [note_to_freq(n) for n in ["C#3", "G#3", "C#4", "E4"]],
        [note_to_freq(n) for n in ["A2", "E3", "A3", "C#4"]]
    ]
    bass_e = ["E1", "B0", "C#1", "A0"]

    add_crash(left, right, 2.0 * bar_sec, gain=0.38)

    for bar in range(2, 22):
        b_time = bar * bar_sec
        if b_time >= total_sec:
            break
        ch = chords_e[bar % 4]
        b_freq = note_to_freq(bass_e[bar % 4])

        # Smooth ballad drum groove
        add_kick(left, right, b_time, gain=0.38)
        add_kick(left, right, b_time + 2.5 * beat_sec, gain=0.34)
        add_snare(left, right, b_time + 1.0 * beat_sec, gain=0.28)
        add_snare(left, right, b_time + 3.0 * beat_sec, gain=0.28)
        for h in range(8):
            add_hihat(left, right, b_time + h * 0.5 * beat_sec, gain=0.12, is_open=(h == 6))

        # Rhodes chords
        add_dx7_rhodes_piano(left, right, b_time, beat_sec * 3.5, ch[2], gain=0.20)
        add_dx7_rhodes_piano(left, right, b_time, beat_sec * 3.5, ch[3], gain=0.18)

        # Fretless / chorused bassline
        add_melodic_pop_bass(left, right, b_time, beat_sec * 1.8, b_freq, gain=0.32)
        add_melodic_pop_bass(left, right, b_time + 2.0 * beat_sec, beat_sec * 1.8, b_freq * 1.5, gain=0.28)

        # Warm guitar lead swells
        if bar >= 6:
            lead_pitch = note_to_freq("Ab5") if bar % 2 == 0 else note_to_freq("B5")
            add_jpop_lead_guitar(left, right, b_time + 2.0 * beat_sec, beat_sec * 1.8, lead_pitch, gain=0.20)

    # SUNG VOCALS TIMELINE
    # Bar 2: Verse
    mix_vocal_phrase(left, right, v_verse, 2.0 * bar_sec, gain=0.55, pan=-0.1, drive=1.15, delay_send=0.35)
    add_sung_melody_note(left, right, 2.0 * bar_sec, 2.5, note_to_freq("E4"), vowel="ah", gain=0.20)
    add_sung_melody_note(left, right, 4.5 * bar_sec, 2.5, note_to_freq("Ab4"), vowel="oh", gain=0.22)

    # Bar 8: Chorus (Don't you see!)
    mix_vocal_phrase(left, right, v_chorus, 8.0 * bar_sec, gain=0.58, pan=0.0, drive=1.2, delay_send=0.38)
    mix_vocal_phrase(left, right, v_chorus_h, 8.0 * bar_sec, gain=0.40, pan=0.25, drive=1.15, delay_send=0.32)
    add_sung_melody_note(left, right, 8.0 * bar_sec, 1.5, note_to_freq("B4"), vowel="oh", gain=0.24)
    add_sung_melody_note(left, right, 8.0 * bar_sec + 1.5, 2.0, note_to_freq("E5"), vowel="ee", gain=0.26)

    # Bar 16: Outro reflection
    mix_vocal_phrase(left, right, v_outro, 16.0 * bar_sec, gain=0.56, pan=0.0, drive=1.15, delay_send=0.40)
    add_sung_melody_note(left, right, 16.0 * bar_sec, 2.5, note_to_freq("Ab4"), vowel="ah", gain=0.22)

    write_ogg_file(left, right, track_id, total_sec)


# =============================================================================
# 3. G.T. GRAND TOUR ODYSSEY (INSTRUMENTAL COSMIC SYNTH-ROCK)
# =============================================================================

def compose_grand_tour():
    """
    3. ost_dbgt_grand_tour (140 BPM, D major):
    INSTRUMENTAL SPACE ADVENTURE SYNTH-ROCK!
    - Cosmic 16th-note analog synth arpeggios + Dragon Radar pulses.
    - Driving four-on-the-floor beat, melodic electric guitars, brass fanfares.
    - Seamless 45.0s loop crossfade!
    """
    total_sec = 45.0
    track_id = "ost_dbgt_grand_tour"
    print(f"  -> Composing 3/5: {track_id} (G.T. Grand Tour Odyssey)...")
    bpm = 140
    beat_sec = 60.0 / bpm
    bar_sec = beat_sec * 4.0
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Dragon Radar beeps in intro
    add_radar_beep(left, right, 0.2, gain=0.25)
    add_radar_beep(left, right, 1.8, gain=0.25)

    # D major cosmic arpeggio notes (D4, F#4, A4, B4, D5)
    d_arp = [note_to_freq(n) for n in ["D4", "F#4", "A4", "D5", "F#5", "D5", "A4", "F#4"]]

    add_crash(left, right, 2.0 * bar_sec, gain=0.45)

    for bar in range(26):
        b_time = bar * bar_sec
        if b_time >= total_sec:
            break

        # Cosmic 16th synth arpeggiator
        for s in range(8):
            s_time = b_time + s * 0.5 * beat_sec
            if s_time < total_sec:
                add_cosmic_synth_arp(left, right, s_time, beat_sec * 0.45, d_arp[s], gain=0.22)

        # Driving electro-rock drums (kick on 1, 2, 3, 4 from Bar 2)
        if bar >= 2:
            for beat in range(4):
                add_kick(left, right, b_time + beat * beat_sec, gain=0.38)
            add_snare(left, right, b_time + 1.0 * beat_sec, gain=0.30)
            add_snare(left, right, b_time + 3.0 * beat_sec, gain=0.30)
            for h in range(8):
                add_hihat(left, right, b_time + h * 0.5 * beat_sec, gain=0.14)

        # Space bassline in D major
        b_freq = note_to_freq("D2") if bar % 4 in (0, 1) else note_to_freq("G2")
        add_melodic_pop_bass(left, right, b_time, beat_sec * 0.9, b_freq, gain=0.32)
        add_melodic_pop_bass(left, right, b_time + 2.0 * beat_sec, beat_sec * 0.9, b_freq, gain=0.32)

        # Soaring anime lead guitar fanfare (Bar 6 onward)
        if bar >= 6:
            lead_f = note_to_freq("F#5") if bar % 2 == 0 else note_to_freq("A5")
            add_jpop_lead_guitar(left, right, b_time, beat_sec * 1.8, lead_f, gain=0.24)

        # Brass stabs at Bar 14 onward
        if bar >= 14:
            add_jpop_brass_stab(left, right, b_time + 1.0 * beat_sec, beat_sec * 0.6, note_to_freq("D4"), gain=0.26)
            add_jpop_brass_stab(left, right, b_time + 3.0 * beat_sec, beat_sec * 0.6, note_to_freq("A4"), gain=0.26)

    write_ogg_file(left, right, track_id, total_sec)


# =============================================================================
# 4. PRIMAL AWAKENING: SUPER SAIYAN 4 (INSTRUMENTAL METAL & SHAKUHACHI)
# =============================================================================

def compose_super_saiyan_4():
    """
    4. ost_dbgt_super_saiyan_4 (156 BPM, D minor):
    PRIMAL GOLDEN APE / SUPER SAIYAN 4 AWAKENING!
    - Solo Shakuhachi bamboo flute crying over wind atmosphere.
    - Sudden explosive heavy metal guitars, double-bass drums, Taiko rolls.
    - Seamless 45.0s loop crossfade!
    """
    total_sec = 45.0
    track_id = "ost_dbgt_super_saiyan_4"
    print(f"  -> Composing 4/5: {track_id} (Primal Awakening: Super Saiyan 4)...")
    bpm = 156
    beat_sec = 60.0 / bpm
    bar_sec = beat_sec * 4.0
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # INTRO (0:00 - 4.61s, Bars 0-3): Haunting solo Shakuhachi flute
    shaku_melody = [
        (note_to_freq("D4"), 1.8),
        (note_to_freq("F4"), 1.2),
        (note_to_freq("A4"), 2.0),
        (note_to_freq("D5"), 2.5)
    ]
    cur_t = 0.2
    for freq, dur_b in shaku_melody:
        dur = dur_b * beat_sec
        if cur_t + dur < total_sec:
            add_shakuhachi_flute(left, right, cur_t, dur * 0.95, freq, gain=0.30)
        cur_t += dur

    # EXPLOSION AT BAR 3 (4.61s): Primal metal onslaught!
    f_d1 = note_to_freq("D1")
    f_f1 = note_to_freq("F1")

    for bar in range(3, 29):
        b_time = bar * bar_sec
        if b_time >= total_sec:
            break

        if bar == 3:
            add_crash(left, right, b_time, gain=0.55)

        # Fast double kick on 16th steps
        for step in range(4):
            add_kick(left, right, b_time + step * beat_sec, gain=0.40)
            if step in [1, 3]:
                add_snare(left, right, b_time + step * beat_sec, gain=0.35)

        # Heavy metal rhythm guitar chugs
        freq = f_d1 if bar % 4 != 3 else f_f1
        for b in range(4):
            add_jpop_lead_guitar(left, right, b_time + b * beat_sec, beat_sec * 0.8, freq * 2.0, gain=0.28, vibrato=False)

        # Melodic electric bass
        add_melodic_pop_bass(left, right, b_time, bar_sec * 0.8, freq, gain=0.34)

        # Shakuhachi warrior theme over the metal rhythm (Bar 8 onward)
        if bar >= 8:
            flute_n = note_to_freq("F5") if bar % 2 == 0 else note_to_freq("D5")
            add_shakuhachi_flute(left, right, b_time, beat_sec * 1.8, flute_n, gain=0.26)

        # Brass heroic blasts (Bar 16 onward)
        if bar >= 16:
            add_jpop_brass_stab(left, right, b_time, bar_sec * 0.7, note_to_freq("D4"), gain=0.28)

    write_ogg_file(left, right, track_id, total_sec)


# =============================================================================
# 5. RUSTING MACHINE GUN (INSTRUMENTAL 90s POP-PUNK / WANDS STYLE)
# =============================================================================

def compose_sabitsuita_machine_gun():
    """
    5. ost_dbgt_sabitsuita_machine_gun (168 BPM, G major):
    HIGH-ENERGY 90s ANIME POP-PUNK / WANDS ENDING!
    - Clean staccato skank guitar intro + crash explosion!
    - Fast skate-punk drums, melodic walking bass, nostalgic guitar hooks.
    - Seamless 45.0s loop crossfade!
    """
    total_sec = 45.0
    track_id = "ost_dbgt_sabitsuita_machine_gun"
    print(f"  -> Composing 5/5: {track_id} (Rusting Machine Gun - 90s Pop-Punk Ending)...")
    bpm = 168
    beat_sec = 60.0 / bpm
    bar_sec = beat_sec * 4.0
    total_samples = int(total_sec * SAMPLE_RATE)
    left = [0.0] * total_samples
    right = [0.0] * total_samples

    # Intro (Bars 0-2): Clean guitar skank on offbeats + hi-hat count
    chord_g = [note_to_freq(n) for n in ["G3", "B3", "D4", "G4"]]
    for b in range(4):
        add_hihat(left, right, b * beat_sec, gain=0.18)
        add_acoustic_strum(left, right, (b + 0.5) * beat_sec, beat_sec * 0.35, chord_g, gain=0.25)

    add_crash(left, right, 2.0 * bar_sec, gain=0.48)

    chords_punk = [
        [note_to_freq(n) for n in ["G3", "B3", "D4"]],
        [note_to_freq(n) for n in ["D3", "F#3", "A3"]],
        [note_to_freq(n) for n in ["E3", "G3", "B3"]],
        [note_to_freq(n) for n in ["C3", "E3", "G3"]]
    ]
    bass_punk = ["G1", "D1", "E1", "C1"]

    for bar in range(2, 31):
        b_time = bar * bar_sec
        if b_time >= total_sec:
            break
        ch = chords_punk[bar % 4]
        b_f = note_to_freq(bass_punk[bar % 4])

        # Fast skate-punk drum beat (kick on 1 and 2.5, snare on 2 and 4)
        add_kick(left, right, b_time, gain=0.40)
        add_kick(left, right, b_time + 1.5 * beat_sec, gain=0.36)
        add_kick(left, right, b_time + 2.0 * beat_sec, gain=0.38)
        add_snare(left, right, b_time + 1.0 * beat_sec, gain=0.32)
        add_snare(left, right, b_time + 3.0 * beat_sec, gain=0.32)
        for h in range(8):
            add_hihat(left, right, b_time + h * 0.5 * beat_sec, gain=0.14)

        # Distorted rhythm guitar power chords on every eighth note
        for beat in range(4):
            add_jpop_lead_guitar(left, right, b_time + beat * beat_sec, beat_sec * 0.45, ch[0], gain=0.24, vibrato=False)
            add_jpop_lead_guitar(left, right, b_time + (beat + 0.5) * beat_sec, beat_sec * 0.45, ch[1], gain=0.22, vibrato=False)

        # Driving walking punk bassline
        add_melodic_pop_bass(left, right, b_time, beat_sec * 0.9, b_f, gain=0.32)
        add_melodic_pop_bass(left, right, b_time + 2.0 * beat_sec, beat_sec * 0.9, b_f, gain=0.32)

        # Soaring nostalgic J-Rock guitar solo (Bar 6 onward)
        if bar >= 6:
            sol_f = note_to_freq("B4") if bar % 2 == 0 else note_to_freq("D5")
            add_jpop_lead_guitar(left, right, b_time, beat_sec * 1.8, sol_f, gain=0.22)

        # Triumphant brass accents at Bar 14 onward
        if bar >= 14:
            add_jpop_brass_stab(left, right, b_time + 1.0 * beat_sec, beat_sec * 0.6, note_to_freq("G4"), gain=0.25)
            add_jpop_brass_stab(left, right, b_time + 3.0 * beat_sec, beat_sec * 0.6, note_to_freq("D5"), gain=0.25)

    write_ogg_file(left, right, track_id, total_sec)


def main():
    import sys
    os.makedirs(OUT_DIR, exist_ok=True)
    all_targets = [
        "dan_dan_vocal", "dont_you_see_vocal",
        "grand_tour", "super_saiyan_4", "sabitsuita_machine_gun"
    ]
    targets = sys.argv[1:] if len(sys.argv) > 1 else all_targets
    print(f"=== Synthesizing Dragon Ball GT OSTs (Targets: {targets}) ===")

    if any(t in targets for t in ("dan_dan_vocal", "ost_dbgt_dan_dan_vocal")):
        compose_dan_dan_vocal()
    if any(t in targets for t in ("dont_you_see_vocal", "ost_dbgt_dont_you_see_vocal")):
        compose_dont_you_see_vocal()
    if any(t in targets for t in ("grand_tour", "ost_dbgt_grand_tour")):
        compose_grand_tour()
    if any(t in targets for t in ("super_saiyan_4", "ost_dbgt_super_saiyan_4")):
        compose_super_saiyan_4()
    if any(t in targets for t in ("sabitsuita_machine_gun", "ost_dbgt_sabitsuita_machine_gun")):
        compose_sabitsuita_machine_gun()

    print("\nDragon Ball GT OST synthesis complete!")


if __name__ == "__main__":
    main()
