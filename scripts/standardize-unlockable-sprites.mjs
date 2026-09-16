import sharp from "sharp";
import path from "node:path";

const ROOT = path.resolve(import.meta.dirname, "..");

const CONTRACTS = {
  oracolo: { reference: "maestro" },
  colosso: { reference: "steamer" },
};

const STATES = ["idle", "action", "run"];
const VIEWS = ["front", "back"];

function masterPath(athlete, view, state) {
  const directory = view === "back"
    ? "assets/_archivio/originali/sprites/back"
    : "assets/_archivio/originali/sprites";
  if (athlete === "maestro" || athlete === "steamer") {
    const suffix = state === "idle" ? "" : state === "action" ? "-action" : "-run-v3";
    return path.join(ROOT, directory, `${athlete}${suffix}.png`);
  }
  const suffix = athlete === "oracolo" && state === "idle"
    ? "idle-consistent-v2"
    : `${state}-unique`;
  return path.join(ROOT, directory, `${athlete}-${suffix}.png`);
}

function outputPath(athlete, view, state) {
  const directory = view === "back" ? "assets/sprites/back" : "assets/sprites";
  const suffix = athlete === "oracolo" && state === "idle"
    ? "idle-consistent-v2"
    : `${state}-unique`;
  return path.join(ROOT, directory, `${athlete}-${suffix}.webp`);
}

function activeReferencePath(reference, view, state) {
  const directory = view === "back" ? "assets/sprites/back" : "assets/sprites";
  const suffix = state === "idle" ? "" : state === "action" ? "-action" : "-run-v3";
  return path.join(ROOT, directory, `${reference}${suffix}.webp`);
}

const ALPHA_FLOOR = 24;

async function frameBounds(image, left, top, width, height) {
  const { data, info } = await image
    .clone()
    .extract({ left, top, width, height })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  let minX = info.width;
  let minY = info.height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
      if (data[(y * info.width + x) * 4 + 3] < ALPHA_FLOOR) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) throw new Error("Fotogramma sprite vuoto");
  return { left: left + minX, top: top + minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}

async function connectedFrames(image, expectedCount, expectedRows = 1) {
  const { data, info } = await image.clone().ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const source = Buffer.from(data.buffer, data.byteOffset, data.byteLength);
  const visited = new Uint8Array(info.width * info.height);
  const components = [];
  for (let start = 0; start < visited.length; start += 1) {
    if (visited[start] || data[start * 4 + 3] < 8) continue;
    const queue = [start];
    const pixels = [];
    visited[start] = 1;
    let minX = info.width;
    let minY = info.height;
    let maxX = 0;
    let maxY = 0;
    for (let cursor = 0; cursor < queue.length; cursor += 1) {
      const index = queue[cursor];
      const x = index % info.width;
      const y = Math.floor(index / info.width);
      pixels.push(index);
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      for (let dy = -1; dy <= 1; dy += 1) {
        for (let dx = -1; dx <= 1; dx += 1) {
          const nextX = x + dx;
          const nextY = y + dy;
          if (nextX < 0 || nextX >= info.width || nextY < 0 || nextY >= info.height) continue;
          const next = nextY * info.width + nextX;
          if (!visited[next] && data[next * 4 + 3] >= 8) {
            visited[next] = 1;
            queue.push(next);
          }
        }
      }
    }
    components.push({ pixels, left: minX, top: minY, width: maxX - minX + 1, height: maxY - minY + 1 });
  }
  const selected = components.sort((a, b) => b.pixels.length - a.pixels.length).slice(0, expectedCount);
  const frames = selected.sort((a, b) => expectedRows === 1
    ? a.left - b.left
    : Math.round(a.top / (info.height / expectedRows)) - Math.round(b.top / (info.height / expectedRows)) || a.left - b.left);
  if (frames.length !== expectedCount) throw new Error(`Attesi ${expectedCount} componenti, trovati ${frames.length}`);
  for (const frame of frames) {
    const isolated = Buffer.alloc(frame.width * frame.height * 4);
    const selectedPixels = new Set(frame.pixels);
    for (let y = frame.top; y < frame.top + frame.height; y += 1) {
      for (let x = frame.left; x < frame.left + frame.width; x += 1) {
        const index = y * info.width + x;
        const alpha = data[index * 4 + 3];
        if (alpha < 8) continue;
        let belongsToFrame = selectedPixels.has(index);
        if (!belongsToFrame && alpha >= 192) {
          for (let dy = -1; dy <= 1 && !belongsToFrame; dy += 1) {
            for (let dx = -1; dx <= 1; dx += 1) {
              if (selectedPixels.has((y + dy) * info.width + x + dx)) {
                belongsToFrame = true;
                break;
              }
            }
          }
        }
        if (!belongsToFrame) continue;
        const target = ((y - frame.top) * frame.width + x - frame.left) * 4;
        source.copy(isolated, target, index * 4, index * 4 + 4);
      }
    }
    frame.input = isolated;
  }
  return { metadata: info, bounds: frames };
}

function frameLayout(athlete, view, state, width, height) {
  const count = state === "run" ? 8 : 4;
  const columns = athlete === "colosso" && view === "front" && state === "run" ? 4 : count;
  const rows = count / columns;
  return Array.from({ length: count }, (_, index) => {
    const column = index % columns;
    const row = Math.floor(index / columns);
    const left = Math.round(column * width / columns);
    const right = Math.round((column + 1) * width / columns);
    const top = Math.round(row * height / rows);
    const bottom = Math.round((row + 1) * height / rows);
    return { left, top, width: right - left, height: bottom - top };
  });
}

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

async function resizePremultiplied(image, sourceWidth, sourceHeight, width, height) {
  const { data, info } = await image.ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let offset = 0; offset < data.length; offset += 4) {
    const sourceAlpha = data[offset + 3];
    const normalizedAlpha = sourceAlpha < ALPHA_FLOOR ? 0 : 255;
    data[offset + 3] = normalizedAlpha;
    const alpha = normalizedAlpha / 255;
    data[offset] = Math.round(data[offset] * alpha);
    data[offset + 1] = Math.round(data[offset + 1] * alpha);
    data[offset + 2] = Math.round(data[offset + 2] * alpha);
  }
  const resized = await sharp(data, { raw: { width: info.width ?? sourceWidth, height: info.height ?? sourceHeight, channels: 4 } })
    .resize(width, height, { kernel: sharp.kernel.lanczos3 })
    .raw()
    .toBuffer();
  for (let offset = 0; offset < resized.length; offset += 4) {
    const alpha = resized[offset + 3];
    if (alpha < 4) {
      resized[offset] = 0; resized[offset + 1] = 0; resized[offset + 2] = 0;
      resized[offset + 3] = 0;
      continue;
    }
    resized[offset] = Math.min(255, Math.round(resized[offset] * 255 / alpha));
    resized[offset + 1] = Math.min(255, Math.round(resized[offset + 1] * 255 / alpha));
    resized[offset + 2] = Math.min(255, Math.round(resized[offset + 2] * 255 / alpha));
  }
  return sharp(resized, { raw: { width, height, channels: 4 } }).png().toBuffer();
}

async function inspectSheet(file, athlete, view, state) {
  const image = sharp(file);
  const metadata = await image.metadata();
  if ((athlete === "oracolo" || athlete === "colosso") && state === "run") {
    const connected = await connectedFrames(image, 8, athlete === "colosso" && view === "front" ? 2 : 1);
    return { image, metadata, layout: null, bounds: connected.bounds, connected: true };
  }
  const layout = frameLayout(athlete, view, state, metadata.width, metadata.height);
  const bounds = await Promise.all(layout.map((frame) => frameBounds(image, frame.left, frame.top, frame.width, frame.height)));
  return { image, metadata, layout, bounds };
}

async function standardize(athlete, reference, view, state) {
  const source = await inspectSheet(masterPath(athlete, view, state), athlete, view, state);
  const model = await inspectSheet(activeReferencePath(reference, view, state), reference, view, state);
  const count = state === "run" ? 8 : 4;
  const activeReference = await sharp(activeReferencePath(reference, view, state)).metadata();
  const activeWidth = activeReference.width;
  const activeHeight = activeReference.height;
  const cellWidth = activeWidth / count;

  const layers = [];
  const frameScales = [];
  for (let index = 0; index < source.bounds.length; index += 1) {
    const box = source.bounds[index];
    const modelBox = model.bounds[index];
    // Ogni posa eredita l'occupazione del corrispondente frame standard.
    // Una scala unica per tutto il foglio faceva risultare piccole le pose
    // raccolte quando un altro frame era molto più alto o largo.
    const scale = Math.min(
      modelBox.height / box.height,
      // Racchetta e capelli possono oltrepassare la cella senza cambiare la
      // scala del corpo: il canvas li ritaglia come nei fogli standard.
      (cellWidth * 1.7) / box.width,
      (activeHeight * 0.98) / box.height,
    );
    frameScales.push(scale);
    const width = Math.min(Math.round(cellWidth * 1.7), Math.max(1, Math.round(box.width * scale)));
    const height = Math.min(activeHeight, Math.max(1, Math.round(box.height * scale)));
    const frameImage = source.connected
      ? sharp(box.input, { raw: { width: box.width, height: box.height, channels: 4 } })
      : source.image.clone().extract(box);
    // Il resize deve avvenire in alpha premoltiplicato: alcuni master conservano
    // RGB nei pixel trasparenti e senza questo passaggio generano rettangoli colorati.
    const input = await resizePremultiplied(frameImage, box.width, box.height, width, height);
    layers.push({
      input,
      left: Math.min(activeWidth - width, Math.max(0, Math.round(index * cellWidth + (cellWidth - width) / 2))),
      top: Math.min(
        activeHeight - height,
        Math.max(0, Math.round(activeHeight - (activeHeight - modelBox.top - modelBox.height) - height)),
      ),
    });
  }

  const normalizedMaster = sharp({
    create: {
      width: activeWidth,
      height: activeHeight,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  });
  for (const layer of layers) {
    const metadata = await sharp(layer.input).metadata();
    if (layer.left < 0 || layer.top < 0 || layer.left + metadata.width > activeWidth || layer.top + metadata.height > activeHeight) {
      throw new Error(`${athlete}/${view}/${state}: livello ${layer.left},${layer.top} ${metadata.width}x${metadata.height} fuori da ${activeWidth}x${activeHeight}`);
    }
  }
  const masterBuffer = await normalizedMaster.composite(layers).png().toBuffer();
  const { data: masterData, info: masterInfo } = await sharp(masterBuffer).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let offset = 0; offset < masterData.length; offset += 4) {
    if (masterData[offset + 3] < 16) {
      masterData[offset] = 0; masterData[offset + 1] = 0; masterData[offset + 2] = 0; masterData[offset + 3] = 0;
    } else {
      masterData[offset + 3] = 255;
    }
  }
  await sharp(masterData, { raw: { width: masterInfo.width, height: masterInfo.height, channels: 4 } })
    .webp({ lossless: true })
    .toFile(outputPath(athlete, view, state));
  console.log(`${athlete}/${view}/${state}: ${activeWidth}x${activeHeight}, scale frame ${frameScales.map((scale) => scale.toFixed(2)).join("/")}`);
}

const athleteFilter = process.argv[2];
const stateFilter = process.argv[3];
for (const [athlete, contract] of Object.entries(CONTRACTS)) {
  if (athleteFilter && athlete !== athleteFilter) continue;
  for (const view of VIEWS) {
    for (const state of STATES) {
      if (stateFilter && state !== stateFilter) continue;
      await standardize(athlete, contract.reference, view, state);
    }
  }
}
