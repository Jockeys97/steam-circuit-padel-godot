# Mixer contract

Status: done — implemented and proven, 2026-09-17 (audio captain); confirmed in the
final integrated proof and corrected at integration (review F-10, F-11), 2026-09-18.

Read and validate the mixer contract once, then supply the existing audio adapters. Keep playback behavior separate and unchanged.

Done when both audio adapters use the shared reader and both audio suites pass.

## Outcome

`godot/src/audio/mixer_contract.gd` is the one reader. It owns the contract
parse, the schema/events validation, the sha256 of the copy it read, the mixer
facts (master default 0.5, music bus 0.55, mute default false, gain range), the
gain law (clamp + level relative to the bake, silence at 0) and the bus setup
facts (names, send graph, per-bus levels, idempotent `ensure_bus`).

`godot/src/audio/audio_port.gd` and `godot/src/audio/music.gd` both consume it
through a `mixer_contract` property and keep all playback: sounds, players,
polyphony, sequencer, scheduler, voices, mute/gain state. Neither parses the
contract JSON, checks its schema, hashes it, or restates a bus name, level or
mixer number any more. Test-only seam: the property can be assigned before the
node enters the tree.

## Evidence

| Command | Exit | Result |
|---|---|---|
| RED — `Godot --headless --path godot --script res://tests/mixer_contract_test.gd` (before the reader existed) | 1 | `FAIL 0/3` — no reader, neither adapter held one |
| `… --script res://tests/mixer_contract_test.gd` | 0 | `PASS 35/35` |
| `… --script res://tests/audio_port_test.gd` | 0 | `PASS 15/15` (unchanged tally) |
| `… --script res://tests/music_port_test.gd` | 0 | `PASS 32/32` (unchanged tally) |
| `gdlint` on the four changed files | — | 0 new findings (both adapters now have fewer) |

The seam is proven by injection: each adapter is handed a reader pointed at a
doctored contract copy (master 0.4, music 0.7, mute default true, range
0.1..0.9) and its `describe()` and the real AudioServer buses must show those
numbers; a control engine per adapter then shows the shipped numbers. An adapter
that still parsed the file itself fails that check.

Notes: the first green run corrected a test-side assumption (0.2 against a 0.4
default is half, −6.02 dB, not unity) — the module was right. The reader also
requires `events` to be non-empty for `music.gd`, which previously checked only
the schema; with the shipped contract both loads are identical. No commit;
frozen paths untouched. Known gap: each adapter still builds its own reader
instance — one shared instance at match level is a later decision the reader
already supports.

## Final integration (2026-09-18)

- **Confirmed in the integrated sweep** (serial, engine lock): `mixer_contract_test`
  exit 0 `PASS 35/35`; `audio_port_test` exit 0 `PASS 15/15`; `music_port_test`
  exit 0 `PASS 32/32`. The two engine `ERROR:` lines the suite produces are the
  reader's deliberate refusal probes (impostor schema; missing file), asserted by
  the checks beside them — the repo's "ok-flanked refusal" class, not silenced.
- **Review F-10 applied**: the test-only `bus_plan()` is deleted. Its check now
  drives the production entry (`ensure_bus`) and reads the real AudioServer for the
  send graph, with `bus_volume_db()` for the levels — same facts, no plan getter.
  Tally unchanged (35/35).
- **Review F-11 recorded, no change**: the adapters' `reference_master_gain()`,
  `muted_default()`, `master_gain_range()` forwards and `audio_port._mixer()` stay as
  compatibility seams; they are public names tests read, not dead code.
- Commit handle: `refactor: deepen match architecture seams` (local, 2026-09-18);
  no push.
