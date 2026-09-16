import json, urllib.request, urllib.error, time, sys
BASE="https://api.meshy.ai/openapi/v1"
KEY=open("/root/.config/meshy/api_key").read().strip()
def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE+path, data=data, method=method,
        headers={"Authorization":"Bearer "+KEY,"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:800]
s,b=req("POST","/rigging",{"input_task_id":"01a0a77f-097d-7091-80b0-e904b7d93ecb","height_meters":1.1})
print("RIG_CREATE",s,json.dumps(b)[:500],flush=True)
if s not in (200,201,202): sys.exit(1)
tid=b["result"]
open("rig_create.json","w").write(json.dumps({"status":s,"body":b}))
for i in range(60):
    time.sleep(15)
    s2,b2=req("GET",f"/rigging/{tid}")
    st=b2.get("status") if isinstance(b2,dict) else None
    print(f"RIG_POLL {i} status={st} progress={b2.get('progress') if isinstance(b2,dict) else '?'}",flush=True)
    if st in ("SUCCEEDED","FAILED","CANCELED","EXPIRED"):
        open("rig_final.json","w").write(json.dumps(b2,indent=1))
        print(json.dumps({k:b2.get(k) for k in ("status","progress","consumed_credits","result","task_error")},indent=1)[:3000],flush=True)
        break
