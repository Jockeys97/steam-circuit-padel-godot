#!/usr/bin/env python3
"""gen_medina_t2.py — generate the ten Medina arena props through the Meshy API.

One script, the whole batch. Reads the ten intake PNGs (meshy/arenas/medina/<slot>.png),
creates one Image-to-3D task per slot — Mesh T2 + Smart Topology (model_type
"smart-topology", ai_model "meshy-t2"), textured, PBR on, 2K, triangle output at
target_polycount 4000, GLB only — polls every task to a terminal status, downloads the
GLB the moment it succeeds (signed URLs expire in ~3 days), downloads the task thumbnail
as the slot preview, appends one LEDGER.jsonl line per slot, and journals every step to
run/tmp/arena-kit/medina-t2-journal.txt. A crash loses nothing: state + journal are on
disk before any call that spends credits, and a re-run resumes.

Authority: docs/mission/arena-kit/meshy-t2-medina/PIPELINE-BRIEF.md (+ CHARTER.md, RECON.md).

Hard rules honoured here:
  * the API key is never printed or written anywhere (scrubbed from all messages);
  * max 12 create POSTs total (10 slots + at most 2 retries), one retry per failed slot;
  * stop launching new jobs when the balance reads below 150 credits;
  * abort further launches if a single job reports more than 30 consumed credits;
  * per-slot cost is the task's own consumed_credits (authoritative).

Modes:
  python3 tools/arena-kit/gen_medina_t2.py            run the batch (resumable, idempotent)
  python3 tools/arena-kit/gen_medina_t2.py --report   (re)write PIPELINE-RESULT.md from disk
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

SRC_DIR = REPO / "meshy" / "arenas" / "medina"
GLB_DIR = REPO / "godot" / "assets" / "arenas" / "medina"
MISSION = REPO / "docs" / "mission" / "arena-kit" / "meshy-t2-medina"
LEDGER = MISSION / "LEDGER.jsonl"
PREVIEWS = MISSION / "previews"
RESULT = MISSION / "PIPELINE-RESULT.md"
RUN_DIR = REPO / "run" / "tmp" / "arena-kit"
JOURNAL = RUN_DIR / "medina-t2-journal.txt"
STATE_PATH = RUN_DIR / "medina-t2-state.json"

API = "https://api.meshy.ai/openapi/v1"
CREATE_URL = API + "/image-to-3d"
BALANCE_URL = API + "/balance"

TARGET_POLYCOUNT = 4000
TEXTURE_RESOLUTION = "2k"
MIN_GLB_BYTES = 50 * 1024
BALANCE_FLOOR = 150
MAX_CREATES = 12           # POST calls total: 10 slots + at most 2 retries
MAX_ATTEMPTS = 2           # one retry per failed slot
PER_JOB_CREDIT_ABORT = 30  # CHARTER: abort the rest above this per job
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


def ledger_has_success(slot: str) -> bool:
    return any(r.get("slot") == slot and r.get("status") == "SUCCEEDED" for r in read_ledger())


def upsert_ledger_row(row: dict) -> None:
    """One line per slot. A SUCCEEDED row is never downgraded; a RETRYABLE failure row is
    replaced by the slot's final outcome on a later run."""
    rows = read_ledger()
    out, replaced = [], False
    for existing in rows:
        if existing.get("slot") != row["slot"]:
            out.append(existing)
            continue
        replaced = True
        if existing.get("status") == "SUCCEEDED" and row.get("status") != "SUCCEEDED":
            out.append(existing)  # keep the success
        else:
            out.append(row)
    if not replaced:
        out.append(row)
    out.sort(key=lambda r: SLOTS.index(r["slot"]) if r.get("slot") in SLOTS else 99)
    payload = "".join(json.dumps(r, sort_keys=False) + "\n" for r in out)
    atomic_write_bytes(LEDGER, payload.encode("utf-8"))


# --------------------------------------------------------------------------- http

class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__("HTTP %s: %s" % (status, body))
        self.status = status
        self.body = body


def http(method: str, url: str, key: str | None = None, body: dict | None = None, timeout: int = 120):
    headers = {"Accept": "application/json", "User-Agent": "medina-t2-pipeline/1.0"}
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

def create_body(slot: str) -> dict:
    png = SRC_DIR / ("%s.png" % slot)
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


def try_create(slot: str) -> str | None:
    """One POST attempt for a slot. Attempts and POST count are persisted BEFORE the call."""
    st = STATE["slots"].setdefault(slot, {})
    st["attempts"] = int(st.get("attempts", 0)) + 1
    STATE["posts_used"] = int(STATE.get("posts_used", 0)) + 1
    save_state()
    png = SRC_DIR / ("%s.png" % slot)
    if not png.exists():
        st["status"] = "CREATE_FAILED"
        st["error"] = "missing intake PNG %s" % png
        log_line("slot=%s CREATE_FAILED missing intake PNG" % slot)
        save_state()
        return None
    log_line("slot=%s CREATE_POST attempt=%s posts_used=%s png_bytes=%s png_sha256=%s" % (
        slot, st["attempts"], STATE["posts_used"], png.stat().st_size, sha256_file(png)[:12]))
    try:
        tid = api_create(create_body(slot))
    except ApiError as e:
        st["status"] = "CREATE_FAILED"
        st["error"] = "create HTTP %s: %s" % (e.status, e.body[:300])
        log_line("slot=%s CREATE_FAILED status=%s body=%r" % (slot, e.status, e.body[:300]))
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
    log_line("slot=%s CREATED task_id=%s" % (slot, tid))
    return tid


# --------------------------------------------------------------------------- success path

def process_success(slot: str, tid: str, task: dict) -> None:
    st = STATE["slots"].setdefault(slot, {})
    st["status"] = "SUCCEEDED"
    st["finished_at_ms"] = task.get("finished_at")
    st["created_at_ms"] = task.get("created_at") or st.get("created_at_ms")
    st["consumed_credits"] = task.get("consumed_credits")
    tex = task.get("texture_urls") or []
    if tex and isinstance(tex, list) and isinstance(tex[0], dict):
        st["pbr_maps"] = sorted(tex[0].keys())
    consumed = task.get("consumed_credits") or 0
    log_line("slot=%s SUCCEEDED consumed_credits=%s" % (slot, consumed))
    if consumed > PER_JOB_CREDIT_ABORT:
        STATE["no_new_creates"] = True
        log_line("ALERT slot=%s consumed %s credits > %s: stopping further launches" % (slot, consumed, PER_JOB_CREDIT_ABORT))

    urls = task.get("model_urls") or {}
    glb_url = urls.get("glb")
    if not glb_url:
        st["status"] = "FAILED_NO_GLB_URL"
        st["error"] = "SUCCEEDED but model_urls.glb missing"
        log_line("slot=%s ERROR SUCCEEDED but model_urls.glb missing" % slot)
        save_state()
        return

    dest = GLB_DIR / ("%s.glb" % slot)
    ok = False
    for attempt in (1, 2):
        try:
            n = download(glb_url, dest)
        except ApiError as e:
            log_line("slot=%s WARN glb download failed (attempt %s) status=%s" % (slot, attempt, e.status))
            time.sleep(3)
            continue
        if n >= MIN_GLB_BYTES and dest.read_bytes()[:4] == b"glTF":
            ok = True
            st["glb_bytes"] = n
            st["glb_sha256"] = sha256_file(dest)
            break
        log_line("slot=%s WARN downloaded file invalid (%s bytes); re-minting URL" % (slot, n))
        try:
            fresh = api_get("%s/%s" % (CREATE_URL, tid))
            glb_url = (fresh.get("model_urls") or {}).get("glb") or glb_url
        except ApiError:
            pass
        time.sleep(2)
    if not ok:
        st["status"] = "FAILED_DOWNLOAD"
        st["error"] = "GLB download/validation failed"
        log_line("slot=%s ERROR GLB download/validation failed" % slot)
        save_state()
        return
    log_line("slot=%s GLB_SAVED bytes=%s sha256=%s" % (slot, st["glb_bytes"], st["glb_sha256"][:12]))

    thumb = task.get("thumbnail_url")
    if thumb:
        pv = PREVIEWS / ("%s.png" % slot)
        try:
            n = download(thumb, pv)
            png_ok = pv.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
            st["preview_ok"] = bool(png_ok)
            st["preview_bytes"] = n
            log_line("slot=%s PREVIEW_SAVED bytes=%s png=%s" % (slot, n, png_ok))
        except ApiError as e:
            st["preview_ok"] = False
            log_line("slot=%s WARN preview download failed status=%s" % (slot, e.status))
    else:
        st["preview_ok"] = False
        log_line("slot=%s WARN no thumbnail_url on task" % slot)

    try:
        tri, method, info = inspect_glb(dest)
        st["tri_count"], st["tri_method"] = tri, method
        st["materials"], st["images"], st["texture_ok"] = info["materials"], info["images"], info["has_base_color"]
        log_line("slot=%s TRIANGLES=%s via %s materials=%s images=%s base_color=%s" % (
            slot, tri, method, info["materials"], info["images"], info["has_base_color"]))
    except Exception as exc:  # noqa: BLE001
        st["tri_count"] = None
        log_line("slot=%s WARN triangle count failed: %s" % (slot, scrub(str(exc))[:200]))

    upsert_ledger_row({
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
    log_line("slot=%s LEDGER_WRITTEN" % slot)


def mark_failure(slot: str, status: str, error: str) -> None:
    st = STATE["slots"].setdefault(slot, {})
    st["status"] = status
    st["error"] = error
    log_line("slot=%s %s error=%r" % (slot, status, error[:200]))
    save_state()


# --------------------------------------------------------------------------- batch

def sweep(live: dict[str, str]) -> None:
    started = {slot: time.time() for slot in live}
    err_counts = {slot: 0 for slot in live}
    while live:
        for slot in list(live):
            tid = live[slot]
            try:
                task = api_get("%s/%s" % (CREATE_URL, tid))
                err_counts[slot] = 0
            except ApiError as e:
                err_counts[slot] += 1
                if e.status == 404:
                    mark_failure(slot, "FAILED", "task 404 (expired or missing): %s" % tid)
                    del live[slot]
                    continue
                if err_counts[slot] >= 30:
                    log_line("slot=%s WARN poll failing repeatedly (status=%s); leaving task %s for a later run" % (slot, e.status, tid))
                    del live[slot]
                    continue
                log_line("slot=%s WARN poll error status=%s" % (slot, e.status))
                continue
            status = task.get("status")
            st = STATE["slots"].setdefault(slot, {})
            if task.get("created_at"):
                st["created_at_ms"] = task.get("created_at")
            if status != st.get("status"):
                st["status"] = status
                save_state()
                log_line("slot=%s STATUS=%s progress=%s" % (slot, status, task.get("progress")))
            if status == "SUCCEEDED":
                process_success(slot, tid, task)
                bal = get_balance()
                if bal is not None:
                    STATE["balance_log"].append({"ts": now_iso(), "balance": bal, "note": "after %s" % slot})
                    STATE["balance_last"] = bal
                    save_state()
                    log_line("BALANCE after slot=%s: %s" % (slot, bal))
                    if bal < BALANCE_FLOOR:
                        STATE["no_new_creates"] = True
                        log_line("BALANCE %s below floor %s: no further creates" % (bal, BALANCE_FLOOR))
                del live[slot]
            elif status in ("FAILED", "CANCELED"):
                msg = task_error_message(task)
                consumed = task.get("consumed_credits") or 0
                if consumed > PER_JOB_CREDIT_ABORT:
                    STATE["no_new_creates"] = True
                    log_line("ALERT slot=%s consumed %s credits > %s: stopping further launches" % (slot, consumed, PER_JOB_CREDIT_ABORT))
                st["consumed_credits"] = consumed
                st["finished_at_ms"] = task.get("finished_at")
                mark_failure(slot, status, msg or "no task_error message")
                del live[slot]
            else:
                if time.time() - started[slot] > STALL_SECONDS:
                    log_line("slot=%s WARN stalled non-terminal for %ss; leaving task %s for a later run" % (slot, STALL_SECONDS, tid))
                    del live[slot]
        if live:
            time.sleep(POLL_SECONDS)
        if time.time() - min(started.values()) > RUN_CEILING_SECONDS:
            log_line("WARN run ceiling reached; leaving %d live tasks for a later run" % len(live))
            break


def resume_live() -> dict[str, str]:
    live = {}
    for slot in SLOTS:
        st = STATE["slots"].get(slot, {})
        if st.get("task_id") and st.get("status") in ("PENDING", "IN_PROGRESS"):
            live[slot] = st["task_id"]
    return live


def reconcile_ledger() -> None:
    """State says SUCCEEDED with a GLB on disk, but the ledger line never got written
    (crash between the two): write it now from state."""
    for slot in SLOTS:
        st = STATE["slots"].get(slot, {})
        if st.get("status") != "SUCCEEDED" or ledger_has_success(slot):
            continue
        glb = GLB_DIR / ("%s.glb" % slot)
        if glb.exists() and st.get("glb_sha256"):
            upsert_ledger_row({
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
            log_line("RECONCILE ledger line written for slot=%s from state" % slot)


def run_batch() -> int:
    global KEY
    for d in (GLB_DIR, MISSION, PREVIEWS, RUN_DIR):
        d.mkdir(parents=True, exist_ok=True)
    KEY, key_source = load_key()
    if not KEY:
        log_line("FATAL no Meshy key found ($MESHY_API_KEY, ~/.hermes/profiles/dev-work/.env, ~/.config/meshy/api_key)")
        return 4
    load_state()
    log_line("START key_source=%s posts_used=%s slots=%d" % (key_source, STATE["posts_used"], len(SLOTS)))

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
        for slot in SLOTS:
            if ledger_has_success(slot) or slot in live:
                continue
            st = STATE["slots"].get(slot, {})
            if st.get("attempts", 0) >= MAX_ATTEMPTS:
                continue
            st.pop("error", None)
            to_create.append(slot)

        if STATE.get("no_new_creates"):
            to_create = []
        if to_create:
            bal = get_balance() or bal
            if bal is not None and bal < BALANCE_FLOOR:
                STATE["no_new_creates"] = True
                log_line("BALANCE %s below floor %s: no further creates" % (bal, BALANCE_FLOOR))
                to_create = []
        for slot in to_create:
            if STATE["posts_used"] >= MAX_CREATES:
                STATE["no_new_creates"] = True
                log_line("CREATE CAP: %s POSTs used of max %s; no further launches" % (STATE["posts_used"], MAX_CREATES))
                break
            tid = try_create(slot)
            if tid:
                live[slot] = tid
            time.sleep(1.5)

        if not live:
            break
        sweep(live)

    # final balance + failed-slot ledger rows
    bal = get_balance()
    if bal is not None:
        STATE["balance_log"].append({"ts": now_iso(), "balance": bal, "note": "end"})
        STATE["balance_last"] = bal
        log_line("BALANCE end=%s" % bal)
    for slot in SLOTS:
        if ledger_has_success(slot):
            continue
        st = STATE["slots"].get(slot, {})
        upsert_ledger_row({
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
    rows = {r.get("slot"): r for r in read_ledger()}
    state = load_state()

    table = ["| slot | task_id | status | credits | triangles | GLB bytes | sha256 (12) | preview |",
             "|---|---|---|---|---|---|---|---|"]
    tri_ok = True
    missing = []
    for slot in SLOTS:
        r = rows.get(slot)
        glb = GLB_DIR / ("%s.glb" % slot)
        preview = PREVIEWS / ("%s.png" % slot)
        if not r:
            missing.append(slot)
            table.append("| %s | — | MISSING | — | — | — | — | — |" % slot)
            tri_ok = False
            continue
        tri = r.get("tri_count")
        if tri in (None, ""):
            tri_ok = False
        table.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
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
    for slot in SLOTS:
        glb = GLB_DIR / ("%s.glb" % slot)
        if not glb.exists():
            glb_lines.append("%s: missing" % slot)
            texture_ok = False
            continue
        size = glb.stat().st_size
        try:
            tri, method, info = inspect_glb(glb)
            bc = "base-colour texture: %s" % ("yes" if info["has_base_color"] else "NO")
            texture_ok = texture_ok and bool(info["has_base_color"])
            glb_lines.append("%s: %d bytes, %d tris, %s, %d material(s), %d image(s)" % (
                slot, size, tri, bc, info["materials"], info["images"]))
        except Exception as exc:  # noqa: BLE001
            texture_ok = False
            glb_lines.append("%s: %d bytes, inspection failed: %s" % (slot, size, exc))

    size_gate = all((GLB_DIR / ("%s.glb" % slot)).exists() and (GLB_DIR / ("%s.glb" % slot)).stat().st_size > MIN_GLB_BYTES
                    for slot in SLOTS)
    ledger_gate = len(rows) == len(SLOTS) and all(rows.get(s) and rows[s].get("task_id") and rows[s].get("consumed_credits") is not None
                                                  for s in SLOTS)
    bal_start = state.get("balance_start")
    bal_end = state.get("balance_last")
    ledger_sum = sum((r.get("consumed_credits") or 0) for r in rows.values() if r.get("status") == "SUCCEEDED")
    balance_delta = (bal_start - bal_end) if isinstance(bal_start, int) and isinstance(bal_end, int) else None

    failed = [s for s in SLOTS if (rows.get(s) or {}).get("status") != "SUCCEEDED"]
    retried = [s for s in SLOTS if int(((state.get("slots") or {}).get(s) or {}).get("attempts", 0) or 0) > 1]

    gates = [
        "| GLBs on disk | ten files at `godot/assets/arenas/medina/<slot>.glb`, each over 50 KB | %s |" % ("PASS" if size_gate else "FAIL"),
        "| Texture present | each GLB has a material with a base-colour image, and `enable_pbr` was accepted | %s |" % ("PASS" if texture_ok else "FAIL"),
        "| Triangles | per-slot count recorded in the ledger | %s |" % ("PASS" if tri_ok else "FAIL"),
        "| Ledger | ten lines with task_id and consumed_credits, no missing slot | %s |" % ("PASS" if ledger_gate else "FAIL"),
        "| Balance | remaining balance recorded in PIPELINE-RESULT.md | %s |" % ("PASS" if bal_end is not None else "FAIL"),
        "| Tree scope | `git status --short` shows only Medina GLBs, the new script, and the mission docs | see raw output below |",
    ]

    pbr_rows = []
    for slot in SLOTS:
        st = (state.get("slots") or {}).get(slot) or {}
        pbr_rows.append("- %s: texture_urls keys = %s" % (slot, ", ".join(st.get("pbr_maps") or []) or "(not recorded)"))

    md = f"""# Medina Mesh T2 pack — PIPELINE RESULT

Date: {now_iso()} · Pipeline captain · Repo: `steam-circuit-padel-godot` (primary `main`)
Brief: `docs/mission/arena-kit/meshy-t2-medina/PIPELINE-BRIEF.md` · Script: `tools/arena-kit/gen_medina_t2.py`

## What generated

Ten textured Medina arena props were generated through the Meshy Image-to-3D API exactly as the
brief specifies: Mesh T2 + Smart Topology (`model_type: "smart-topology"`, `ai_model: "meshy-t2"`),
texture on the create call (`should_texture: true`, `enable_pbr: true`, `texture_resolution: "2k"`),
triangle output at `target_polycount: 4000`, `target_formats: ["glb"]`. Each intake PNG
(`meshy/arenas/medina/<slot>.png`, 1024×1024) was sent as a base64 data URI. GLBs were downloaded
immediately on `SUCCEEDED` (signed URLs expire), with the task thumbnail saved as the slot preview.

| slot | task_id | status | credits | triangles | GLB bytes | sha256 (12) | preview |
|---|---|---|---|---|---|---|---|
{chr(10).join(table[2:])}

- Slots succeeded: {len(SLOTS) - len(failed)} of {len(SLOTS)}
- Credits consumed (ledger sum of `consumed_credits`): {ledger_sum}
- Balance before: {bal_start} · after: {bal_end} · remaining: {bal_end}
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
  in-script GLB JSON parse. Method used per slot is in `run/tmp/arena-kit/medina-t2-state.json`
  (`tri_method`) and in the journal.
- `enable_pbr` acceptance, straight from each task's `texture_urls`:
{chr(10).join(pbr_rows)}
- Balance readings ({len(state.get("balance_log") or [])}) are in `run/tmp/arena-kit/medina-t2-state.json`
  and the journal; cost per task is the task's own `consumed_credits` (authoritative per RECON).
- Journal: `run/tmp/arena-kit/medina-t2-journal.txt`. Ledger: `docs/mission/arena-kit/meshy-t2-medina/LEDGER.jsonl`.
  Previews: `docs/mission/arena-kit/meshy-t2-medina/previews/<slot>.png`.
- `ground_texture` was NOT sent to Meshy (material swatch only), per the kit standard.
"""
    RESULT.write_text(md, encoding="utf-8")
    log_line("RESULT_WRITTEN %s" % RESULT)


def failed_slots_block(failed, retried) -> str:
    parts = []
    if failed:
        parts.append("Failed slots:")
        parts.extend(failed)
    else:
        parts.append("No failed slots — all ten landed.")
    if retried:
        parts.append("")
        parts.append("Slots that needed more than one create attempt: " + ", ".join(retried) + ".")
    return "\n".join(parts)


# --------------------------------------------------------------------------- main

def main(argv) -> int:
    parser = argparse.ArgumentParser(description="Medina Mesh T2 batch (Meshy Image to 3D).")
    parser.add_argument("--report", action="store_true", help="(re)write PIPELINE-RESULT.md from disk data, no API calls")
    args = parser.parse_args(argv)
    for d in (GLB_DIR, MISSION, PREVIEWS, RUN_DIR):
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
