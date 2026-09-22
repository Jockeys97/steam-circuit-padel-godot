#!/usr/bin/env python3
import sys
import json
import urllib.request

API_KEY = sys.argv[1]

for model_name in ["lyria-3-clip-preview", "lyria-3.5", "lyria-3-pro-preview"]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}?key={API_KEY}"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            print(f"=== Model: {model_name} ===")
            print("Supported generation methods:", data.get("supportedGenerationMethods"))
            print("Description:", data.get("description"))
    except Exception as e:
        print(f"Error checking {model_name}: {e}")
