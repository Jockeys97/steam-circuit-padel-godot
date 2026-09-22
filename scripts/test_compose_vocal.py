#!/usr/bin/env python3
import os
import math
import struct
import subprocess
import random

SAMPLE_RATE = 44100
FFMPEG_BIN = "/opt/homebrew/bin/ffmpeg"
if not os.path.exists(FFMPEG_BIN):
    FFMPEG_BIN = "ffmpeg"

def read_wav_mono(path):
    with open(path, 'rb') as f:
        # Simple WAV reader
        data = f.read()
    # Find 'data' chunk
    d_idx = data.find(b'data')
    if d_idx == -1:
        return []
    d_len = struct.unpack_from('<I', data, d_idx + 4)[0]
    raw_samples = data[d_idx + 8 : d_idx + 8 + d_len]
    n_samples = len(raw_samples) // 2
    return [struct.unpack_from('<h', raw_samples, i * 2)[0] / 32768.0 for i in range(n_samples)]

def generate_voice_clip(name, voice, rate, text, semitones=0):
    raw_path = f"/tmp/raw_vox_{name}.wav"
    cmd = ["say", "-v", voice, "-r", str(rate), "-o", raw_path, "--data-format=LEI16@44100", text]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    if semitones == 0:
        return read_wav_mono(raw_path)
    
    # Pitch shift with ffmpeg
    out_path = f"/tmp/shift_vox_{name}_{semitones}.wav"
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

print("Testing vocal generation...")
smp = generate_voice_clip("intro", "Daniel", 140, "Vanguard. Stand your ground.", 0)
print(f"Generated {len(smp)} samples ({len(smp)/44100:.2f}s)")
