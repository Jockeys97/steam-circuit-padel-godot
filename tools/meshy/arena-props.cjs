// Arena kit props from the owner's 2D references (2026-09-25): Meshy image-to-3D with
// smart topology (the triangle budget IS the generation's, no post-hoc decimation) and a
// base-colour texture. One slot per run: `node arena-props.cjs <arena> <slot> [polycount]`.
// Reads MESHY_API_KEY from the environment, enforces MESHY_CEILING per run, never retries
// a POST, honours MESHY_FLOOR (live balance floor), records task ids (no secrets, no signed URLs) in docs/agent-work/meshy-arenas/.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const [arena,slot,poly]=process.argv.slice(2);
if(!arena||!slot)throw Error('usage: arena-props.cjs <arena> <slot> [polycount]');
// `crowd` is not an arena: its references live in art/crowd/, its models in godot/assets/crowd/.
const crowd=arena==='crowd';
const src=crowd?path.join(root,'art/crowd',slot+'.png'):path.join(root,'art/arena-kits',arena,slot+'.png');
if(!fs.existsSync(src))throw Error('missing reference '+src);
const outDir=crowd?path.join(root,'godot/assets/crowd'):path.join(root,'godot/assets/arenas',arena);
const logDir=path.join(root,'docs/agent-work/meshy-arenas');
fs.mkdirSync(outDir,{recursive:true});fs.mkdirSync(logDir,{recursive:true});
const file=path.join(logDir,'tasks.json');
const state=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
const key=process.env.MESHY_API_KEY;
if(!key)throw Error('Set MESHY_API_KEY securely before running');
const CEILING=Number(process.env.MESHY_CEILING||15);
// Re-read before writing: parallel runs (one per slot) share this file, and writing a copy
// read at start-up would drop the entries the other runs added meanwhile.
const TASK=arena+'/'+slot;
const save=()=>{const now=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{};now[TASK]=state[TASK];fs.writeFileSync(file,JSON.stringify(now,null,2));};
async function api(p,body){const r=await fetch('https://api.meshy.ai/openapi/v1/'+p,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});if(!r.ok)throw Error('Meshy HTTP '+r.status+' '+p+' '+(await r.text()).slice(0,300));return r.json();}
(async()=>{
 const name=arena+'/'+slot;
 if(!state[name]){
  if(15>CEILING)throw Error('Budget exceeded');
  // Account floor (MESHY_FLOOR): the owner's second account may spend at most 500 credits,
  // so refuse any job that would take its live balance below start - 500.
  if(process.env.MESHY_FLOOR){const b=(await api('balance')).balance;if(b-15<Number(process.env.MESHY_FLOOR))throw Error('Account floor reached: balance '+b+', floor '+process.env.MESHY_FLOOR);console.log('balance',b,'floor',process.env.MESHY_FLOOR);}
  const img='data:image/png;base64,'+fs.readFileSync(src).toString('base64');
  const body={image_url:img,model_type:'smart-topology',ai_model:'meshy-t2',target_polycount:Number(poly||10000),should_texture:true,enable_pbr:false,texture_resolution:'2k'};
  state[name]={request_started:true};save();
  let d;try{d=await api('image-to-3d',body);}catch(e){if(String(e.message).startsWith('Meshy HTTP')){delete state[name];save();}throw e;}
  state[name].id=d.result;save();console.log(name,'created',d.result);
 }
 if(!state[name].id)throw Error('Uncertain creation; inspect remote tasks before retrying');
 for(;;){const d=await api('image-to-3d/'+state[name].id);state[name].status=d.status;state[name].credits=d.consumed_credits;save();console.log(name,d.status,d.progress);
  if(d.status==='SUCCEEDED'){const u=(d.model_urls||{}).glb;const r=await fetch(u);if(!r.ok)throw Error('Download '+r.status);fs.writeFileSync(path.join(outDir,slot+'.glb'),Buffer.from(await r.arrayBuffer()));console.log('DONE',name,'credits='+d.consumed_credits);return;}
  if(['FAILED','CANCELED'].includes(d.status))throw Error(name+' '+d.status+' '+JSON.stringify(d.task_error||''));
  await new Promise(r=>setTimeout(r,10000));}
})().catch(e=>{console.error(e.message);process.exitCode=1});
