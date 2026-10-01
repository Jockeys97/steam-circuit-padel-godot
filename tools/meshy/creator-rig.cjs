// Rig the "Crea atleta" bodies (2026-09-27): Meshy rigging on the image-to-3D task of each
// body (ids from docs/agent-work/meshy-arenas/tasks.json, key `creator/<body>`), at the body's
// own height, then download the rigged GLB and Meshy's walking/running clips into
// godot/assets/custom_character/<body>-{rigged,walking,running}.glb.
// `node creator-rig.cjs <body> <height_m>`; MESHY_API_KEY from the environment, MESHY_FLOOR
// honoured, one POST per body, never retried; task ids logged in the same tasks.json.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const [body,height]=process.argv.slice(2);
if(!body||!height)throw Error('usage: creator-rig.cjs <body> <height_m>');
const file=path.join(root,'docs/agent-work/meshy-arenas/tasks.json');
const out=path.join(root,'godot/assets/custom_character');
const key=process.env.MESHY_API_KEY;
if(!key)throw Error('Set MESHY_API_KEY securely before running');
const TASK='creator-rig/'+body;
const load=()=>JSON.parse(fs.readFileSync(file,'utf8'));
const save=(v)=>{const now=load();now[TASK]=v;fs.writeFileSync(file,JSON.stringify(now,null,2));};
async function api(p,b){const r=await fetch('https://api.meshy.ai/openapi/v1/'+p,{method:b?'POST':'GET',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:b?JSON.stringify(b):undefined});if(!r.ok)throw Error('Meshy HTTP '+r.status+' '+p+' '+(await r.text()).slice(0,300));return r.json();}
async function get(url,name){const r=await fetch(url);if(!r.ok)throw Error('Download '+r.status);fs.writeFileSync(path.join(out,name),Buffer.from(await r.arrayBuffer()));console.log('saved',name);}
(async()=>{
 const src=load()['creator/'+body];
 if(!src||!src.id||src.status!=='SUCCEEDED')throw Error('no finished image-to-3D task for '+body);
 let st=load()[TASK];
 if(!st){
  if(process.env.MESHY_FLOOR){const b=(await api('balance')).balance;if(b-5<Number(process.env.MESHY_FLOOR))throw Error('Account floor reached: balance '+b);console.log('balance',b);}
  st={request_started:true};save(st);
  let d;try{d=await api('rigging',{input_task_id:src.id,height_meters:Number(height)});}catch(e){if(String(e.message).startsWith('Meshy HTTP')){const now=load();delete now[TASK];fs.writeFileSync(file,JSON.stringify(now,null,2));}throw e;}
  st.id=d.result;save(st);console.log(body,'rig created',d.result);
 }
 if(!st.id)throw Error('Uncertain creation; inspect remote tasks before retrying');
 for(;;){const d=await api('rigging/'+st.id);st.status=d.status;st.credits=d.consumed_credits;save(st);console.log(body,d.status,d.progress);
  if(d.status==='SUCCEEDED'){const r=d.result||{};
   if(r.rigged_character_glb_url)await get(r.rigged_character_glb_url,body+'-rigged.glb');
   for(const [k,u] of Object.entries(r.basic_animations||{}))if(k.endsWith('_glb_url')&&u&&!k.includes('armature'))await get(u,body+'-'+k.replace('_glb_url','')+'.glb');
   console.log('DONE',body,'credits='+d.consumed_credits);return;}
  if(['FAILED','CANCELED'].includes(d.status))throw Error(body+' '+d.status+' '+JSON.stringify(d.task_error||''));
  await new Promise(r=>setTimeout(r,8000));}
})().catch(e=>{console.error(e.message);process.exitCode=1});
