import fs from 'node:fs/promises';
import sharp from 'sharp';

const arena = process.argv[2];
if (!['torii', 'medina', 'aurora'].includes(arena)) {
  throw Error('Use: node scripts/optimize-outdoor-landmark.mjs torii|medina|aurora');
}
const input = new URL(`../meshy/outdoor-landmarks/${arena}-source.glb`, import.meta.url);
const output = new URL(`../godot/assets/arenas/${arena}/distant_landmark.glb`, import.meta.url);
const bytes = await fs.readFile(input);
if (bytes.toString('ascii', 0, 4) !== 'glTF') throw Error('Invalid source GLB');
const jsonLength = bytes.readUInt32LE(12);
const gltf = JSON.parse(bytes.subarray(20, 20 + jsonLength).toString());
const binary = bytes.subarray(28 + jsonLength);
const images = new Map((gltf.images ?? [])
  .filter(image => image.bufferView !== undefined)
  .map(image => [image.bufferView, image]));
const parts = [];
let offset = 0;
for (let i = 0; i < gltf.bufferViews.length; i++) {
  const view = gltf.bufferViews[i];
  let part = binary.subarray(view.byteOffset ?? 0, (view.byteOffset ?? 0) + view.byteLength);
  if (images.has(i)) {
    part = await sharp(part)
      .resize({width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true})
      .png().toBuffer();
    images.get(i).mimeType = 'image/png';
  }
  view.byteOffset = offset;
  view.byteLength = part.length;
  const padding = Buffer.alloc((4 - part.length % 4) % 4);
  parts.push(part, padding);
  offset += part.length + padding.length;
}
gltf.buffers[0].byteLength = offset;
const json = Buffer.from(JSON.stringify(gltf));
const jsonPadding = Buffer.alloc((4 - json.length % 4) % 4, 32);
const header = Buffer.alloc(20);
header.write('glTF');
header.writeUInt32LE(2, 4);
header.writeUInt32LE(28 + json.length + jsonPadding.length + offset, 8);
header.writeUInt32LE(json.length + jsonPadding.length, 12);
header.writeUInt32LE(0x4e4f534a, 16);
const binaryHeader = Buffer.alloc(8);
binaryHeader.writeUInt32LE(offset);
binaryHeader.writeUInt32LE(0x004e4942, 4);
await fs.mkdir(new URL('.', output), {recursive: true});
const optimized = Buffer.concat([header, json, jsonPadding, binaryHeader, ...parts]);
await fs.writeFile(output, optimized, {flag: 'wx'});
console.log(JSON.stringify({arena, sourceBytes: bytes.length,
  runtimeBytes: optimized.length, textures: images.size}));
