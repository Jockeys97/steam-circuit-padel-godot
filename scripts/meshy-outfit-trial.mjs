// Bounded, resumable two-outfit trial. Never logs credentials or signed URLs.
import {readFile, writeFile, mkdir, access} from 'node:fs/promises';
import {resolve, dirname} from 'node:path';
import {createHash} from 'node:crypto';
const root = resolve(import.meta.dirname, '..');
const dir = resolve(root, 'docs/agent-work/meshy-outfit-trial');
const mode = process.argv[2];
const name = process.argv[3];
if (!['submit','status'].includes(mode) || !['colosso-signature','maestro-mythic','maestro-mythic-rig'].includes(name)) throw Error('Use submit|status colosso-signature|maestro-mythic|maestro-mythic-rig');
const raw = await readFile('/Users/alessiofantini/Downloads/codice.md','utf8');
const key = raw.match(/msy_[A-Za-z0-9_-]+/)?.[0];
if (!key) throw Error('Credential format not recognized');
const endpoint = name === 'colosso-signature' ? 'retexture' : name.endsWith('-rig') ? 'rigging' : 'image-to-3d';
const statePath = resolve(dir, `${name}.json`);
async function api(path, payload) {
  const r = await fetch(`https://api.meshy.ai/openapi/v1/${path}`, {method:payload?'POST':'GET',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:payload?JSON.stringify(payload):undefined,signal:AbortSignal.timeout(180000)});
  if (!r.ok) throw Error(`Meshy HTTP ${r.status}; response omitted to protect credentials`);
  return r.json();
}
const hash = b => createHash('sha256').update(b).digest('hex');
await mkdir(dir,{recursive:true});
if (mode === 'submit') {
  try {await access(statePath); throw Error('Existing task state: use status, never resubmit');} catch(e) {if(e.code!=='ENOENT') throw e;}
  const reference = await readFile(resolve(dir,`${name.replace(/-rig$/, '')}-reference.png`));
  const image = `data:image/png;base64,${reference.toString('base64')}`;
  let payload = {ai_model:'meshy-7',enable_pbr:true,texture_resolution:'2k',target_formats:['glb']};
  let model;
  if(endpoint==='retexture') {
    model=await readFile(resolve(root,'godot/assets/athletes/colosso.glb'));
    Object.assign(payload,{model_url:`data:application/octet-stream;base64,${model.toString('base64')}`,image_style_url:image,enable_original_uv:true});
  } else if(endpoint==='rigging') {
    const parent=JSON.parse(await readFile(resolve(dir,'maestro-mythic.json'),'utf8'));
    if(parent.status!=='SUCCEEDED')throw Error('Parent must succeed before rigging');
    payload={input_task_id:parent.id,height_meters:1.8};
  } else Object.assign(payload,{image_url:image,model_type:'standard',should_texture:true,pose_mode:'a-pose',image_enhancement:false,should_remesh:true,topology:'triangle',target_polycount:20000});
  const balance=await api('balance');
  const record={name,endpoint,status:'SUBMISSION_PENDING',created:new Date().toISOString(),balanceBefore:balance.balance,referenceSha256:hash(reference),modelSha256:model?hash(model):undefined,settings:Object.fromEntries(Object.entries(payload).filter(([k])=>!['model_url','image_url','image_style_url'].includes(k)))};
  // Exclusive reservation prevents accidental duplicate billable requests.
  await writeFile(statePath,JSON.stringify(record,null,2)+'\n',{flag:'wx'});
  const task=await api(endpoint,payload);
  if(!task.result) throw Error('Missing task ID: reconcile in Meshy before retrying');
  record.id=task.result;record.status='SUBMITTED';
  await writeFile(statePath,JSON.stringify(record,null,2)+'\n');
  console.log(JSON.stringify(record));
} else {
  const record=JSON.parse(await readFile(statePath,'utf8'));
  if(!record.id) throw Error('Uncertain submission: reconcile in Meshy; do not resubmit');
  const task=await api(`${endpoint}/${record.id}`);
  Object.assign(record,{status:task.status,progress:task.progress,credits:task.consumed_credits,checked:new Date().toISOString()});
  if(task.status==='SUCCEEDED' && !record.downloaded) {
    const urls={model:task.model_urls?.glb??task.result?.rigged_character_glb_url,preview:task.thumbnail_url};
    if(!urls.model)throw Error('Successful task returned no model; keep state resumable');
    if(endpoint==='rigging')Object.assign(urls,{running:task.result?.basic_animations?.running_glb_url,walking:task.result?.basic_animations?.walking_glb_url});
    for(const [i,maps] of (task.texture_urls??[]).entries()) for(const [kind,url] of Object.entries(maps)) urls[`texture-${i}-${kind}`]=url;
    record.files=[];
    for(const [kind,url] of Object.entries(urls)) {
      if(!url || typeof url!=='string') continue;
      const ext=['model','running','walking'].includes(kind)?'.glb':new URL(url).pathname.match(/\.[a-zA-Z0-9]+$/)?.[0]??'.png';
      const file=resolve(dir,name,`${kind}${ext}`);
      const r=await fetch(url,{signal:AbortSignal.timeout(180000)});if(!r.ok)throw Error(`Download HTTP ${r.status}`);
      await mkdir(dirname(file),{recursive:true});await writeFile(file,Buffer.from(await r.arrayBuffer()));record.files.push(file.slice(root.length+1));
    }
    record.downloaded=true;
  }
  record.balanceAfter=(await api('balance')).balance;
  await writeFile(statePath,JSON.stringify(record,null,2)+'\n');
  console.log(JSON.stringify(record));
}
