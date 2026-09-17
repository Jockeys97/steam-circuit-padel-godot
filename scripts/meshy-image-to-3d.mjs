#!/usr/bin/env node

/**
 * Generate a game-ready GLB from a local reference image with Meshy.
 *
 * The API key is read only from MESHY_API_KEY. It is never printed or saved.
 */

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { basename, dirname, extname, resolve } from 'node:path';

const API_BASE = 'https://api.meshy.ai/openapi/v1/image-to-3d';
const POLL_INTERVAL_MS = 5_000;
const POLL_TIMEOUT_MS = 20 * 60 * 1_000;

function usage() {
  console.error('Uso: node scripts/meshy-image-to-3d.mjs --image <png|jpg> --output <file.glb> [--name <nome>]');
  process.exit(2);
}

function arg(name, fallback = undefined) {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1];
}

const imagePath = arg('--image');
const outputPath = arg('--output');
const name = arg('--name', 'pantera');
const apiKey = process.env.MESHY_API_KEY;

if (!imagePath || !outputPath) usage();
if (!apiKey) {
  console.error('MESHY_API_KEY non è impostata in questa sessione Terminale.');
  process.exit(1);
}

const inputPath = resolve(imagePath);
const destination = resolve(outputPath);
const extension = extname(inputPath).toLowerCase();
const mime = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg' }[extension];
if (!mime) {
  console.error('Meshy API accetta PNG/JPG/JPEG. Converti prima l’immagine WebP in PNG.');
  process.exit(1);
}

const image = await readFile(inputPath);
const imageUrl = `data:${mime};base64,${image.toString('base64')}`;

const payload = {
  image_url: imageUrl,
  model_type: 'standard',
  ai_model: 'meshy-7',
  should_texture: true,
  enable_pbr: true,
  texture_resolution: '4k',
  pose_mode: 'a-pose',
  image_enhancement: false,
  should_remesh: true,
  topology: 'triangle',
  target_polycount: 100000,
  target_formats: ['glb'],
};

async function meshRequest(url, options = {}) {
  const requestHeaders = {
    Authorization: `Bearer ${apiKey}`,
    ...(options.headers ?? {}),
  };
  if (options.body) requestHeaders['Content-Type'] = 'application/json';
  const response = await fetch(url, {
    ...options,
    headers: requestHeaders,
  });
  const text = await response.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { message: text.slice(0, 300) };
  }
  if (!response.ok) {
    throw new Error(`Meshy API ${response.status}: ${body.message ?? body.error ?? 'richiesta fallita'}`);
  }
  return body;
}

console.log(`Invio a Meshy il riferimento ${basename(inputPath)}…`);
const created = await meshRequest(API_BASE, {
  method: 'POST',
  body: JSON.stringify(payload),
});
const taskId = created.result;
if (!taskId) throw new Error('Meshy non ha restituito un task ID.');
console.log(`Task Meshy creato (${taskId}). Attendo il modello…`);

const started = Date.now();
let task;
while (Date.now() - started < POLL_TIMEOUT_MS) {
  await new Promise((resolvePromise) => setTimeout(resolvePromise, POLL_INTERVAL_MS));
  task = await meshRequest(`${API_BASE}/${taskId}`, { method: 'GET' });
  console.log(`Stato: ${task.status ?? 'UNKNOWN'}${Number.isFinite(task.progress) ? ` — ${task.progress}%` : ''}`);
  if (task.status === 'SUCCEEDED' || task.status === 'FAILED' || task.status === 'CANCELED') break;
}

if (!task || task.status !== 'SUCCEEDED' || !task.model_urls?.glb) {
  const detail = task?.task_error?.message || `stato finale ${task?.status ?? 'sconosciuto'}`;
  throw new Error(`Generazione Pantera non riuscita: ${detail}`);
}

await mkdir(dirname(destination), { recursive: true });
const modelResponse = await fetch(task.model_urls.glb);
if (!modelResponse.ok) throw new Error(`Download GLB fallito: HTTP ${modelResponse.status}`);
const modelBuffer = Buffer.from(await modelResponse.arrayBuffer());
await writeFile(destination, modelBuffer);

const metadataPath = destination.replace(/\.glb$/i, '.meshy-task.json');
await writeFile(metadataPath, `${JSON.stringify({ name, taskId, status: task.status, consumedCredits: task.consumed_credits, source: basename(inputPath) }, null, 2)}\n`);
console.log(`GLB salvato in ${destination}`);
console.log(`Metadati salvati in ${metadataPath}`);
