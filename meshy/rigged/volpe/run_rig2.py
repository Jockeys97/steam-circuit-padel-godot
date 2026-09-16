"""Rig the remeshed Volpe model. Resumable: writes rig_final.json on completion."""
import json, os, sys, time, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://api.meshy.ai/openapi/v1"
KEY = open("/root/.config/meshy/api_key").read().strip()
REMESH_TASK = "01a0a78d-cf8e-763e-9bc0-4d1513e0d0b5"
HEIGHT_M = 1.8


def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(
        BASE + path,
        data=data,
        method=method,
        headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:900]


final = os.path.join(HERE, "rig_final.json")
if os.path.exists(final):
    print("rig_final.json already exists, nothing to do")
    sys.exit(0)

status, body = req("POST", "/rigging", {"input_task_id": REMESH_TASK, "height_meters": HEIGHT_M})
print("RIG_CREATE", status, json.dumps(body)[:400], flush=True)
if status not in (200, 201, 202):
    sys.exit(1)
tid = body["result"]
open(os.path.join(HERE, "rig_create.json"), "w").write(json.dumps({"status": status, "body": body}))

for i in range(40):
    time.sleep(15)
    s2, b2 = req("GET", "/rigging/" + tid)
    st = b2.get("status") if isinstance(b2, dict) else None
    print(f"RIG_POLL {i} status={st} progress={b2.get('progress') if isinstance(b2, dict) else '?'}", flush=True)
    if st in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"):
        open(final, "w").write(json.dumps(b2, indent=1))
        print(json.dumps({k: b2.get(k) for k in ("status", "progress", "consumed_credits", "task_error")}, indent=1), flush=True)
        print("RESULT_KEYS", list((b2.get("result") or {}).keys()), flush=True)
        anim = (b2.get("result") or {}).get("basic_animations") or {}
        print("ANIM_KEYS", list(anim.keys()), flush=True)
        break
else:
    print("TIMED OUT waiting for rig", flush=True)
    sys.exit(2)
