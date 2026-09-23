import {readFile, writeFile, mkdir} from 'node:fs/promises';
const dir = new URL('../meshy/carioca-pilot/', import.meta.url);
await mkdir(dir, {recursive:true});
const raw = await readFile('/Users/alessiofantini/Downloads/codice.md','utf8');
const key = raw.match(/msy_[A-Za-z0-9_-]+/)?.[0];
if (!key) throw Error('Credential unavailable');
const stateFile = new URL('preview.json',dir);
let state;
try { state=JSON.parse(await readFile(stateFile,'utf8')); } catch(e) {if(e.code!=='ENOENT')throw e;}
async function api(path, payload) {
 const r=await fetch('https://api.meshy.ai/openapi/'+path,{method:payload?'POST':'GET',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:payload?JSON.stringify(payload):undefined,signal:AbortSignal.timeout(60000)});
 if(!r.ok)throw Error(`Meshy HTTP ${r.status}; response omitted`);
 return r.json();
}
if(!state){
 const balance=await api('v1/balance');
 console.log('Balance', JSON.stringify(balance));
 const payload={mode:'preview',model_type:'standard',ai_model:'meshy-7.1',should_remesh:true,target_polycount:8000,topology:'triangle',target_formats:['glb'],prompt:'Single isolated tropical coastal granite mountain inspired by Sugarloaf Mountain in Rio de Janeiro. Recognizable tall rounded asymmetrical granite dome, steep weathered gray rock faces, irregular dark green vegetation patches on lower slopes and crown, attached smaller rocky foothill. Stylized realistic game environment landmark, readable large silhouette, broad natural irregular base, no rectangular pedestal. No ocean, no sky, no buildings, no text, no people. Solid static terrain prop viewed from all sides.'};
 await writeFile(stateFile,JSON.stringify({status:'SUBMITTING',payload},null,2),{flag:'wx'});
 const created=await api('v2/text-to-3d',payload);
 state={id:created.result,payload};
 await writeFile(stateFile,JSON.stringify(state,null,2));
}
if(!state.id)throw Error('Submission uncertain; reconcile remotely before retrying');
const task=await api('v2/text-to-3d/'+state.id);
await writeFile(new URL('preview-status.json',dir),JSON.stringify(task,null,2));
console.log(JSON.stringify({id:state.id,status:task.status,progress:task.progress,credits:task.consumed_credits}));
if(task.status==='SUCCEEDED'){
 const response=await fetch(task.model_urls.glb);
 if(!response.ok)throw Error('Preview download failed');
 await writeFile(new URL('preview.glb',dir),Buffer.from(await response.arrayBuffer()));
 console.log('Preview GLB saved locally');
}
