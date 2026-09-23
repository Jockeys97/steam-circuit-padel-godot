import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const dir = new URL('../meshy/carioca-pilot/', import.meta.url);
const key = (await readFile('/Users/alessiofantini/Downloads/codice.md','utf8')).match(/msy_[A-Za-z0-9_-]+/)?.[0];
if(!key)throw Error('Credential unavailable');
async function api(path, payload){
 const r=await fetch('https://api.meshy.ai/openapi/v1/'+path,{method:payload?'POST':'GET',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:payload?JSON.stringify(payload):undefined,signal:AbortSignal.timeout(60000)});
 if(!r.ok)throw Error(`Meshy HTTP ${r.status}; details omitted`);
 return r.json();
}
const file=new URL('image-v2-task.json',dir);
let saved;
try {saved=JSON.parse(await readFile(file,'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
if(!saved){
 const image=await readFile(new URL('reference-v2.png',dir));
 const options={ai_model:'meshy-7',should_texture:true,enable_pbr:true,texture_resolution:'2k',should_remesh:true,topology:'triangle',target_polycount:8000,target_formats:['glb'],image_enhancement:false};
 saved={status:'SUBMITTING',reference:'reference-v2.png',sha256:createHash('sha256').update(image).digest('hex'),options};
 await writeFile(file,JSON.stringify(saved,null,2),{flag:'wx'});
 const result=await api('image-to-3d',{...options,image_url:'data:image/png;base64,'+image.toString('base64')});
 saved.id=result.result;
 await writeFile(file,JSON.stringify(saved,null,2));
}
if(!saved.id)throw Error('Uncertain submission: reconcile remotely before retrying');
const task=await api('image-to-3d/'+saved.id);
await writeFile(new URL('image-v2-status.json',dir),JSON.stringify(task,null,2));
console.log(JSON.stringify({id:saved.id,status:task.status,progress:task.progress,credits:task.consumed_credits}));
if(task.status==='SUCCEEDED'){
 const r=await fetch(task.model_urls.glb);
 if(!r.ok)throw Error('GLB download failed');
 const b=Buffer.from(await r.arrayBuffer());
 if(b.toString('ascii',0,4)!=='glTF')throw Error('Invalid GLB');
 await writeFile(new URL('image-v2.glb',dir),b);
 console.log('Saved GLB bytes='+b.length);
}
