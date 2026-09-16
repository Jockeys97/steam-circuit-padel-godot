import json, base64, urllib.request, sys, time, os
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
        return e.code, e.read().decode()[:500]
import urllib.error
# balance pre-check
for p in ["/balance","/account/balance","/credits"]:
    s,b = req("GET", p)
    print("BAL", p, s, str(b)[:200], flush=True)
    if s==200: break
imgs=[]
for f in ["volpe-front.png","volpe-side.png","volpe-back.png","volpe-45.png"]:
    raw=open(f"/root/projects/steam-circuit-padel-pro/meshy/volpe-views/{f}","rb").read()
    imgs.append("data:image/png;base64,"+base64.b64encode(raw).decode())
    print("loaded",f,len(raw),flush=True)
payload={"image_urls":imgs,"ai_model":"latest","pose_mode":"a-pose",
 "should_texture":True,"target_polycount":30000,"target_formats":["glb","fbx"],
 "texture_prompt":"Anthropomorphic ivory-white spitz dog athlete standing in A-pose: fluffy curled tail, tall pointed ears, brass goggle strap on forehead, ivory tee with gold trim, navy shorts, brass wristbands"}
s,b=req("POST","/multi-image-to-3d",payload)
print("CREATE",s,json.dumps(b)[:500],flush=True)
if s not in (200,201,202): sys.exit(1)
tid=b["result"]
open("/root/projects/steam-circuit-padel-pro/meshy/rigged/volpe/gen_create.json","w").write(json.dumps({"status":s,"body":b}))
for i in range(60):
    time.sleep(15)
    s2,b2=req("GET",f"/multi-image-to-3d/{tid}")
    st=b2.get("status") if isinstance(b2,dict) else None
    print(f"POLL {i} status={st} progress={b2.get('progress') if isinstance(b2,dict) else '?'}",flush=True)
    if st in ("SUCCEEDED","FAILED","CANCELED","EXPIRED"):
        open("/root/projects/steam-circuit-padel-pro/meshy/rigged/volpe/gen_final.json","w").write(json.dumps(b2,indent=1))
        print(json.dumps({k:b2.get(k) for k in ("status","progress","consumed_credits","model_urls","task_error")},indent=1)[:2000],flush=True)
        break
