# Structural validation: the UIR pack

Run 2026-09-16 against this directory, docs-only. This file is the evidence; the script at the bottom is the check. No Godot, no engine, no repo writes: structure only.

**Result: 18/18 checks pass** (recorded output below).

## How to rerun

Save the script block as `validate_pack.py`, then:

```bash
python3 validate_pack.py docs/implementation/ui-recreation   # exits 0 on pass, 1 on any failure
```

## Checks

| # | Check | Result |
|---|---|---|
| 1 | 28 tickets `UIR-00`..`UIR-27`, frontmatter parses | PASS |
| 2 | every `blocked_by` id resolves | PASS |
| 3 | `blocked_by` graph is acyclic | PASS |
| 4 | every `blocks` list is the exact reverse of `blocked_by` (UIR-09 also lists the `GATE-A` pseudo-node) | PASS |
| 5 | only UIR-09 lists the `GATE-A` pseudo-node | PASS |
| 6 | `luca-final` appears in no ticket's `gates` (closing-only gate) | PASS |
| 7 | UIR-25 shape: `closing_gate: luca-final`, `gates: [plan-approval, gate-a]`, `conditional_blocked_by: [UIR-26]`, `blocked_by` includes UIR-27 | PASS |
| 8 | UIR-26 stays external (`blocked_by: []`, `readiness: external`) | PASS |
| 9 | UIR-27 serializes on UIR-22 (shared `godot/game/**` writer) | PASS |
| 10 | board waves cover every ticket (UIR-26 external excepted) | PASS |
| 11 | no ticket is waved before one of its blockers | PASS |
| 12 | same-wave edges are sequenced by explicit board phrases | PASS |
| 13 | the board's ticket table has a row for each ticket | PASS |
| 14 | write-allowlist collisions are only the documented integration chain | PASS |
| 15 | README states the serial orders for the shared paths | PASS |
| 16 | every `res://tests/ui` script used by an acceptance command is owned by exactly one ticket | PASS |
| 17 | every ticket declares evidence in frontmatter | PASS |
| 18 | the README entrypoint link resolves to the workspace plan | PASS |

## Interpretations the script encodes

- `GATE-A` is a pseudo-node (a human verdict, not a ticket): it may appear in UIR-09's `blocks` and nowhere else.
- `conditional_blocked_by` (UIR-25 → UIR-26) is a defined extension field, deliberately outside the `blocked_by` graph so the graph stays acyclic and the wave map stays total.
- UIR-26 has no wave: it is external (product-scope decision).
- Same-wave dependency edges — `UIR-12←UIR-11`, `UIR-20←UIR-13`, `UIR-20←UIR-19`, `UIR-23←UIR-10/11/12/21`, `UIR-27←UIR-22` — are each required to be, and are, sequenced by an explicit phrase in `BOARD.md` ("UIR-12 opens when UIR-11 lands"; "UIR-20 opens when UIR-13 and UIR-19 land"; "UIR-23 opens when UIR-10, 11, 12, 21 land"; "UIR-22 integration, then UIR-27").
- The collision check reads the bullet lines of each `## Write allowlist` section, skips "do not touch" prose, and requires that any path held by two tickets matches the allowed shared map: the `godot/game/**` chain (UIR-09 → UIR-22 → UIR-27) and `godot/tests/game_slice_test.gd` (UIR-22, plus UIR-27's `r`-key assertion). Both orders are stated in README rules 1 and 6.
- Script ownership: an acceptance command may run another ticket's script (UIR-25 runs UIR-24's harness and every audit); exactly one ticket must own the file, and that owner is the only writer.
- Waves are parsed from the `Frontier` bullets in `BOARD.md` with parentheticals stripped; a ticket's wave is its first mention.

## Recorded output (2026-09-16)

```
[PASS] 28 tickets UIR-00..UIR-27 with parseable frontmatter
[PASS] every blocked_by id resolves
[PASS] blocked_by graph is acyclic
[PASS] every blocks list is the exact reverse of blocked_by (UIR-09 also blocks GATE-A)
[PASS] only UIR-09 lists the GATE-A pseudo-node
[PASS] luca-final appears in no gates list (closing-only gate)
[PASS] UIR-25: closing_gate luca-final, gates [plan-approval, gate-a], conditional [UIR-26], blocked_by includes UIR-27
[PASS] UIR-26 stays external (blocked_by empty, readiness external)
[PASS] UIR-27 serializes on UIR-22 (shared godot/game/** writer)
[PASS] board waves cover every ticket (UIR-26 external excepted)
[PASS] no ticket is waved before one of its blockers
[PASS] same-wave edges are sequenced by explicit board phrases
[PASS] board ticket table has a row for each ticket
[PASS] write-allowlist collisions are only the documented integration chain
[PASS] README states the serial orders for shared paths
[PASS] every res://tests/ui script referenced by acceptance is owned by exactly one ticket
[PASS] every ticket declares evidence in frontmatter
[PASS] README entrypoint link resolves to the workspace plan

wave map: {'UIR-00': 0, 'UIR-01': 0, 'UIR-02': 1, 'UIR-03': 0, 'UIR-04': 1, 'UIR-05': 1, 'UIR-06': 0, 'UIR-07': 2, 'UIR-08': 2, 'UIR-09': 3, 'UIR-10': 4, 'UIR-11': 4, 'UIR-12': 4, 'UIR-13': 4, 'UIR-14': 4, 'UIR-15': 4, 'UIR-16': 4, 'UIR-17': 4, 'UIR-18': 4, 'UIR-19': 4, 'UIR-20': 4, 'UIR-21': 4, 'UIR-22': 5, 'UIR-23': 4, 'UIR-24': 4, 'UIR-25': 6, 'UIR-26': None, 'UIR-27': 5}
same-wave edges: [('UIR-12', 'UIR-11'), ('UIR-20', 'UIR-13'), ('UIR-20', 'UIR-19'), ('UIR-23', 'UIR-10'), ('UIR-23', 'UIR-11'), ('UIR-23', 'UIR-12'), ('UIR-23', 'UIR-21'), ('UIR-27', 'UIR-22')]
shared paths: {'godot/game/Main.tscn': ['UIR-09', 'UIR-22'], 'godot/game/Match.tscn': ['UIR-09', 'UIR-22'], 'godot/game/hud.gd': ['UIR-09', 'UIR-22'], 'godot/game/main_menu.gd': ['UIR-09', 'UIR-22'], 'godot/game/match_controller.gd': ['UIR-09', 'UIR-22', 'UIR-27'], 'godot/tests/game_slice_test.gd': ['UIR-22', 'UIR-27']}

RESULT: 18/18 checks passed
```

## Scope and limits

- Structural only: it does not run Godot, re-verify repo facts, or judge prose beyond the quoted phrases. The pack's repo facts carry their own evidence pointers; prose-level consistency (claim protocol, acceptance completeness, gate split) was reviewed on the same date by hand.
- It fails closed: any unresolved id, cycle, missing wave, unsequenced same-wave edge, unexpected collision or missing evidence declaration fails the run. Rerun it after any edit to the pack.

## Script (`validate_pack.py`)

```python
#!/usr/bin/env python3
# Structural validation for docs/implementation/ui-recreation (docs-only; no Godot, no repo writes).
# Usage: python3 validate_pack.py [pack_dir]   (default: current directory)
import re, sys, os, glob

PACK = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
results = []

def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}" + (f" — {detail}" if detail and not ok else ""))

def fm_parse(path):
    txt = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", txt, re.S)
    fm = {}
    if not m: return fm, txt
    for line in m.group(1).splitlines():
        mm = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if mm:
            k, v = mm.group(1), mm.group(2).strip()
            fm[k] = [x.strip() for x in v.strip("[]").split(",") if x.strip()] if v.startswith("[") else (v or True)
    return fm, txt

# ---- load ----
tickets = {}
for f in sorted(glob.glob(os.path.join(PACK, "tickets", "UIR-*.md"))):
    fm, txt = fm_parse(f)
    tickets[fm.get("id", os.path.basename(f))] = (fm, txt)
ids = sorted(tickets)
blocked = {k: (v[0].get("blocked_by") or []) for k, v in tickets.items()}

check("28 tickets UIR-00..UIR-27 with parseable frontmatter", ids == ["UIR-%02d" % i for i in range(28)], str(ids))

# ---- refs, acyclicity, reverse consistency ----
bad_refs = [f"{k}->{b}" for k, bl in blocked.items() for b in bl if b not in tickets]
check("every blocked_by id resolves", not bad_refs, str(bad_refs))

state, cyc = {}, []
def visit(n):
    if state.get(n) == "done": return
    if state.get(n) == "open": cyc.append(n); return
    state[n] = "open"
    for b in blocked[n]: visit(b)
    state[n] = "done"
for k in blocked: visit(k)
check("blocked_by graph is acyclic", not cyc, str(cyc))

rev_bad = []
for k, (fm, txt) in tickets.items():
    declared = set(fm.get("blocks") or [])
    reverse = {t for t, bl in blocked.items() if k in bl}
    if k == "UIR-09": reverse.add("GATE-A")  # pseudo-node: the prototype verdict
    if declared != reverse: rev_bad.append(f"{k}: {sorted(declared)} != {sorted(reverse)}")
check("every blocks list is the exact reverse of blocked_by (UIR-09 also blocks GATE-A)", not rev_bad, "; ".join(rev_bad))

pseudo = [k for k, (fm, txt) in tickets.items() if "GATE-A" in (fm.get("blocks") or []) and k != "UIR-09"]
check("only UIR-09 lists the GATE-A pseudo-node", not pseudo, str(pseudo))

# ---- gate split + UIR-25 shape ----
gated_final = [k for k, (fm, txt) in tickets.items() if "luca-final" in (fm.get("gates") or [])]
check("luca-final appears in no gates list (closing-only gate)", not gated_final, str(gated_final))

u25, u26, u27 = tickets["UIR-25"][0], tickets["UIR-26"][0], tickets["UIR-27"][0]
check("UIR-25: closing_gate luca-final, gates [plan-approval, gate-a], conditional [UIR-26], blocked_by includes UIR-27",
      u25.get("closing_gate") == "luca-final"
      and (u25.get("gates") or []) == ["plan-approval", "gate-a"]
      and (u25.get("conditional_blocked_by") or []) == ["UIR-26"]
      and "UIR-27" in (u25.get("blocked_by") or []),
      str({k: u25.get(k) for k in ("closing_gate", "gates", "conditional_blocked_by", "blocked_by")}))
check("UIR-26 stays external (blocked_by empty, readiness external)",
      (u26.get("blocked_by") or []) == [] and u26.get("readiness") == "external",
      str({k: u26.get(k) for k in ("blocked_by", "readiness")}))
check("UIR-27 serializes on UIR-22 (shared godot/game/** writer)",
      "UIR-22" in (u27.get("blocked_by") or []) and "UIR-20" in (u27.get("blocked_by") or []),
      str(u27.get("blocked_by")))

# ---- board waves ----
board = open(os.path.join(PACK, "BOARD.md")).read()
wave_of = {}
for wm in re.finditer(r"^- Wave (\d+)[^:]*: ([^\n]*)$", board, re.M):
    body = re.sub(r"\([^)]*\)", "", wm.group(2))
    for i in re.findall(r"UIR-\d\d", body):
        wave_of.setdefault(i, int(wm.group(1)))
missing = [t for t in tickets if t not in wave_of and t != "UIR-26"]
check("board waves cover every ticket (UIR-26 external excepted)", not missing, str(missing))
viol = [(k, b) for k in tickets for b in blocked[k]
        if b in wave_of and k in wave_of and wave_of[b] > wave_of[k]]
check("no ticket is waved before one of its blockers", not viol, str(viol))
equal = sorted((k, b) for k in tickets for b in blocked[k]
               if b in wave_of and k in wave_of and wave_of[k] == wave_of[b])
probes = {"UIR-12": ("UIR-12 opens when UIR-11 lands", ["UIR-11"]),
          "UIR-20": ("UIR-20 opens when UIR-13 and UIR-19 land", ["UIR-13", "UIR-19"]),
          "UIR-23": ("UIR-23 opens when UIR-10, 11, 12, 21 land", ["UIR-10", "UIR-11", "UIR-12", "UIR-21"]),
          "UIR-27": ("UIR-22 integration, then UIR-27", ["UIR-22"])}
seq_bad = []
for k, b in equal:
    probe, allowed = probes.get(k, (None, []))
    if not probe or b not in allowed: seq_bad.append(f"{k}<-{b} unsequenced")
    elif probe not in board: seq_bad.append(f"{k}<-{b} probe missing")
check("same-wave edges are sequenced by explicit board phrases", not seq_bad, "; ".join(seq_bad))
rows = len(re.findall(r"^\| UIR-\d\d \|", board, re.M))
check("board ticket table has a row for each ticket", rows == 28, f"{rows} rows")

# ---- allowlist collisions + README order statements ----
SKIP = re.compile(r"do not|don't|never|read-only|frozen|leave|no other writes", re.I)
owner_paths = {}
for k, (fm, txt) in tickets.items():
    m = re.search(r"## Write allowlist[^\n]*\n(.*?)(?=\n## |\Z)", txt, re.S)
    if not m: continue
    for line in m.group(1).splitlines():
        if not line.strip().startswith("- ") or SKIP.search(line): continue
        for p in re.findall(r"`([^`]+)`", line):
            if "/" in p and not p.startswith("$"):
                owner_paths.setdefault(p, set()).add(k)
coll = {p: sorted(o) for p, o in owner_paths.items() if len(o) > 1}
allowed = {"godot/game/Main.tscn": ["UIR-09", "UIR-22"],
           "godot/game/Match.tscn": ["UIR-09", "UIR-22"],
           "godot/game/hud.gd": ["UIR-09", "UIR-22"],
           "godot/game/main_menu.gd": ["UIR-09", "UIR-22"],
           "godot/game/match_controller.gd": ["UIR-09", "UIR-22", "UIR-27"],
           "godot/tests/game_slice_test.gd": ["UIR-22", "UIR-27"]}
unexpected = {p: o for p, o in coll.items() if allowed.get(p) != o}
check("write-allowlist collisions are only the documented integration chain", not unexpected, str(unexpected))
readme = open(os.path.join(PACK, "README.md")).read()
probes_r = ["UIR-09, then UIR-22, then UIR-27", "UIR-03, then (only) UIR-22", "UIR-22, plus UIR-27"]
check("README states the serial orders for shared paths", all(p in readme for p in probes_r),
      str([p for p in probes_r if p not in readme]))

# ---- acceptance scripts owned by exactly one ticket ----
used, multi = {}, []
for k, (fm, txt) in tickets.items():
    m = re.search(r"## Acceptance commands[^\n]*\n(.*?)(?=\n## |\Z)", txt, re.S)
    if not m: continue
    for s in set(re.findall(r"res://tests/ui/[A-Za-z0-9_/]+\.(?:gd|tscn)", m.group(1))):
        used.setdefault(s, set()).add(k)
for s, users in sorted(used.items()):
    rel = "godot/" + s.replace("res://", "")
    owners = [k for k, (fm, txt) in tickets.items()
              if re.search(r"(## Write allowlist[\s\S]*?)(?=\n## |\Z)", txt)
              and rel in re.search(r"(## Write allowlist[\s\S]*?)(?=\n## |\Z)", txt).group(1)]
    if len(owners) != 1: multi.append(f"{s}: owners={owners} users={sorted(users)}")
check("every res://tests/ui script referenced by acceptance is owned by exactly one ticket", not multi, "; ".join(multi))

# ---- evidence + entrypoint ----
no_ev = [k for k, (fm, txt) in tickets.items() if not fm.get("evidence")]
check("every ticket declares evidence in frontmatter", not no_ev, str(no_ev))
ep = re.search(r"`(/Users/[^`]+2026-09-16_225600-ui-recreation-plan\.md)`", readme)
check("README entrypoint link resolves to the workspace plan", bool(ep and os.path.exists(ep.group(1))),
      ep.group(1) if ep else "no link")

print()
print("wave map:", {k: wave_of.get(k) for k in ids})
print("same-wave edges:", equal)
print("shared paths:", {p: o for p, o in sorted(coll.items())})
failed = [n for n, ok, d in results if not ok]
print()
print(f"RESULT: {len(results) - len(failed)}/{len(results)} checks passed" + (f"; FAILED: {failed}" if failed else ""))
sys.exit(1 if failed else 0)
```
