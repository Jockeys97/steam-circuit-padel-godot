// B male pilot only. No credentials or signed URLs are persisted.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const dir = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(dir, 'meshy-pilot');
fs.mkdirSync(out, {recursive:true});
const ledgerPath = path.join(out, 'ledger.json');
const ledger = fs.existsSync(ledgerPath) ? JSON.parse(fs.readFileSync(ledgerPath)) : {account:2, limit:55, jobs:{}};
const secret = fs.readFileSync('/Users/alessiofantini/Downloads/codice.md','utf8').split(/API Accout 2 Meshy/i)[1];
const key = secret?.match(/msy_[A-Za-z0-9_-]+/)?.[0];
if (!key) throw Error('Second account key not identified');
const save = () => fs.writeFileSync(ledgerPath, JSON.stringify(ledger,null,2)+'\n');
async function api(endpoint, payload) {
  const r = await fetch('https://api.meshy.ai/openapi/v1/'+endpoint, {method:payload?'POST':'GET',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:payload?JSON.stringify(payload):undefined,signal:AbortSignal.timeout(90000)});
  if(!r.ok) throw Error('Meshy HTTP '+r.status+' at '+endpoint);
  return r.json();
}
const data = name => 'data:image/png;base64,'+fs.readFileSync(path.join(dir,name)).toString('base64');
const action = process.argv[2];
if (['body','hair','rig'].includes(action)) {
  if(ledger.jobs[action]) throw Error('Already reserved/submitted: inspect ledger; never automatically resubmit');
  const cost = {body:30,hair:20,rig:5}[action];
  if(Object.values(ledger.jobs).reduce((n,j)=>n+j.reserved,0)+cost>ledger.limit) throw Error('Budget exceeded');
  const balance = await api('balance');
  if(balance.balance<cost) throw Error('Insufficient credits');
  if(action==='rig' && ledger.jobs.body?.status!=='SUCCEEDED') throw Error('Body must succeed first');
  const endpoint = action==='rig'?'rigging':'image-to-3d';
  const payload = action==='rig'?{input_task_id:ledger.jobs.body.id,height_meters:1.8}:{
    image_url:data(action==='body'?'corpo-frontale.png':'capelli-corti.png'),
    ai_model:'meshy-7',model_type:'standard',should_texture:action==='body',
    should_remesh:true,topology:'triangle',target_polycount:action==='body'?16000:3500,
    image_enhancement:false,target_formats:['glb'],
    ...(action==='body'?{enable_pbr:true,texture_resolution:'2k',pose_mode:'a-pose'}:{})
  };
  ledger.jobs[action]={reserved:cost,endpoint,status:'SUBMISSION_PENDING',balanceBefore:balance.balance};save();
  const result=await api(endpoint,payload);
  if(!result.result) throw Error('Missing task id; do not resubmit');
  Object.assign(ledger.jobs[action],{id:result.result,status:'PENDING'});save();
  console.log(action,result.result,'reserved',cost);
} else if(action==='status') {
  for(const [name,j] of Object.entries(ledger.jobs)) {
    if(!j.id) {console.log(name,j.status);continue;}
    const t=await api(j.endpoint+'/'+j.id);
    Object.assign(j,{status:t.status,progress:t.progress,consumed:t.consumed_credits});save();
    console.log(name,t.status,t.progress,'credits',t.consumed_credits);
    if(t.status!=='SUCCEEDED') continue;
    const files=name==='rig'?{'body-rigged.glb':t.result?.rigged_character_glb_url,'walk.glb':t.result?.basic_animations?.walking_glb_url}:{[name+'.glb']:t.model_urls?.glb};
    for(const [filename,url] of Object.entries(files)) {
      if(!url || fs.existsSync(path.join(out,filename))) continue;
      const r=await fetch(url,{signal:AbortSignal.timeout(120000)});
      if(!r.ok) throw Error('Download HTTP '+r.status);
      const b=Buffer.from(await r.arrayBuffer());
      if(b.toString('ascii',0,4)!=='glTF') throw Error('Invalid GLB');
      fs.writeFileSync(path.join(out,filename),b);console.log('Saved',filename,b.length);
    }
  }
  console.log('Balance',(await api('balance')).balance);
} else throw Error('Use body, hair, rig, or status');
