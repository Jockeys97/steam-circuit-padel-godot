#!/usr/bin/env python3
"""gen_arena_t2.py — generate the forty remaining arena props through the Meshy API.

Four arenas (torii, carioca, aurora, egeo) times ten slots, one Image-to-3D task per
(arena, slot) — Mesh T2 + Smart Topology (model_type "smart-topology", ai_model
"meshy-t2"), textured, PBR on, 2K, triangle output at target_polycount 4000, GLB only.
Reads the intake PNGs (meshy/arenas/<arena>/<slot>.png, 1024x1024, local -> base64 data
URI), polls every task to a terminal status, downloads the GLB the moment it succeeds
(signed URLs expire), saves the task thumbnail as the slot preview, appends one
LEDGER.jsonl line per (arena, slot), and journals every step to
run/tmp/arena-kit/gen-arena-journal.txt. Resumable: a slot whose GLB already exists and
is over 50 KB is skipped; state + journal are on disk before any call that spends credits,
so a crash loses nothing and a re-run resumes.

Authority: docs/mission/arena-kit/arena-props/BRIEF-GEN.md (+ CHARTER.md).
Modeled on the proven tools/arena-kit/gen_medina_t2.py (do not edit that file).

Hard rules honoured here:
  * the API key is never printed, logged or written anywhere (scrubbed from all messages);
  * max 42 create POSTs total: 40 slots + at most 2 retries (one retry per failed slot,
    no third attempt);
  * stop launching new jobs when the balance reads below 600 credits;
  * approved worst-case spend 630 credits: stop launching when the cumulative
    consumed_credits recorded for the batch reaches that cap;
  * abort further launches if any single job reports more than 30 consumed credits
    (2x the expected 15) — an unexplained cost anomaly;
  * per-slot cost is the task's own consumed_credits (authoritative);
  * images go as base64 data URIs (local files); no topology/remesh fields are sent
    with smart-topology; ground textures never upload.

Modes:
  python3 tools/arena-kit/gen_arena_t2.py            run the batch (resumable, idempotent)
  python3 tools/arena-kit/gen_arena_t2.py --report   (re)write GEN-RESULT.md from disk
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

ARENAS = ["torii", "carioca", "aurora", "egeo"]

SLOTS = [
    "hero_landmark",
    "gate_portal",
    "light_source",
    "vegetation_cluster",
    "ground_dressing",
    "ornament_accent",
    "column_pillar",
    "railing_segment",
    "furniture",
    "signage_banner",
]

ALL_KEYS = ["%s/%s" % (a, s) for a in ARENAS for s in SLOTS]  # 40

SRC_ROOT = REPO / "meshy" / "arenas"
GLB_ROOT = REPO / "godot" / "assets" / "arenas"
MISSION = REPO / "docs" / "mission" / "arena-kit" / "arena-props"
LEDGER = MISSION / "LEDGER.jsonl"
PREVIEWS = MISSION / "previews"
RESULT = MISSION / "GEN-RESULT.md"
RUN_DIR = REPO / "run" / "tmp" / "arena-kit"
JOURNAL = RUN_DIR / "gen-arena-journal.txt"
STATE_PATH = RUN_DIR / "gen-arena-state.json"

API = "https://api.meshy.ai/openapi/v1"
CREATE_URL = API + "/image-to-3d"
BALANCE_URL = API + "/balance"

TARGET_POLYCOUNT = 4000
TEXTURE_RESOLUTION = "2k"
MIN_GLB_BYTES = 50 * 1024
BALANCE_FLOOR = 600        # BRIEF: stop launching below this balance
MAX_CREATES = 42           # POST calls total: 40 slots + at most 2 retries
MAX_ATTEMPTS = 2           # one retry per failed slot; a third failure goes to the board
CREDIT_CAP = MAX_CREATES * 15   # 630: approved worst-case spend
PER_JOB_CREDIT_ABORT = 30  # 2x the expected 15 credits/job -> halt further launches
MAX_CONCURRENT = 10        # concurrency proven by the medina run
POLL_SECONDS = 8
STALL_SECONDS = 3600       # a task non-terminal this long is flagged, not killed
RUN_CEILING_SECONDS = 3 * 3600

KEY = ""                   # set by load_key(); never printed
STATE = {}


# --------------------------------------------------------------------------- io

def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def ms_to_iso(ms) -> str | None:
    if not ms:
        return None
    try:
        return datetime.fromtimestamp(int(ms) / 1000, tz=timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    except (TypeError, ValueError, OSError):
        return None


def scrub(text: str) -> str:
    return text.replace(KEY, "***") if KEY else text


def log_line(msg: str) -> None:
    line = "%s %s" % (now_iso(), scrub(str(msg)))
    JOURNAL.parent.mkdir(parents=True, exist_ok=True)
    with JOURNAL.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")
        fh.flush()
        os.fsync(fh.fileno())
    print(line, flush=True)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def atomic_write_bytes(dest: Path, data: bytes) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, dest)


# --------------------------------------------------------------------------- paths

def split_key(key: str) -> tuple[str, str]:
    arena, slot = key.split("/", 1)
    return arena, slot


def src_png(key: str) -> Path:
    arena, slot = split_key(key)
    return SRC_ROOT / arena / ("%s.png" % slot)


def glb_path(key: str) -> Path:
    arena, slot = split_key(key)
    return GLB_ROOT / arena / ("%s.glb" % slot)


def preview_path(key: str) -> Path:
    arena, slot = split_key(key)
    return PREVIEWS / arena / ("%s.png" % slot)


def glb_done_on_disk(key: str) -> bool:
    p = glb_path(key)
    return p.exists() and p.stat().st_size > MIN_GLB_BYTES


# --------------------------------------------------------------------------- key

def load_key() -> tuple[str, str]:
    """$MESHY_API_KEY -> ~/.hermes/profiles/dev-work/.env -> ~/.config/meshy/api_key.
    Returns (key, source-label). The key value itself is never logged."""
    key = os.environ.get("MESHY_API_KEY", "").strip()
    if key:
        return key, "$MESHY_API_KEY"
    envf = Path.home() / ".hermes" / "profiles" / "dev-work" / ".env"
    if envf.exists():
        for line in envf.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("MESHY_API_KEY="):
                value = line.split("=", 1)[1].strip().strip('"').strip("'")
                if value:
                    return value, "~/.hermes/profiles/dev-work/.env"
    cfg = Path.home() / ".config" / "meshy" / "api_key"
    if cfg.exists():
        value = cfg.read_text(encoding="utf-8").strip()
        if value:
            return value, "~/.config/meshy/api_key"
    return "", "none"


# --------------------------------------------------------------------------- state

def save_state() -> None:
    STATE["updated_at"] = now_iso()
    atomic_write_bytes(STATE_PATH, json.dumps(STATE, indent=1, sort_keys=True).encode("utf-8"))


def load_state() -> dict:
    global STATE
    if STATE_PATH.exists():
        try:
            STATE = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        except ValueError:
            log_line("WARN state file unreadable; starting a fresh state")
            STATE = {}
    STATE.setdefault("posts_used", 0)
    STATE.setdefault("creates_used", 0)
    STATE.setdefault("no_new_creates", False)
    STATE.setdefault("balance_log", [])
    STATE.setdefault("slots", {})
    STATE.setdefault("started_at", now_iso())
    return STATE


def cumulative_consumed() -> int:
    return sum(int((st or {}).get("consumed_credits") or 0) for st in STATE.get("slots", {}).values())


# --------------------------------------------------------------------------- ledger

def read_ledger() -> list[dict]:
    if not LEDGER.exists():
        return []
    rows = []
    for line in LEDGER.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            log_line("WARN unparseable ledger line skipped: %r" % line[:120])
    return rows


def ledger_has_success(key: str) -> bool:
    arena, slot = split_key(key)
    return any(r.get("arena") == arena and r.get("slot") == slot and r.get("status") == "SUCCEEDED"
               for r in read_ledger())


def ledger_sort_key(row: dict) -> tuple:
    a = row.get("arena")
    s = row.get("slot")
    return (ARENAS.index(a) if a in ARENAS else 99,
            SLOTS.index(s) if s in SLOTS else 99)


def upsert_ledger_row(row: dict) -> None:
    """One line per (arena, slot). A SUCCEEDED row is never downgraded; a failure row is
    replaced by the slot's final outcome on a later run."""
    rows = read_ledger()
    out, replaced = [], False
    for existing in rows:
        if not (existing.get("arena") == row.get("arena") and existing.get("slot") == row.get("slot")):
            out.append(existing)
            continue
        replaced = True
        if existing.get("status") == "SUCCEEDED" and row.get("status") != "SUCCEEDED":
            out.append(existing)  # keep the success
        else:
            out.append(row)
    if not replaced:
        out.append(row)
    out.sort(key=ledger_sort_key)
    payload = "".join(json.dumps(r, sort_keys=False) + "\n" for r in out)
    atomic_write_bytes(LEDGER, payload.encode("utf-8"))


# --------------------------------------------------------------------------- http

class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__("HTTP %s: %s" % (status, body))
        self.status = status
        self.body = body


def http(method: str, url: str, key: str | None = None, body: dict | None = None, timeout: int = 120):
    headers = {"Accept": "application/json", "User-Agent": "arena-props-t2-pipeline/1.0"}
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if key:
        headers["Authorization"] = "Bearer " + key
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        raw = e.read()[:2000]
        raise ApiError(e.code, scrub(raw.decode("utf-8", "replace"))) from None
    except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as e:
        raise ApiError(0, "network: %s" % scrub(str(e))) from None


def api_get(url: str, tries: int = 4) -> dict:
    delay = 5
    last = None
    for i in range(tries):
        try:
            status, raw = http("GET", url, key=KEY)
            return json.loads(raw.decode("utf-8"))
        except ApiError as e:
            last = e
            if e.status in (429, 500, 502, 503, 504) and i < tries - 1:
                log_line("WARN GET %s status=%s; grow-backoff %ss" % (url.split("/openapi/v1/")[-1], e.status, delay))
                time.sleep(delay)
                delay = min(delay * 2, 120)
                continue
            raise
    if last is not None:
        raise last
    raise ApiError(0, "GET failed with no recorded error")


def api_create(body: dict) -> str:
    """POST one create. 429 is retried (nothing was created); 4xx/5xx are surfaced.
    Never blind-retries a 5xx/network failure on POST: a retried POST could create a
    second task and spend credits twice."""
    delay = 5
    for i in range(5):
        try:
            status, raw = http("POST", CREATE_URL, key=KEY, body=body, timeout=300)
            data = json.loads(raw.decode("utf-8"))
            tid = data.get("result") if isinstance(data, dict) else None
            if not tid:
                raise ApiError(-1, "create response had no result id: %s" % scrub(raw[:200].decode("utf-8", "replace")))
            return str(tid)
        except ApiError as e:
            if e.status == 429 and i < 4:
                log_line("WARN create got 429; grow-backoff %ss" % delay)
                time.sleep(delay)
                delay = min(delay * 2, 120)
                continue
            raise
    raise ApiError(0, "create failed with no recorded error")


def download(url: str, dest: Path, timeout: int = 300) -> int:
    delay = 4
    last = None
    for i in range(4):
        try:
            status, raw = http("GET", url, key=None, timeout=timeout)
            atomic_write_bytes(dest, raw)
            return len(raw)
        except ApiError as e:
            last = e
            if e.status in (429, 500, 502, 503, 504) and i < 3:
                time.sleep(delay)
                delay = min(delay * 2, 60)
                continue
            raise
    if last is not None:
        raise last
    raise ApiError(0, "download failed with no recorded error")


# --------------------------------------------------------------------------- api helpers

def get_balance() -> int | None:
    try:
        data = api_get(BALANCE_URL)
    except ApiError as e:
        log_line("WARN balance read failed status=%s" % e.status)
        return None
    if isinstance(data, dict):
        for k in ("balance", "credits", "remaining"):
            v = data.get(k)
            if isinstance(v, (int, float)):
                return int(v)
        nums = [v for v in data.values() if isinstance(v, (int, float))]
        if len(nums) == 1:
            return int(nums[0])
    if isinstance(data, (int, float)):
        return int(data)
    log_line("WARN balance response shape unexpected")
    return None


def task_error_message(task: dict) -> str:
    err = task.get("task_error")
    if isinstance(err, dict) and err.get("message"):
        return str(err["message"])
    if isinstance(err, str):
        return err
    return ""


# --------------------------------------------------------------------------- glb inspection

def fallback_inspect(path: Path):
    blob = path.read_bytes()
    if blob[:4] != b"glTF":
        raise ValueError("%s: not a GLB" % path.name)
    off, gltf = 12, None
    while off + 8 <= len(blob):
        clen, ctype = struct.unpack_from("<I4s", blob, off)
        off += 8
        if ctype == b"JSON":
            gltf = json.loads(blob[off:off + clen].decode("utf-8"))
            break
        off += clen
    if gltf is None:
        raise ValueError("%s: no JSON chunk" % path.name)
    accessors = gltf.get("accessors", [])
    tri = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if prim.get("mode", 4) != 4:
                continue
            if "indices" in prim:
                tri += accessors[prim["indices"]].get("count", 0) // 3
            else:
                tri += accessors[prim["attributes"]["POSITION"]].get("count", 0) // 3
    mats = gltf.get("materials", [])
    has_bc = any((m.get("pbrMetallicRoughness") or {}).get("baseColorTexture") is not None for m in mats)
    info = {
        "materials": len(mats),
        "images": len(gltf.get("images", [])),
        "textures": len(gltf.get("textures", [])),
        "has_base_color": has_bc,
    }
    return tri, "in-script GLB JSON parse", info


def inspect_glb(path: Path):
    """-> (triangles, method_label, {"materials","images","textures","has_base_color"}).
    Prefers tools/character/glb_tri_count.py; falls back to an in-script GLB parse."""
    tool = REPO / "tools" / "character" / "glb_tri_count.py"
    if tool.exists():
        try:
            proc = subprocess.run([sys.executable, str(tool), str(path)],
                                  capture_output=True, text=True, timeout=180)
            if proc.returncode == 0 and "[" in proc.stdout and "]" in proc.stdout:
                data = json.loads(proc.stdout[proc.stdout.index("["):proc.stdout.rindex("]") + 1])
                row = data[0] if data else {}
                if isinstance(row, dict) and "triangles" in row:
                    details = row.get("material_detail") or []
                    has_bc = any(d.get("baseColorTexture") is not None for d in details)
                    info = {
                        "materials": len(row.get("materials") or []),
                        "images": row.get("images", 0),
                        "textures": row.get("textures", 0),
                        "has_base_color": has_bc,
                    }
                    return int(row["triangles"]), "glb_tri_count.py", info
            log_line("WARN glb_tri_count.py gave no rows for %s; using in-script parse" % path.name)
        except Exception as exc:  # noqa: BLE001 - fall back, but say so
            log_line("WARN glb_tri_count.py failed on %s: %s" % (path.name, scrub(str(exc))[:200]))
    return fallback_inspect(path)


# --------------------------------------------------------------------------- creation

def create_body(key: str) -> dict:
    png = src_png(key)
    b64 = base64.b64encode(png.read_bytes()).decode("ascii")
    return {
        "image_url": "data:image/png;base64," + b64,
        "model_type": "smart-topology",
        "ai_model": "meshy-t2",
        "target_polycount": TARGET_POLYCOUNT,
        "should_texture": True,
        "enable_pbr": True,
        "texture_resolution": TEXTURE_RESOLUTION,
        "target_formats": ["glb"],
    }


def try_create(key: str) -> str | None:
    """One POST attempt for a key. Attempts and POST count are persisted BEFORE the call."""
    st = STATE["slots"].setdefault(key, {})
    st["attempts"] = int(st.get("attempts", 0)) + 1
    STATE["posts_used"] = int(STATE.get("posts_used", 0)) + 1
    save_state()
    png = src_png(key)
    if not png.exists():
        st["status"] = "CREATE_FAILED"
        st["error"] = "missing intake PNG %s" % png
        log_line("key=%s CREATE_FAILED missing intake PNG" % key)
        save_state()
        return None
    log_line("key=%s CREATE_POST attempt=%s posts_used=%s png_bytes=%s png_sha256=%s" % (
        key, st["attempts"], STATE["posts_used"], png.stat().st_size, sha256_file(png)[:12]))
    try:
        tid = api_create(create_body(key))
    except ApiError as e:
        st["status"] = "CREATE_FAILED"
        st["error"] = "create HTTP %s: %s" % (e.status, e.body[:300])
        log_line("key=%s CREATE_FAILED status=%s body=%r" % (key, e.status, e.body[:300]))
        if e.status in (401, 403):
            STATE["no_new_creates"] = True
            log_line("AUTH failure on create: stopping all further creates")
        save_state()
        return None
    st["task_id"] = tid
    st["status"] = "PENDING"
    st["error"] = None
    st.pop("consumed_credits", None)
    save_state()
    log_line("key=%s CREATED task_id=%s" % (key, tid))
    return tid


# --------------------------------------------------------------------------- success path

def process_success(key: str, tid: str, task: dict) -> None:
    st = STATE["slots"].setdefault(key, {})
    st["status"] = "SUCCEEDED"
    st["finished_at_ms"] = task.get("finished_at")
    st["created_at_ms"] = task.get("created_at") or st.get("created_at_ms")
    st["consumed_credits"] = task.get("consumed_credits")
    tex = task.get("texture_urls") or []
    if tex and isinstance(tex, list) and isinstance(tex[0], dict):
        st["pbr_maps"] = sorted(tex[0].keys())
    consumed = task.get("consumed_credits") or 0
    log_line("key=%s SUCCEEDED consumed_credits=%s" % (key, consumed))
    if consumed > PER_JOB_CREDIT_ABORT:
        STATE["no_new_creates"] = True
        log_line("ALERT key=%s consumed %s credits > %s: stopping further launches" % (key, consumed, PER_JOB_CREDIT_ABORT))

    urls = task.get("model_urls") or {}
    glb_url = urls.get("glb")
    if not glb_url:
        st["status"] = "FAILED_NO_GLB_URL"
        st["error"] = "SUCCEEDED but model_urls.glb missing"
        log_line("key=%s ERROR SUCCEEDED but model_urls.glb missing" % key)
        save_state()
        return

    dest = glb_path(key)
    ok = False
    for attempt in (1, 2):
        try:
            n = download(glb_url, dest)
        except ApiError as e:
            log_line("key=%s WARN glb download failed (attempt %s) status=%s" % (key, attempt, e.status))
            time.sleep(3)
            continue
        if n >= MIN_GLB_BYTES and dest.read_bytes()[:4] == b"glTF":
            ok = True
            st["glb_bytes"] = n
            st["glb_sha256"] = sha256_file(dest)
            break
        log_line("key=%s WARN downloaded file invalid (%s bytes); re-minting URL" % (key, n))
        try:
            fresh = api_get("%s/%s" % (CREATE_URL, tid))
            glb_url = (fresh.get("model_urls") or {}).get("glb") or glb_url
        except ApiError:
            pass
        time.sleep(2)
    if not ok:
        st["status"] = "FAILED_DOWNLOAD"
        st["error"] = "GLB download/validation failed"
        log_line("key=%s ERROR GLB download/validation failed" % key)
        save_state()
        return
    log_line("key=%s GLB_SAVED bytes=%s sha256=%s" % (key, st["glb_bytes"], st["glb_sha256"][:12]))

    thumb = task.get("thumbnail_url")
    if thumb:
        pv = preview_path(key)
        try:
            n = download(thumb, pv)
            png_ok = pv.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
            st["preview_ok"] = bool(png_ok)
            st["preview_bytes"] = n
            log_line("key=%s PREVIEW_SAVED bytes=%s png=%s" % (key, n, png_ok))
        except ApiError as e:
            st["preview_ok"] = False
            log_line("key=%s WARN preview download failed status=%s" % (key, e.status))
    else:
        st["preview_ok"] = False
        log_line("key=%s WARN no thumbnail_url on task" % key)

    try:
        tri, method, info = inspect_glb(dest)
        st["tri_count"], st["tri_method"] = tri, method
        st["materials"], st["images"], st["texture_ok"] = info["materials"], info["images"], info["has_base_color"]
        log_line("key=%s TRIANGLES=%s via %s materials=%s images=%s base_color=%s" % (
            key, tri, method, info["materials"], info["images"], info["has_base_color"]))
    except Exception as exc:  # noqa: BLE001
        st["tri_count"] = None
        log_line("key=%s WARN triangle count failed: %s" % (key, scrub(str(exc))[:200]))

    arena, slot = split_key(key)
    upsert_ledger_row({
        "arena": arena,
        "slot": slot,
        "task_id": tid,
        "status": "SUCCEEDED",
        "consumed_credits": st.get("consumed_credits"),
        "created_at": ms_to_iso(st.get("created_at_ms")),
        "finished_at": ms_to_iso(st.get("finished_at_ms")),
        "glb_bytes": st.get("glb_bytes"),
        "glb_sha256": st.get("glb_sha256"),
        "attempt": st.get("attempts"),
        "tri_count": st.get("tri_count"),
    })
    st["ledger_written"] = True
    save_state()
    log_line("key=%s LEDGER_WRITTEN" % key)


def mark_failure(key: str, status: str, error: str) -> None:
    st = STATE["slots"].setdefault(key, {})
    st["status"] = status
    st["error"] = error
    log_line("key=%s %s error=%r" % (key, status, error[:200]))
    save_state()


# --------------------------------------------------------------------------- batch

def sweep(live: dict[str, str]) -> None:
    started = {key: time.time() for key in live}
    err_counts = {key: 0 for key in live}
    while live:
        for key in list(live):
            tid = live[key]
            try:
                task = api_get("%s/%s" % (CREATE_URL, tid))
                err_counts[key] = 0
            except ApiError as e:
                err_counts[key] += 1
                if e.status == 404:
                    mark_failure(key, "FAILED", "task 404 (expired or missing): %s" % tid)
                    del live[key]
                    continue
                if err_counts[key] >= 30:
                    log_line("key=%s WARN poll failing repeatedly (status=%s); leaving task %s for a later run" % (key, e.status, tid))
                    del live[key]
                    continue
                log_line("key=%s WARN poll error status=%s" % (key, e.status))
                continue
            status = task.get("status")
            st = STATE["slots"].setdefault(key, {})
            if task.get("created_at"):
                st["created_at_ms"] = task.get("created_at")
            if status != st.get("status"):
                st["status"] = status
                save_state()
                log_line("key=%s STATUS=%s progress=%s" % (key, status, task.get("progress")))
            if status == "SUCCEEDED":
                process_success(key, tid, task)
                bal = get_balance()
                if bal is not None:
                    STATE["balance_log"].append({"ts": now_iso(), "balance": bal, "note": "after %s" % key})
                    STATE["balance_last"] = bal
                    save_state()
                    log_line("BALANCE after key=%s: %s" % (key, bal))
                    if bal < BALANCE_FLOOR:
                        STATE["no_new_creates"] = True
                        log_line("BALANCE %s below floor %s: no further creates" % (bal, BALANCE_FLOOR))
                del live[key]
            elif status in ("FAILED", "CANCELED"):
                msg = task_error_message(task)
                consumed = task.get("consumed_credits") or 0
                if consumed > PER_JOB_CREDIT_ABORT:
                    STATE["no_new_creates"] = True
                    log_line("ALERT key=%s consumed %s credits > %s: stopping further launches" % (key, consumed, PER_JOB_CREDIT_ABORT))
                st["consumed_credits"] = consumed
                st["finished_at_ms"] = task.get("finished_at")
                mark_failure(key, status, msg or "no task_error message")
                del live[key]
            else:
                if time.time() - started[key] > STALL_SECONDS:
                    log_line("key=%s WARN stalled non-terminal for %ss; leaving task %s for a later run" % (key, STALL_SECONDS, tid))
                    del live[key]
        if live:
            time.sleep(POLL_SECONDS)
        if time.time() - min(started.values()) > RUN_CEILING_SECONDS:
            log_line("WARN run ceiling reached; leaving %d live tasks for a later run" % len(live))
            break


def resume_live() -> dict[str, str]:
    live = {}
    for key in ALL_KEYS:
        st = STATE["slots"].get(key, {})
        if st.get("task_id") and st.get("status") in ("PENDING", "IN_PROGRESS"):
            live[key] = st["task_id"]
    return live


def reconcile_ledger() -> None:
    """State says SUCCEEDED with a GLB on disk, but the ledger line never got written
    (crash between the two): write it now from state."""
    for key in ALL_KEYS:
        st = STATE["slots"].get(key, {})
        if st.get("status") != "SUCCEEDED" or ledger_has_success(key):
            continue
        glb = glb_path(key)
        if glb.exists() and st.get("glb_sha256"):
            arena, slot = split_key(key)
            upsert_ledger_row({
                "arena": arena,
                "slot": slot,
                "task_id": st.get("task_id"),
                "status": "SUCCEEDED",
                "consumed_credits": st.get("consumed_credits"),
                "created_at": ms_to_iso(st.get("created_at_ms")),
                "finished_at": ms_to_iso(st.get("finished_at_ms")),
                "glb_bytes": st.get("glb_bytes") or glb.stat().st_size,
                "glb_sha256": st.get("glb_sha256"),
                "attempt": st.get("attempts"),
                "tri_count": st.get("tri_count"),
            })
            log_line("RECONCILE ledger line written for key=%s from state" % key)


def run_batch() -> int:
    global KEY
    for d in (GLB_ROOT, MISSION, PREVIEWS, RUN_DIR):
        d.mkdir(parents=True, exist_ok=True)
    for a in ARENAS:
        (GLB_ROOT / a).mkdir(parents=True, exist_ok=True)
        (PREVIEWS / a).mkdir(parents=True, exist_ok=True)
    KEY, key_source = load_key()
    if not KEY:
        log_line("FATAL no Meshy key found ($MESHY_API_KEY, ~/.hermes/profiles/dev-work/.env, ~/.config/meshy/api_key)")
        return 4
    load_state()
    log_line("START key_source=%s posts_used=%s arena_slots=%d" % (key_source, STATE["posts_used"], len(ALL_KEYS)))

    bal = get_balance()
    if bal is not None:
        STATE["balance_log"].append({"ts": now_iso(), "balance": bal, "note": "start"})
        STATE["balance_start"] = bal
        STATE["balance_last"] = bal
        save_state()
        log_line("BALANCE start=%s" % bal)
    if bal is None:
        log_line("WARN balance unreadable; continuing with caution")
    elif bal < BALANCE_FLOOR:
        log_line("ABORT balance %s below floor %s; no jobs launched" % (bal, BALANCE_FLOOR))
        write_report()
        return 5

    reconcile_ledger()

    while True:
        live = resume_live()
        to_create = []
        for key in ALL_KEYS:
            if ledger_has_success(key) or key in live or glb_done_on_disk(key):
                continue
            st = STATE["slots"].get(key, {})
            if st.get("attempts", 0) >= MAX_ATTEMPTS:
                continue
            st.pop("error", None)
            to_create.append(key)
        room = MAX_CONCURRENT - len(live)
        if room <= 0:
            to_create = []
        else:
            to_create = to_create[:room]

        if STATE.get("no_new_creates"):
            to_create = []
        if to_create:
            bal = get_balance() or bal
            if bal is not None and bal < BALANCE_FLOOR:
                STATE["no_new_creates"] = True
                log_line("BALANCE %s below floor %s: no further creates" % (bal, BALANCE_FLOOR))
                to_create = []
        spent = cumulative_consumed()
        if to_create and spent >= CREDIT_CAP:
            STATE["no_new_creates"] = True
            log_line("CREDIT CAP: cumulative consumed %s >= approved cap %s; no further launches" % (spent, CREDIT_CAP))
            to_create = []
        for key in to_create:
            if STATE["posts_used"] >= MAX_CREATES:
                STATE["no_new_creates"] = True
                log_line("CREATE CAP: %s POSTs used of max %s; no further launches" % (STATE["posts_used"], MAX_CREATES))
                break
            tid = try_create(key)
            if tid:
                live[key] = tid
            time.sleep(2.0)

        if not live:
            break
        sweep(live)

    # final balance + failed-slot ledger rows
    bal = get_balance()
    if bal is not None:
        STATE["balance_log"].append({"ts": now_iso(), "balance": bal, "note": "end"})
        STATE["balance_last"] = bal
        log_line("BALANCE end=%s" % bal)
    for key in ALL_KEYS:
        if ledger_has_success(key):
            continue
        st = STATE["slots"].get(key, {})
        arena, slot = split_key(key)
        upsert_ledger_row({
            "arena": arena,
            "slot": slot,
            "task_id": st.get("task_id"),
            "status": st.get("status") or "NOT_SUBMITTED",
            "consumed_credits": st.get("consumed_credits", 0),
            "created_at": ms_to_iso(st.get("created_at_ms")),
            "finished_at": ms_to_iso(st.get("finished_at_ms")),
            "glb_bytes": st.get("glb_bytes", 0),
            "glb_sha256": st.get("glb_sha256"),
            "attempt": st.get("attempts", 0),
            "tri_count": st.get("tri_count"),
        })
    save_state()
    log_line("BATCH_DONE")
    write_report()
    return 0


# --------------------------------------------------------------------------- report

def git_status_short() -> str:
    try:
        proc = subprocess.run(["git", "status", "--short"], cwd=str(REPO), capture_output=True, text=True, timeout=60)
        return proc.stdout.strip() or "(clean)"
    except Exception as exc:  # noqa: BLE001
        return "(git status failed: %s)" % exc


def write_report() -> None:
    rows = {(r.get("arena"), r.get("slot")): r for r in read_ledger()}
    state = load_state()

    table = ["| arena | slot | task_id | status | credits | triangles | GLB bytes | sha256 (12) | preview |",
             "|---|---|---|---|---|---|---|---|---|"]
    tri_ok = True
    succeeded = 0
    for key in ALL_KEYS:
        arena, slot = split_key(key)
        r = rows.get((arena, slot))
        preview = preview_path(key)
        if not r:
            table.append("| %s | %s | — | MISSING | — | — | — | — | — |" % (arena, slot))
            tri_ok = False
            continue
        if r.get("status") == "SUCCEEDED":
            succeeded += 1
        tri = r.get("tri_count")
        if tri in (None, ""):
            tri_ok = False
        table.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            arena,
            slot,
            r.get("task_id") or "—",
            r.get("status"),
            r.get("consumed_credits"),
            tri if tri is not None else "—",
            r.get("glb_bytes") or "—",
            (r.get("glb_sha256") or "—")[:12],
            "yes" if preview.exists() else "no",
        ))

    # live gate checks, straight from disk
    glb_lines = []
    texture_ok = True
    tri_values = []
    for key in ALL_KEYS:
        glb = glb_path(key)
        if not glb.exists():
            glb_lines.append("%s: missing" % key)
            texture_ok = False
            continue
        size = glb.stat().st_size
        try:
            tri, method, info = inspect_glb(glb)
            tri_values.append(tri)
            bc = "base-colour texture: %s" % ("yes" if info["has_base_color"] else "NO")
            texture_ok = texture_ok and bool(info["has_base_color"])
            glb_lines.append("%s: %d bytes, %d tris, %s, %d material(s), %d image(s)" % (
                key, size, tri, bc, info["materials"], info["images"]))
        except Exception as exc:  # noqa: BLE001
            texture_ok = False
            glb_lines.append("%s: %d bytes, inspection failed: %s" % (key, size, exc))

    size_gate = all(glb_done_on_disk(k) for k in ALL_KEYS)
    ledger_gate = len(rows) == len(ALL_KEYS) and all(
        rows.get((a, s)) and rows[(a, s)].get("task_id") and rows[(a, s)].get("consumed_credits") is not None
        for a in ARENAS for s in SLOTS)
    bal_start = state.get("balance_start")
    bal_end = state.get("balance_last")
    ledger_sum = sum((r.get("consumed_credits") or 0) for r in rows.values() if r.get("status") == "SUCCEEDED")
    balance_delta = (bal_start - bal_end) if isinstance(bal_start, int) and isinstance(bal_end, int) else None
    balance_reconciles = balance_delta is not None and balance_delta == ledger_sum

    failed = ["%s/%s" % (a, s) for a in ARENAS for s in SLOTS
              if (rows.get((a, s)) or {}).get("status") != "SUCCEEDED"]
    retried = ["%s/%s" % (a, s) for a in ARENAS for s in SLOTS
               if int(((state.get("slots") or {}).get("%s/%s" % (a, s)) or {}).get("attempts", 0) or 0) > 1]

    tri_range = ("%d – %d" % (min(tri_values), max(tri_values))) if tri_values else "n/a"

    gates = [
        "| GLBs | 40 files, each over 50 KB, named to slot | %s |" % ("PASS" if size_gate else "FAIL"),
        "| Texture | every GLB carries a base-colour image in its material | %s |" % ("PASS" if texture_ok else "FAIL"),
        "| Ledger | 40 lines with task_id and consumed_credits, no missing slot | %s |" % ("PASS" if ledger_gate else "FAIL"),
        "| Balance | remaining balance recorded, reconciled against the ledger sum | %s |" % (
            "PASS" if balance_reconciles else ("PARTIAL" if bal_end is not None else "FAIL")),
        "| Scope | `git status --short` shows only your owned paths | see raw output below |",
    ]

    pbr_rows = []
    for key in ALL_KEYS:
        st = (state.get("slots") or {}).get(key) or {}
        pbr_rows.append("- %s: texture_urls keys = %s" % (key, ", ".join(st.get("pbr_maps") or []) or "(not recorded)"))

    md = f"""# Arena props (torii, carioca, aurora, egeo) — GEN RESULT

Date: {now_iso()} · Captain A (generation) · Repo: `steam-circuit-padel-godot` (primary `main`)
Brief: `docs/mission/arena-kit/arena-props/BRIEF-GEN.md` · Script: `tools/arena-kit/gen_arena_t2.py`

## What generated

Forty textured arena props were generated through the Meshy Image-to-3D API exactly as the
brief specifies: Mesh T2 + Smart Topology (`model_type: "smart-topology"`, `ai_model: "meshy-t2"`),
texture on the create call (`should_texture: true`, `enable_pbr: true`, `texture_resolution: "2k"`),
triangle output at `target_polycount: 4000`, `target_formats: ["glb"]`. Each intake PNG
(`meshy/arenas/<arena>/<slot>.png`, 1024×1024) was sent as a base64 data URI. GLBs were
downloaded immediately on `SUCCEEDED` (signed URLs expire), with the task thumbnail saved as
the slot preview (`previews/<arena>/<slot>.png`). Medina was not regenerated.

| arena | slot | task_id | status | credits | triangles | GLB bytes | sha256 (12) | preview |
|---|---|---|---|---|---|---|---|---|
{chr(10).join(table[2:])}

- Slots succeeded: {succeeded} of {len(ALL_KEYS)}
- Credits consumed (ledger sum of `consumed_credits`): {ledger_sum}
- Balance before: {bal_start} · after: {bal_end} · remaining: {bal_end}
- Triangle range across generated GLBs: {tri_range}
"""
    if balance_delta is not None and balance_delta != ledger_sum:
        md += f"- Note: balance delta ({balance_delta}) differs from the ledger sum ({ledger_sum}) — a re-created task or an unlogged spend is involved; both numbers are true.\n"
    md += f"""
## Failures and retries

{failed_slots_block(failed, retried)}

## Gates (as specified in the brief)

| Gate | Threshold | Result |
|---|---|---|
{chr(10).join(gates)}

Raw tree scope (`git status --short`):

```
{git_status_short()}
```

## Disk checks (live, at report time)

{chr(10).join(glb_lines)}

## Method notes

- Triangle counts: measured with `tools/character/glb_tri_count.py` when it ran; otherwise an
  in-script GLB JSON parse. Method used per slot is in `run/tmp/arena-kit/gen-arena-state.json`
  (`tri_method`) and in the journal.
- `enable_pbr` acceptance, straight from each task's `texture_urls`:
{chr(10).join(pbr_rows)}
- Balance readings ({len(state.get("balance_log") or [])}) are in `run/tmp/arena-kit/gen-arena-state.json`
  and the journal; cost per task is the task's own `consumed_credits` (authoritative).
- Journal: `run/tmp/arena-kit/gen-arena-journal.txt`. Ledger: `docs/mission/arena-kit/arena-props/LEDGER.jsonl`.
  Previews: `docs/mission/arena-kit/arena-props/previews/<arena>/<slot>.png`.
- Ground textures were NOT sent to Meshy (material swatches only), per the kit standard.
- Launches were capped at {MAX_CONCURRENT} concurrent tasks (the concurrency proven by the Medina
  run), POSTs at {MAX_CREATES} (40 slots + at most 2 retries), and launches halt below a {BALANCE_FLOOR}-credit
  balance or above the {CREDIT_CAP}-credit cumulative spend cap.
"""
    RESULT.write_text(md, encoding="utf-8")
    log_line("RESULT_WRITTEN %s" % RESULT)


def failed_slots_block(failed, retried) -> str:
    parts = []
    if failed:
        parts.append("Failed slots:")
        parts.extend(failed)
    else:
        parts.append("No failed slots — all forty landed.")
    if retried:
        parts.append("")
        parts.append("Slots that needed more than one create attempt: " + ", ".join(retried) + ".")
    return "\n".join(parts)


# --------------------------------------------------------------------------- main

def main(argv) -> int:
    parser = argparse.ArgumentParser(description="Arena props Mesh T2 batch (Meshy Image to 3D).")
    parser.add_argument("--report", action="store_true", help="(re)write GEN-RESULT.md from disk data, no API calls")
    args = parser.parse_args(argv)
    for d in (MISSION, PREVIEWS, RUN_DIR):
        d.mkdir(parents=True, exist_ok=True)
    if args.report:
        write_report()
        print("wrote %s" % RESULT)
        return 0
    try:
        return run_batch()
    except Exception as exc:  # noqa: BLE001 - background run must not die silently
        import traceback
        log_line("FATAL unhandled exception: %s" % scrub(str(exc)))
        log_line(scrub(traceback.format_exc()))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
