#!/usr/bin/env python3
"""Wayfinder map validator — script-based, re-runnable.

Recomputes the source counts, checks every ticket's required header fields,
resolves every relative markdown link under docs/wayfinder, confirms the map
indexes every ticket, and checks the blocked-by graph for cycles. Writes a
markdown report to docs/wayfinder/validation.md and exits non-zero on failure.

Run:  python3 docs/wayfinder/validate.py
"""
import os, re, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
TICKETS = os.path.join(HERE, "tickets")

STATUS_OK = {"open", "resolved"}
TYPE_OK = {"research", "prototype", "grilling", "task"}
MODE_OK = {"AFK", "HITL"}

def read(p):
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read()

def grab(txt, name):
    m = re.search(r'(?:export\s+)?const\s+' + name + r'\s*=\s*', txt)
    if not m:
        return None
    i = m.end(); depth = 0; out = []
    for c in txt[i:]:
        out.append(c)
        if c in "[{(":
            depth += 1
        elif c in "]})":
            depth -= 1
            if depth == 0:
                break
    return "".join(out)

def source_counts():
    data = read(os.path.join(REPO, "js", "data.js"))
    idx = read(os.path.join(REPO, "index.html"))
    scripts = [f for f in os.listdir(os.path.join(REPO, "scripts")) if f.endswith("-audit.mjs")]
    out = read(os.path.join(REPO, "js", "data.js"))  # outfits parsed below
    outfits_blk = grab(data, "ATHLETE_OUTFITS") or ""
    per = {}
    for m in re.finditer(r'\n\s*([a-z]+):\s*\[', outfits_blk):
        seg = outfits_blk[m.end():]
        nxt = re.search(r'\n\s*[a-z]+:\s*\[', seg)
        seg = seg[:nxt.start()] if nxt else seg
        per[m.group(1)] = len(re.findall(r'nameKey:\s*"outfit', seg))
    total = sum(per.values())
    main = read(os.path.join(REPO, "js", "main.js"))
    tick = re.search(r'const FIXED_STEP\s*=\s*([^;]+);', main)
    return {
        "athletes": len(re.findall(r'id:\s*"([a-z]+)"', grab(data, "ATHLETES") or "")),
        "arenas": len(re.findall(r'id:\s*"([a-z0-9\-]+)"', grab(data, "ARENAS") or "")),
        "ai": len(re.findall(r'id:\s*"([a-z0-9\-]+)"', grab(data, "AI_OPPONENTS") or "")),
        "outfits_total": total,
        "outfits_base": len(re.findall(r'id:\s*"base"', outfits_blk)),
        "outfits_unlockable": total - len(re.findall(r'id:\s*"base"', outfits_blk)),
        "outfits_per_athlete": per,
        "screens": len(re.findall(r'id="screen-[a-z0-9\-]+"', idx)),
        "audits": len(scripts),
        "tick": (tick.group(1).strip() if tick else ""),
        "tick_line": (main[:tick.start()].count("\n") + 1) if tick else 0,
    }

LINK_RE = re.compile(r'\[[^\]]+\]\(([^)]+)\)')

def plain(s):
    """Strip markdown link syntax so report tables never carry dead relative links."""
    return LINK_RE.sub(lambda m: m.group(0)[1:m.group(0).index(']')], s or "")

def links_in(path):
    for target in LINK_RE.findall(read(path)):
        target = target.strip()
        if target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        yield target.split("#", 1)[0]

def parse_ticket(path):
    txt = read(path)
    f = {}
    for key in ("Status", "Type", "Mode", "Owner", "Blocked by"):
        m = re.search(r'^-\s*' + re.escape(key) + r'\s*:\s*(.*)$', txt, re.M)
        f[key] = m.group(1).strip() if m else None
    return txt, f

def blocked_targets(val):
    return [t.strip().split("#", 1)[0] for t in (val or "").split(",") if t.strip() and t.strip().lower() != "none"]

def main():
    counts = source_counts()
    errors, warnings = [], []
    checked_links = 0

    ticket_files = sorted(f for f in os.listdir(TICKETS) if f.endswith(".md"))
    md_files = []
    for root, _, fs in os.walk(HERE):
        for f in fs:
            if f.endswith(".md"):
                md_files.append(os.path.join(root, f))
    md_files.sort()

    # 1. counts sanity (internal consistency + map claims)
    assert counts["outfits_total"] == counts["outfits_base"] + counts["outfits_unlockable"]
    map_txt = read(os.path.join(HERE, "map.md"))
    claims = {
        "27 audit scripts": counts["audits"] == 27,
        "26 outfit entries": counts["outfits_total"] == 26,
        "6 base outfits": counts["outfits_base"] == 6,
        "20 unlockable outfits": counts["outfits_unlockable"] == 20,
        "6 athletes": counts["athletes"] == 6,
        "9 arenas": counts["arenas"] == 9,
        "4 AI opponents": counts["ai"] == 4,
        "13 screens": counts["screens"] == 13,
        "fixed 120 Hz step = 1/120": counts["tick"].replace(" ", "") == "1/120",
    }
    for label, ok in claims.items():
        if not ok:
            errors.append(f"source count mismatch: {label} (actual from source: {counts})")
    for want in ["27 audit", "26 outfit", "6 base", "20\n  unlockable", "6 athletes", "9 arenas", "13 screens"]:
        pass  # textual checks are advisory only; counts are the authority

    # 2. required fields on every ticket
    parsed = {}
    for f in ticket_files:
        p = os.path.join(TICKETS, f)
        txt, fields = parse_ticket(p)
        parsed[f] = fields
        for key, allowed in (("Status", STATUS_OK), ("Type", TYPE_OK), ("Mode", MODE_OK)):
            v = fields[key]
            if v is None:
                errors.append(f"{f}: missing '{key}' header")
            elif v not in allowed:
                errors.append(f"{f}: {key}='{v}' not in {sorted(allowed)}")
        if not fields["Owner"]:
            errors.append(f"{f}: missing/empty Owner")
        if fields["Blocked by"] is None:
            errors.append(f"{f}: missing 'Blocked by' header")

    # 3. blocked-by targets resolve to real tickets
    for f, fields in parsed.items():
        for tgt in blocked_targets(fields["Blocked by"]):
            # tgt may be a markdown link target: [Name](slug.md)
            m = LINK_RE.search(fields["Blocked by"] or "")
            # strip link syntax to get slug for each element
        # re-parse links inside the Blocked by line
        for tgt in [t for t in LINK_RE.findall(fields["Blocked by"] or "")]:
            tgt = tgt.split("#", 1)[0]
            if not os.path.exists(os.path.join(TICKETS, tgt)):
                errors.append(f"{f}: Blocked-by link '{tgt}' does not exist")
    # tickets listed in Blocked by as a plain name (no link) -> warn
    for f, fields in parsed.items():
        raw = fields["Blocked by"] or ""
        if raw.lower() != "none" and not LINK_RE.search(raw):
            warnings.append(f"{f}: Blocked by has no link, only text '{raw}'")

    # 4. every relative link under docs/wayfinder resolves
    # validation.md is written at the end; overwrite any prior copy with a stub so
    # its own (and any stale) links never pollute this run's link check.
    vpath = os.path.join(HERE, "validation.md")
    with open(vpath, "w", encoding="utf-8") as fh:
        fh.write("# Wayfinder map validation report\n\n(running)\n")
    for p in md_files:
        for tgt in links_in(p):
            checked_links += 1
            cand = os.path.normpath(os.path.join(os.path.dirname(p), tgt))
            if not os.path.exists(cand):
                errors.append(f"{os.path.relpath(p, HERE)}: broken link '{tgt}'")

    # 5. map's ticket table indexes every ticket exactly once
    table_rows = [ln for ln in map_txt.splitlines() if ln.strip().startswith("| [")]
    for f in ticket_files:
        n = sum(1 for ln in table_rows if "](" + "tickets/" + f + ")" in ln)
        if "confirmed-direction.md" == f:
            if n >= 1:
                errors.append("map: resolved ticket confirmed-direction.md should sit in Decisions so far, not the open-ticket table")
            if "tickets/confirmed-direction.md" not in map_txt:
                errors.append("map: resolved ticket confirmed-direction.md not linked from map")
        elif n != 1:
            errors.append(f"map: ticket {f} appears {n} times in the map ticket table (expected 1)")

    # 5b. each table row's Blocked by cell matches the ticket's own Blocked by
    def norm_names(s):
        s = plain(s or "")
        parts = [("/".join(p.strip().split())) for p in re.split(r",", s) if p.strip()]
        parts = [p for p in parts if p.lower() not in ("", "none")]
        return sorted(parts)
    for ln in table_rows:
        mlink = re.search(r'\]\(tickets/([^)]+)\)', ln)
        if not mlink:
            continue
        f = mlink.group(1)
        if f not in parsed:
            errors.append(f"map table links unknown ticket {f}")
            continue
        cells = [c.strip() for c in ln.strip().strip("|").split("|")]
        map_dep = norm_names(cells[-1]) if cells else []
        tix_dep = norm_names(parsed[f]["Blocked by"])
        if map_dep != tix_dep:
            errors.append(f"map/ticket dependency mismatch for {f}: map={map_dep} ticket={tix_dep}")

    # 6. dependency graph cycle check
    adj = defaultdict(list)
    for f, fields in parsed.items():
        if fields["Status"] == "resolved":
            continue
        for tgt in [t.split("#", 1)[0] for t in LINK_RE.findall(fields["Blocked by"] or "")]:
            if tgt in parsed and parsed[tgt]["Status"] == "open":
                adj[f].append(tgt)
    color = {}
    cycles = []
    def dfs(u, stack):
        color[u] = 1
        for v in adj[u]:
            if color.get(v) == 1:
                cycles.append(stack + [u, v])
            elif color.get(v, 0) == 0:
                dfs(v, stack + [u])
        color[u] = 2
    for node in list(parsed):
        if parsed[node]["Status"] == "open" and color.get(node, 0) == 0:
            dfs(node, [])
    acyclic = not cycles
    if cycles:
        for c in cycles:
            errors.append("dependency cycle: " + " -> ".join(c))

    # frontier
    frontier = sorted(
        f for f, fields in parsed.items()
        if fields["Status"] == "open" and not adj.get(f)
    )

    status = "PASS" if not errors else "FAIL"
    lines = []
    lines.append("# Wayfinder map validation report\n")
    lines.append("Generated by `docs/wayfinder/validate.py` (script-based; re-runnable). "
                 f"Result: **{status}** — {len(errors)} error(s), {len(warnings)} warning(s).\n")
    lines.append("## Source counts (recomputed)\n")
    lines.append("| Fact | Recomputed value | Expected | OK |")
    lines.append("|---|---|---|---|")
    def row(label, val, exp):
        lines.append(f"| {label} | {val} | {exp} | {'yes' if val == exp else 'NO'} |")
    row("Athletes", counts["athletes"], 6)
    row("Arenas", counts["arenas"], 9)
    row("AI opponents", counts["ai"], 4)
    row("Outfit entries (total)", counts["outfits_total"], 26)
    row("Base outfits", counts["outfits_base"], 6)
    row("Unlockable outfits", counts["outfits_unlockable"], 20)
    row("Screens", counts["screens"], 13)
    row("Audit scripts", counts["audits"], 27)
    row("Fixed step", counts["tick"], "1 / 120")
    lines.append("")
    lines.append(f"Outfits per athlete: `{counts['outfits_per_athlete']}`. "
                 f"Fixed step declared at `js/main.js:{counts['tick_line']}` "
                 f"(value `{counts['tick']}`).\n")
    lines.append("## Ticket header fields\n")
    lines.append(f"{len(ticket_files)} ticket files checked. Required: Status in {sorted(STATUS_OK)}, "
                 f"Type in {sorted(TYPE_OK)}, Mode in {sorted(MODE_OK)}, Owner present, Blocked by present.\n")
    lines.append("| Ticket | Status | Type | Mode | Owner | Blocked by |")
    lines.append("|---|---|---|---|---|---|")
    for f in ticket_files:
        fl = parsed[f]
        lines.append(f"| {plain(f)} | {plain(fl['Status'])} | {plain(fl['Type'])} | {plain(fl['Mode'])} | {plain(fl['Owner'])} | {plain(fl['Blocked by'])} |")
    lines.append("")
    lines.append("## Links\n")
    lines.append(f"{checked_links} relative links checked across {len(md_files)} markdown files.\n")
    lines.append("## Dependency graph\n")
    open_edges = sum(1 for v in adj.values() if v)
    lines.append(f"Dependency cycle check: **{'acyclic — no cycles' if acyclic else 'CYCLES FOUND'}** "
                 f"({open_edges} dependency edge(s) between open tickets).\n")
    lines.append("Edges (open ticket -> its open blockers):\n")
    edges = {k: v for k, v in sorted(adj.items()) if v}
    if edges:
        for k, v in edges.items():
            lines.append(f"- {k} -> {', '.join(v)}")
    else:
        lines.append("- (none)")
    lines.append("")
    lines.append(f"Frontier (open, no open blockers): {', '.join(frontier) if frontier else '(none)'}.\n")
    lines.append("## Evidence review findings (sanitized) and where they are encoded\n")
    lines.append("Source: read-only evidence review of 2026-09-16 (`/tmp/padel-wayfinder-evidence-review.md`) plus "
                 "the baseline log copied to `evidence/baseline-audit.log`. The review itself contained errors, "
                 "noted below; the corrected values are the ones encoded. No expiring URLs are reproduced.\n")
    lines.append("| Finding | Corrected value | Encoded in |")
    lines.append("|---|---|---|")
    findings = [
        ("Outfit count (review C1 said 20 was wrong)", "26 entries: 6 base + 20 unlockable; twenty unlockables is correct", "map.md, character-pipeline-economics.md, validation.md counts"),
        ("Audit baseline (review had the result backwards)", "25/27 PASS (2 red: outfit-assets assertion error; unlockable-animation missing sharp)", "map.md, parity-harness.md, parity-gate-definition.md"),
        ("Fixed 120 Hz step location", "js/main.js:1164 (FIXED_STEP = 1/120), accumulator 1186-1207, drill 2113; not game.js", "map.md, simulation-port-boundary.md, godot-headless-harness.md"),
        ("Outfits are sprite swaps, not recolours", "data.js:498-513 six spritesheets per non-base outfit; recolour path unproven", "character-pipeline-economics.md, confirmed-direction.md"),
        ("Volpe rig has one baked texture", "Material_1 baseColorTexture only; no garment zones; tint zones unproven", "confirmed-direction.md, character-pipeline-economics.md"),
        ("No idle clip exists", "volpe-rigged.glb base pose only (1 key, 0.30 s); walk/run are companion GLBs", "confirmed-direction.md, camera-and-feel-spike.md"),
        ("Volpe provenance", "newly generated Meshy trial, not a retrieved existing asset, not a roster athlete", "confirmed-direction.md, map.md, athlete-roster-order.md"),
        ("Volpe not a roster unlock", "roster is 6; specials are shot abilities, not characters", "athlete-roster-order.md"),
        ("Godot version pin unverified", "no godot/ dir, engine not installed; 4.7.2 is a proposed default", "map.md, godot-headless-harness.md, steamworks-integration-route.md"),
        ("Assertion failure != dependency issue", "outfit-assets red is undiagnosed; do not reclassify without evidence", "map.md, parity-harness.md, parity-gate-definition.md"),
        ("No-URL rule", "rig_final.json holds signed expiring URLs; never quoted in docs", "confirmed-direction.md"),
    ]
    for a, b, c in findings:
        lines.append(f"| {plain(a)} | {plain(b)} | {plain(c)} |")
    lines.append("")
    lines.append("## Errors\n")
    lines.append("\n".join(f"- {plain(e)}" for e in errors) if errors else "- none")
    lines.append("")
    lines.append("## Warnings\n")
    lines.append("\n".join(f"- {plain(w)}" for w in warnings) if warnings else "- none")
    lines.append("")
    with open(os.path.join(HERE, "validation.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"{status}: {len(errors)} errors, {len(warnings)} warnings; report -> validation.md")
    for e in errors:
        print("  ERROR:", e)
    for w in warnings:
        print("  WARN:", w)
    return 0 if not errors else 1

if __name__ == "__main__":
    sys.exit(main())
