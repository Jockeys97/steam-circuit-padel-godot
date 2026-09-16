import assert from "node:assert/strict";
import fs from "node:fs/promises";
import { createRequire } from "node:module";
import { ATHLETES, ATHLETE_OUTFITS } from "../js/data.js?v=20260910-sprite-gate-v41";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const expectedAthletes = ["maestro", "pantera", "steamer", "fiamma", "oracolo", "colosso"];
const spriteKeys = ["sprite", "backSprite", "actionSprite", "backActionSprite", "runSprite", "backRunSprite"];
let dedicatedSheets = 0;

async function alphaMetrics(file, frameCount) {
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const frames = Array.from({ length: frameCount }, () => ({ minY: info.height, maxY: -1, visible: 0, partial: 0, hiddenRgb: 0 }));
  const frameWidth = info.width / frameCount;
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      const offset = (y * info.width + x) * 4;
      const alpha = data[offset + 3];
      const frame = Math.min(frameCount - 1, Math.floor(x / frameWidth));
      if (alpha === 0) continue;
      frames[frame].visible += 1;
      if (alpha < 224) frames[frame].partial += 1;
      frames[frame].minY = Math.min(frames[frame].minY, y);
      frames[frame].maxY = Math.max(frames[frame].maxY, y);
    }
  }
  return frames.map((frame) => ({
    ...frame,
    height: frame.maxY - frame.minY + 1,
    partialRatio: frame.partial / Math.max(1, frame.visible),
  }));
}

for (const athleteId of expectedAthletes) {
  const outfits = ATHLETE_OUTFITS[athleteId];
  const expectedCount = ["oracolo", "colosso"].includes(athleteId) ? 3 : 5;
  assert.equal(outfits?.length, expectedCount, `${athleteId}: numero di completi inatteso`);
  assert.equal(outfits[0].id, "base", `${athleteId}: il primo completo deve restare quello base`);

  for (const outfit of outfits.slice(1)) {
    // I completi ora si ottengono superando una sfida con il rispettivo atleta,
    // non raggiungendo una soglia generica di stelle o trofei.
    assert.ok(outfit.challenge, `${athleteId}/${outfit.id}: sfida di sblocco mancante`);
    assert.equal(outfit.unlockKey, `${athleteId}:${outfit.id}`, `${athleteId}/${outfit.id}: chiave di sblocco errata`);
    assert.ok(outfit.preview, `${athleteId}/${outfit.id}: anteprima mancante`);
    await fs.access(outfit.preview);
    for (const key of spriteKeys) {
      assert.ok(outfit.sprites?.[key], `${athleteId}/${outfit.id}: ${key} mancante`);
      await fs.access(outfit.sprites[key]);
      const generated = await sharp(outfit.sprites[key]).metadata();
      const generatedStats = await sharp(outfit.sprites[key]).stats();
      const originalPath = ATHLETES.find((athlete) => athlete.id === athleteId)?.[key];
      assert.ok(originalPath, `${athleteId}/${key}: sprite sorgente mancante nei dati atleta`);
      const original = await sharp(originalPath).metadata();
      const frameCount = key.toLowerCase().includes("run") ? 8 : 4;
      const expectedWidth = Math.round((original.width * 0.6) / frameCount) * frameCount;
      assert.equal(generated.width, expectedWidth, `${athleteId}/${outfit.id}/${key}: lo sprite deve essere a 0,6x`);
      assert.equal(generated.format, "webp", `${athleteId}/${outfit.id}/${key}: formato non WebP`);
      assert.equal(generatedStats.isOpaque, false, `${athleteId}/${outfit.id}/${key}: trasparenza persa`);
      const [sourceFrames, outfitFrames] = await Promise.all([
        alphaMetrics(originalPath, frameCount),
        alphaMetrics(outfit.sprites[key], frameCount),
      ]);
      outfitFrames.forEach((frame, index) => {
        const expectedHeight = sourceFrames[index].height * generated.height / original.height;
        const heightRatio = frame.height / expectedHeight;
        assert.ok(heightRatio >= 0.96 && heightRatio <= 1.04,
          `${athleteId}/${outfit.id}/${key}/${index}: silhouette alterata (${heightRatio.toFixed(2)}x)`);
        assert.ok(frame.partialRatio <= 0.01,
          `${athleteId}/${outfit.id}/${key}/${index}: ${(frame.partialRatio * 100).toFixed(1)}% pixel semitrasparenti`);
      });
      dedicatedSheets += 1;
    }
  }
}

const outfitCount = expectedAthletes.reduce((total, athleteId) => total + ATHLETE_OUTFITS[athleteId].length, 0);
const unlockableOutfitCount = outfitCount - expectedAthletes.length;
assert.equal(dedicatedSheets, unlockableOutfitCount * spriteKeys.length,
  "Ogni completo sbloccabile deve avere sei fogli sprite dedicati");
console.log(JSON.stringify({ athletes: expectedAthletes.length, outfits: outfitCount, dedicatedSheets }, null, 2));
