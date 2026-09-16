import json, urllib.request, urllib.error, time, sys
KEY=open("/root/.config/meshy/api_key").read().strip()
def req(base, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(base+path, data=data, method=method,
        headers={"Authorization":"Bearer "+KEY,"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:800]
body={"input_task_id":"01a0a77f-097d-7091-80b0-e904b7d93ecb","target_polycount":30000,"topology":"triangle","target_formats":["glb"]}
s,b=None,None
for base in ["https://api.meshy.ai/openapi/v2","https://api.meshy.ai/openapi/v1"]:
    s,b=req(base,"POST","/remesh",body)
    print("REMESH_CREATE",base,s,json.dumps(b)[:400],flush=True)
    if s in (200,201,202):
        API=base; break
else: sys.exit(1)
tid=b["result"]
open("remesh_create.json","w").write(json.dumps({"base":API,"status":s,"body":b}))
for i in range(60):
    time.sleep(15)
    s2,b2=req(API,"GET",f"/remesh/{tid}")
    st=b2.get("status") if isinstance(b2,dict) else None
    print(f"REMESH_POLL {i} status={st} progress={b2.get('progress') if isinstance(b2,dict) else '?'}",flush=True)
    if st in ("SUCCEEDED","FAILED","CANCELED","EXPIRED"):
        open("remesh_final.json","w").write(json.dumps(b2,indent=1))
        print(json.dumps({k:b2.get(k) for k in ("status","progress","consumed_credits","model_urls","task_error")},indent=1)[:2000],flush=True)
        break
