import fs from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const ROOT = process.cwd();
const SPRITES = path.join(ROOT, "assets/sprites");
const OUTPUT = path.join(ROOT, "assets/outfits");
const MASTER_ROOT = path.join(ROOT, "assets/_archivio/originali/outfits");

const athletes = {
  maestro: {
    id: "maestro",
    primary: (h, s) => h >= 175 && h <= 245 && s >= 0.28,
    accent: (h, s, v) => h >= 175 && h <= 215 && s >= 0.18 && v >= 0.62,
    concepts: "tmp/imagegen/outfits/maestro.png",
    signatureConcept: "tmp/imagegen/signature/maestro.png",
    signature: { primaryHue: 194, secondaryHue: 220, saturation: 0.92, value: 1.02 },
    mythicConcept: "tmp/imagegen/mythic/maestro.png",
    mythic: { primaryHue: 218, secondaryHue: 198, lowerHue: 42, saturation: 0.88, value: 0.78, sleeves: true, trousers: true, sleeveSaturation: 0.76, sleeveValue: 0.62, lowerSaturation: 0.08, lowerValue: 0.98 },
  },
  pantera: {
    id: "pantera",
    primary: (h, s) => (h >= 332 || h <= 8) && s >= 0.48,
    accent: (h, s, v) => (h >= 338 || h <= 12) && s >= 0.28 && v >= 0.68,
    concepts: "tmp/imagegen/outfits/pantera.png",
    signatureConcept: "tmp/imagegen/signature/pantera.png",
    signature: { primaryHue: 346, secondaryHue: 326, saturation: 0.94, value: 0.82 },
    mythicConcept: "tmp/imagegen/mythic/pantera.png",
    mythic: { primaryHue: 346, secondaryHue: 225, lowerHue: 225, saturation: 0.94, value: 0.76, shortSleeves: true, sleeveSaturation: 0.84, sleeveValue: 0.72 },
  },
  steamer: {
    id: "steamer",
    primary: (h, s) => h >= 12 && h <= 48 && s >= 0.72,
    accent: (h, s, v) => h >= 18 && h <= 48 && s >= 0.62 && v >= 0.72,
    secondary: (h, s) => h >= 198 && h <= 238 && s >= 0.35,
    concepts: "tmp/imagegen/outfits/steamer.png",
    signatureConcept: "tmp/imagegen/signature/steamer.png",
    signature: { primaryHue: 18, secondaryHue: 214, saturation: 0.72, value: 0.72 },
    mythicConcept: "tmp/imagegen/mythic/steamer.png",
    mythic: { primaryHue: 20, secondaryHue: 24, lowerHue: 25, saturation: 0.82, value: 0.62, trousers: true, lowerSaturation: 0.18, lowerValue: 0.3 },
  },
  fiamma: {
    id: "fiamma",
    primary: (h, s) => h >= 58 && h <= 105 && s >= 0.46,
    accent: (h, s, v) => h >= 55 && h <= 108 && s >= 0.36 && v >= 0.68,
    concepts: "tmp/imagegen/outfits/fiamma.png",
    signatureConcept: "tmp/imagegen/signature/fiamma.png",
    signature: { primaryHue: 174, secondaryHue: 79, saturation: 0.9, value: 0.78 },
    mythicConcept: "tmp/imagegen/mythic/fiamma.png",
    mythic: { primaryHue: 185, secondaryHue: 82, lowerHue: 24, saturation: 0.9, value: 0.7, sleeves: true, sleeveSaturation: 0.86, sleeveValue: 0.76 },
  },
  oracolo: {
    id: "oracolo",
    primary: (h, s) => h >= 245 && h <= 292 && s >= 0.28,
    accent: (h, s, v) => h >= 245 && h <= 305 && s >= 0.2 && v >= 0.45,
    source: {
      // Stesso linguaggio grafico dell'action sheet: la vecchia idle aveva
      // capelli bianchi e bagliori ciano che sul campo sembravano trasparenza.
      idle: "oracolo-idle-consistent-v2.webp",
      action: "oracolo-action-unique.webp",
      run: "oracolo-run-unique.webp",
    },
    signatureConcept: "tmp/imagegen/signature/oracolo.png",
    signature: { primaryHue: 262, secondaryHue: 193, saturation: 0.9, value: 0.8 },
    mythicConcept: "tmp/imagegen/mythic/oracolo.png",
    mythic: { primaryHue: 260, secondaryHue: 193, lowerHue: 260, saturation: 0.82, value: 0.36 },
  },
  colosso: {
    id: "colosso",
    primary: (h, s, v) => h >= 32 && h <= 62 && s >= 0.42 && v >= 0.35,
    accent: (h, s, v) => h >= 24 && h <= 62 && s >= 0.28 && v >= 0.55,
    source: {
      idle: "colosso-idle-unique.webp",
      action: "colosso-action-unique.webp",
      run: "colosso-run-unique.webp",
    },
    signatureConcept: "tmp/imagegen/signature/colosso.png",
    signature: { primaryHue: 29, secondaryHue: 18, saturation: 0.94, value: 0.7 },
    mythicConcept: "tmp/imagegen/mythic/colosso.png",
    mythic: { primaryHue: 45, secondaryHue: 126, lowerHue: 132, saturation: 0.58, value: 0.78, shortSleeves: true, sleeveSaturation: 0.1, sleeveValue: 0.92 },
  },
};

const variants = {
  circuit: { primaryHue: 218, secondaryHue: 190, saturation: 0.84, value: 0.98 },
  legend: { primaryHue: 42, secondaryHue: 36, saturation: 0.82, value: 0.96 },
  signature: {},
  mythic: {},
};

const sheets = [
  ["idle", (id) => `${id}.webp`],
  ["action", (id) => `${id}-action.webp`],
  ["run", (id) => `${id}-run-v3.webp`],
  ["back-idle", (id) => `back/${id}.webp`],
  ["back-action", (id) => `back/${id}-action.webp`],
  ["back-run", (id) => `back/${id}-run-v3.webp`],
];

function rgbToHsv(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  let h = 0;
  if (delta) {
    if (max === r) h = 60 * (((g - b) / delta) % 6);
    else if (max === g) h = 60 * ((b - r) / delta + 2);
    else h = 60 * ((r - g) / delta + 4);
  }
  if (h < 0) h += 360;
  return [h, max ? delta / max : 0, max];
}

function hsvToRgb(h, s, v) {
  const c = v * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = v - c;
  let rgb;
  if (h < 60) rgb = [c, x, 0];
  else if (h < 120) rgb = [x, c, 0];
  else if (h < 180) rgb = [0, c, x];
  else if (h < 240) rgb = [0, x, c];
  else if (h < 300) rgb = [x, 0, c];
  else rgb = [c, 0, x];
  return rgb.map((channel) => Math.round((channel + m) * 255));
}

function recolorPixel(r, g, b, athlete, variant, normalizedY) {
  const [h, s, v] = rgbToHsv(r, g, b);
  const isAccent = athlete.accent(h, s, v);
  const isPrimary = athlete.primary(h, s, v);
  const isSecondary = athlete.secondary?.(h, s, v) ?? false;
  if (variant !== "mythic" && !isPrimary && !isSecondary) return [r, g, b];

  if (variant === "circuit") {
    const targetHue = isSecondary ? variants.circuit.secondaryHue : variants.circuit.primaryHue;
    const targetSaturation = Math.min(0.96, Math.max(0.48, s * variants.circuit.saturation));
    const targetValue = Math.min(1, v * (isAccent ? 1.06 : variants.circuit.value));
    return hsvToRgb(targetHue, targetSaturation, targetValue);
  }

  if (variant === "signature") {
    const palette = athlete.signature;
    const targetHue = isSecondary ? palette.secondaryHue : palette.primaryHue;
    const targetSaturation = Math.min(0.98, Math.max(0.5, s * palette.saturation));
    const targetValue = Math.min(1, v * (isAccent ? Math.min(1.16, palette.value + 0.24) : palette.value));
    return hsvToRgb(targetHue, targetSaturation, targetValue);
  }

  if (variant === "mythic") {
    const palette = athlete.mythic;
    // Le racchette sono parte dell'identita' dell'atleta, non del completo.
    // Il giallo saturo dei quattro campioni non deve essere intercettato dalle
    // palette mitiche; Oracolo e Colosso hanno racchette gia' fuori palette.
    const isYellowRacket = h >= 42 && h <= 68 && s >= 0.72 && v >= 0.48;
    if (isYellowRacket) return [r, g, b];
    const isSkin = (h <= 52 || h >= 350) && s >= 0.12 && v >= 0.12;
    const longSleeveZone = palette.sleeves && normalizedY >= 0.24 && normalizedY <= 0.56;
    const shortSleeveZone = palette.shortSleeves && normalizedY >= 0.25 && normalizedY <= 0.4;
    const trouserZone = palette.trousers && normalizedY >= 0.5 && normalizedY <= 0.88;
    if (isSkin && (longSleeveZone || shortSleeveZone || trouserZone)) {
      const hue = trouserZone ? palette.lowerHue : palette.primaryHue;
      const targetSaturation = trouserZone ? palette.lowerSaturation : palette.sleeveSaturation;
      const targetValue = trouserZone ? palette.lowerValue : palette.sleeveValue;
      return hsvToRgb(hue, targetSaturation, Math.max(0.18, Math.min(1, v * targetValue)));
    }
    // Pantera: la fascia bassa della vecchia canotta diventa pelle, rendendo
    // leggibile la nuova crop T-shirt anche nello sprite piccolo.
    if (athlete.id === "pantera" && isPrimary && normalizedY >= 0.41 && normalizedY <= 0.49) {
      return hsvToRgb(24, Math.min(0.58, s), Math.min(1, v * 1.08));
    }
    // Colosso: la corazza scura del torso diventa tessuto crema. Le parti in
    // ottone restano accessori e il completo non sembra piu' l'armatura base.
    if (athlete.id === "colosso" && !isSkin && normalizedY >= 0.2 && normalizedY <= 0.52 && v < 0.74) {
      return hsvToRgb(42, 0.12, Math.max(0.72, v * 1.7));
    }
    if (!isPrimary && !isSecondary) return [r, g, b];
    const hue = isSecondary ? palette.secondaryHue : palette.primaryHue;
    const value = Math.min(1, v * (isAccent ? Math.min(1.18, palette.value + 0.28) : palette.value));
    return hsvToRgb(hue, Math.min(0.96, Math.max(0.42, s * palette.saturation)), value);
  }

  if (isSecondary) return hsvToRgb(32, Math.min(0.22, s), Math.max(0.12, v * 0.48));
  if (isAccent) return hsvToRgb(45, 0.16, Math.min(1, v * 1.08));
  return hsvToRgb(variants.legend.primaryHue, Math.min(0.92, Math.max(0.52, s * variants.legend.saturation)), Math.min(1, v * variants.legend.value));
}

async function createSheet(athleteId, athlete, variant, sheetName, sourceRelative) {
  const source = path.join(SPRITES, sourceRelative);
  const image = sharp(source).ensureAlpha();
  const { data, info } = await image.raw().toBuffer({ resolveWithObject: true });
  const frameCount = sheetName.includes("run") ? 8 : 4;
  const frameWidth = Math.floor(info.width / frameCount);
  const frameBounds = Array.from({ length: frameCount }, () => ({ top: info.height, bottom: 0 }));
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 8) continue;
    const pixel = i / 4;
    const x = pixel % info.width;
    const y = Math.floor(pixel / info.width);
    const frame = Math.min(frameCount - 1, Math.floor(x / frameWidth));
    frameBounds[frame].top = Math.min(frameBounds[frame].top, y);
    frameBounds[frame].bottom = Math.max(frameBounds[frame].bottom, y);
  }
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 8) continue;
    const pixel = i / 4;
    const x = pixel % info.width;
    const pixelY = Math.floor(pixel / info.width);
    const frame = Math.min(frameCount - 1, Math.floor(x / frameWidth));
    const bounds = frameBounds[frame];
    const normalizedY = (pixelY - bounds.top) / Math.max(1, bounds.bottom - bounds.top);
    const [r, g, b] = recolorPixel(data[i], data[i + 1], data[i + 2], athlete, variant, normalizedY);
    data[i] = r; data[i + 1] = g; data[i + 2] = b;
  }
  const outDir = path.join(OUTPUT, athleteId, variant);
  await fs.mkdir(outDir, { recursive: true });
  const targetWidth = Math.max(frameCount, Math.round((info.width * 0.6) / frameCount) * frameCount);
  // Gli sprite base sono gia' ritagli puliti. Il resize diretto di RGBA pero'
  // interpola anche il colore nascosto nei pixel trasparenti: sui master degli
  // sbloccabili creava rettangoli colorati e bordi quasi invisibili. Prima
  // azzeriamo davvero il fondo, poi ridimensioniamo RGB e alpha separatamente.
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 24) {
      data[i] = 0; data[i + 1] = 0; data[i + 2] = 0; data[i + 3] = 0;
    } else {
      data[i + 3] = 255;
    }
  }
  // WebP conserva RGB anche sotto alpha zero. Impostarlo a zero *prima* della
  // codifica non basta: il codec lossless puo' ricostruire quei canali. Una
  // maschera alpha separata, riapplicata dopo il resize, impedisce al colore di
  // contaminare il bordo e rende trasparente qualunque residuo del master.
  const targetHeight = Math.round(info.height * targetWidth / info.width);
  const alpha = Buffer.alloc(info.width * info.height);
  const rgb = Buffer.alloc(info.width * info.height * 3);
  for (let pixel = 0; pixel < alpha.length; pixel += 1) {
    alpha[pixel] = data[pixel * 4 + 3];
    rgb[pixel * 3] = data[pixel * 4];
    rgb[pixel * 3 + 1] = data[pixel * 4 + 1];
    rgb[pixel * 3 + 2] = data[pixel * 4 + 2];
  }
  const resizedColor = await sharp(rgb, { raw: { width: info.width, height: info.height, channels: 3 } })
    .resize({ width: targetWidth, height: targetHeight, kernel: sharp.kernel.nearest })
    .raw()
    .toBuffer();
  const resizedAlpha = await sharp(alpha, { raw: { width: info.width, height: info.height, channels: 1 } })
    .resize({ width: targetWidth, height: targetHeight, kernel: sharp.kernel.nearest })
    .extractChannel(0)
    .raw()
    .toBuffer();
  const targetName = athleteId === "oracolo" && (sheetName === "idle" || sheetName === "back-idle")
    ? `${sheetName}-v2.webp`
    : `${sheetName}.webp`;
  await sharp(resizedColor, { raw: { width: targetWidth, height: targetHeight, channels: 3 } })
    .joinChannel(resizedAlpha, { raw: { width: targetWidth, height: targetHeight, channels: 1 } })
    .webp({ lossless: true, effort: 6 })
    .toFile(path.join(outDir, targetName));
}

// Le anteprime vengono mostrate come card grandi, con lo stesso stile di quelle
// degli atleti: devono avere la loro stessa forma e la loro stessa nitidezza.
// A 240 px si vedevano sfocate, e i concept hanno orientamenti diversi (quello
// del Maestro e' verticale, gli altri orizzontali) quindi i mezzi pannelli
// uscivano con proporzioni incompatibili fra loro.
const PREVIEW_WIDTH = 560;
// 3/4 e' l'aspect-ratio di .athlete-card__art: generando gia' con quella forma
// il `background-size: cover` della card non ritaglia nulla.
const PREVIEW_RATIO = 0.75;
const PREVIEW_HEIGHT = Math.round(PREVIEW_WIDTH / PREVIEW_RATIO);

/**
 * Un pannello molto piu' stretto del 3/4 della card non si puo' ritagliare a
 * `cover` senza perdere meta' figura: il concept del Maestro e' verticale, e la
 * sua meta' e' 543x1448 contro un bersaglio di 0,75, quindi il ritaglio dall'alto
 * lasciava testa e busto e tagliava via le gambe. In quel caso la figura ci
 * entra intera e lo sfondo viene esteso col colore del concept stesso.
 */
function previewPipeline(pipeline) {
  return pipeline
    .resize({ width: PREVIEW_WIDTH, height: PREVIEW_HEIGHT, fit: "cover", position: "top" })
    .webp({ quality: 82, effort: 6 });
}

/** Luminosita' media di una colonna del pannello. */
async function lumaColonna(sorgente, left, width, height) {
  const { channels } = await sharp(sorgente)
    .extract({ left, top: 0, width, height })
    .stats();
  return channels.slice(0, 3).reduce((somma, c) => somma + c.mean, 0) / 3;
}

/**
 * Anteprima di un pannello troppo stretto per il 3/4 della card.
 *
 * Il concept del Maestro e' verticale: ogni meta' e' 543x1448, rapporto 0,375
 * contro lo 0,75 della card. Ritagliarla a `cover` significava buttare via
 * meta' altezza, e restavano testa e busto senza gambe.
 *
 * Qui la figura ci entra intera e lo spazio ai lati viene riempito estendendo
 * le colonne di bordo del pannello. Due strade piu' ovvie non funzionano: un
 * colore piatto lascia due barre nette su un fondo che e' un gradiente, e il
 * pannello sfocato usato come sfondo contiene la figura spalmata, quindi risulta
 * piu' chiaro del fondo dentro il riquadro e disegna una cornice (misurati 38
 * livelli di stacco contro i 10 di variazione naturale). Le colonne di bordo
 * sono invece fondo puro alla stessa altezza: si raccordano senza stacco.
 */
async function narrowPanelPreview(panel) {
  const sorgente = await panel().toBuffer();
  const { width: panelW, height: panelH } = await sharp(sorgente).metadata();

  const figura = await sharp(sorgente)
    .resize({ width: PREVIEW_WIDTH, height: PREVIEW_HEIGHT, fit: "inside" })
    .toBuffer();
  const { width: figuraW } = await sharp(figura).metadata();
  const sinistraW = Math.floor((PREVIEW_WIDTH - figuraW) / 2);
  const destraW = PREVIEW_WIDTH - figuraW - sinistraW;

  const striscia = Math.max(2, Math.round(panelW * 0.015));
  // La sfocatura leggera serve solo a non trasformare in bande orizzontali il
  // rumore della singola colonna, una volta stirata su tutta la larghezza.
  const bordo = (left, width) => sharp(sorgente)
    .extract({ left, top: 0, width: striscia, height: panelH })
    .resize({ width: Math.max(1, width), height: PREVIEW_HEIGHT, fit: "fill" })
    .blur(3)
    .toBuffer();

  // Le due meta' del concept si toccano e il bagliore della figura accanto
  // sborda oltre la cucitura: la colonna interna, stirata in orizzontale,
  // diventava una strisciolina colorata. Si sceglie quindi la colonna piu'
  // pulita fra le due e la si usa per entrambi i lati. "Piu' pulita" e' la piu'
  // scura: su un fondo notturno la contaminazione e' sempre luce in piu'.
  const [chiaraSinistra, chiaraDestra] = await Promise.all([
    lumaColonna(sorgente, 0, striscia, panelH),
    lumaColonna(sorgente, panelW - striscia, striscia, panelH),
  ]);
  const pulita = chiaraSinistra <= chiaraDestra ? 0 : panelW - striscia;
  const [sinistra, destra] = await Promise.all([
    bordo(pulita, sinistraW),
    bordo(pulita, destraW),
  ]);

  return sharp({
    create: {
      width: PREVIEW_WIDTH, height: PREVIEW_HEIGHT, channels: 3,
      background: { r: 0, g: 0, b: 0 },
    },
  })
    .composite([
      { input: sinistra, left: 0, top: 0 },
      { input: destra, left: sinistraW + figuraW, top: 0 },
      { input: figura, left: sinistraW, top: 0 },
    ])
    .webp({ quality: 82, effort: 6 });
}

async function createPreviews(athleteId, athlete) {
  const dir = path.join(OUTPUT, athleteId);
  const masterDir = path.join(MASTER_ROOT, athleteId);
  await fs.mkdir(dir, { recursive: true });
  await fs.mkdir(masterDir, { recursive: true });
  const tasks = [];
  if (athlete.concepts) {
    const source = path.join(ROOT, athlete.concepts);
    const meta = await sharp(source).metadata();
    const half = Math.floor(meta.width / 2);
    const panel = async (left, width, file) => {
      const estrai = () => sharp(source).extract({ left, top: 0, width, height: meta.height });
      // Quanto del pannello sacrificherebbe il ritaglio a `cover`. Sotto un
      // quarto la figura sopravvive e il ritaglio resta la resa migliore, perche'
      // riempie il riquadro; oltre, sparirebbero le gambe. I concept normali
      // perdono l'11-17%, quello verticale del Maestro il 50%.
      const perditaRitaglio = 1 - (width / meta.height) / PREVIEW_RATIO;
      const stretto = perditaRitaglio > 0.25;
      const immagine = stretto
        ? await narrowPanelPreview(estrai)
        : previewPipeline(estrai());
      await immagine.toFile(path.join(dir, file));
    };
    tasks.push(
      fs.copyFile(source, path.join(masterDir, "concept-master.png")),
      panel(0, half, "circuit-preview.webp"),
      panel(half, meta.width - half, "legend-preview.webp"),
    );
  }
  const signatureSource = path.join(ROOT, athlete.signatureConcept);
  const mythicSource = path.join(ROOT, athlete.mythicConcept);
  tasks.push(
    fs.copyFile(signatureSource, path.join(masterDir, "signature-master.png")),
    previewPipeline(sharp(signatureSource)).toFile(path.join(dir, "signature-preview.webp")),
    fs.copyFile(mythicSource, path.join(masterDir, "mythic-master.png")),
    previewPipeline(sharp(mythicSource)).toFile(path.join(dir, "mythic-preview.webp")),
  );
  await Promise.all(tasks);
}

const athleteFilter = process.argv[2];
const sheetFilter = process.argv[3];
for (const [athleteId, athlete] of Object.entries(athletes)) {
  if (athleteFilter && athleteId !== athleteFilter) continue;
  if (!sheetFilter) await createPreviews(athleteId, athlete);
  const athleteVariants = athlete.concepts ? Object.keys(variants) : ["signature", "mythic"];
  for (const variant of athleteVariants) {
    for (const [sheetName, sourceName] of sheets) {
      if (sheetFilter && sheetName !== sheetFilter) continue;
      const side = sheetName.startsWith("back-") ? "back/" : "";
      const sourceKey = sheetName.replace("back-", "");
      const sourceRelative = athlete.source ? `${side}${athlete.source[sourceKey]}` : sourceName(athleteId);
      await createSheet(athleteId, athlete, variant, sheetName, sourceRelative);
    }
  }
}

const sheetCount = Object.values(athletes).reduce((total, athlete) => total + (athlete.concepts ? 4 : 2) * sheets.length, 0);
console.log(`Generated outfit previews and ${sheetCount} dedicated sprite sheets in assets/outfits.`);
