#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error

API_KEY = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GEMINI_API_KEY", "")

if not API_KEY:
    print("Error: No API key provided.")
    sys.exit(1)

# Test listing models from Google Gemini API
url = f"https://generativelanguage.googleapis.com/v1beta/models?key={API_KEY}"

try:
    req = urllib.request.Request(url, headers={"User-Agent": "Antigravity/1.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode())
        models = data.get("models", [])
        print(f"Success! Connected to Gemini API. Found {len(models)} models.")
        lyria_models = [m["name"] for m in models if "lyria" in m["name"].lower() or "audio" in m["name"].lower() or "music" in m["name"].lower()]
        print("Audio/Lyria related models found:", lyria_models if lyria_models else "None in standard v1beta list")
except urllib.error.HTTPError as e:
    print(f"HTTP Error {e.code}: {e.read().decode()}")
except Exception as e:
    print(f"Connection error: {e}")
