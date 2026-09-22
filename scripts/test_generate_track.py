#!/usr/bin/env python3
import sys
import json
import base64
import urllib.request
import urllib.error

API_KEY = sys.argv[1]
prompt = "A high-energy steampunk electro-swing main theme for an arcade sports game. Upright acoustic bass groove, syncopated brass section, clockwork percussion."

for model in ["lyria-3.5", "lyria-3-clip-preview"]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}"
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt}
                ]
            }
        ]
    }

    data_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data_bytes,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    print(f"\n--- Testing generateContent with {model} ---")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            res_json = json.loads(resp.read().decode())
            print("Response keys:", list(res_json.keys()))
            candidates = res_json.get("candidates", [])
            print(f"Candidates count: {len(candidates)}")
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                print(f"Parts count: {len(parts)}")
                for i, p in enumerate(parts):
                    print(f"Part {i} keys: {list(p.keys())}")
                    if "inlineData" in p:
                        mime = p["inlineData"].get("mimeType")
                        data_len = len(p["inlineData"].get("data", ""))
                        print(f"  inlineData mime: {mime}, data length: {data_len}")
                        # Save sample audio
                        raw_audio = base64.b64decode(p["inlineData"]["data"])
                        ext = ".mp3" if "mp3" in mime else (".ogg" if "ogg" in mime else ".wav")
                        out_path = f"/Users/alessiofantini/Documents/steam-circuit-padel-11m/godot/assets/audio/music/ost_menu{ext}"
                        with open(out_path, "wb") as f:
                            f.write(raw_audio)
                        print(f"  SUCCESS! Audio saved to: {out_path} ({len(raw_audio)} bytes)")
                        sys.exit(0)
    except urllib.error.HTTPError as e:
        print(f"HTTP Error {e.code}: {e.read().decode()}")
    except Exception as e:
        print(f"Error: {e}")
