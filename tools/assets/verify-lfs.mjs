#!/usr/bin/env node

/**
 * Reject newly committed heavyweight art binaries that bypass Git LFS.
 *
 * Existing blobs are explicitly listed in docs/art/lfs-legacy-large-assets.txt.
 * That list is a one-way compatibility bridge, not an exception mechanism for
 * future files: never add to it without the planned whole-history migration.
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const REPO = process.cwd();
const LEGACY_LIST = 'docs/art/lfs-legacy-large-assets.txt';
const MIN_LFS_BYTES = 5 * 1024 * 1024;
const ASSET_ROOTS = ['godot/assets', 'art/generated', 'meshy', 'tools/meshy/output'];
const BINARY_EXTENSIONS = new Set([
  '.glb', '.blend', '.fbx', '.psd', '.tga', '.tif', '.tiff', '.exr',
  '.wav', '.ogg', '.mp3', '.flac', '.png', '.jpg', '.jpeg', '.webp',
  '.mp4', '.mov',
]);
const LFS_POINTER = /^version https:\/\/git-lfs\.github\.com\/spec\/v1\noid sha256:[0-9a-f]{64}\nsize \d+\n?$/;

function git(args, encoding = 'utf8') {
  return execFileSync('git', args, {
    cwd: REPO,
    encoding,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function extension(path) {
  const slash = path.lastIndexOf('/');
  const dot = path.lastIndexOf('.');
  return dot > slash ? path.slice(dot).toLowerCase() : '';
}

function legacyPaths() {
  return new Set(readFileSync(LEGACY_LIST, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#')));
}

function indexedFiles() {
  const raw = git(['ls-files', '-s', '-z', '--', ...ASSET_ROOTS]);
  return raw.split('\0').filter(Boolean).map((record) => {
    const match = /^(\d+) ([0-9a-f]{40,64}) (\d)\t(.+)$/.exec(record);
    if (!match) throw new Error(`Indice Git non leggibile: ${record}`);
    return { oid: match[2], stage: match[3], path: match[4] };
  }).filter((entry) => entry.stage === '0');
}

function hasLfsAttribute(path) {
  return git(['check-attr', 'filter', '--', path]).trim().endsWith('filter: lfs');
}

function blobSize(oid) {
  return Number(git(['cat-file', '-s', oid]).trim());
}

function isLfsPointer(oid, size) {
  // A valid pointer is a tiny text file. Never materialise a legacy GLB just
  // to learn that it is not one: some payloads are tens of megabytes.
  return size <= 512 && LFS_POINTER.test(git(['cat-file', '-p', oid]));
}

const legacy = legacyPaths();
const failures = [];
let checked = 0;
let legacyCount = 0;
let lfsCount = 0;

for (const entry of indexedFiles()) {
  if (!BINARY_EXTENSIONS.has(extension(entry.path))) continue;
  const size = blobSize(entry.oid);
  const pointer = isLfsPointer(entry.oid, size);
  if (!pointer && size < MIN_LFS_BYTES) continue;

  checked += 1;
  if (!hasLfsAttribute(entry.path)) {
    failures.push(`${entry.path}: manca filter=lfs in .gitattributes`);
  } else if (pointer) {
    lfsCount += 1;
  } else if (legacy.has(entry.path)) {
    legacyCount += 1;
  } else {
    failures.push(`${entry.path}: blob Git da ${size} byte, deve essere un puntatore Git LFS`);
  }
}

if (failures.length) {
  console.error(`ASSET LFS FAIL (${failures.length})`);
  for (const failure of failures) console.error(`- ${failure}`);
  console.error('Installa Git LFS e aggiungi di nuovo l\'asset; non estendere la lista legacy.');
  process.exit(1);
}

console.log(`ASSET LFS PASS checked=${checked} lfs=${lfsCount} legacy=${legacyCount}`);
