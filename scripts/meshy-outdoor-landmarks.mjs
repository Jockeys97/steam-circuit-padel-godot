import {readFile, writeFile, access} from 'node:fs/promises';
import {createHash} from 'node:crypto';

const arena = process.argv[2];
if (!['torii', 'medina', 'aurora'].includes(arena)) {
  throw Error('Use: node scripts/meshy-outdoor-landmarks.mjs torii|medina|aurora');
}
const root = new URL('../meshy/outdoor-landmarks/', import.meta.url);
const reference = new URL(`${arena}-reference.png`, root);
const stateFile = new URL(`${arena}-task.json`, root);
const modelFile = new URL(`${arena}-source.glb`, root);
const credential = (await readFile('/Users/alessiofantini/Downloads/codice.md', 'utf8'))
  .match(/msy_[A-Za-z0-9_-]+/)?.[0];
if (!credential) throw Error('Meshy credential unavailable');

async function api(path, payload) {
  const response = await fetch(`https://api.meshy.ai/openapi/v1/${path}`, {
    method: payload ? 'POST' : 'GET',
    headers: {Authorization: `Bearer ${credential}`, 'Content-Type': 'application/json'},
    body: payload ? JSON.stringify(payload) : undefined,
    signal: AbortSignal.timeout(60000),
  });
  if (!response.ok) throw Error(`Meshy HTTP ${response.status}; response redacted`);
  return response.json();
}

let state;
try {
  state = JSON.parse(await readFile(stateFile, 'utf8'));
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
if (!state) {
  const balance = Number((await api('balance')).balance);
  if (!Number.isFinite(balance) || balance < 30) throw Error('Insufficient Meshy credits');
  const input = await readFile(reference);
  const options = {
    ai_model: 'meshy-7.1', should_texture: true, enable_pbr: true,
    texture_resolution: '2k', should_remesh: true, topology: 'triangle',
    target_polycount: 10000, target_formats: ['glb'], image_enhancement: false,
  };
  state = {arena, status: 'SUBMITTING', reservedCredits: 30,
    referenceSha256: createHash('sha256').update(input).digest('hex'), options};
  await writeFile(stateFile, JSON.stringify(state, null, 2), {flag: 'wx'});
  const submitted = await api('image-to-3d', {
    ...options, image_url: `data:image/png;base64,${input.toString('base64')}`,
  });
  state.id = submitted.result;
  await writeFile(stateFile, JSON.stringify(state, null, 2));
}
if (!state.id) throw Error('Submission outcome uncertain; do not retry automatically');
const task = await api(`image-to-3d/${state.id}`);
state.status = task.status;
state.progress = task.progress;
state.consumedCredits = task.consumed_credits;
await writeFile(stateFile, JSON.stringify(state, null, 2));
console.log(JSON.stringify({arena, status: task.status, progress: task.progress,
  credits: task.consumed_credits}));
if (task.status === 'SUCCEEDED') {
  let exists = true;
  try { await access(modelFile); } catch { exists = false; }
  if (!exists) {
    const response = await fetch(task.model_urls.glb, {signal: AbortSignal.timeout(120000)});
    if (!response.ok) throw Error('GLB download failed');
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.toString('ascii', 0, 4) !== 'glTF') throw Error('Downloaded file is not GLB');
    await writeFile(modelFile, bytes, {flag: 'wx'});
    console.log(JSON.stringify({arena, modelBytes: bytes.length}));
  }
}
