import assert from "node:assert/strict";
import sharp from "sharp";
import path from "node:path";
import { ATHLETES, ATHLETE_OUTFITS } from "../js/data.js?v=20260910-sprite-gate-v41";

const unlockables = ["oracolo", "colosso"];
const states = ["idle", "action", "run"];
const views = ["front", "back"];
const standardModels = { oracolo: "maestro", colosso: "steamer" };
const root = path.resolve(import.meta.dirname, "..");

function spritePath(athlete, view, state) {
  if (view === "back") return state === "idle" ? athlete.backSprite : state === "action" ? athlete.backActionSprite : athlete.backRunSprite;
  return state === "idle" ? athlete.sprite : state === "action" ? athlete.actionSprite : athlete.runSprite;
}

async function frameMetrics(file, frames) {
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const metrics = [];
  for (let frame = 0; frame < frames; frame += 1) {
    const left = frame * info.width / frames;
    const right = (frame + 1) * info.width / frames;
    let minY = info.height;
    let maxY = -1;
    let alphaTotal = 0;
    let opaquePixels = 0;
    for (let y = 0; y < info.height; y += 1) {
      for (let x = left; x < right; x += 1) {
        const alpha = data[(y * info.width + x) * 4 + 3];
        if (alpha < 24) continue;
        minY = Math.min(minY, y);
        maxY = Math.max(maxY, y);
        alphaTotal += alpha;
        opaquePixels += 1;
      }
    }
    metrics.push({ height: maxY - minY + 1, alpha: alphaTotal / opaquePixels });
  }
  return metrics;
}

async function visibleLuma(file) {
  const { data } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  let pixels = 0;
  let total = 0;
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] < 24) continue;
    total += data[offset] * 0.2126 + data[offset + 1] * 0.7152 + data[offset + 2] * 0.0722;
    pixels += 1;
  }
  return total / Math.max(1, pixels);
}

for (const athleteId of unlockables) {
  const athlete = ATHLETES.find((candidate) => candidate.id === athleteId);
  assert.ok(athlete, `${athleteId}: atleta mancante`);
  assert.equal(athlete.runFrames, 8, `${athleteId}: la corsa deve dichiarare 8 frame`);
  const standard = ATHLETES.find((candidate) => candidate.id === standardModels[athleteId]);
  assert.deepEqual(athlete.runDisplay, standard.runDisplay, `${athleteId}: scala corsa diversa dal modello standard`);
  assert.equal(athlete.runGrid, undefined, `${athleteId}: non deve richiedere griglie speciali`);
  assert.equal(athlete.spriteAspect, undefined, `${athleteId}: non deve richiedere correzioni di proporzione`);
  assert.equal(athlete.spriteHeights, undefined, `${athleteId}: non deve richiedere correzioni di altezza`);
  for (const view of views) {
    for (const state of states) {
      const actual = await sharp(path.join(root, spritePath(athlete, view, state))).metadata();
      const expected = await sharp(path.join(root, spritePath(standard, view, state))).metadata();
      assert.deepEqual(
        { width: actual.width, height: actual.height },
        { width: expected.width, height: expected.height },
        `${athleteId}/${view}/${state}: il foglio non rispetta le dimensioni del modello standard`,
      );
      const frames = state === "run" ? 8 : 4;
      assert.equal(actual.width % frames, 0, `${athleteId}/${view}/${state}: i frame non sono una striscia orizzontale regolare`);
      const actualMetrics = await frameMetrics(path.join(root, spritePath(athlete, view, state)), frames);
      const expectedMetrics = await frameMetrics(path.join(root, spritePath(standard, view, state)), frames);
      actualMetrics.forEach((metric, frame) => {
        const heightRatio = metric.height / expectedMetrics[frame].height;
        // Le pose possono essere più raccolte per silhouette, ma non devono
        // più avere salti di scala evidenti come il vecchio Colosso (0,75x).
        assert.ok(heightRatio >= 0.85 && heightRatio <= 1.20,
          `${athleteId}/${view}/${state}/${frame}: altezza visiva ${heightRatio.toFixed(2)} rispetto allo standard`);
        assert.ok(metric.alpha >= 210,
          `${athleteId}/${view}/${state}/${frame}: alpha media troppo bassa (${metric.alpha.toFixed(1)})`);
      });
    }
  }
  for (const outfit of ATHLETE_OUTFITS[athleteId]) {
    if (outfit.id === "base") continue;
    assert.ok(outfit.sprites, `${athleteId}/${outfit.id}: fogli outfit mancanti`);
  }
  if (athleteId === "oracolo") {
    const idleLuma = await visibleLuma(path.join(root, athlete.sprite));
    const actionLuma = await visibleLuma(path.join(root, athlete.actionSprite));
    const runLuma = await visibleLuma(path.join(root, athlete.runSprite));
    const animatedLuma = (actionLuma + runLuma) / 2;
    assert.ok(idleLuma <= animatedLuma * 1.75,
      `oracolo/front/idle: stile troppo luminoso rispetto alle animazioni (${idleLuma.toFixed(1)} vs ${animatedLuma.toFixed(1)})`);
  }
}

console.log(JSON.stringify({ unlockables: unlockables.length, standardizedStates: unlockables.length * views.length * states.length }, null, 2));
