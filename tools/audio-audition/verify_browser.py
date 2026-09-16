#!/usr/bin/env python3
"""verify_browser.py — real-browser check of the audio catalogue.

What it does, and what it deliberately is NOT
---------------------------------------------
It drives the audition page (`tools/audio-audition/index.html`) in a real
headless Chromium through Playwright and calls the page's own offline bake
(`window.__auditionBake`), which swaps `window.AudioContext` for a 2 s
`OfflineAudioContext`, imports a FRESH instance of the game's real
`js/audio.js` per sound, plays it, and renders the result. The rendered buffer
is measured numerically (peak / RMS / audible seconds) and written to WAV.

So: the game's actual synthesis code runs inside Chromium's actual WebAudio
engine and the output is really rendered — but nobody listens to it. This host
has no sound device, so "verified by ear" would be a false claim. The script
prints that limitation instead of hiding it. A human listening check is the
`baked/*.wav` files plus the page's own click-to-play cards.

Exit: 0 all checks pass, 1 otherwise.  Run:  node-free, python only.
    python3 tools/audio-audition/verify_browser.py
"""

import base64
import http.server
import pathlib
import socketserver
import sys
import threading

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(__file__).resolve().parent / "baked"

# Every catalogued one-shot is expected to render audible output, and the muted
# path is expected to render pure silence. Nothing else is asserted from source.
EXPECT_AUDIBLE = [
    "hit",
    "bounce",
    "wall",
    "net",
    "serve",
    "special",
    "point-win",
    "point-loss",
    "victory",
    "defeat",
]


class Quiet(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(ROOT), **kw)

    def log_message(self, *a):  # keep the transcript to our own output
        pass


def serve():
    # Not a `with` block: returning from inside it would call __exit__ and close
    # the listening socket before the browser ever connects.
    httpd = socketserver.TCPServer(("127.0.0.1", 0), Quiet)
    port = httpd.server_address[1]
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd, port


def main():
    from playwright.sync_api import sync_playwright

    httpd, port = serve()
    url = f"http://127.0.0.1:{port}/tools/audio-audition/index.html"
    failures = []
    print(f"serving {ROOT} at {url}")
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                args=[
                    "--no-sandbox",
                    "--autoplay-policy=no-user-gesture-required",
                    "--mute-audio",
                ]
            )
            page = browser.new_page()
            errors = []
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(url)
            page.wait_for_function("window.__audition && window.__audition.ready", timeout=20000)
            print("page ready — js/audio.js is the game's own module, imported by the page")

            bake = page.evaluate(
                """async () => {
                    const out = await window.__auditionBake({ renderSeconds: 1.5, sampleRate: 44100 });
                    // Mixer check: the same sound at two master volumes must scale.
                    const snd = window.__audition.api;
                    return { results: out.results, wavs: out.wavs };
                }"""
            )

            # Master-volume scaling, measured in the same offline renderer.
            volume = page.evaluate(
                """async () => {
                    const SR = 44100, SECS = 1.5;
                    const shim = (instances) => class extends window.OfflineAudioContext {
                        constructor() { super(1, Math.round(SR * SECS), SR); instances.push(this); }
                        get state() { return "running"; }
                        resume() { return Promise.resolve(); }
                    };
                    const Real = window.AudioContext;
                    const peakFor = async (vol) => {
                        const instances = [];
                        window.AudioContext = shim(instances);
                        const api = await import(`../../js/audio.js?vol=${vol}-${Math.random()}`);
                        api.setVolume(vol);
                        // bounce() = one sine sweep, no noise term, so the measured
                        // peak is deterministic and isolates the mixer gain. Using
                        // hit() here made the check flaky: its 0.04 s noise burst is
                        // a fresh Math.random() draw per render and moved the peak.
                        api.sfx.bounce();
                        await new Promise((r) => setTimeout(r, 50));
                        const buf = await instances[instances.length - 1].startRendering();
                        const d = buf.getChannelData(0);
                        let peak = 0;
                        for (let i = 0; i < d.length; i += 1) peak = Math.max(peak, Math.abs(d[i]));
                        return peak;
                    };
                    try {
                        return { half: await peakFor(0.5), quarter: await peakFor(0.25) };
                    } finally {
                        window.AudioContext = Real;
                    }
                }"""
            )
            browser.close()
    finally:
        httpd.shutdown()

    if errors:
        failures.append(f"page errors: {errors}")

    OUT.mkdir(parents=True, exist_ok=True)
    seen = {}
    print(f"\n{'sound':<12} {'peak':>10} {'rms':>10} {'audible s':>10}  verdict")
    for row in bake["results"]:
        seen[row["id"]] = row
        muted = row.get("muted", False)
        if muted:
            ok = row["peak"] == 0
            verdict = "silent as designed" if ok else "LEAKED AUDIO"
        else:
            ok = row["peak"] > 0
            verdict = "audible" if ok else "SILENT"
        if not ok:
            failures.append(f"{row['id']}: {verdict} (peak {row['peak']})")
        print(f"{row['id']:<12} {row['peak']:>10} {row['rms']:>10} {row['audibleSeconds']:>10}  {verdict}")

    for want in EXPECT_AUDIBLE:
        if want not in seen:
            failures.append(f"{want}: not rendered at all")

    for wav in bake["wavs"]:
        path = OUT / f"{wav['id']}.wav"
        path.write_bytes(base64.b64decode(wav["base64"]))
    print(f"\nbaked {len(bake['wavs'])} WAV file(s) to {OUT.relative_to(ROOT)}/ (mono 44.1 kHz)")

    ratio = volume["quarter"] / volume["half"] if volume["half"] else 0
    print(
        f"mixer: bounce() peak {volume['half']} @ volume 0.5 vs {volume['quarter']} @ volume 0.25 "
        f"-> ratio {ratio:.4f} (expected 0.5; bounce() is noise-free, so this is exact)"
    )
    if abs(ratio - 0.5) > 0.005:
        failures.append(f"setVolume did not scale the rendered output linearly (ratio {ratio:.4f})")

    print(
        "\nLIMIT: no listening test. This host has no sound device; the checks above are "
        "numeric measurements of a real Chromium WebAudio render."
    )
    if failures:
        print("\nFAILED: " + "; ".join(failures))
        return 1
    print(f"\n{len(bake['results'])}/{len(bake['results'])} renders as expected — catalogue audible, muted path silent, mixer scales")
    return 0


if __name__ == "__main__":
    sys.exit(main())
