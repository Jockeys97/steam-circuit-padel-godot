// User-approved batch: five image generations (30 each) + five rigs (5 each).
// No retries of paid submissions, no runtime promotion, no credentials/URLs in logs.
import {readFile,writeFile,mkdir,access,rename} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const root=resolve(import.meta.dirname,'..');
const dir=resolve(root,'docs/agent-work/meshy-mythic-batch');
const ids=['fiamma','pantera','steamer','oracolo','colosso'];
const [mode,id,stage='model']=process.argv.slice(2);
if(!['submit','status','balance'].includes(mode) || (mode!=='balance' && (!ids.includes(id)||!['model','rig'].includes(stage)))) throw Error('Use balance | submit|status athlete model|rig');
const cost=stage==='model'?30:5;
const endpoint=stage==='model'?'image-to-3d':'rigging';
const statePath=resolve(dir,`${id}-${stage}.json`);
async function api(path,payload){
  const raw=await readFile('/Users/alessiofantini/Downloads/codice.md','utf8');
  const key=raw.match(/msy_[A-Za-z0-9_-]+/)?.[0];
  if(!key)throw Error('Credential format not recognized');
  let response;
  try {response=await fetch(`https://api.meshy.ai/openapi/v1/${path}`,{method:payload?'POST':'GET',headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:payload?JSON.stringify(payload):undefined,signal:AbortSignal.timeout(60000)});}
  catch {throw Error('Meshy transport failure; reconcile existing reservation before any paid retry');}
  if(!response.ok)throw Error(`Meshy HTTP ${response.status}; response omitted`);
  return response.json();
}
async function save(record){
  const tmp=statePath+'.tmp';
  await writeFile(tmp,JSON.stringify(record,null,2)+'\n');
  await rename(tmp,statePath);
}
async function run(){
  await mkdir(dir,{recursive:true});
  if(mode==='balance'){console.log(JSON.stringify(await api('balance')));return;}
  if(mode==='submit'){
    for(const athlete of ids)for(const phase of ['model','rig']){
      try{
        const prior=JSON.parse(await readFile(resolve(dir,`${athlete}-${phase}.json`),'utf8'));
        if(Number(prior.credits)>prior.reservedCredits)throw Error('Unexpected prior billing: stop paid batch');
      }catch(e){if(e.code!=='ENOENT')throw e;}
    }
    try {await access(statePath);throw Error('Task already reserved; use status, never resubmit');}catch(e){if(e.code!=='ENOENT')throw e;}
    let payload,referenceHash;
    if(stage==='model'){
      const source=resolve(root,`assets/outfits/${id}/mythic-preview.webp`);
      const reference=resolve(dir,`${id}-reference.png`);
      // Format conversion only: original illustration, no generated image edit.
      execFileSync('/usr/bin/sips',['-s','format','png',source,'--out',reference],{stdio:'ignore'});
      const bytes=await readFile(reference);
      referenceHash=createHash('sha256').update(bytes).digest('hex');
      payload={image_url:`data:image/png;base64,${bytes.toString('base64')}`,ai_model:'meshy-7.1',geometry_resolution:'standard',model_type:'standard',should_texture:true,enable_pbr:true,texture_resolution:'2k',target_formats:['glb'],pose_mode:'a-pose',image_enhancement:false,should_remesh:true,topology:'triangle',target_polycount:20000};
    }else{
      const parent=JSON.parse(await readFile(resolve(dir,`${id}-model.json`),'utf8'));
      if(parent.status!=='SUCCEEDED'||!parent.downloaded)throw Error('Parent must succeed and download before rigging');
      payload={input_task_id:parent.id,height_meters:1.8};
    }
    const balance=await api('balance');
    if(Number(balance.balance)<cost)throw Error('Insufficient credit balance');
    // Fixed allowlist and exclusive record = at most 5*30 + 5*5 reserved credits.
    // Uncertain/failed requests retain reservations, so no replacement spending.
    const record={athlete:id,stage,endpoint,status:'SUBMISSION_PENDING',reservedCredits:cost,batchCap:175,created:new Date().toISOString(),balanceBefore:balance.balance,referenceHash,settings:Object.fromEntries(Object.entries(payload).filter(([k])=>k!=='image_url'))};
    await writeFile(statePath,JSON.stringify(record,null,2)+'\n',{flag:'wx'});
    const result=await api(endpoint,payload);
    if(!result.result)throw Error('Missing task ID: uncertain paid submission; reconcile manually');
    record.id=result.result;record.status='SUBMITTED';await save(record);
    console.log(JSON.stringify(record));
  }else{
    const record=JSON.parse(await readFile(statePath,'utf8'));
    if(!record.id)throw Error('Uncertain submission; never retry POST');
    const task=await api(`${endpoint}/${record.id}`);
    Object.assign(record,{status:task.status,progress:task.progress,credits:task.consumed_credits,checked:new Date().toISOString()});
    await save(record);
    if(Number(record.credits)>record.reservedCredits)throw Error('Billed amount exceeded reservation: stop batch');
    if(task.status==='SUCCEEDED'&&!record.downloaded){
      const urls={model:task.model_urls?.glb??task.result?.rigged_character_glb_url,preview:task.thumbnail_url};
      if(!urls.model)throw Error('Succeeded without GLB: no paid retry');
      if(stage==='rig')Object.assign(urls,{running:task.result?.basic_animations?.running_glb_url,walking:task.result?.basic_animations?.walking_glb_url});
      const files=[];
      for(const [kind,url] of Object.entries(urls)){
        if(!url)continue;
        const ext=kind==='preview'?'.png':'.glb';
        const path=resolve(dir,`${id}-${stage}`,kind+ext);
        let response;
        try{response=await fetch(url,{signal:AbortSignal.timeout(60000)});}catch{throw Error('Artifact download failed; status can resume without credits');}
        if(!response.ok)throw Error(`Artifact HTTP ${response.status}`);
        const bytes=Buffer.from(await response.arrayBuffer());
        if(ext==='.glb'&&bytes.toString('ascii',0,4)!=='glTF')throw Error('Invalid GLB artifact');
        await mkdir(dirname(path),{recursive:true});await writeFile(path,bytes);
        files.push({path:path.slice(root.length+1),bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});
      }
      record.files=files;record.downloaded=true;await save(record);
    }
    console.log(JSON.stringify(record));
  }
}
run().catch(e=>{console.error(e.message);process.exitCode=1;});
