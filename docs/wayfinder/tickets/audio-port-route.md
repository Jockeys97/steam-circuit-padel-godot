# Audio port route

- Status: resolved
- Type: research
- Mode: AFK
- Owner: unassigned
- Blocked by: none

## Question

Catalogue the sound the game actually makes: the synthesised effects in
`js/audio.js` (292 lines), the generative music and its intensity control driven
by rally length (around `js/main.js:1226`), and the reduced-motion handling. Then
choose the Godot realisation — live synthesis, baked audio, or a mix — and say
which parts of the current feel each choice keeps.

## Why it matters

Audio is entirely synthesised today, so there is nothing to copy across.
Guessing here means re-designing the feel by accident.

## Resolved when

A catalogue of every sound with its trigger, plus a decision per sound on how it
is produced in Godot, plus a note on how rally intensity still drives the music.
Verified by playing the catalogue against the running web build, not by reading
alone.

## Outcome

**RESOLVED 2026-09-16.** Full catalogue, per-sound Godot decision, intensity note,
reduced-motion note, and the raw command output:
[audio port route evidence](../evidence/audio-port-route.md).

The game makes **15 sounds**: 10 one-shots (9 `sfx` methods; `point(win)` splits into
win and loss) and 5 music voices. Every row carries its trigger (`js/game.js:750, 1893,
1898, 2111, 2113, 2115, 2209, 2363, 2382`), its synthesis anchor in `js/audio.js`, and
its measured render.

### Decision per sound

| Group | Godot realisation | Why |
|---|---|---|
| `hit`, `wall`, `net`, `serve`, `special` | **baked audio**, 4-6 randomized variants via `AudioStreamRandomizer` | Their noise term is a fresh `Math.random()` buffer per play (`js/audio.js:45`); one bake would freeze the grain. The tonal sweeps bake exactly. |
| `bounce`, `point-loss` | **baked audio**, single file each | Fully deterministic, noise-free: one WAV is bit-faithful and a live synth adds nothing. |
| `point-win`, `victory`, `defeat` | **baked audio**, one sequence file each | They stagger notes with `setTimeout` (`js/audio.js:88, 96, 101`); a single sequence bake is frame-independent, a timer chain is four chances to drift. |
| 5 music voices (bass, pad, arp, kick, hat) | **mix**: baked per-voice one-shot samples played by a ported step sequencer | The sequencer is real logic (chord table, gates, tempo), not a fixed loop; the samples are short and deterministic. |

**No row keeps live synthesis.** Godot 4.7 has no WebAudio-style node graph; the
procedural option (`AudioStreamGenerator` + per-frame `push_buffer`) cannot place a
40 ms event with a 3 ms attack and exponential release at the sample, the way
`js/audio.js:30-32` does. Live synthesis returns only for a future sound whose
parameter `pitch_scale` cannot express (a continuous ball-speed pitch glide, say).

### Rally intensity still drives the music

Ported, not approximated: the same formula (`js/main.js:1220-1226`,
`min(1, 0.12 + min(1, rallyHits/12)*0.55 + stakes)`), fed the same three simulation
values, recomputed per frame, then applied at step-schedule time — tempo
`60 / (96 + intensity*54)` (96→150 BPM), gates at 0.4 (arp), 0.6 (off-beat bass),
0.72 (kick + hat), the continuous voice gains, and the same 40 ms tick with a 150 ms
lookahead. Start/stop parity kept, including the quirk that `pauseGame()` does **not**
stop the music (`js/main.js:1530-1545`). The cheaper alternative — three baked
intensity stems crossfaded — is recorded as rejected: it loses the tempo ramp, which is
the most felt part of a long rally.

### Reduced motion

`js/audio.js` consults reduced motion **nowhere** (`grep` → no match). The flag lives in
`js/fx.js:2-10` and only scales particles (`:26`), caps shake (`:63`) and toggles a CSS
class (`js/main.js:2301`, `styles.css:2715-2722`). The port must preserve that: the audio
layer never reads the setting. Motion reduction stays in the effects layer. If Luca wants
motion-linked audio cues later, that is a new decision, not a port of a branch that does
not exist.

### Verification

| Command | Exit | Result |
|---|---|---|
| `node tools/audio-audition/verify-stub.mjs` | 0 | 54/54 — catalogue matches `js/audio.js`, every parameter reaches the stubbed API, mute suppresses all 10 one-shots, music tempo/gates/intensity anchors hold |
| `python3 tools/audio-audition/verify_browser.py` | 0 | 11/11 — real headless Chromium offline render: 10/10 sounds audible, muted path silent, mixer ratio exactly 0.5000; 10 WAVs baked to `tools/audio-audition/baked/` |
| `npm run audit` | 0 | 27/27 audit passano |

The harness was broken when this ticket started (31/54, exit 1) and the promised
`verify_browser.py` did not exist. Seven defects were fixed inside
`tools/audio-audition/` (wrong `play()` argument, stale master-gain capture, head-anchor
scheme, cumulative `setTimeout` model, an impossible `initAudio()` count, the page bake
rendering the wrong offline context for staggered sounds, a flaky mixer probe) — listed
with causes in the evidence file. `js/audio.js` itself was read only, never edited.

### Still open, and not claimed here

1. **No listening test.** This host has no sound device; headless Chromium ran with
   `--mute-audio`. Everything above is numeric measurement plus API assertions. Whether
   the port feels right is Luca's ear call — the baked WAVs and the audition page's
   click-to-play cards are the artefacts for it.
2. **The music is source-verified, not render-verified.** The sequencer is driven by
   `setInterval`, which an `OfflineAudioContext` does not advance, so no end-to-end music
   render exists. Its tempo, gates, voice parameters and start/stop anchors are asserted
   against source instead.
3. **`verify_browser.py` is not wired into `npm run audit`.** It needs Playwright
   Chromium; adding it to the audit suite is a separate decision nobody has taken.
