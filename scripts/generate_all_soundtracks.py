#!/usr/bin/env python3
"""
generate_all_soundtracks.py — Multi-Timbral Procedural Audio Engine
Generates 30 radically distinct, genre-specific steampunk OST tracks:
- Unique rhythm engines (Swing shuffle, 160 BPM Amen DnB, Samba Batucada, Power Metal, Taiko, Industrial, Baroque)
- Dedicated acoustic/electric instruments (Pipe organ, Shamisen, Bouzouki, Oud, J-Rock guitar, Upright bass, Reese bass, Sonar ping, Agogo bells, Steam whistle, etc.)
- Multi-section arrangements (~45s per track) with loop continuity.
"""

import math
import os
import random
import struct
import subprocess
import sys
import time
import wave

SAMPLE_RATE = 44100
OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../godot/assets/audio/music"))
FFMPEG = "/opt/homebrew/bin/ffmpeg"

def note_freq(midi):
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))

# ============================================================================
# 1. SPECIALIZED PERCUSSION GENERATORS
# ============================================================================

def make_kick(kind="punchy", duration=0.28):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    for i in range(length):
        t = i / SAMPLE_RATE
        if kind == "sub808":
            pitch = 95.0 * math.exp(-t * 14.0) + 38.0
            env = math.exp(-t * 5.0)
            s = math.sin(2.0 * math.pi * pitch * t)
            s = math.tanh(s * 1.5) * env * 0.95
        elif kind == "rock":
            pitch = 160.0 * math.exp(-t * 35.0) + 48.0
            env = math.exp(-t * 22.0)
            s = math.sin(2.0 * math.pi * pitch * t)
            s = math.tanh(s * 1.8) * env * 0.95
        elif kind == "surdo":
            pitch = 75.0 * math.exp(-t * 8.0) + 42.0
            env = math.exp(-t * 7.0)
            s = math.sin(2.0 * math.pi * pitch * t) + 0.25 * math.sin(4.0 * math.pi * pitch * t)
            s = math.tanh(s * 1.3) * env * 0.95
        elif kind == "taiko":
            pitch = 68.0 * (1.0 + 0.45 * math.exp(-t * 25.0))
            env = math.exp(-t * 8.0)
            p = 2.0 * math.pi * pitch * t
            s = (math.sin(p) + 0.35 * math.sin(p * 1.52) + 0.18 * math.sin(p * 2.3)) * env
            s = math.tanh(s * 1.6) * 0.95
        else: # punchy 4-on-the-floor
            pitch = 135.0 * math.exp(-t * 24.0) + 42.0
            env = math.exp(-t * 16.0)
            s = math.sin(2.0 * math.pi * pitch * t)
            s = math.tanh(s * 1.5) * env * 0.95
        smp[i] = s
    return smp

def make_snare(kind="standard", duration=0.26):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    rnd = random.Random(42)
    for i in range(length):
        t = i / SAMPLE_RATE
        if kind == "rock":
            tone = math.sin(2.0 * math.pi * 210.0 * t) * math.exp(-t * 20.0)
            noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 18.0)
            s = math.tanh(tone * 0.6 + noise * 0.8) * 0.9
        elif kind == "brush":
            noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 12.0)
            s = noise * 0.45
        elif kind == "darbuka_tek":
            tone = math.sin(2.0 * math.pi * 840.0 * t) * math.exp(-t * 40.0)
            noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 60.0)
            s = (tone * 0.7 + noise * 0.4) * 0.85
        elif kind == "hyoshigi": # Japanese wooden block
            tone = (math.sin(2.0 * math.pi * 1850.0 * t) * 0.7 + math.sin(2.0 * math.pi * 2780.0 * t) * 0.4) * math.exp(-t * 55.0)
            snap = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 90.0) * 0.4
            s = (tone + snap) * 0.9
        elif kind == "anvil": # Resonant steel anvil
            f1, f2, f3 = 1120.0, 1840.0, 3150.0
            tone = (math.sin(2.0*math.pi*f1*t)*0.5 + math.sin(2.0*math.pi*f2*t)*0.35 + math.sin(2.0*math.pi*f3*t)*0.2) * math.exp(-t * 9.0)
            noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 28.0) * 0.3
            s = math.tanh(tone * 0.8 + noise) * 0.9
        elif kind == "rimshot":
            tone = math.sin(2.0 * math.pi * 580.0 * t) * math.exp(-t * 35.0)
            noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 45.0)
            s = (tone * 0.6 + noise * 0.5) * 0.8
        else: # standard
            tone = math.sin(2.0 * math.pi * 260.0 * t) * math.exp(-t * 26.0)
            noise = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 22.0)
            s = math.tanh(tone * 0.4 + noise * 0.7) * 0.85
        smp[i] = s
    return smp

def make_agogo(high=True):
    length = int(0.18 * SAMPLE_RATE)
    smp = [0.0] * length
    freq = 1120.0 if high else 760.0
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 18.0)
        s = (math.sin(2.0 * math.pi * freq * t) + 0.35 * math.sin(2.0 * math.pi * freq * 2.04 * t)) * env
        smp[i] = s * 0.6
    return smp

def make_tick(pitch_high=True):
    length = int(0.035 * SAMPLE_RATE)
    smp = [0.0] * length
    freq = 5400.0 if pitch_high else 3200.0
    rnd = random.Random(101 if pitch_high else 202)
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 140.0)
        s = (math.sin(2.0 * math.pi * freq * t) * 0.6 + (rnd.random() * 2.0 - 1.0) * 0.4) * env
        smp[i] = s * 0.5
    return smp

def make_crash_cymbal(duration=1.4):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    rnd = random.Random(555)
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 3.5)
        # filtered metallic noise
        n = (rnd.random() * 2.0 - 1.0)
        s = (n * 0.8 + math.sin(2.0 * math.pi * 6200.0 * t) * 0.2) * env * 0.4
        smp[i] = s
    return smp

def make_steam_whistle(duration=0.45):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    for i in range(length):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * t / duration) if t < duration else 0.0
        p = 2.0 * math.pi * 1760.0 * t
        s = (math.sin(p) + 0.4 * math.sin(2*p) + 0.15 * math.sin(3*p)) * env * 0.55
        smp[i] = s
    return smp

def make_sonar_ping(duration=1.2):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    f = 1180.0
    for i in range(length):
        t = i / SAMPLE_RATE
        p0 = math.sin(2.0 * math.pi * f * t) * math.exp(-t * 7.0)
        e1 = math.sin(2.0 * math.pi * f * (t - 0.35)) * math.exp(-(t - 0.35) * 8.0) * 0.4 if t >= 0.35 else 0.0
        e2 = math.sin(2.0 * math.pi * f * (t - 0.70)) * math.exp(-(t - 0.70) * 9.0) * 0.16 if t >= 0.70 else 0.0
        smp[i] = (p0 + e1 + e2) * 0.7
    return smp

def make_steam(duration=0.38):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    rnd = random.Random(777)
    for i in range(length):
        t = i / SAMPLE_RATE
        env = (t / 0.04) if t < 0.04 else math.exp(-(t - 0.04) * 9.0)
        n = (rnd.random() * 2.0 - 1.0)
        s = (n * 0.75 + math.sin(2.0 * math.pi * 3800.0 * t) * 0.25) * env * 0.45
        smp[i] = s
    return smp

def make_siren(duration=0.8):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    for i in range(length):
        t = i / SAMPLE_RATE
        freq = 440.0 + 440.0 * (t / duration)
        env = (t / 0.1) if t < 0.1 else (1.0 - (t - 0.1) / (duration - 0.1))
        s = math.sin(2.0 * math.pi * freq * t) * env * 0.4
        smp[i] = s
    return smp

def make_vinyl_crackle(duration=0.6):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    rnd = random.Random(888)
    for i in range(length):
        # sporadic clicks
        if rnd.random() < 0.003:
            smp[i] = (rnd.random() * 2.0 - 1.0) * 0.15
    return smp


# ============================================================================
# 2. SPECIALIZED BASSLINE SYNTHESIZERS
# ============================================================================

def make_bass(midi, duration, waveform="saw_pluck"):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    f = note_freq(midi)
    for i in range(length):
        t = i / SAMPLE_RATE
        if waveform == "upright_bass": # Acoustic upright walking bass
            env = math.exp(-t * 4.2)
            p = 2.0 * math.pi * f * t
            s = math.sin(p) + 0.35 * math.sin(2*p) + 0.12 * math.sin(3*p)
            # soft thumb transient
            thumb = math.sin(2.0 * math.pi * 90.0 * t) * math.exp(-t * 30.0) * 0.4
            s = (s + thumb) * env * 0.9
        elif waveform == "reese_bass": # Detuned beating DnB saw
            env = math.exp(-t * 2.0)
            p1 = 2.0 * math.pi * (f - 1.2) * t
            p2 = 2.0 * math.pi * (f + 1.2) * t
            s = (math.sin(p1) + 0.4 * math.sin(2*p1) + math.sin(p2) + 0.4 * math.sin(2*p2)) * 0.5
            s = math.tanh(s * 1.5) * env * 0.85
        elif waveform == "slap_bass": # Funk slap with pop transient
            env = math.exp(-t * 5.0)
            p = 2.0 * math.pi * f * t
            pop = math.sin(2.0 * math.pi * (f * 4.0) * t) * math.exp(-t * 40.0) * 0.6
            s = (math.sin(p) + 0.6 * math.sin(2*p) + 0.4 * math.sin(3*p) + pop)
            s = math.tanh(s * 1.4) * env * 0.85
        elif waveform == "sub_sine": # Deep pure 40-50Hz sub
            env = math.exp(-t * 2.2)
            s = (math.sin(2.0 * math.pi * f * t) + 0.2 * math.sin(4.0 * math.pi * f * t)) * env * 0.9
        elif waveform == "power_bass": # Overdriven rock bass
            env = math.exp(-t * 3.2)
            p = 2.0 * math.pi * f * t
            s = math.sin(p) + 0.7 * math.sin(2*p) + 0.5 * math.sin(3*p)
            s = math.tanh(s * 2.0) * env * 0.8
        elif waveform == "cello_drone": # Bowed cello with vibrato
            vib = 1.0 + 0.015 * math.sin(2.0 * math.pi * 5.0 * t)
            p = 2.0 * math.pi * f * vib * t
            env = (t / 0.08) if t < 0.08 else math.exp(-(t - 0.08) * 1.8)
            s = (math.sin(p) + 0.5 * math.sin(2*p) + 0.3 * math.sin(3*p)) * env * 0.8
        else: # saw_pluck
            env = math.exp(-t * 3.8)
            p = 2.0 * math.pi * f * t
            s = math.sin(p) + 0.5 * math.sin(2*p) + 0.3 * math.sin(3*p)
            s = math.tanh(s * 1.3) * env * 0.85
        smp[i] = s
    return smp


# ============================================================================
# 3. SPECIALIZED LEAD & HARMONIC INSTRUMENT SYNTHESIZERS
# ============================================================================

def make_lead(midi, duration, waveform="brass"):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    f = note_freq(midi)
    
    if waveform == "pipe_organ": # Liturgical Baroque Pipe Organ (drawbars: 16', 8', 4', 2')
        drawbars = [(0.5, 0.5), (1.0, 1.0), (2.0, 0.6), (4.0, 0.35)]
        for mult, amp in drawbars:
            freq = f * mult
            p = 2.0 * math.pi * freq
            for i in range(length):
                t = i / SAMPLE_RATE
                smp[i] += math.sin(p * t) * amp
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / 0.03) if t < 0.03 else (1.0 if t < duration - 0.04 else (duration - t) / 0.04)
            smp[i] = smp[i] * env * 0.28
        return smp

    elif waveform == "shamisen": # Japanese silk plucked string with bachi snap
        rnd = random.Random(midi)
        for i in range(length):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 10.0)
            p = 2.0 * math.pi * f * t
            tone = math.sin(p) + 0.7 * math.sin(2*p) + 0.5 * math.sin(3*p) + 0.3 * math.sin(4*p)
            snap = (rnd.random() * 2.0 - 1.0) * math.exp(-t * 85.0) * 0.7
            smp[i] = (tone * 0.65 + snap) * env * 0.85
        return smp

    elif waveform == "oud_tremolo": # Arabic Oud with tremolo flutter
        for i in range(length):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 8.0)
            tremolo = 1.0 + 0.35 * math.sin(2.0 * math.pi * 14.0 * t)
            p = 2.0 * math.pi * f * t
            s = (math.sin(p) + 0.6 * math.sin(2*p) + 0.3 * math.sin(3*p)) * tremolo * env * 0.75
            smp[i] = s
        return smp

    elif waveform == "bouzouki": # Greek double string chorused bouzouki
        for i in range(length):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 9.0)
            p1 = 2.0 * math.pi * f * t
            p2 = 2.0 * math.pi * (f * 1.004) * t
            s = (math.sin(p1) + 0.5 * math.sin(2*p1) + math.sin(p2) + 0.5 * math.sin(2*p2)) * 0.5
            smp[i] = s * env * 0.8
        return smp

    elif waveform == "jrock_guitar": # Screaming overdrive electric guitar
        att = 0.015
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / att) if t < att else math.exp(-(t - att) * 2.8)
            p = 2.0 * math.pi * f * t
            raw = math.sin(p) + 0.6 * math.sin(1.5 * p) + 0.5 * math.sin(2.0 * p) + 0.3 * math.sin(3.0 * p)
            s = math.tanh(raw * 2.8) * 0.85 * env
            smp[i] = s
        return smp

    elif waveform == "slide_guitar": # Blues slide guitar gliding up
        att = 0.02
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / att) if t < att else math.exp(-(t - att) * 3.0)
            f_slide = f * (1.0 + 0.09 * math.exp(-t * 4.5))
            p = 2.0 * math.pi * f_slide * t
            s = (math.sin(p) + 0.45 * math.sin(2*p) + 0.25 * math.sin(3*p)) * env * 0.75
            smp[i] = s
        return smp

    elif waveform == "accordion": # French musette accordion with detuned reeds
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / 0.03) if t < 0.03 else math.exp(-(t - 0.03) * 3.5)
            p1 = 2.0 * math.pi * f * t
            p2 = 2.0 * math.pi * (f + 2.5) * t # Musette detune
            s = (math.sin(p1) + 0.7 * math.sin(2*p1) + math.sin(p2) + 0.7 * math.sin(2*p2)) * 0.45
            smp[i] = math.sin(s * 1.5) * env * 0.75
        return smp

    elif waveform == "shakuhachi": # Breathy bamboo flute with vibrato
        rnd = random.Random(midi)
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / 0.08) if t < 0.08 else math.exp(-(t - 0.08) * 2.2)
            vib = 1.0 + 0.03 * math.sin(2.0 * math.pi * 5.5 * t) if t > 0.1 else 1.0
            p = 2.0 * math.pi * f * vib * t
            breath = (rnd.random() * 2.0 - 1.0) * 0.12
            s = (math.sin(p) + 0.2 * math.sin(2*p) + breath) * env * 0.8
            smp[i] = s
        return smp

    elif waveform == "epic_violin": # Soaring orchestral violin
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / 0.04) if t < 0.04 else math.exp(-(t - 0.04) * 3.2)
            vib = 1.0 + 0.02 * math.sin(2.0 * math.pi * 6.0 * t) if t > 0.08 else 1.0
            p = 2.0 * math.pi * f * vib * t
            s = (math.sin(p) + 0.5 * math.sin(2*p) + 0.3 * math.sin(3*p) + 0.15 * math.sin(4*p))
            smp[i] = math.tanh(s * 1.3) * env * 0.85
        return smp

    elif waveform in ("celesta", "glock", "chime"): # Pure crystalline clockwork chimes
        for i in range(length):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 6.5)
            p = 2.0 * math.pi * f * t
            s = (math.sin(p) + 0.45 * math.sin(2.76 * p) + 0.2 * math.sin(5.4 * p)) * env * 0.7
            smp[i] = s
        return smp

    else: # brass / default
        att = 0.025
        for i in range(length):
            t = i / SAMPLE_RATE
            env = (t / att) if t < att else math.exp(-(t - att) * 3.5)
            p = 2.0 * math.pi * f * t
            s = math.sin(p) + 0.55 * math.sin(2*p) + 0.35 * math.sin(3*p) + 0.2 * math.sin(4*p)
            smp[i] = math.tanh(s * 1.3) * env * 0.85
        return smp

def make_chord_pad(midi_list, duration, waveform="strings"):
    length = int(duration * SAMPLE_RATE)
    smp = [0.0] * length
    att = 0.09
    for i in range(length):
        t = i / SAMPLE_RATE
        env = (t / att) if t < att else math.exp(-(t - att) * 1.6)
        acc = 0.0
        for m in midi_list:
            f = note_freq(m)
            p = 2.0 * math.pi * f * t
            if waveform == "pipe_organ":
                acc += math.sin(p) + 0.6 * math.sin(2*p) + 0.4 * math.sin(4*p)
            elif waveform == "choir_pad":
                acc += math.sin(p) + math.sin(p * 1.003) * 0.5 + math.sin(2*p) * 0.3
            else:
                acc += math.sin(p) + 0.3 * math.sin(2*p)
        smp[i] = (acc / len(midi_list)) * env * 0.55
    return smp

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
    dur = total_samples / SAMPLE_RATE
    print(f"  [OK] {track_id}.ogg ({dur:.1f}s, {file_size_kb:.1f} KB)")


# ============================================================================
# 4. MULTI-SECTION DYNAMIC ARRANGER & RENDERER
# ============================================================================

def render_track(track_id, bpm, scale_root, scale_type, style_config):
    beat_len = 60.0 / bpm
    step_len = beat_len / 4.0 # 16th note
    bar_len = beat_len * 4.0
    phrase_len = bar_len * 4.0
    
    # Target ~45 seconds, aligned to integer 4-bar phrases
    cycles = max(4, int(round(45.0 / phrase_len)))
    n_bars = cycles * 4
    n_steps = n_bars * 16
    total_samples = int(n_steps * step_len * SAMPLE_RATE)
    
    left_buf = [0.0] * total_samples
    right_buf = [0.0] * total_samples
    
    # Pre-render specific instruments for this track
    kick_type = style_config.get("kick_type", "punchy")
    snare_type = style_config.get("snare_type", "standard")
    lead_wave = style_config.get("lead_wave", "brass")
    bass_wave = style_config.get("bass_wave", "saw_pluck")
    chord_wave = style_config.get("chord_wave", "strings")
    drum_style = style_config.get("drum_style", "four_on_floor")
    use_swing = style_config.get("swing", False)
    intro_mode = style_config.get("intro_mode", "instant")
    
    kick = make_kick(kind=kick_type)
    snare = make_snare(kind=snare_type)
    tick_hi = make_tick(True)
    tick_lo = make_tick(False)
    steam = make_steam()
    crash = make_crash_cymbal()
    agogo_hi = make_agogo(True)
    agogo_lo = make_agogo(False)
    sonar = make_sonar_ping()
    whistle = make_steam_whistle()
    siren = make_siren()
    crackle = make_vinyl_crackle()
    
    # Helper to calculate sample position with optional swing shuffle
    def get_pos(step_index):
        if not use_swing:
            return int(step_index * step_len * SAMPLE_RATE)
        # 16th swing shuffle: odd 16th notes (sub==1, sub==3) delayed slightly
        sub = step_index % 4
        base_beat = step_index // 4
        if sub == 0:
            frac = 0.0
        elif sub == 1:
            frac = 0.33 # Swing delayed
        elif sub == 2:
            frac = 0.50
        else: # sub == 3
            frac = 0.83 # Swing delayed
        t_sec = (base_beat + frac) * beat_len
        return int(t_sec * SAMPLE_RATE)

    # 1. PERCUSSION PATTERNS ACROSS ALL CYCLES
    for step in range(n_steps):
        t_pos = get_pos(step)
        bar = step // 16
        c = bar // 4
        beat = (step // 4) % 4
        sub = step % 4
        step_bar = step % 16
        
        # Distinct Intro cycle (c == 0)
        if c == 0:
            if intro_mode == "solo_lead":
                continue # ZERO percussion during solo lead intro! Pure instrument intimacy.
            elif intro_mode == "fx_atmosphere":
                # Only play the specific atmosphere FX, zero standard drum groove
                if style_config.get("sonar_fx", False) and step == 0:
                    mix(left_buf, right_buf, sonar, t_pos, total_samples, 0.0, 0.9)
                if style_config.get("whistle_fx", False) and step == 0:
                    mix(left_buf, right_buf, whistle, t_pos, total_samples, 0.0, 0.85)
                if style_config.get("siren_fx", False) and step == 0:
                    mix(left_buf, right_buf, siren, t_pos, total_samples, 0.0, 0.75)
                if beat in (0, 2) and sub == 0:
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.5)
                continue
            elif intro_mode == "groove_bass":
                # Vintage / swing intro: kick on 0 and 2, brush on 1 and 3, vinyl
                if sub == 0:
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.75)
                if sub == 0 and beat in (1, 3):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.65)
                if style_config.get("vinyl", False) and step % 8 == 0:
                    mix(left_buf, right_buf, crackle, t_pos, total_samples, 0.1, 0.4)
                continue
            # If intro_mode == "instant", fall through directly to the full drum groove!
            
        is_breakdown = (cycles >= 6 and c == cycles - 2)
        
        # Entrance crash cymbal when full band drops after solo intro
        if c == 1 and step_bar == 0 and intro_mode in ("solo_lead", "fx_atmosphere"):
            mix(left_buf, right_buf, crash, t_pos, total_samples, 0.0, 0.65)
        
        # --- GENRE-SPECIFIC RHYTHM ENGINES ---
        if drum_style == "four_on_floor":
            if is_breakdown:
                if beat in (0, 2) and sub == 0:
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.8)
                if beat == 2 and sub == 0:
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.6)
            else:
                if sub == 0:
                    mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.85)
                if sub == 0 and beat in (1, 3):
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.75)
            if sub in (0, 2):
                mix(left_buf, right_buf, tick_hi if sub == 2 else tick_lo, t_pos, total_samples, 0.3 if sub == 2 else -0.3, 0.4)
            if c >= cycles - 1 and step_bar == 0:
                mix(left_buf, right_buf, crash, t_pos, total_samples, -0.2, 0.5)
                
        elif drum_style == "electro_swing":
            # Swing kick on 0 and 2, snare on 1 and 3, shuffle tick-tock
            if sub == 0:
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.85)
            if sub == 0 and beat in (1, 3):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.75)
            # Shuffle hi-hat on swing offbeat
            if sub in (0, 1, 2, 3):
                tick = tick_hi if sub in (1, 3) else tick_lo
                mix(left_buf, right_buf, tick, t_pos, total_samples, 0.35 if sub%2==1 else -0.35, 0.35)
            if style_config.get("vinyl", False) and step % 8 == 0:
                mix(left_buf, right_buf, crackle, t_pos, total_samples, 0.1, 0.4)
                
        elif drum_style == "samba_batucada":
            # Syncopated Surdo on 0, 7, 10, 14; Agogô bells on 2, 5, 8, 12
            if step_bar in (0, 7, 10, 14):
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.9)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.15, 0.7)
            if step_bar in (2, 8):
                mix(left_buf, right_buf, agogo_hi, t_pos, total_samples, 0.3, 0.6)
            if step_bar in (5, 12):
                mix(left_buf, right_buf, agogo_lo, t_pos, total_samples, -0.3, 0.6)
            if step % 64 == 0 and c >= 2:
                mix(left_buf, right_buf, whistle, t_pos, total_samples, 0.2, 0.7)
                
        elif drum_style == "liquid_dnb":
            # Fast 160 BPM rolling breakbeat: kick on 0, 10; snare on 4, 12; ghost snares on 7, 14
            if step_bar in (0, 10):
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.9)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
            if step_bar in (7, 14): # Ghost snares
                mix(left_buf, right_buf, snare, t_pos, total_samples, -0.15, 0.35)
            # Continuous fast 16th rolling hat
            mix(left_buf, right_buf, tick_hi if sub % 2 == 0 else tick_lo, t_pos, total_samples, 0.25 if sub%2==0 else -0.25, 0.35)
            
        elif drum_style == "taiko_tribal":
            if step_bar in (0, 3, 8, 11, 14):
                mix(left_buf, right_buf, kick, t_pos, total_samples, -0.1 if step_bar%2==0 else 0.1, 0.95)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.2, 0.75)
            if sub in (1, 3):
                mix(left_buf, right_buf, tick_lo, t_pos, total_samples, -0.3, 0.3)
                
        elif drum_style == "locomotive_chug":
            # Accelerating train chug: double kicks on 0, 2, 8, 10
            if step_bar in (0, 2, 8, 10):
                mix(left_buf, right_buf, kick, t_pos, total_samples, -0.15, 0.85)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.2, 0.8)
            mix(left_buf, right_buf, tick_lo, t_pos, total_samples, 0.3, 0.3)
            if step % 64 == 32:
                mix(left_buf, right_buf, whistle, t_pos, total_samples, 0.15, 0.6)
                
        elif drum_style == "anime_rock":
            # Driving J-Rock: kicks on 0, 3, 8, 10; snare on 4, 12; double kick fills
            if step_bar in (0, 3, 8, 10):
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.9)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
            if c >= cycles - 1 and step_bar in (14, 15):
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.8)
            mix(left_buf, right_buf, tick_hi if sub % 2 == 0 else tick_lo, t_pos, total_samples, 0.25 if sub%2==0 else -0.25, 0.35)
            if step_bar == 0 and c >= 2:
                mix(left_buf, right_buf, crash, t_pos, total_samples, -0.2, 0.5)

        elif drum_style == "power_metal":
            # Continuous double-bass kick galloping
            if sub in (0, 2):
                mix(left_buf, right_buf, kick, t_pos, total_samples, -0.1 if sub == 0 else 0.1, 0.88)
            if step_bar in (4, 12):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
            mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.3, 0.4)
            if step_bar == 0 and c in (2, cycles - 1):
                mix(left_buf, right_buf, crash, t_pos, total_samples, -0.2, 0.6)

        elif drum_style == "sawano_climax":
            if sub == 0:
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.9)
                if beat == 0:
                    mix(left_buf, right_buf, snare, t_pos, total_samples, 0.0, 0.85)
            if sub == 0 and beat in (1, 3):
                mix(left_buf, right_buf, snare, t_pos, total_samples, 0.1, 0.85)
            if sub in (0, 2):
                mix(left_buf, right_buf, tick_hi, t_pos, total_samples, 0.3, 0.35)
            if step_bar == 0:
                mix(left_buf, right_buf, crash, t_pos, total_samples, 0.2, 0.5)

        elif drum_style == "ambient_tick":
            if sub == 0:
                mix(left_buf, right_buf, tick_hi if beat % 2 == 0 else tick_lo, t_pos, total_samples, -0.3 if beat % 2 == 0 else 0.3, 0.5)
            if step % 32 == 0:
                mix(left_buf, right_buf, kick, t_pos, total_samples, 0.0, 0.6)

        # Ambient Sonar / Siren / Steam FX
        if style_config.get("sonar_fx", False) and step % 64 == 16:
            mix(left_buf, right_buf, sonar, t_pos, total_samples, 0.25, 0.7)
        if style_config.get("siren_fx", False) and step % 64 == 48:
            mix(left_buf, right_buf, siren, t_pos, total_samples, -0.2, 0.6)
        if style_config.get("steam_fx", True) and step % 64 == 0:
            mix(left_buf, right_buf, steam, t_pos, total_samples, 0.25, 0.45)

    # 2. BASSLINE ACROSS CYCLES
    bass_notes = style_config.get("bass_notes", [])
    for c in range(cycles):
        for i, midi in enumerate(bass_notes):
            step_idx = c * 64 + i * 2
            pos = get_pos(step_idx)
            if c == 0:
                if intro_mode in ("solo_lead", "fx_atmosphere"):
                    continue # No bass during solo lead / atmospheric fx intro!
                bsmp = make_bass(midi, step_len * 1.9, bass_wave)
                mix(left_buf, right_buf, bsmp, pos, total_samples, 0.0, 0.70)
            elif c == 3 and bass_wave == "slap_bass": # Funk slap variation
                bsmp = make_bass(midi + 12 if (i % 4 == 2) else midi, step_len * 1.8, "slap_bass")
                mix(left_buf, right_buf, bsmp, pos, total_samples, 0.0, 0.8)
            else:
                bsmp = make_bass(midi, step_len * 1.9, bass_wave)
                mix(left_buf, right_buf, bsmp, pos, total_samples, 0.0, 0.75)

    # 3. CHORDS / HARMONIC PADS ACROSS CYCLES
    chords = style_config.get("chords", [])
    for c in range(cycles):
        if c == 0 and intro_mode in ("solo_lead", "fx_atmosphere"):
            continue # Keep intro clean and focused on lead instrument / atmosphere
        for bar_idx in range(4):
            chord_midis = chords[bar_idx % len(chords)]
            step_idx = (c * 4 + bar_idx) * 16
            pos = get_pos(step_idx)
            gain = 0.45 if (c == 0) else (0.65 if (c >= cycles - 1) else 0.52)
            csmp = make_chord_pad(chord_midis, step_len * 15.5, chord_wave)
            mix(left_buf, right_buf, csmp, pos, total_samples, 0.0, gain)

    # 4. MELODIC LEAD MOTIF ACROSS CYCLES
    lead_notes = style_config.get("lead_notes", [])
    for c in range(cycles):
        if c == 0:
            if intro_mode == "solo_lead":
                # Play the full melody on its OWN instrument!
                for step_idx, midi, dur_beats in lead_notes:
                    pos = get_pos(c * 64 + step_idx)
                    lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                    mix(left_buf, right_buf, lsmp, pos, total_samples, 0.0, 0.70)
            elif intro_mode == "instant":
                # Immediate full melody on its own instrument
                for step_idx, midi, dur_beats in lead_notes:
                    pos = get_pos(c * 64 + step_idx)
                    lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                    mix(left_buf, right_buf, lsmp, pos, total_samples, 0.1, 0.60)
            elif intro_mode == "groove_bass":
                # Lead enters at bar 2 (step 32)
                for step_idx, midi, dur_beats in lead_notes:
                    if step_idx >= 32:
                        pos = get_pos(c * 64 + step_idx)
                        lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                        mix(left_buf, right_buf, lsmp, pos, total_samples, 0.15, 0.60)
            elif intro_mode == "fx_atmosphere":
                # Enters in second half of cycle 0 (step >= 32)
                for step_idx, midi, dur_beats in lead_notes:
                    if step_idx >= 32:
                        pos = get_pos(c * 64 + step_idx)
                        lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                        mix(left_buf, right_buf, lsmp, pos, total_samples, 0.0, 0.55)
        elif c == 1:
            for step_idx, midi, dur_beats in lead_notes:
                pos = get_pos(c * 64 + step_idx)
                lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                pan = 0.15 if (step_idx // 4) % 2 == 0 else -0.15
                mix(left_buf, right_buf, lsmp, pos, total_samples, pan, 0.55)
        elif c in (2, cycles - 1):
            lead_gain = 0.75 if (c == cycles - 1) else 0.65
            for step_idx, midi, dur_beats in lead_notes:
                pos = get_pos(c * 64 + step_idx)
                lsmp = make_lead(midi, dur_beats * beat_len, lead_wave)
                pan = 0.2 if (step_idx // 4) % 2 == 0 else -0.2
                mix(left_buf, right_buf, lsmp, pos, total_samples, pan, lead_gain)
        elif c == 3: # Octave variation
            for step_idx, midi, dur_beats in lead_notes:
                pos = get_pos(c * 64 + step_idx)
                oct_shift = 12 if (midi >= scale_root + 4) else 0
                lsmp = make_lead(midi + oct_shift, dur_beats * beat_len * 0.88, lead_wave)
                pan = -0.25 if (step_idx // 4) % 2 == 0 else 0.25
                mix(left_buf, right_buf, lsmp, pos, total_samples, pan, 0.62)
        else: # Breakdown / solo
            for step_idx, midi, dur_beats in lead_notes[::2]:
                pos = get_pos(c * 64 + step_idx)
                solo_wave = "shakuhachi" if lead_wave == "shamisen" else ("celesta" if lead_wave != "celesta" else "pipe_organ")
                lsmp = make_lead(midi, dur_beats * beat_len * 1.2, solo_wave)
                mix(left_buf, right_buf, lsmp, pos, total_samples, 0.1, 0.58)

    export_track(track_id, left_buf, right_buf)


# ============================================================================
# 5. ALL 30 RADICALLY DIFFERENT TRACK COMPOSITIONS
# ============================================================================

TRACKS = {
    # --- 1. SYSTEM & MENUS ---
    "ost_menu": { # Electro-Swing Steampunk
        "bpm": 118, "root": 62, "scale": "minor",
        "style": {
            "intro_mode": "groove_bass",
            "drum_style": "electro_swing", "swing": True, "vinyl": True, "steam_fx": True,
            "kick_type": "punchy", "snare_type": "standard",
            "bass_wave": "upright_bass",
            "bass_notes": [38, 38, 41, 43,  45, 45, 43, 41,  38, 38, 45, 43,  41, 43, 45, 40,
                           38, 38, 41, 43,  45, 48, 45, 43,  41, 41, 43, 45,  38, 40, 41, 45],
            "chords": [[50, 53, 57], [48, 52, 55], [46, 50, 53], [45, 48, 52]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 69, 0.6), (3, 67, 0.4), (4, 65, 0.8), (7, 62, 0.8), (10, 65, 0.6), (12, 69, 1.2),
                (16, 72, 0.6), (19, 70, 0.4), (20, 69, 0.8), (24, 65, 1.0), (28, 62, 1.8),
                (32, 62, 0.5), (34, 65, 0.5), (36, 69, 0.8), (40, 72, 1.0), (44, 74, 1.5),
                (48, 72, 0.8), (52, 69, 0.8), (56, 65, 1.0), (60, 62, 2.5)
            ]
        }
    },
    "ost_roster": { # Parisian Gypsy Jazz Manouche
        "bpm": 105, "root": 57, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "electro_swing", "swing": True, "steam_fx": False,
            "kick_type": "punchy", "snare_type": "brush",
            "bass_wave": "upright_bass",
            "bass_notes": [33, 33, 36, 38,  40, 40, 38, 36,  33, 33, 40, 38,  36, 38, 40, 35,
                           33, 33, 36, 38,  40, 43, 40, 38,  36, 36, 38, 40,  33, 35, 36, 40],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "accordion",
            "lead_notes": [
                (0, 64, 0.8), (3, 65, 0.4), (4, 64, 0.6), (6, 60, 0.6), (8, 57, 1.2), (12, 60, 0.8),
                (16, 64, 0.8), (19, 67, 0.5), (20, 69, 1.5), (26, 67, 0.6), (28, 64, 1.0),
                (32, 60, 0.8), (35, 62, 0.4), (36, 64, 1.2), (40, 62, 0.8), (44, 60, 1.0), (48, 57, 2.5)
            ]
        }
    },
    "ost_career": { # Neo-Victorian Ambient Chamber
        "bpm": 95, "root": 64, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "ambient_tick", "steam_fx": True,
            "bass_wave": "cello_drone",
            "bass_notes": [28, 28, 28, 28,  31, 31, 31, 31,  33, 33, 33, 33,  35, 35, 35, 35,
                           28, 28, 28, 28,  31, 31, 31, 31,  33, 33, 33, 33,  28, 28, 31, 35],
            "chords": [[40, 43, 47], [43, 47, 50], [45, 48, 52], [38, 43, 47]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 55, 2.5), (10, 59, 1.5), (16, 64, 2.0), (24, 62, 1.0), (28, 59, 1.5),
                (32, 57, 2.0), (40, 55, 1.5), (46, 54, 1.0), (48, 52, 3.5)
            ]
        }
    },
    "ost_training": { # Minimal Steampunk Tech-House
        "bpm": 124, "root": 60, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "punchy", "snare_type": "standard",
            "bass_wave": "sub_sine",
            "bass_notes": [36, 36, 39, 41,  36, 36, 43, 41,  36, 36, 39, 41,  44, 43, 41, 39,
                           36, 36, 39, 41,  36, 36, 43, 41,  36, 36, 39, 41,  36, 39, 41, 43],
            "chords": [[48, 51, 55], [44, 48, 51], [46, 50, 53], [43, 46, 50]],
            "lead_wave": "celesta",
            "lead_notes": [
                (0, 72, 0.4), (2, 72, 0.4), (6, 75, 0.6), (10, 70, 0.6), (14, 72, 1.2),
                (16, 75, 0.4), (18, 75, 0.4), (22, 77, 0.6), (26, 75, 0.6), (28, 70, 1.0),
                (32, 67, 0.5), (36, 70, 0.5), (40, 72, 0.8), (44, 75, 0.8), (48, 72, 2.0)
            ]
        }
    },

    # --- 2. MATCH PHASES ---
    "ost_climax": { # Heartbeat Cinematic Tension
        "bpm": 140, "root": 62, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "ambient_tick", "siren_fx": True, "steam_fx": True,
            "kick_type": "sub808", "snare_type": "anvil",
            "bass_wave": "sub_sine",
            "bass_notes": [38, 38, 38, 38,  41, 41, 41, 41,  45, 45, 45, 45,  46, 46, 45, 43,
                           38, 38, 38, 38,  41, 41, 41, 41,  45, 45, 45, 45,  48, 48, 46, 45],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 74, 1.5), (6, 73, 1.0), (10, 74, 1.5), (16, 70, 1.5), (22, 69, 1.0), (26, 67, 1.5),
                (32, 77, 1.0), (36, 76, 1.0), (40, 74, 1.5), (46, 73, 1.0), (48, 62, 3.0)
            ]
        }
    },
    "ost_victory": { # Imperial Victory Parade Fanfare
        "bpm": 110, "root": 60, "scale": "major",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "punchy", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [36, 36, 40, 43,  45, 45, 43, 40,  36, 36, 43, 41,  40, 43, 45, 38,
                           36, 36, 40, 43,  45, 48, 45, 43,  41, 41, 43, 45,  36, 38, 40, 43],
            "chords": [[48, 52, 55], [43, 47, 50], [45, 48, 52], [41, 45, 48]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 60, 0.5), (2, 60, 0.5), (4, 60, 0.8), (7, 64, 0.5), (8, 67, 1.8),
                (14, 67, 0.5), (16, 67, 0.5), (18, 67, 0.8), (21, 69, 0.5), (22, 72, 2.2),
                (30, 72, 0.5), (32, 76, 1.2), (36, 74, 0.8), (40, 72, 1.2), (44, 67, 1.2), (48, 72, 3.5)
            ]
        }
    },

    # --- 3. THE 9 FROZEN ROSTER ARENAS ---
    "ost_officina": { # Heavy Industrial Funk with Anvils & Slap Bass
        "bpm": 128, "root": 65, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "rock", "snare_type": "anvil",
            "bass_wave": "slap_bass",
            "bass_notes": [41, 41, 44, 46,  41, 41, 48, 46,  41, 41, 44, 46,  49, 48, 46, 44,
                           41, 41, 44, 46,  41, 41, 48, 46,  41, 41, 44, 46,  41, 44, 46, 48],
            "chords": [[53, 56, 60], [49, 53, 56], [51, 55, 58], [48, 51, 55]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 65, 0.6), (2, 65, 0.6), (4, 68, 0.8), (8, 71, 0.5), (10, 72, 1.2),
                (16, 72, 0.6), (18, 70, 0.6), (20, 68, 0.8), (24, 65, 1.2), (28, 68, 0.8),
                (32, 75, 0.8), (36, 72, 0.8), (40, 70, 0.8), (44, 68, 0.8), (48, 65, 2.5)
            ]
        }
    },
    "ost_fonderia": { # Dark Industrial Rock with Chugging Riffs
        "bpm": 132, "root": 62, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "anime_rock", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [38, 38, 38, 41,  38, 38, 45, 43,  38, 38, 38, 41,  46, 45, 43, 41,
                           38, 38, 38, 41,  38, 38, 45, 43,  38, 38, 38, 41,  38, 41, 45, 48],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 50, 0.6), (2, 53, 0.6), (4, 52, 0.8), (8, 50, 1.2),
                (16, 55, 0.6), (18, 57, 0.6), (20, 58, 0.8), (24, 57, 1.2), (28, 53, 0.8),
                (32, 62, 1.0), (36, 65, 1.0), (40, 67, 1.0), (44, 65, 1.0), (48, 62, 2.5)
            ]
        }
    },
    "ost_cattedrale": { # Baroque Pipe Organ Fugue & Breakbeat
        "bpm": 135, "root": 67, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "sub808", "snare_type": "rimshot",
            "bass_wave": "sub_sine",
            "bass_notes": [43, 43, 46, 48,  50, 50, 48, 46,  43, 43, 50, 48,  46, 48, 50, 45,
                           43, 43, 46, 48,  50, 53, 50, 48,  46, 46, 48, 50,  43, 45, 46, 50],
            "chord_wave": "pipe_organ",
            "chords": [[55, 58, 62], [51, 55, 58], [53, 57, 60], [50, 53, 57]],
            "lead_wave": "pipe_organ",
            "lead_notes": [
                (0, 74, 0.5), (2, 72, 0.3), (3, 70, 0.3), (4, 69, 0.5), (6, 67, 1.2),
                (12, 66, 0.5), (14, 67, 0.5), (16, 69, 1.0), (20, 70, 1.0), (24, 74, 1.5),
                (32, 79, 1.0), (36, 77, 0.8), (40, 75, 0.8), (44, 74, 1.0), (48, 67, 3.0)
            ]
        }
    },
    "ost_forgia": { # High-Voltage Electro-Industrial Tesla
        "bpm": 130, "root": 59, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "punchy", "snare_type": "standard",
            "bass_wave": "reese_bass",
            "bass_notes": [35, 35, 38, 40,  42, 42, 40, 38,  35, 35, 42, 40,  38, 40, 42, 37,
                           35, 35, 38, 40,  42, 45, 42, 40,  38, 38, 40, 42,  35, 37, 38, 42],
            "chords": [[47, 50, 54], [43, 47, 50], [45, 49, 52], [42, 45, 49]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 59, 0.3), (2, 71, 0.3), (4, 59, 0.3), (6, 71, 0.3), (8, 64, 0.8), (12, 62, 0.8),
                (16, 59, 0.3), (18, 71, 0.3), (20, 66, 0.5), (24, 69, 1.2),
                (32, 74, 0.6), (36, 71, 0.6), (40, 66, 0.8), (44, 62, 0.8), (48, 59, 2.0)
            ]
        }
    },
    "ost_osservatorio": { # Celestial Astrolabe Music Box & French Horn
        "bpm": 125, "root": 57, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "ambient_tick", "steam_fx": False,
            "kick_type": "sub808", "snare_type": "rimshot",
            "bass_wave": "sub_sine",
            "bass_notes": [33, 33, 36, 38,  40, 40, 38, 36,  33, 33, 40, 38,  36, 38, 40, 35,
                           33, 33, 36, 38,  40, 43, 40, 38,  36, 36, 38, 40,  33, 35, 36, 40],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "celesta",
            "lead_notes": [
                (0, 81, 0.8), (3, 79, 0.5), (4, 76, 1.2), (8, 74, 0.8), (11, 72, 0.5), (12, 69, 1.8),
                (16, 72, 0.8), (19, 74, 0.5), (20, 76, 1.2), (24, 81, 1.5), (28, 79, 1.0),
                (32, 84, 1.0), (36, 81, 0.8), (40, 76, 1.0), (44, 72, 1.0), (48, 69, 2.5)
            ]
        }
    },
    "ost_tempesta": { # Liquid Drum & Bass 160 BPM
        "bpm": 160, "root": 66, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "liquid_dnb", "steam_fx": True,
            "kick_type": "punchy", "snare_type": "standard",
            "bass_wave": "reese_bass",
            "bass_notes": [42, 42, 45, 47,  49, 49, 47, 45,  42, 42, 49, 47,  45, 47, 49, 44,
                           42, 42, 45, 47,  49, 52, 49, 47,  45, 45, 47, 49,  42, 44, 45, 49],
            "chords": [[54, 57, 61], [50, 54, 57], [52, 56, 59], [49, 52, 56]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 73, 0.8), (3, 71, 0.5), (4, 69, 1.2), (8, 66, 1.5),
                (16, 69, 0.5), (18, 71, 0.5), (20, 73, 1.0), (24, 78, 1.5), (28, 76, 1.0),
                (32, 81, 0.8), (36, 78, 0.8), (40, 73, 0.8), (44, 69, 0.8), (48, 66, 2.5)
            ]
        }
    },
    "ost_abissale": { # Deep Cavernous Dub with Sonar Pings
        "bpm": 120, "root": 61, "scale": "minor",
        "style": {
            "intro_mode": "fx_atmosphere",
            "drum_style": "ambient_tick", "sonar_fx": True, "steam_fx": True,
            "kick_type": "sub808", "snare_type": "rimshot",
            "bass_wave": "sub_sine",
            "bass_notes": [25, 25, 25, 25,  28, 28, 28, 28,  30, 30, 30, 30,  32, 32, 32, 32,
                           25, 25, 25, 25,  28, 28, 28, 28,  30, 30, 30, 30,  25, 25, 28, 32],
            "chords": [[49, 52, 56], [45, 49, 52], [47, 51, 54], [44, 47, 51]],
            "lead_wave": "celesta",
            "lead_notes": [
                (0, 85, 2.5), (16, 80, 2.0), (28, 76, 1.0), (32, 85, 2.0), (44, 73, 1.5), (48, 61, 3.5)
            ]
        }
    },
    "ost_caldera": { # Volcanic Taiko Tribal Battle
        "bpm": 136, "root": 64, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "taiko_tribal", "steam_fx": True,
            "kick_type": "taiko", "snare_type": "anvil",
            "bass_wave": "reese_bass",
            "bass_notes": [28, 28, 31, 33,  35, 35, 33, 31,  28, 28, 35, 33,  31, 33, 35, 30,
                           28, 28, 31, 33,  35, 38, 35, 33,  31, 31, 33, 35,  28, 30, 31, 35],
            "chords": [[40, 43, 47], [36, 40, 43], [38, 42, 45], [35, 38, 42]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 40, 1.2), (4, 43, 0.8), (7, 42, 0.5), (8, 38, 1.5),
                (16, 43, 0.8), (20, 45, 0.8), (24, 47, 1.8), (30, 45, 0.5),
                (32, 52, 1.2), (36, 48, 1.0), (40, 47, 1.0), (44, 43, 1.0), (48, 40, 3.0)
            ]
        }
    },
    "ost_orrery": { # Grand Mechanical Planetarium Symphony
        "bpm": 126, "root": 62, "scale": "major",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "four_on_floor", "steam_fx": False,
            "kick_type": "punchy", "snare_type": "standard",
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 42, 45,  47, 47, 45, 42,  38, 38, 45, 43,  42, 45, 47, 40,
                           38, 38, 42, 45,  47, 50, 47, 45,  43, 43, 45, 47,  38, 40, 42, 45],
            "chords": [[50, 54, 57], [45, 49, 52], [47, 50, 54], [43, 47, 50]],
            "lead_wave": "celesta",
            "lead_notes": [
                (0, 66, 0.4), (2, 69, 0.4), (4, 74, 0.6), (8, 78, 0.8), (12, 74, 0.6), (14, 69, 0.6),
                (16, 67, 0.4), (18, 71, 0.4), (20, 74, 0.6), (24, 79, 1.2), (28, 74, 0.8),
                (32, 78, 0.8), (36, 74, 0.8), (40, 69, 0.8), (44, 66, 0.8), (48, 62, 2.5)
            ]
        }
    },

    # --- 4. THE 5 WORLD CIRCUIT ARENAS ---
    "ost_torii": { # Kyoto Shamisen & Shakuhachi Traditional
        "bpm": 116, "root": 62, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "taiko", "snare_type": "hyoshigi",
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 41, 43,  45, 45, 43, 41,  38, 38, 45, 43,  41, 43, 45, 38,
                           38, 38, 41, 43,  45, 48, 45, 43,  41, 41, 43, 45,  38, 41, 43, 45],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "shamisen",
            "lead_notes": [
                (0, 63, 0.8), (3, 62, 0.5), (4, 67, 1.5), (8, 68, 0.8), (11, 67, 0.5), (12, 63, 1.8),
                (16, 62, 0.8), (20, 67, 1.0), (24, 74, 1.5), (28, 72, 1.0),
                (32, 70, 0.8), (36, 67, 0.8), (40, 63, 1.0), (44, 62, 1.0), (48, 50, 3.0)
            ]
        }
    },
    "ost_medina": { # Electric Oud on D Hijaz Scale with Darbuka
        "bpm": 122, "root": 62, "scale": "hijaz",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "sub808", "snare_type": "darbuka_tek",
            "bass_wave": "saw_pluck",
            "bass_notes": [38, 38, 39, 42,  43, 43, 42, 39,  38, 38, 45, 43,  42, 43, 45, 39,
                           38, 38, 39, 42,  43, 46, 43, 42,  39, 39, 42, 43,  38, 39, 42, 45],
            "chords": [[50, 54, 57], [49, 52, 55], [47, 50, 54], [45, 48, 52]],
            "lead_wave": "oud_tremolo",
            "lead_notes": [
                (0, 66, 0.4), (2, 63, 0.4), (4, 62, 1.2), (8, 63, 0.5), (10, 66, 0.5), (12, 67, 1.5),
                (16, 69, 0.6), (18, 70, 0.6), (20, 69, 0.8), (24, 66, 1.2), (28, 63, 1.0),
                (32, 67, 0.8), (36, 66, 0.8), (40, 63, 0.8), (44, 62, 1.0), (48, 50, 3.0)
            ]
        }
    },
    "ost_carioca": { # Rio Samba Batucada with Agogô & Whistles
        "bpm": 134, "root": 55, "scale": "major",
        "style": {
            "intro_mode": "instant",
            "drum_style": "samba_batucada", "steam_fx": True,
            "kick_type": "surdo", "snare_type": "standard",
            "bass_wave": "upright_bass",
            "bass_notes": [31, 31, 35, 38,  40, 40, 38, 35,  31, 31, 38, 36,  35, 38, 40, 33,
                           31, 31, 35, 38,  40, 43, 40, 38,  36, 36, 38, 40,  31, 33, 35, 38],
            "chords": [[43, 47, 50], [38, 42, 45], [40, 43, 47], [36, 40, 43]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 59, 0.4), (2, 62, 0.4), (4, 67, 0.8), (7, 69, 0.4), (8, 71, 1.2),
                (14, 71, 0.4), (16, 69, 0.6), (18, 67, 0.6), (20, 64, 0.8), (24, 62, 1.5),
                (32, 71, 0.6), (35, 74, 0.6), (38, 76, 1.0), (42, 71, 1.0), (48, 67, 2.5)
            ]
        }
    },
    "ost_aurora": { # Nordic Tagelharpa & Cryo Pads
        "bpm": 120, "root": 57, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "ambient_tick", "steam_fx": False,
            "kick_type": "sub808", "snare_type": "brush",
            "bass_wave": "cello_drone",
            "bass_notes": [33, 33, 33, 33,  36, 36, 36, 36,  38, 38, 38, 38,  40, 40, 40, 40,
                           33, 33, 33, 33,  36, 36, 36, 36,  38, 38, 38, 38,  33, 33, 36, 40],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 64, 2.2), (8, 62, 1.8), (16, 60, 2.0), (24, 57, 2.5),
                (32, 65, 1.5), (38, 64, 1.2), (42, 60, 2.0), (48, 57, 3.5)
            ]
        }
    },
    "ost_egeo": { # Greek Bouzouki on E Phrygian Mode
        "bpm": 128, "root": 64, "scale": "phrygian",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "punchy", "snare_type": "anvil",
            "bass_wave": "saw_pluck",
            "bass_notes": [28, 28, 29, 31,  33, 33, 31, 29,  28, 28, 35, 33,  31, 33, 35, 29,
                           28, 28, 29, 31,  33, 36, 33, 31,  29, 29, 31, 33,  28, 29, 31, 35],
            "chords": [[40, 43, 47], [41, 45, 48], [38, 42, 45], [36, 40, 43]],
            "lead_wave": "bouzouki",
            "lead_notes": [
                (0, 65, 0.3), (2, 67, 0.3), (4, 68, 0.6), (8, 67, 0.4), (10, 65, 0.4), (12, 64, 1.2),
                (16, 68, 0.4), (18, 70, 0.4), (20, 72, 1.0), (24, 70, 0.5), (26, 68, 0.5), (28, 67, 1.0),
                (32, 72, 0.8), (36, 70, 0.8), (40, 67, 0.8), (44, 65, 0.8), (48, 64, 3.0)
            ]
        }
    },

    # --- 5. THE 2 NEW ARENAS ---
    "ost_heritage_hall": { # Noble String Quartet & Piano
        "bpm": 115, "root": 60, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "ambient_tick", "steam_fx": False,
            "kick_type": "sub808", "snare_type": "rimshot",
            "bass_wave": "cello_drone",
            "bass_notes": [36, 36, 39, 41,  43, 43, 41, 39,  36, 36, 43, 41,  39, 41, 43, 38,
                           36, 36, 39, 41,  43, 46, 43, 41,  39, 39, 41, 43,  36, 38, 39, 43],
            "chords": [[48, 51, 55], [44, 48, 51], [46, 50, 53], [43, 46, 50]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 67, 1.2), (4, 64, 0.8), (7, 60, 0.5), (8, 64, 1.5), (12, 67, 1.0),
                (16, 72, 1.2), (20, 71, 0.8), (24, 69, 1.5), (28, 67, 1.0),
                (32, 74, 1.2), (36, 72, 0.8), (40, 69, 1.0), (44, 64, 1.0), (48, 60, 3.0)
            ]
        }
    },
    "ost_steam_workshop": { # Locomotive Blues Slide Guitar & Piston Chug
        "bpm": 138, "root": 64, "scale": "minor",
        "style": {
            "intro_mode": "fx_atmosphere",
            "drum_style": "locomotive_chug", "whistle_fx": True, "steam_fx": True,
            "kick_type": "rock", "snare_type": "anvil",
            "bass_wave": "saw_pluck",
            "bass_notes": [28, 28, 31, 33,  34, 35, 33, 31,  28, 28, 35, 33,  31, 33, 35, 30,
                           28, 28, 31, 33,  34, 35, 38, 35,  33, 33, 34, 35,  28, 30, 31, 35],
            "chords": [[40, 43, 47], [36, 40, 43], [38, 42, 45], [35, 38, 42]],
            "lead_wave": "slide_guitar",
            "lead_notes": [
                (0, 55, 0.6), (3, 57, 0.5), (4, 58, 0.6), (6, 59, 1.2), (10, 57, 0.6), (12, 55, 1.5),
                (16, 52, 1.0), (20, 55, 0.8), (24, 57, 1.5), (28, 55, 1.0),
                (32, 64, 0.8), (35, 67, 0.6), (38, 71, 1.2), (44, 69, 1.0), (48, 52, 3.0)
            ]
        }
    },

    # --- 6. THE 8 EPIC / ANIME SPECIAL SOUNDTRACKS ---
    "ost_epic_anthem": { # Symphonic J-Rock Anime Opening
        "bpm": 150, "root": 64, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "anime_rock", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [28, 28, 28, 31,  33, 33, 31, 28,  36, 36, 36, 36,  38, 38, 38, 38,
                           28, 28, 28, 31,  33, 33, 31, 28,  36, 36, 38, 38,  28, 31, 35, 38],
            "chords": [[40, 43, 47], [36, 40, 43], [38, 42, 45], [43, 47, 50]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 76, 0.6), (3, 74, 0.4), (4, 71, 1.0), (8, 74, 0.8), (11, 76, 0.5), (12, 79, 1.5),
                (16, 81, 0.8), (20, 79, 0.8), (24, 76, 1.5), (28, 74, 1.0),
                (32, 83, 1.0), (36, 81, 0.8), (40, 79, 1.0), (44, 76, 1.0), (48, 76, 3.0)
            ]
        }
    },
    "ost_epic_semifinal": { # Anime Battle Ostinato & Steel Percussion
        "bpm": 145, "root": 62, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "four_on_floor", "steam_fx": True,
            "kick_type": "punchy", "snare_type": "anvil",
            "bass_wave": "reese_bass",
            "bass_notes": [38, 38, 41, 43,  45, 45, 43, 41,  34, 34, 38, 41,  36, 36, 40, 43,
                           38, 38, 41, 43,  45, 45, 43, 41,  34, 34, 36, 36,  38, 41, 45, 48],
            "chords": [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 69, 0.3), (2, 65, 0.3), (4, 69, 0.3), (6, 65, 0.3), (8, 72, 0.8), (12, 70, 0.8),
                (16, 69, 0.3), (18, 65, 0.3), (20, 74, 0.6), (24, 77, 1.2), (28, 76, 1.0),
                (32, 74, 0.6), (36, 72, 0.6), (40, 69, 0.8), (44, 65, 0.8), (48, 62, 2.5)
            ]
        }
    },
    "ost_epic_grand_final": { # Hiroyuki Sawano Monumental Climax
        "bpm": 148, "root": 59, "scale": "minor",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "sawano_climax", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [35, 35, 35, 35,  31, 31, 31, 31,  33, 33, 33, 33,  30, 30, 30, 30,
                           35, 35, 35, 35,  31, 31, 31, 31,  33, 33, 33, 33,  35, 38, 42, 45],
            "chord_wave": "choir_pad",
            "chords": [[47, 50, 54], [43, 47, 50], [45, 49, 52], [42, 45, 49]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 71, 1.5), (6, 66, 1.0), (10, 71, 1.5), (16, 74, 1.8), (22, 73, 1.0), (24, 78, 2.5),
                (32, 83, 1.2), (36, 81, 1.0), (40, 78, 1.2), (44, 74, 1.0), (48, 71, 3.5)
            ]
        }
    },
    "ost_epic_rival_legend": { # High-Speed Shonen Rival Duel
        "bpm": 155, "root": 66, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "anime_rock", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "slap_bass",
            "bass_notes": [42, 42, 45, 47,  49, 49, 47, 45,  38, 38, 42, 45,  40, 40, 44, 47,
                           42, 42, 45, 47,  49, 49, 47, 45,  38, 38, 40, 40,  42, 45, 49, 52],
            "chords": [[54, 57, 61], [50, 54, 57], [52, 56, 59], [49, 52, 56]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 73, 0.3), (2, 74, 0.3), (4, 78, 0.6), (8, 76, 0.4), (10, 73, 0.4), (12, 69, 1.2),
                (16, 71, 0.4), (18, 73, 0.4), (20, 74, 0.8), (24, 81, 1.2), (28, 78, 1.0),
                (32, 85, 0.8), (36, 81, 0.8), (40, 78, 0.8), (44, 74, 0.8), (48, 66, 2.8)
            ]
        }
    },
    "ost_epic_awakening": { # Steampunk Power Metal Overdrive
        "bpm": 165, "root": 69, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "power_metal", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [33, 33, 33, 33,  29, 29, 29, 29,  31, 31, 31, 31,  28, 28, 28, 28,
                           33, 33, 33, 33,  29, 29, 29, 29,  31, 31, 31, 31,  33, 36, 40, 43],
            "chords": [[45, 48, 52], [41, 45, 48], [43, 47, 50], [40, 43, 47]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 76, 0.3), (2, 77, 0.3), (4, 81, 0.6), (8, 79, 0.4), (10, 77, 0.4), (12, 76, 1.0),
                (16, 77, 0.4), (18, 79, 0.4), (20, 81, 0.8), (24, 84, 1.5), (28, 81, 0.8),
                (32, 88, 0.6), (36, 84, 0.6), (40, 81, 0.6), (44, 76, 0.6), (48, 69, 3.0)
            ]
        }
    },
    "ost_epic_sudden_death": { # Dramatic Sudden Death Suspense
        "bpm": 142, "root": 62, "scale": "minor",
        "style": {
            "intro_mode": "fx_atmosphere",
            "drum_style": "ambient_tick", "siren_fx": True, "steam_fx": True,
            "kick_type": "sub808", "snare_type": "anvil",
            "bass_wave": "sub_sine",
            "bass_notes": [38, 38, 38, 38,  37, 37, 37, 37,  36, 36, 36, 36,  35, 35, 35, 35,
                           34, 34, 34, 34,  33, 33, 33, 33,  34, 34, 36, 36,  38, 41, 45, 48],
            "chords": [[50, 53, 57], [49, 53, 57], [48, 52, 55], [45, 49, 52]],
            "lead_wave": "epic_violin",
            "lead_notes": [
                (0, 68, 0.4), (2, 67, 0.4), (4, 68, 0.4), (6, 67, 0.4), (8, 62, 1.5),
                (16, 68, 0.4), (18, 67, 0.4), (20, 74, 0.8), (24, 73, 1.5),
                (32, 77, 0.5), (34, 76, 0.5), (36, 74, 0.5), (38, 73, 0.5), (40, 68, 1.0), (48, 62, 3.0)
            ]
        }
    },
    "ost_epic_ascension": { # Triumphant Anime Victory Anthem
        "bpm": 130, "root": 67, "scale": "major",
        "style": {
            "intro_mode": "solo_lead",
            "drum_style": "sawano_climax", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [31, 31, 31, 31,  38, 38, 38, 38,  40, 40, 40, 40,  36, 36, 36, 36,
                           31, 31, 31, 31,  38, 38, 38, 38,  40, 40, 43, 43,  36, 38, 40, 43],
            "chords": [[43, 47, 50], [38, 42, 45], [40, 43, 47], [36, 40, 43]],
            "lead_wave": "brass",
            "lead_notes": [
                (0, 71, 0.8), (3, 74, 0.5), (4, 79, 1.2), (8, 83, 1.5),
                (16, 81, 0.8), (20, 79, 0.8), (24, 86, 2.0),
                (32, 86, 0.8), (35, 83, 0.5), (36, 81, 1.0), (40, 79, 1.2), (44, 74, 1.0), (48, 67, 3.5)
            ]
        }
    },
    "ost_epic_rematch": { # Heroic Resurgence & Comeback Rock
        "bpm": 138, "root": 60, "scale": "minor",
        "style": {
            "intro_mode": "instant",
            "drum_style": "anime_rock", "steam_fx": True,
            "kick_type": "rock", "snare_type": "rock",
            "bass_wave": "power_bass",
            "bass_notes": [36, 36, 36, 36,  32, 32, 32, 32,  39, 39, 39, 39,  34, 34, 34, 34,
                           36, 36, 36, 36,  32, 32, 32, 32,  34, 34, 36, 36,  36, 39, 43, 46],
            "chords": [[48, 51, 55], [44, 48, 51], [51, 55, 58], [46, 50, 53]],
            "lead_wave": "jrock_guitar",
            "lead_notes": [
                (0, 63, 0.6), (3, 65, 0.4), (4, 67, 1.2), (8, 70, 0.8), (11, 67, 0.5), (12, 63, 1.5),
                (16, 65, 0.6), (18, 67, 0.6), (20, 72, 1.0), (24, 75, 1.5), (28, 72, 1.0),
                (32, 75, 0.8), (36, 72, 0.8), (40, 67, 0.8), (44, 63, 0.8), (48, 60, 3.0)
            ]
        }
    }
}

def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else list(TRACKS.keys())
    print(f"--- Synthesizing {len(targets)} Multi-Timbral Steam Circuit Padel Pro OSTs (Total Catalog: {len(TRACKS)}) ---")
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
