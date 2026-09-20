// One approved four-stroke batch, hard ceiling 52 credits. Never auto-retry POST.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const dir=path.join(root,'docs/agent-work/meshy-fiamma-strokes');
fs.mkdirSync(dir,{recursive:true});
const file=path.join(dir,'tasks.json');
const state=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
const key=process.env.MESHY_API_KEY;
if(!key)throw Error('Set MESHY_API_KEY securely before running');
const save=()=>fs.writeFileSync(file,JSON.stringify(state,null,2));
async function api(endpoint,body){const r=await fetch('https://api.meshy.ai/openapi/v1/'+endpoint,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});if(!r.ok)throw Error('Meshy HTTP '+r.status+' '+endpoint);return r.json();}
async function task(name,endpoint,body,cost){
 if(!state[name]){const reserved=Object.values(state).reduce((n,t)=>n+(t.reserved||0),0);if(reserved+cost>52)throw Error('Budget exceeded');state[name]={reserved:cost,request_started:true};save();const d=await api(endpoint,body);state[name].id=d.result;save();console.log(name,'created',d.result);}
 if(!state[name].id)throw Error('Uncertain creation; inspect remote tasks before retrying');
 for(;;){const d=await api(endpoint+'/'+state[name].id);state[name].status=d.status;state[name].credits=d.consumed_credits;save();console.log(name,d.status,d.progress);if(d.status==='SUCCEEDED')return d;if(['FAILED','CANCELED'].includes(d.status))throw Error(name+' '+d.status);await new Promise(r=>setTimeout(r,15000));}
}
async function download(url,name){if(!url)throw Error('Missing output URL');const r=await fetch(url);if(!r.ok)throw Error('Download HTTP '+r.status);fs.writeFileSync(path.join(dir,name),Buffer.from(await r.arrayBuffer()));}
const prompts={
 smash:'Right-handed padel player performs ONE overhead smash. Athletic ready stance, turn sideways, left hand points up at the ball, right elbow lifts and bends behind head, extend right arm overhead to strike, follow through down across the body, recover to ready. Feet remain grounded near start. No jump, walking or props. Realistic sports action.',
 bandeja:'Right-handed padel player performs ONE controlled bandeja overhead slice. Turn sideways, raise right elbow to shoulder height, right hand behind head, left arm points upward. Sweep right hand forward at head height with a horizontal slicing arc, follow through across body and recover to ready stance. Feet grounded, no jump, no props. Not a power smash.',
 backhand:'Right-handed padel player performs ONE one-handed backhand groundstroke. Ready stance with bent knees, turn shoulders left, bring right hand across body toward left hip, swing right arm forward from left to right through waist-height contact. Left arm opens behind for balance. Follow through and return to ready. Stay in place, no jumps, no props.',
 slice:'Right-handed padel player performs ONE forehand slice groundstroke. Start ready, turn shoulders right, raise right hand to chest height, swing forward and slightly downward through waist-height contact with a controlled cutting motion, finish forward across body and return to ready. Left arm balances. Feet grounded near start, no props, no overhead stroke.'
};
(async()=>{
 const rig=JSON.parse(fs.readFileSync(path.join(root,'docs/agent-work/meshy-fiamma-trial/tasks.json'))).rig.id;
 const r=await api('rigging/'+rig);if(r.status!=='SUCCEEDED')throw Error('Rig unavailable');
 console.log('RIG_VERIFIED',rig);
 for(const [name,prompt] of Object.entries(prompts)){
  const motion=await task(name+'_motion','text-to-motion',{mode:'prime',duration:3,prompt},10);
  await download(motion.result.motion_url,name+'.fbx');
  const animation=await task(name+'_animation','animations',{rig_task_id:rig,motion_task_id:motion.id},3);
  await download(animation.result.animation_glb_url,name+'.glb');
 }
 console.log('BATCH_COMPLETE credits='+Object.values(state).reduce((n,t)=>n+(t.credits||0),0));
})().catch(e=>{console.error(e.message);process.exitCode=1});
