#!/usr/bin/env python3
"""
generate_all_soundtracks.py — Procedural High-Quality Steampunk Audio Generator
Generates all 22 OST tracks for Steam Circuit Padel Pro matching exact BPM, Key, and Theme.
Exports directly to godot/assets/audio/music/ost_<name>.ogg.
"""

import math
import os
import random
import struct
import subprocess
import time
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../godot/assets/audio/music"))
FFMPEG = "/opt/homebrew/bin/ffmpeg"

def note_freq(midi):
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))

# --- DSP INSTRUMENT GENERATORS ---

def make_kick(pitch_start=130.0, pitch_end=42.0, duration=0.28, sat=1.4):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 16.0)
        pitch = (pitch_start - pitch_end) * math.exp(-t * 26.0) + pitch_end
        phase = 2.0 * math.pi * pitch * t
        s = math.sin(phase) * env
        samples[i] = math.tanh(s * sat) * 0.95
    return samples

def make_taiko(pitch=55.0, duration=0.45):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 9.0)
        pitch_cur = pitch * (1.0 + 0.4 * math.exp(-t * 30.0))
        phase = 2.0 * math.pi * pitch_cur * t
        s = (math.sin(phase) + 0.3 * math.sin(phase * 1.52) + 0.15 * math.sin(phase * 2.3)) * env
        samples[i] = math.tanh(s * 1.5) * 0.95
    return samples

def make_snare(is_anvil=False, duration=0.25):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    rnd = random.Random(42)
    f1 = 1150.0 if is_anvil else 260.0
    f2 = 1880.0 if is_anvil else 430.0
    f3 = 3120.0 if is_anvil else 890.0
    decay_tone = 10.0 if is_anvil else 26.0
    decay_noise = 18.0 if is_anvil else 22.0
    for i in range(length):
        t = i / SAMPLE_RATE
        noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * decay_noise)
        tone = (math.sin(2.0 * math.pi * f1 * t) * 0.5 +
                math.sin(2.0 * math.pi * f2 * t) * 0.35 +
                math.sin(2.0 * math.pi * f3 * t) * 0.2) * math.exp(-t * decay_tone)
        mix_val = (tone * 0.7 + noise * 0.5) if is_anvil else (noise * 0.7 + tone * 0.4)
        samples[i] = math.tanh(mix_val * 1.3) * 0.9
    return samples

def make_tick(pitch_high=True, duration=0.035):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    freq = 5200.0 if pitch_high else 3100.0
    rnd = random.Random(101 if pitch_high else 202)
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 140.0)
        s = (math.sin(2.0 * math.pi * freq * t) * 0.6 + (rnd.random() * 2.0 - 1.0) * 0.4) * env
        samples[i] = s * 0.65
    return samples

def make_steam(duration=0.35, high_pass=False):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    rnd = random.Random(303)
    for i in range(length):
        t = i / SAMPLE_RATE
        env = (t / 0.04) if t < 0.04 else math.exp(-(t - 0.04) * 9.0)
        n = (rnd.random() * 2.0 - 1.0)
        # steam hiss tone
        s = (n * 0.7 + math.sin(2.0 * math.pi * 3800.0 * t) * 0.3) * env * 0.45
        samples[i] = s
    return samples

def make_bass(midi, duration, waveform="saw_pluck"):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    f = note_freq(midi)
    for i in range(length):
        t = i / SAMPLE_RATE
        if waveform == "sub_sine":
            env = math.exp(-t * 2.5)
            s = math.sin(2.0 * math.pi * f * t) + 0.25 * math.sin(4.0 * math.pi * f * t)
        elif waveform == "fm_growl":
            env = math.exp(-t * 3.5)
            mod = math.sin(2.0 * math.pi * f * 2.0 * t) * 2.5 * math.exp(-t * 5.0)
            s = math.sin(2.0 * math.pi * f * t + mod)
        else: # saw_pluck
            env = math.exp(-t * 3.8)
            p = 2.0 * math.pi * f * t
            s = (math.sin(p) + 0.5 * math.sin(2*p) + 0.3 * math.sin(3*p) + 0.15 * math.sin(4*p))
        samples[i] = math.tanh(s * 1.3) * env * 0.85
    return samples

def make_lead(midi, duration, waveform="brass"):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    f = note_freq(midi)
    att = 0.02
    decay_rate = 3.5
    if waveform in ("glock", "chime", "pluck"):
        att = 0.005
        decay_rate = 6.0
    for i in range(length):
        t = i / SAMPLE_RATE
        env = (t / att) if t < att else math.exp(-(t - att) * decay_rate)
        p = 2.0 * math.pi * f * t
        if waveform == "brass":
            s = math.sin(p) + 0.55 * math.sin(2*p) + 0.35 * math.sin(3*p) + 0.2 * math.sin(4*p)
            s = math.tanh(s * 1.25)
        elif waveform == "organ":
            s = math.sin(p) + 0.7 * math.sin(2*p) + 0.6 * math.sin(3*p) + 0.5 * math.sin(4*p) + 0.3 * math.sin(6*p)
            s = s * 0.5
        elif waveform == "accordion":
            s = math.sin(p) + 0.8 * math.sin(2*p) + 0.4 * math.sin(3*p) + 0.3 * math.sin(4*p)
            s = math.sin(s * 1.4) * 0.7
        elif waveform in ("glock", "chime"):
            s = math.sin(p) + 0.5 * math.sin(2.76*p) + 0.25 * math.sin(5.4*p)
        elif waveform == "flute":
            s = math.sin(p) + 0.15 * math.sin(2*p) + 0.08 * math.sin(3*p)
            s = s * (1.0 + 0.05 * math.sin(2.0 * math.pi * 5.5 * t)) # vibrato
        elif waveform == "synth_acid":
            cutoff = f * (1.0 + 3.0 * math.exp(-t * 8.0))
            p_mod = 2.0 * math.pi * cutoff * t
            s = math.sin(p) * 0.7 + math.sin(p_mod) * 0.4
            s = math.tanh(s * 1.6)
        elif waveform == "slide":
            # slide pitch up slightly
            f_slide = f * (1.0 + 0.08 * math.exp(-t * 5.0))
            s = math.sin(2.0 * math.pi * f_slide * t) + 0.4 * math.sin(4.0 * math.pi * f_slide * t)
        elif waveform == "jrock_guitar":
            s = math.sin(p) + 0.6 * math.sin(1.5 * p) + 0.5 * math.sin(2.0 * p) + 0.3 * math.sin(3.0 * p)
            s = math.tanh(s * 2.6) * 0.9
        elif waveform == "epic_violin":
            vib = 1.0 + 0.02 * math.sin(2.0 * math.pi * 6.0 * t) if t > 0.08 else 1.0
            p_vib = p * vib
            s = (math.sin(p_vib) + 0.5 * math.sin(2*p_vib) + 0.35 * math.sin(3*p_vib) + 0.2 * math.sin(4*p_vib))
            s = math.tanh(s * 1.3) * 0.85
        elif waveform == "choir_pad":
            s = (math.sin(p) + math.sin(p * 1.002) * 0.7 + math.sin(p * 0.998) * 0.7 + math.sin(2*p) * 0.4) * 0.55
        else: # strings
            s = (math.sin(p) + math.sin(p * 1.003) * 0.5 + math.sin(2*p) * 0.3) * 0.6
        samples[i] = s * env * 0.7
    return samples

def make_chord_pad(midi_list, duration, waveform="strings"):
    length = int(duration * SAMPLE_RATE)
    samples = [0.0] * length
    att = 0.08
    for i in range(length):
        t = i / SAMPLE_RATE
        env = (t / att) if t < att else math.exp(-(t - att) * 1.8)
        acc = 0.0
        for m in midi_list:
            f = note_freq(m)
            p = 2.0 * math.pi * f * t
            acc += math.sin(p) + 0.3 * math.sin(2*p)
        samples[i] = acc / len(midi_list) * env * 0.6
    return samples

def mix(buf_l, buf_r, smp, pos, total_samples, pan=0.0, gain=1.0):
    gl = gain * math.cos((pan + 1.0) * math.pi / 4.0)
    gr = gain * math.sin((pan + 1.0) * math.pi / 4.0)
    for i, s in enumerate(smp):
        p = (pos + i) % total_samples
        buf_l[p] += s * gl
        buf_r[p] += s * gr

def export_track(track_id, left_buf, right_buf):
    total_samples = len(left_buf)
    max_val = 0.0001
    for i in range(total_samples):
        max_val = max(max_val, abs(left_buf[i]), abs(right_buf[i]))

    scale = 0.88 / max_val
    raw = bytearray()
    for i in range(total_samples):
        l = int(max(-32767, min(32767, left_buf[i] * scale * 32767.0)))
        r = int(max(-32767, min(32767, right_buf[i] * scale * 32767.0)))
        raw += struct.pack('<hh', l, r)

    wav_path = f"/tmp/{track_id}.wav"
    ogg_path = os.path.join(OUT_DIR, f"{track_id}.ogg")

    with wave.open(wav_path, 'wb') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(raw)

    subprocess.run([
        FFMPEG, '-y', '-i', wav_path,
        '-c:a', 'vorbis', '-strict', '-2', '-q:a', '5',
        ogg_path
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    os.remove(wav_path)
    file_size_kb = os.path.getsize(ogg_path) / 1024.0
    print(f"  [OK] {track_id}.ogg ({file_size_kb:.1f} KB)")


# --- TRACK GENERATOR DEFINITIONS ---

def render_track(track_id, bpm, scale_root, scale_type, style_config):
    beat_len = 60.0 / bpm
    step_len = beat_len / 4.0 # 16th note
    bar_len = beat_len * 4.0
    phrase_len = bar_len * 4.0 # 4 bars = 1 phrase

    # Target ~45 seconds, aligned to integer 4-bar phrases for musical phrasing
    cycles = max(4, int(round(45.0 / phrase_len)))
    n_bars = cycles * 4
    n_steps = n_bars * 16
    total_samples = int(n_steps * step_len * SAMPLE_RATE)

    left_buf = [0.0] * total_samples
    right_buf = [0.0] * total_samples

    kick = make_kick(sat=style_config.get("kick_sat", 1.4))
    taiko = make_taiko()
    snare = make_snare(is_anvil=False)
    anvil = make_snare(is_anvil=True)
    tick_hi = make_tick(True)
    tick_lo = make_tick(False)
    steam = make_steam()

    drum_style = style_config.get("drum_style", "four_on_floor")
    bass_notes = style_config.get("bass_notes", [])
    bass_wave = style_config.get("bass_wave", "saw_pluck")
    chords = style_config.get("chords", [])
    chord_wave = style_config.get("chord_wave", "strings")
    lead_notes = style_config.get("lead_notes", [])
    lead_wave = style_config.get("lead_wave", "brass")

    # 1. PERCUSSION PATTERNS ACROSS ALL CYCLES
    for step in range(n_steps):
        t_pos = int(step * step_len * SAMPLE_RATE)
        bar = step // 16
        c = bar // 4 # Cycle index (0 .. cycles - 1)
        beat = (step // 4) % 4
        sub = step % 4
        step_bar = step % 16

        # Intro cycle (c == 0): minimal atmospheric clockwork & kick on beat 1
        if c == 0:
            if beat == 0 and sub == 0:
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.7)
            if sub in (0, 2):
                mix(left_buf, right_buf, tick_hi if sub == 2 else tick_lo, t_pos, total_samples, -0.3 if sub == 0 else 0.3, 0.35)
            if step == 0 and style_config.get("steam_fx", True):
                mix(left_buf, right_buf, steam, t_pos, total_samples, 0.2, 0.4)
            continue

        # Breakdown cycle (c == cycles - 2 if cycles >= 6): halftime drums
        is_breakdown = (cycles >= 6 and c == cycles - 2)

        if drum_style == "four_on_floor":
            if is_breakdown:
                if beat in (0, 2) and sub == 0:
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.8)
                if beat == 2 and sub == 0:
                    mix(left_buf, right_buf, anvil, t_pos, total_samples, 0.1, 0.6)
            else:
                if sub == 0:
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.85)
                if sub == 0 and beat in (1, 3):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.7)
                    if style_config.get("use_anvil", False) or c >= cycles - 1:
                        mix(left_buf, right_buf, anvil, t_pos, total_samples, -0.2, 0.5)
            if sub in (0, 2):
                mix(left_buf, right_buf, tick_hi if sub == 2 else tick_lo, t_pos, total_samples, 0.3 if sub == 2 else -0.3, 0.4)
            if c == 3 and sub == 3: # 16th shaker fill in cycle 3
                mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.4, 0.25)

        elif drum_style == "breakbeat":
            if is_breakdown:
                if step_bar in (0, 8):
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.8)
                if step_bar in (4, 12):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.6)
            else:
                if step_bar in (0, 6, 10):
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.85)
                if step_bar in (4, 12):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.8)
                    mix(left_buf, right_buf, anvil, t_pos, total_samples, -0.2, 0.45)
            if sub in (0, 2):
                mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.3, 0.35)

        elif drum_style == "taiko_tribal":
            if is_breakdown:
                if step_bar in (0, 8):
                    mix(left_buf, right_buf, taiko, t_pos, total_samples, 0.0, 0.85)
            else:
                if step_bar in (0, 3, 8, 11, 14):
                    mix(left_buf, right_buf, taiko, t_pos, total_samples, -0.1 if step_bar%2==0 else 0.1, 0.9)
                if step_bar in (4, 12):
                    mix(left_buf, right_buf, anvil, t_pos, total_samples, 0.2, 0.7)
            if sub in (1, 3):
                mix(left_buf, right_buf, tick_lo, t_pos, total_samples, -0.3, 0.3)

        elif drum_style == "samba":
            if step_bar in (0, 4, 7, 10, 14):
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.85)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.15, 0.7)
            if sub % 2 == 1:
                mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.35, 0.45)

        elif drum_style == "train_chug":
            if step_bar in (0, 2, 8, 10):
                mix(left_buf, right_buf, kick, t_pos, total_samples, -0.15, 0.8)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, anvil, t_pos, total_samples, 0.2, 0.75)
            if step_bar in (6, 14):
                mix(left_buf, right_buf, snare, t_pos, total_samples, -0.1, 0.6)
            mix(left_buf, right_buf, tick_lo, t_pos, total_samples, 0.3, 0.3)

        elif drum_style == "ambient_tick":
            if sub == 0:
                mix(left_buf, right_buf, tick_hi if beat % 2 == 0 else tick_lo, t_pos, total_samples, -0.3 if beat % 2 == 0 else 0.3, 0.5)
            if step % 32 == 0:
                mix(left_buf, right_buf, taiko, t_pos, total_samples, 0.0, 0.6)

        elif drum_style == "anime_rock":
            if is_breakdown:
                if step_bar in (0, 8):
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.85)
                if step_bar in (4, 12):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.65)
            else:
                if step_bar in (0, 3, 8, 10):
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.9)
                if step_bar in (4, 12):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
                    mix(left_buf, right_buf, anvil, t_pos, total_samples, -0.2, 0.45)
                if c >= cycles - 1 and step_bar in (14, 15):
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.8)
            mix(left_buf, right_buf, tick_hi if sub % 2 == 0 else tick_lo, t_pos, total_samples, 0.25 if sub % 2 == 0 else -0.25, 0.35)

        elif drum_style == "power_metal":
            if sub in (0, 2):
                mix(left_buf, right_buf, kick, t_pos, total_samples, -0.1 if sub == 0 else 0.1, 0.88)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
                mix(left_buf, right_buf, anvil, t_pos, total_samples, 0.2, 0.5)
            mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.3, 0.4)

        elif drum_style == "sawano_climax":
            if sub == 0:
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.9)
                if beat == 0:
                    mix(left_buf, right_buf, taiko, t_pos, total_samples, 0.0, 0.85)
            if sub == 0 and beat in (1, 3):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
                mix(left_buf, right_buf, anvil, t_pos, total_samples, -0.2, 0.6)
            if sub in (0, 2):
                mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.3, 0.35)

        # Steam releases on phrase downbeats & climax transitions
        if step % 64 == 0 and style_config.get("steam_fx", True):
            mix(left_buf, right_buf, steam, t_pos, total_samples, 0.25, 0.45)
        if c == cycles - 1 and step_bar == 12 and style_config.get("steam_fx", True):
            mix(left_buf, right_buf, steam, t_pos, total_samples, -0.3, 0.6)

    # 2. BASSLINE ACROSS ALL CYCLES
    for c in range(cycles):
        cycle_start_pos = int(c * 64 * step_len * SAMPLE_RATE)
        for i, midi in enumerate(bass_notes):
            pos = cycle_start_pos + int(i * 2 * step_len * SAMPLE_RATE)
            # Intro cycle: root notes only on beats 1 & 3
            if c == 0:
                if i % 4 != 0:
                    continue
                bsmp = make_bass(midi, step_len * 3.8, "sub_sine")
                mix(left_buf, right_buf, bsmp, pos, total_samples, 0.0, 0.6)
            elif c == 3: # Octave accent variation
                note_val = midi + 12 if (i % 8 == 6) else midi
                bsmp = make_bass(note_val, step_len * 1.8, bass_wave)
                mix(left_buf, right_buf, bsmp, pos, total_samples, 0.0, 0.75)
            else:
                bsmp = make_bass(midi, step_len * 1.9, bass_wave)
                mix(left_buf, right_buf, bsmp, pos, total_samples, 0.0, 0.75)

    # 3. CHORDS / HARMONIC PADS ACROSS ALL CYCLES
    for c in range(cycles):
        if c == 0: # Sparser pad in intro
            for bar_idx in range(4):
                chord_midis = chords[bar_idx % len(chords)]
                pos = int((c * 4 + bar_idx) * 16 * step_len * SAMPLE_RATE)
                csmp = make_chord_pad(chord_midis, step_len * 15.5, "strings")
                mix(left_buf, right_buf, csmp, pos, total_samples, 0.0, 0.35)
        else:
            chord_gain = 0.65 if (c >= cycles - 1) else 0.52
            for bar_idx in range(4):
                chord_midis = chords[bar_idx % len(chords)]
                pos = int((c * 4 + bar_idx) * 16 * step_len * SAMPLE_RATE)
                csmp = make_chord_pad(chord_midis, step_len * 15.5, chord_wave)
                mix(left_buf, right_buf, csmp, pos, total_samples, 0.0, chord_gain)

    # 4. MELODIC LEAD MOTIF ACROSS CYCLES
    for c in range(cycles):
        cycle_start_pos = int(c * 64 * step_len * SAMPLE_RATE)
        if c == 0:
            # Intro: subtle opening chime on first 2 notes
            for step_idx, midi, dur_beats in lead_notes[:2]:
                pos = cycle_start_pos + int(step_idx * step_len * SAMPLE_RATE)
                lsmp = make_lead(midi, dur_beats * beat_len, "chime")
                mix(left_buf, right_buf, lsmp, pos, total_samples, 0.0, 0.4)
        elif c == 1:
            # Theme entrance at moderate volume
            for step_idx, midi, dur_beats in lead_notes:
                pos = cycle_start_pos + int(step_idx * step_len * SAMPLE_RATE)
                lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                pan = 0.15 if (step_idx // 4) % 2 == 0 else -0.15
                mix(left_buf, right_buf, lsmp, pos, total_samples, pan, 0.5)
        elif c in (2, cycles - 1):
            # Full Theme A & Grand Finale Climax
            lead_gain = 0.72 if (c == cycles - 1) else 0.62
            for step_idx, midi, dur_beats in lead_notes:
                pos = cycle_start_pos + int(step_idx * step_len * SAMPLE_RATE)
                lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                pan = 0.2 if (step_idx // 4) % 2 == 0 else -0.2
                mix(left_buf, right_buf, lsmp, pos, total_samples, pan, lead_gain)
        elif c == 3:
            # Variation: octave up flourish on high notes
            for step_idx, midi, dur_beats in lead_notes:
                pos = cycle_start_pos + int(step_idx * step_len * SAMPLE_RATE)
                oct_shift = 12 if (midi >= scale_root + 5) else 0
                lsmp = make_lead(midi + oct_shift, dur_beats * beat_len * 0.85, lead_wave)
                pan = -0.25 if (step_idx // 4) % 2 == 0 else 0.25
                mix(left_buf, right_buf, lsmp, pos, total_samples, pan, 0.6)
        else: # Bridge / breakdown solo
            for step_idx, midi, dur_beats in lead_notes[::2]: # Sparser syncopated solo
                pos = cycle_start_pos + int(step_idx * step_len * SAMPLE_RATE)
                lsmp = make_lead(midi, dur_beats * beat_len * 1.2, "chime" if lead_wave != "glock" else "flute")
                mix(left_buf, right_buf, lsmp, pos, total_samples, 0.1, 0.55)

    export_track(track_id, left_buf, right_buf)


# --- 22 TRACK COMPOSITIONS ---

TRACKS = {
    "ost_menu": {
        "bpm": 118,
        "root": 62, # D
        "scale": "minor",
        "style": {
            "drum_style": "four_on_floor", "use_anvil": True, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 41, 43,  45, 45, 43, 41,  38, 38, 45, 43,  41, 43, 45, 40,
                           38, 38, 41, 43,  45, 48, 45, 43,  41, 41, 43, 45,  38, 40, 41, 45],
            "chords": [[50, 53, 57], [48, 52, 55], [46, 50, 53], [45, 48, 52]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 62, 1.0), (3, 65, 0.5), (4, 69, 1.5), (8, 67, 1.0), (11, 65, 0.5), (12, 62, 2.0),
                (16, 69, 1.0), (19, 72, 0.5), (20, 74, 1.5), (24, 72, 1.0), (27, 69, 0.5), (28, 65, 2.0),
                (32, 62, 0.8), (34, 65, 0.8), (36, 67, 0.8), (38, 69, 0.8), (40, 72, 1.2), (44, 69, 1.5),
                (48, 67, 1.0), (51, 65, 0.5), (52, 62, 1.5), (56, 60, 1.0), (60, 62, 3.0)
            ]
        }
    },
    "ost_roster": {
        "bpm": 105,
        "root": 57, # A
        "scale": "minor",
        "style": {
            "drum_style": "ambient_tick", "steam_fx": False,
            "bass_wave": "saw_pluck",
            "bass_notes": [33, 33, 36, 38,  40, 40, 38, 36,  33, 33, 40, 38,  36, 38, 40, 35,
                           33, 33, 36, 38,  40, 43, 40, 38,  36, 36, 38, 40,  33, 35, 36, 40],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "accordion",
            "lead_notes": [
                (0, 57, 1.0), (4, 60, 1.0), (8, 64, 1.5), (12, 62, 0.5), (14, 60, 1.0),
                (16, 57, 1.0), (20, 64, 1.0), (24, 67, 1.5), (28, 65, 0.5), (30, 64, 1.0),
                (32, 60, 1.0), (36, 62, 1.0), (40, 64, 1.0), (44, 67, 1.0), (48, 64, 2.0)
            ]
        }
    },
    "ost_career": {
        "bpm": 95,
        "root": 64, # E
        "scale": "minor",
        "style": {
            "drum_style": "ambient_tick", "steam_fx": True,
            "bass_wave": "sub_sine",
            "bass_notes": [28, 28, 28, 28,  31, 31, 31, 31,  33, 33, 33, 33,  35, 35, 35, 35,
                           28, 28, 28, 28,  31, 31, 31, 31,  33, 33, 33, 33,  28, 28, 31, 35],
            "chords": [[40, 43, 47], [43, 47, 50], [45, 48, 52], [38, 43, 47]],
            "lead_wave": "strings",
            "lead_notes": [
                (0, 52, 2.0), (8, 55, 2.0), (16, 59, 2.0), (24, 57, 2.0),
                (32, 55, 1.5), (38, 54, 1.0), (42, 52, 2.5), (52, 47, 3.0)
            ]
        }
    },
    "ost_training": {
        "bpm": 124,
        "root": 60, # C
        "scale": "minor",
        "style": {
            "drum_style": "four_on_floor", "steam_fx": True,
            "bass_wave": "fm_growl",
            "bass_notes": [36, 36, 39, 41,  36, 36, 43, 41,  36, 36, 39, 41,  44, 43, 41, 39,
                           36, 36, 39, 41,  36, 36, 43, 41,  36, 36, 39, 41,  36, 39, 41, 43],
            "chords": [[48, 51, 55], [44, 48, 51], [46, 50, 53], [43, 46, 50]],
            "lead_wave": "pluck",
            "lead_notes": [
                (0, 60, 0.5), (2, 63, 0.5), (4, 67, 0.5), (6, 65, 0.5),
                (8, 63, 0.5), (10, 60, 0.5), (12, 67, 1.0),
                (16, 60, 0.5), (18, 63, 0.5), (20, 70, 0.5), (22, 67, 0.5),
                (24, 65, 0.5), (26, 63, 0.5), (28, 60, 1.0),
                (32, 72, 0.5), (34, 70, 0.5), (36, 67, 0.5), (38, 63, 0.5),
                (40, 65, 0.5), (42, 67, 0.5), (44, 60, 2.0)
            ]
        }
    },
    "ost_officina": {
        "bpm": 128,
        "root": 65, # F
        "scale": "minor",
        "style": {
            "drum_style": "four_on_floor", "use_anvil": True, "steam_fx": True, "kick_sat": 1.7,
            "bass_wave": "fm_growl",
            "bass_notes": [41, 41, 44, 46,  41, 41, 48, 46,  41, 41, 44, 46,  49, 48, 46, 44,
                           41, 41, 44, 46,  41, 41, 48, 46,  41, 41, 44, 46,  41, 44, 46, 48],
            "chords": [[53, 56, 60], [49, 53, 56], [51, 55, 58], [48, 51, 55]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 65, 1.0), (4, 68, 1.0), (8, 72, 1.5), (12, 70, 1.0),
                (16, 65, 1.0), (20, 68, 1.0), (24, 75, 1.5), (28, 72, 1.0),
                (32, 77, 1.0), (36, 75, 1.0), (40, 72, 1.0), (44, 68, 1.0), (48, 65, 2.5)
            ]
        }
    },
    "ost_fonderia": {
        "bpm": 132,
        "root": 62, # D
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "use_anvil": True, "steam_fx": True, "kick_sat": 1.8,
            "bass_wave": "fm_growl",
            "bass_notes": [38, 38, 38, 41,  38, 38, 45, 43,  38, 38, 38, 41,  46, 45, 43, 41,
                           38, 38, 38, 41,  38, 38, 45, 43,  38, 38, 38, 41,  38, 41, 45, 48],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "synth_acid",
            "lead_notes": [
                (0, 62, 0.5), (2, 65, 0.5), (4, 69, 1.0), (8, 67, 1.0), (12, 65, 1.0),
                (16, 62, 0.5), (18, 65, 0.5), (20, 72, 1.0), (24, 69, 1.5),
                (32, 74, 1.0), (36, 72, 1.0), (40, 69, 1.0), (44, 67, 1.0), (48, 62, 2.5)
            ]
        }
    },
    "ost_cattedrale": {
        "bpm": 135,
        "root": 67, # G
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "use_anvil": True, "steam_fx": True,
            "bass_wave": "sub_sine",
            "bass_notes": [43, 43, 46, 48,  50, 50, 48, 46,  43, 43, 50, 48,  46, 48, 50, 45,
                           43, 43, 46, 48,  50, 53, 50, 48,  46, 46, 48, 50,  43, 45, 46, 50],
            "chords": [[55, 58, 62], [51, 55, 58], [53, 57, 60], [50, 53, 57]],
            "lead_wave": "organ",
            "lead_notes": [
                (0, 67, 1.0), (4, 70, 1.0), (8, 74, 1.5), (12, 72, 1.0),
                (16, 70, 1.0), (20, 67, 1.0), (24, 75, 1.5), (28, 74, 1.0),
                (32, 79, 1.0), (36, 77, 1.0), (40, 75, 1.0), (44, 74, 1.0), (48, 67, 3.0)
            ]
        }
    },
    "ost_forgia": {
        "bpm": 130,
        "root": 59, # B
        "scale": "minor",
        "style": {
            "drum_style": "four_on_floor", "use_anvil": True, "steam_fx": True,
            "bass_wave": "fm_growl",
            "bass_notes": [35, 35, 38, 40,  42, 42, 40, 38,  35, 35, 42, 40,  38, 40, 42, 37,
                           35, 35, 38, 40,  42, 45, 42, 40,  38, 38, 40, 42,  35, 37, 38, 42],
            "chords": [[47, 50, 54], [43, 47, 50], [45, 49, 52], [42, 45, 49]],
            "lead_wave": "synth_acid",
            "lead_notes": [
                (0, 59, 0.4), (2, 62, 0.4), (4, 66, 0.8), (8, 64, 0.8), (12, 62, 0.8),
                (16, 59, 0.4), (18, 66, 0.4), (20, 71, 0.8), (24, 69, 0.8),
                (32, 74, 0.5), (36, 71, 0.5), (40, 66, 0.5), (44, 62, 0.5), (48, 59, 2.0)
            ]
        }
    },
    "ost_osservatorio": {
        "bpm": 125,
        "root": 57, # A
        "scale": "minor",
        "style": {
            "drum_style": "four_on_floor", "steam_fx": False,
            "bass_wave": "sub_sine",
            "bass_notes": [33, 33, 36, 38,  40, 40, 38, 36,  33, 33, 40, 38,  36, 38, 40, 35,
                           33, 33, 36, 38,  40, 43, 40, 38,  36, 36, 38, 40,  33, 35, 36, 40],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "glock",
            "lead_notes": [
                (0, 69, 0.5), (2, 72, 0.5), (4, 76, 1.0), (8, 74, 0.5), (10, 72, 0.5), (12, 69, 1.5),
                (16, 76, 0.5), (18, 79, 0.5), (20, 81, 1.0), (24, 79, 0.5), (26, 76, 0.5), (28, 72, 1.5),
                (32, 84, 0.8), (36, 81, 0.8), (40, 76, 0.8), (44, 72, 0.8), (48, 69, 2.5)
            ]
        }
    },
    "ost_tempesta": {
        "bpm": 160,
        "root": 66, # F#
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "use_anvil": False, "steam_fx": True,
            "bass_wave": "fm_growl",
            "bass_notes": [42, 42, 45, 47,  49, 49, 47, 45,  42, 42, 49, 47,  45, 47, 49, 44,
                           42, 42, 45, 47,  49, 52, 49, 47,  45, 45, 47, 49,  42, 44, 45, 49],
            "chords": [[54, 57, 61], [50, 54, 57], [52, 56, 59], [49, 52, 56]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 66, 0.5), (2, 69, 0.5), (4, 73, 1.0), (8, 71, 0.5), (10, 69, 0.5), (12, 66, 1.5),
                (16, 73, 0.5), (18, 76, 0.5), (20, 78, 1.0), (24, 76, 0.5), (26, 73, 0.5), (28, 69, 1.5),
                (32, 81, 0.8), (36, 78, 0.8), (40, 73, 0.8), (44, 69, 0.8), (48, 66, 2.5)
            ]
        }
    },
    "ost_abissale": {
        "bpm": 120,
        "root": 61, # C#
        "scale": "minor",
        "style": {
            "drum_style": "ambient_tick", "steam_fx": True,
            "bass_wave": "sub_sine",
            "bass_notes": [25, 25, 25, 25,  28, 28, 28, 28,  30, 30, 30, 30,  32, 32, 32, 32,
                           25, 25, 25, 25,  28, 28, 28, 28,  30, 30, 30, 30,  25, 25, 28, 32],
            "chords": [[49, 52, 56], [45, 49, 52], [47, 51, 54], [44, 47, 51]],
            "lead_wave": "glock", # sonar ping
            "lead_notes": [
                (0, 73, 2.0), (16, 76, 2.0), (32, 80, 2.0), (48, 73, 3.0)
            ]
        }
    },
    "ost_caldera": {
        "bpm": 136,
        "root": 64, # E
        "scale": "minor",
        "style": {
            "drum_style": "taiko_tribal", "use_anvil": True, "steam_fx": True,
            "bass_wave": "fm_growl",
            "bass_notes": [28, 28, 31, 33,  35, 35, 33, 31,  28, 28, 35, 33,  31, 33, 35, 30,
                           28, 28, 31, 33,  35, 38, 35, 33,  31, 31, 33, 35,  28, 30, 31, 35],
            "chords": [[40, 43, 47], [36, 40, 43], [38, 42, 45], [35, 38, 42]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 52, 1.0), (4, 55, 1.0), (8, 59, 1.5), (12, 57, 1.0),
                (16, 60, 1.0), (20, 59, 1.0), (24, 55, 1.0), (28, 52, 2.0),
                (32, 64, 1.0), (36, 62, 1.0), (40, 59, 1.0), (44, 55, 1.0), (48, 52, 3.0)
            ]
        }
    },
    "ost_orrery": {
        "bpm": 126,
        "root": 62, # D Major
        "scale": "major",
        "style": {
            "drum_style": "four_on_floor", "steam_fx": False,
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 42, 45,  47, 47, 45, 42,  38, 38, 45, 43,  42, 45, 47, 40,
                           38, 38, 42, 45,  47, 50, 47, 45,  43, 43, 45, 47,  38, 40, 42, 45],
            "chords": [[50, 54, 57], [45, 49, 52], [47, 50, 54], [43, 47, 50]],
            "lead_wave": "glock",
            "lead_notes": [
                (0, 62, 0.5), (2, 66, 0.5), (4, 69, 1.0), (8, 71, 0.5), (10, 69, 0.5), (12, 66, 1.5),
                (16, 69, 0.5), (18, 73, 0.5), (20, 74, 1.0), (24, 73, 0.5), (26, 69, 0.5), (28, 66, 1.5),
                (32, 78, 0.8), (36, 74, 0.8), (40, 69, 0.8), (44, 66, 0.8), (48, 62, 2.5)
            ]
        }
    },
    "ost_torii": {
        "bpm": 116,
        "root": 62, # D Minor / In-sen
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 41, 43,  45, 45, 43, 41,  38, 38, 45, 43,  41, 43, 45, 38,
                           38, 38, 41, 43,  45, 48, 45, 43,  41, 41, 43, 45,  38, 41, 43, 45],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "flute",
            "lead_notes": [
                (0, 62, 1.0), (4, 63, 0.8), (8, 67, 1.5), (12, 69, 1.0),
                (16, 70, 1.0), (20, 69, 1.0), (24, 67, 1.0), (28, 63, 1.5),
                (32, 62, 1.0), (36, 67, 1.0), (40, 74, 1.5), (44, 72, 1.0), (48, 62, 3.0)
            ]
        }
    },
    "ost_medina": {
        "bpm": 122,
        "root": 62, # D Hijaz (D, Eb, F#, G, A, Bb, C)
        "scale": "hijaz",
        "style": {
            "drum_style": "breakbeat", "use_anvil": True, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 39, 42,  43, 43, 42, 39,  38, 38, 45, 43,  42, 43, 45, 39,
                           38, 38, 39, 42,  43, 46, 43, 42,  39, 39, 42, 43,  38, 39, 42, 45],
            "chords": [[50, 54, 57], [49, 52, 55], [47, 50, 54], [45, 48, 52]],
            "lead_wave": "pluck", # electric oud
            "lead_notes": [
                (0, 62, 0.5), (2, 63, 0.5), (4, 66, 1.0), (8, 67, 0.8), (12, 66, 0.8), (14, 63, 0.8),
                (16, 62, 1.0), (20, 66, 0.5), (22, 67, 0.5), (24, 69, 1.5), (28, 67, 0.5), (30, 66, 0.5),
                (32, 70, 0.8), (36, 69, 0.8), (40, 67, 0.8), (44, 66, 0.8), (48, 62, 3.0)
            ]
        }
    },
    "ost_carioca": {
        "bpm": 134,
        "root": 55, # G Major
        "scale": "major",
        "style": {
            "drum_style": "samba", "use_anvil": False, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [31, 31, 35, 38,  40, 40, 38, 35,  31, 31, 38, 36,  35, 38, 40, 33,
                           31, 31, 35, 38,  40, 43, 40, 38,  36, 36, 38, 40,  31, 33, 35, 38],
            "chords": [[43, 47, 50], [38, 42, 45], [40, 43, 47], [36, 40, 43]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 55, 0.5), (3, 59, 0.5), (6, 62, 1.0), (10, 64, 0.5), (12, 62, 1.0),
                (16, 59, 0.5), (19, 62, 0.5), (22, 67, 1.5), (28, 64, 1.0),
                (32, 67, 0.5), (35, 69, 0.5), (38, 71, 1.0), (42, 67, 1.0), (48, 55, 2.5)
            ]
        }
    },
    "ost_aurora": {
        "bpm": 120,
        "root": 57, # A Minor
        "scale": "minor",
        "style": {
            "drum_style": "ambient_tick", "steam_fx": False,
            "bass_wave": "sub_sine",
            "bass_notes": [33, 33, 33, 33,  36, 36, 36, 36,  38, 38, 38, 38,  40, 40, 40, 40,
                           33, 33, 33, 33,  36, 36, 36, 36,  38, 38, 38, 38,  33, 33, 36, 40],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "strings", # tagelharpa
            "lead_notes": [
                (0, 57, 2.0), (8, 60, 2.0), (16, 64, 2.0), (24, 62, 2.0),
                (32, 65, 1.5), (38, 64, 1.0), (42, 60, 2.0), (48, 57, 3.0)
            ]
        }
    },
    "ost_egeo": {
        "bpm": 128,
        "root": 64, # E Phrygian (E, F, G, A, B, C, D)
        "scale": "phrygian",
        "style": {
            "drum_style": "four_on_floor", "use_anvil": True, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [28, 28, 29, 31,  33, 33, 31, 29,  28, 28, 35, 33,  31, 33, 35, 29,
                           28, 28, 29, 31,  33, 36, 33, 31,  29, 29, 31, 33,  28, 29, 31, 35],
            "chords": [[40, 43, 47], [41, 45, 48], [38, 42, 45], [36, 40, 43]],
            "lead_wave": "pluck", # bouzouki
            "lead_notes": [
                (0, 64, 0.4), (2, 65, 0.4), (4, 67, 0.8), (8, 69, 0.8), (12, 67, 0.8), (14, 65, 0.8),
                (16, 64, 1.0), (20, 67, 0.5), (22, 69, 0.5), (24, 71, 1.5), (28, 69, 0.5), (30, 67, 0.5),
                (32, 72, 0.8), (36, 71, 0.8), (40, 69, 0.8), (44, 67, 0.8), (48, 64, 3.0)
            ]
        }
    },
    "ost_heritage_hall": {
        "bpm": 115,
        "root": 60, # C Minor
        "scale": "minor",
        "style": {
            "drum_style": "ambient_tick", "steam_fx": False,
            "bass_wave": "sub_sine",
            "bass_notes": [36, 36, 39, 41,  43, 43, 41, 39,  36, 36, 43, 41,  39, 41, 43, 38,
                           36, 36, 39, 41,  43, 46, 43, 41,  39, 39, 41, 43,  36, 38, 39, 43],
            "chords": [[48, 51, 55], [44, 48, 51], [46, 50, 53], [43, 46, 50]],
            "lead_wave": "strings",
            "lead_notes": [
                (0, 60, 1.5), (6, 63, 1.0), (10, 67, 2.0), (16, 65, 1.0), (20, 63, 1.0), (24, 60, 2.5),
                (32, 72, 1.5), (38, 70, 1.0), (42, 67, 1.5), (46, 63, 1.0), (48, 60, 3.0)
            ]
        }
    },
    "ost_steam_workshop": {
        "bpm": 138,
        "root": 64, # E Minor / Blues
        "scale": "minor",
        "style": {
            "drum_style": "train_chug", "use_anvil": True, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [28, 28, 31, 33,  34, 35, 33, 31,  28, 28, 35, 33,  31, 33, 35, 30,
                           28, 28, 31, 33,  34, 35, 38, 35,  33, 33, 34, 35,  28, 30, 31, 35],
            "chords": [[40, 43, 47], [36, 40, 43], [38, 42, 45], [35, 38, 42]],
            "lead_wave": "slide", # blues slide guitar
            "lead_notes": [
                (0, 52, 0.8), (3, 55, 0.8), (6, 57, 1.2), (10, 58, 0.5), (12, 59, 1.5),
                (16, 57, 0.8), (20, 55, 0.8), (24, 52, 2.0),
                (32, 64, 0.8), (36, 67, 0.8), (40, 71, 1.5), (46, 69, 1.0), (48, 52, 3.0)
            ]
        }
    },
    "ost_climax": {
        "bpm": 140,
        "root": 62, # D Minor
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "use_anvil": True, "steam_fx": True, "kick_sat": 1.9,
            "bass_wave": "fm_growl",
            "bass_notes": [38, 38, 38, 38,  41, 41, 41, 41,  45, 45, 45, 45,  46, 46, 45, 43,
                           38, 38, 38, 38,  41, 41, 41, 41,  45, 45, 45, 45,  48, 48, 46, 45],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "synth_acid",
            "lead_notes": [
                (0, 62, 0.3), (2, 65, 0.3), (4, 69, 0.5), (6, 72, 0.5), (8, 74, 1.0),
                (12, 72, 0.5), (14, 69, 0.5), (16, 65, 1.0),
                (20, 62, 0.3), (22, 65, 0.3), (24, 74, 1.5),
                (32, 77, 0.5), (34, 76, 0.5), (36, 74, 0.5), (38, 72, 0.5),
                (40, 69, 0.8), (44, 65, 0.8), (48, 62, 2.5)
            ]
        }
    },
    "ost_victory": {
        "bpm": 110,
        "root": 60, # C Major
        "scale": "major",
        "style": {
            "drum_style": "four_on_floor", "use_anvil": True, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [36, 36, 40, 43,  45, 45, 43, 40,  36, 36, 43, 41,  40, 43, 45, 38,
                           36, 36, 40, 43,  45, 48, 45, 43,  41, 41, 43, 45,  36, 38, 40, 43],
            "chords": [[48, 52, 55], [43, 47, 50], [45, 48, 52], [41, 45, 48]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 60, 0.8), (3, 64, 0.5), (4, 67, 1.5), (8, 69, 0.8), (11, 71, 0.5), (12, 72, 2.0),
                (16, 67, 0.8), (19, 69, 0.5), (20, 72, 1.5), (24, 76, 1.0), (28, 72, 2.0),
                (32, 72, 0.8), (35, 74, 0.5), (36, 76, 1.2), (40, 79, 1.5), (44, 76, 1.0),
                (48, 72, 3.5)
            ]
        }
    },
    # --- 8 EPIC / ANIME STEAMPUNK SPECIAL SOUNDTRACKS ---
    "ost_epic_anthem": {
        "bpm": 150,
        "root": 64, # E Minor
        "scale": "minor",
        "style": {
            "drum_style": "anime_rock", "use_anvil": True, "steam_fx": True, "kick_sat": 1.6,
            "bass_wave": "saw_pluck",
            "bass_notes": [28, 28, 28, 31,  33, 33, 31, 28,  36, 36, 36, 36,  38, 38, 38, 38,
                           28, 28, 28, 31,  33, 33, 31, 28,  36, 36, 38, 38,  28, 31, 35, 38],
            "chords": [[40, 43, 47], [36, 40, 43], [38, 42, 45], [43, 47, 50]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 64, 0.5), (2, 67, 0.5), (4, 71, 1.0), (8, 69, 0.5), (10, 67, 0.5), (12, 64, 1.5),
                (16, 67, 0.5), (18, 71, 0.5), (20, 74, 1.0), (24, 76, 1.5), (28, 74, 0.5), (30, 71, 0.5),
                (32, 76, 1.0), (36, 79, 1.0), (40, 83, 1.5), (46, 81, 0.5), (48, 76, 3.0)
            ]
        }
    },
    "ost_epic_semifinal": {
        "bpm": 145,
        "root": 62, # D Minor
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "use_anvil": True, "steam_fx": True, "kick_sat": 1.7,
            "bass_wave": "fm_growl",
            "bass_notes": [38, 38, 41, 43,  45, 45, 43, 41,  34, 34, 38, 41,  36, 36, 40, 43,
                           38, 38, 41, 43,  45, 45, 43, 41,  34, 34, 36, 36,  38, 41, 45, 48],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 62, 0.4), (2, 65, 0.4), (4, 69, 0.8), (8, 67, 0.4), (10, 65, 0.4), (12, 69, 1.2),
                (16, 70, 0.4), (18, 72, 0.4), (20, 74, 1.0), (24, 77, 1.0), (28, 76, 1.0),
                (32, 74, 0.5), (36, 72, 0.5), (40, 69, 0.5), (44, 65, 0.5), (48, 62, 2.5)
            ]
        }
    },
    "ost_epic_grand_final": {
        "bpm": 148,
        "root": 59, # B Minor (Sawano Epic)
        "scale": "minor",
        "style": {
            "drum_style": "sawano_climax", "use_anvil": True, "steam_fx": True, "kick_sat": 1.9,
            "bass_wave": "fm_growl",
            "bass_notes": [35, 35, 35, 35,  31, 31, 31, 31,  33, 33, 33, 33,  30, 30, 30, 30,
                           35, 35, 35, 35,  31, 31, 31, 31,  33, 33, 33, 33,  35, 38, 42, 45],
            "chords": [[47, 50, 54], [43, 47, 50], [45, 49, 52], [42, 45, 49]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 59, 1.0), (4, 62, 1.0), (8, 66, 1.5), (12, 64, 1.0),
                (16, 67, 1.0), (20, 66, 1.0), (24, 71, 2.0),
                (32, 74, 1.0), (36, 73, 1.0), (40, 71, 1.0), (44, 66, 1.0), (48, 59, 3.5)
            ]
        }
    },
    "ost_epic_rival_legend": {
        "bpm": 155,
        "root": 66, # F# Minor
        "scale": "minor",
        "style": {
            "drum_style": "anime_rock", "use_anvil": True, "steam_fx": True, "kick_sat": 1.7,
            "bass_wave": "fm_growl",
            "bass_notes": [42, 42, 45, 47,  49, 49, 47, 45,  38, 38, 42, 45,  40, 40, 44, 47,
                           42, 42, 45, 47,  49, 49, 47, 45,  38, 38, 40, 40,  42, 45, 49, 52],
            "chords": [[54, 57, 61], [50, 54, 57], [52, 56, 59], [49, 52, 56]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 66, 0.4), (2, 69, 0.4), (4, 73, 0.8), (8, 71, 0.4), (10, 69, 0.4), (12, 66, 1.2),
                (16, 69, 0.4), (18, 73, 0.4), (20, 76, 0.8), (24, 78, 1.5), (28, 76, 0.5), (30, 73, 0.5),
                (32, 81, 0.8), (36, 78, 0.8), (40, 73, 0.8), (44, 69, 0.8), (48, 66, 2.8)
            ]
        }
    },
    "ost_epic_awakening": {
        "bpm": 165,
        "root": 69, # A Minor (Power Metal 165 BPM)
        "scale": "minor",
        "style": {
            "drum_style": "power_metal", "use_anvil": True, "steam_fx": True, "kick_sat": 1.8,
            "bass_wave": "saw_pluck",
            "bass_notes": [33, 33, 33, 33,  29, 29, 29, 29,  31, 31, 31, 31,  28, 28, 28, 28,
                           33, 33, 33, 33,  29, 29, 29, 29,  31, 31, 31, 31,  33, 36, 40, 43],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 69, 0.3), (2, 72, 0.3), (4, 76, 0.8), (8, 74, 0.4), (10, 72, 0.4), (12, 76, 1.2),
                (16, 77, 0.4), (18, 79, 0.4), (20, 81, 1.0), (24, 84, 1.5), (28, 81, 0.8),
                (32, 81, 0.5), (36, 79, 0.5), (40, 76, 0.5), (44, 72, 0.5), (48, 69, 3.0)
            ]
        }
    },
    "ost_epic_sudden_death": {
        "bpm": 142,
        "root": 62, # D Minor
        "scale": "minor",
        "style": {
            "drum_style": "breakbeat", "use_anvil": True, "steam_fx": True, "kick_sat": 2.0,
            "bass_wave": "sub_sine",
            "bass_notes": [38, 38, 38, 38,  37, 37, 37, 37,  36, 36, 36, 36,  35, 35, 35, 35,
                           34, 34, 34, 34,  33, 33, 33, 33,  34, 34, 36, 36,  38, 41, 45, 48],
            "chords": [[50, 53, 57], [49, 53, 57], [48, 52, 55], [45, 49, 52]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 62, 0.25), (2, 63, 0.25), (4, 65, 0.5), (6, 68, 0.5), (8, 69, 1.0),
                (12, 68, 0.5), (14, 65, 0.5), (16, 62, 1.0),
                (20, 62, 0.25), (22, 65, 0.25), (24, 74, 1.5),
                (32, 77, 0.4), (34, 76, 0.4), (36, 74, 0.4), (38, 73, 0.4),
                (40, 69, 0.8), (44, 65, 0.8), (48, 62, 3.0)
            ]
        }
    },
    "ost_epic_ascension": {
        "bpm": 130,
        "root": 67, # G Major (Emotional Anthem)
        "scale": "major",
        "style": {
            "drum_style": "sawano_climax", "use_anvil": True, "steam_fx": True,
            "bass_wave": "saw_pluck",
            "bass_notes": [31, 31, 31, 31,  38, 38, 38, 38,  40, 40, 40, 40,  36, 36, 36, 36,
                           31, 31, 31, 31,  38, 38, 38, 38,  40, 40, 43, 43,  36, 38, 40, 43],
            "chords": [[43, 47, 50], [38, 42, 45], [40, 43, 47], [36, 40, 43]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 67, 1.0), (4, 71, 0.8), (8, 74, 1.5), (12, 76, 0.8), (14, 74, 0.8),
                (16, 71, 1.0), (20, 74, 0.8), (24, 79, 2.0),
                (32, 83, 1.0), (36, 81, 1.0), (40, 79, 1.2), (44, 74, 1.0), (48, 67, 3.5)
            ]
        }
    },
    "ost_epic_rematch": {
        "bpm": 138,
        "root": 60, # C Minor (Defiance)
        "scale": "minor",
        "style": {
            "drum_style": "anime_rock", "use_anvil": True, "steam_fx": True, "kick_sat": 1.7,
            "bass_wave": "fm_growl",
            "bass_notes": [36, 36, 36, 36,  32, 32, 32, 32,  39, 39, 39, 39,  34, 34, 34, 34,
                           36, 36, 36, 36,  32, 32, 32, 32,  34, 34, 36, 36,  36, 39, 43, 46],
            "chords": [[48, 51, 55], [44, 48, 51], [51, 55, 58], [46, 50, 53]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 60, 0.5), (2, 63, 0.5), (4, 67, 1.0), (8, 65, 0.5), (10, 63, 0.5), (12, 67, 1.5),
                (16, 68, 0.5), (18, 70, 0.5), (20, 72, 1.2), (24, 75, 1.5), (28, 74, 1.0),
                (32, 72, 0.8), (36, 70, 0.8), (40, 67, 0.8), (44, 63, 0.8), (48, 60, 3.0)
            ]
        }
    }
}

def main():
    import sys
    targets = sys.argv[1:] if len(sys.argv) > 1 else list(TRACKS.keys())
    print(f"--- Synthesizing {len(targets)} Steam Circuit Padel Pro OSTs (Total Catalog: {len(TRACKS)}) ---")
    os.makedirs(OUT_DIR, exist_ok=True)
    t0 = time.time()
    for tid in targets:
        if tid in TRACKS:
            cfg = TRACKS[tid]
            render_track(tid, cfg["bpm"], cfg["root"], cfg["scale"], cfg["style"])
        else:
            print(f"  [WARN] Unknown track ID: {tid}")
    t1 = time.time()
    print(f"\n{len(targets)} tracks successfully generated in {t1 - t0:.2f} seconds!")

if __name__ == "__main__":
    main()
