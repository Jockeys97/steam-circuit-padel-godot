// Stretch strokes for Fiamma (2026-09-24), same recipe as fiamma-strokes.cjs:
// Prime text-to-motion (10) + retarget onto the Fiamma rig (3) = 13 per stroke.
// The 2026-09-20 rig belongs to another Meshy account (this key gets "Rigging task
// not found"), so the first run re-rigs Fiamma on this account (5, once) from the
// rigged GLB of that trial, at its measured 1.74 m. Run one stroke at a time:
// `node lunge-strokes.cjs <name>`, with a hard per-run ceiling (MESHY_CEILING).
// Never auto-retries a POST.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'../..');
const dir=path.join(root,'docs/agent-work/meshy-lunge');
fs.mkdirSync(dir,{recursive:true});
// One task log per Meshy account: a rig belongs to the account that made it, so the
// second account keeps its own (MESHY_STATE=tasks-meshy2.json) and re-rigs once.
const file=path.join(dir,process.env.MESHY_STATE||'tasks.json');
const state=fs.existsSync(file)?JSON.parse(fs.readFileSync(file)):{};
const key=process.env.MESHY_API_KEY;
if(!key)throw Error('Set MESHY_API_KEY securely before running');
const CEILING=Number(process.env.MESHY_CEILING||13);
const save=()=>fs.writeFileSync(file,JSON.stringify(state,null,2));
async function floorCheck(cost){if(!process.env.MESHY_FLOOR)return;const b=(await api('balance')).balance;if(b-cost<Number(process.env.MESHY_FLOOR))throw Error('Account floor reached: balance '+b+', floor '+process.env.MESHY_FLOOR);console.log('balance',b,'floor',process.env.MESHY_FLOOR);}
async function api(endpoint,body){const r=await fetch('https://api.meshy.ai/openapi/v1/'+endpoint,{method:body?'POST':'GET',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});if(!r.ok)throw Error('Meshy HTTP '+r.status+' '+endpoint+' '+(await r.text()).slice(0,200));return r.json();}
let spentThisRun=0;
async function task(name,endpoint,body,cost){
 if(!state[name]){if(spentThisRun+cost>CEILING)throw Error('Budget exceeded');await floorCheck(cost);spentThisRun+=cost;state[name]={reserved:cost,request_started:true};save();let d;try{d=await api(endpoint,body);}catch(e){if(String(e.message).startsWith('Meshy HTTP')){delete state[name];spentThisRun-=cost;save();}throw e;}state[name].id=d.result;save();console.log(name,'created',d.result);}
 if(!state[name].id)throw Error('Uncertain creation; inspect remote tasks before retrying');
 for(;;){const d=await api(endpoint+'/'+state[name].id);state[name].status=d.status;state[name].credits=d.consumed_credits;save();console.log(name,d.status,d.progress);if(d.status==='SUCCEEDED')return d;if(['FAILED','CANCELED'].includes(d.status))throw Error(name+' '+d.status);await new Promise(r=>setTimeout(r,15000));}
}
async function ensureRig(){
 if(state.rig&&state.rig.id){const r=await api('rigging/'+state.rig.id);if(r.status==='SUCCEEDED')return state.rig.id;}
 const glb=fs.readFileSync(path.join(root,'docs/agent-work/meshy-fiamma-trial/fiamma-trial-rig.glb'));
 const d=await task('rig','rigging',{model_url:'data:model/gltf-binary;base64,'+glb.toString('base64'),height_meters:1.74},5);
 if(d.result&&d.result.rigged_character_glb_url)await download(d.result.rigged_character_glb_url,process.env.MESHY_STATE?'fiamma-rig-'+process.env.MESHY_STATE.replace(/^tasks-|\.json$/g,'')+'.glb':'fiamma-rig.glb');
 return state.rig.id;
}
async function download(url,name){if(!url)throw Error('Missing output URL');const r=await fetch(url);if(!r.ok)throw Error('Download HTTP '+r.status);fs.writeFileSync(path.join(dir,name),Buffer.from(await r.arrayBuffer()));}
const prompts={
 lunge_forehand:'Right-handed padel player, ONE stretched forehand lunge for a wide low ball on the right: from ready stance, one long step right, deep lunge, right knee bent over right foot, left leg extended, hips low, torso fairly upright. Right arm reaches out and swings forward through a low contact near knee height, left arm back for balance. Push off and return to ready. No jump, no dive, no props.',
 // 2026-09-26 trial: the two hand-authored clips most on screen, to compare in a match.
 ready_stance:'Right-handed padel player waiting for the ball in a ready stance, looping idle: feet shoulder-width apart, knees bent, weight on the balls of the feet, racket held in front of the chest with both hands. Small natural weight shifts from foot to foot, light breathing, tiny heel lifts, head steady looking forward. Stays in place. No steps away, no jump, no props.',
 forehand_volley:'Right-handed padel player at the net, ONE forehand volley: from a ready stance, short step forward with the left foot, compact backswing with the racket at shoulder height, firm punch forward meeting the ball in front of the body, very short follow-through, then quickly back to the ready stance. Fast and compact, no big swing, no jump, no props.',
 wall_exit_forehand:'Right-handed padel player, ONE forehand after the ball rebounds off the back glass: stand side-on near the back wall, knees bent, racket back low, wait while the ball drops, then step forward with the left foot and swing a flat forehand through waist-height contact in front, follow through towards the net and return to ready. No jump, no props.',
};
(async()=>{
 const name=process.argv[2];
 if(!prompts[name])throw Error('Unknown stroke '+name+'; known: '+Object.keys(prompts).join(', '));
 const rig=await ensureRig();
 console.log('RIG_VERIFIED',rig);
 const motion=await task(name+'_motion','text-to-motion',{mode:'prime',duration:3,prompt:prompts[name]},10);
 await download(motion.result.motion_url,name+'.fbx');
 const animation=await task(name+'_animation','animations',{rig_task_id:rig,motion_task_id:motion.id},3);
 await download(animation.result.animation_glb_url,name+'.glb');
 console.log('DONE '+name+' credits='+[name+'_motion',name+'_animation'].reduce((n,k)=>n+(state[k].credits||0),0));
})().catch(e=>{console.error(e.message);process.exitCode=1});
