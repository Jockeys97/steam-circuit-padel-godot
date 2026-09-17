// Execute the original browser functions and the real Godot sampler on identical
// press/hold/release sequences. Neither side's shot logic is reimplemented here.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';
const root = path.resolve(import.meta.dirname, '..');
const source = fs.readFileSync(path.join(root, 'js/main.js'), 'utf8');
function extract(name) {
  const start = source.indexOf('function ' + name + '(');
  const end = source.indexOf('\nfunction ', start + 1);
  if (start < 0 || end < 0) throw Error('Missing reference ' + name);
  return source.slice(start, end);
}
const setup = `
var ui = {}, keys = new Set();
var hitQueued=false, sliceQueued=false, shotVariantQueued=null, shotAimQueued=null;
var specialQueued=false, switchQueued=false, switchDirectionQueued=null;
var matchState={humanMode:"solo",smashPrimed:false,cutVolleyPrimed:false,globoPrimed:false};
var gamepad={prevButtons:{},chargeAction:null,move:{x:0,y:0},aim:{x:0,y:0}};
function initAudio(){}
function pulseGamepad(){}
function isSliceAction(a){return a==="slice"||a==="vibora";}
`;
const mapping = {0:0,1:1,2:2,3:3,4:9,5:10,12:11,13:12,14:13,15:14};
let context;
const frames = [], expected = [];
function frame(buttons=[], axes=[0,0,0,0,0,0], flags={}, reset=false) {
  if (reset) {
    context = vm.createContext({});
    vm.runInContext(setup + ['radialStick','shotAimAxis','pollGamepadGameplay','getInput'].map(extract).join('\n'), context);
  }
  context.matchState = {humanMode:'solo',smashPrimed:false,cutVolleyPrimed:false,globoPrimed:false,...flags};
  context.pad = {axes:axes.slice(0,4), buttons:Array.from({length:16},(_,i)=>({value:i===6?axes[4]:i===7?axes[5]:Number(buttons.includes(i))}))};
  context.buttons = buttons;
  const result = vm.runInContext('pollGamepadGameplay(gamepad,pad,i=>buttons.includes(i)); getInput()',context);
  expected.push(JSON.parse(JSON.stringify(result)));
  frames.push({reset,buttons:Object.fromEntries(buttons.filter(i=>i in mapping).map(i=>[mapping[i],true])),axes:Object.fromEntries(axes.map((v,i)=>[i,v])),state:context.matchState});
}
for (const button of [0,2,3]) for (const rb of [false,true]) {
  frame([],undefined,{},true);
  frame(rb?[button,5]:[button],[.65,-.4,0,0,.2,.7]);
  frame(rb?[button]:[button,5],[.8,-.2,.9,0,0,0]);
  frame([]);
  frame([]);
}
for (const [button,flag] of [[0,'smashPrimed'],[2,'cutVolleyPrimed'],[3,'globoPrimed']]) {
  frame([],undefined,{},true);
  frame([button]); frame([]);
  frame([button],[.5,.3,0,0,0,0],{[flag]:true});
  frame([button],undefined,{[flag]:true});
  frame([]); frame([]);
}
frame([],undefined,{},true);
for (const buttons of [[0,2,3],[3,0],[0],[],[1],[1],[],[4],[],[12,13],[],[14],[15],[]]) frame(buttons);
for (const axes of [[0,0,1,0,0,0],[0,0,1,0,0,0],[0,0,0,0,0,0],[.8,.2,-1,0,0,0]]) frame([],axes);
// Deterministic overlaps and changing aim catch order-sensitive charge bugs.
let random = 73471;
const next = () => ((random = (random * 1664525 + 1013904223) >>> 0) / 2**32);
frame([],undefined,{},true);
for(let i=0;i<300;i++) frame([0,1,2,3,4,5,12,13,14,15].filter(()=>next()<.15),Array.from({length:6},(_,j)=>j<4?next()*2-1:next()));
const dir = fs.mkdtempSync(path.join(os.tmpdir(),'padel-controller-parity-'));
const input = path.join(dir,'frames.json');
fs.writeFileSync(input,JSON.stringify(frames));
const output = execFileSync(process.env.GODOT_BIN || '/opt/homebrew/bin/godot',
  ['--headless','--path',path.join(root,'godot'),'--script','res://tests/input/controller_trace.gd','--',input],
  {encoding:'utf8',timeout:30000});
const actual = output.split('\n').filter(l=>l.startsWith('INPUT_JSON ')).map(l=>JSON.parse(l.slice(11)));
let failures=0;
function equal(a,b) {
  if(typeof a==='number'&&typeof b==='number') return Math.abs(a-b)<1e-6;
  if(a&&b&&typeof a==='object'&&typeof b==='object') return Object.keys(a).every(k=>equal(a[k],b[k]));
  return a===b;
}
if(actual.length!==expected.length) throw Error('Incomplete trace '+actual.length);
for(let i=0;i<expected.length;i++) for(const key of Object.keys(expected[i])) {
  if(!equal(expected[i][key],actual[i][key])) {
    if(failures<15) console.error('frame',i,key,'2D=',expected[i][key],'3D=',actual[i][key]);
    failures++;
  }
}
console.log(`${failures?'FAIL':'PASS'} controller parity: ${frames.length} frames, all 23 fields, ${failures} differences`);
process.exitCode=failures?1:0;
