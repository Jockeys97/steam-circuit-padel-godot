import { BALANCE, COURT } from "./data.js?v=20260814-feedback-confirm-v39";
import { t } from "./i18n.js?v=20260814-feedback-confirm-v39";

export function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

const SERV_LINE = 126;
const radialTextureCache = new Map();
const arenaArtworkCache = new Map();

function lazyArenaArtwork(path) {
  if (!path || typeof Image === "undefined") return null;
  if (arenaArtworkCache.has(path)) return arenaArtworkCache.get(path);
  const artwork = new Image();
  artwork.decoding = "async";
  artwork.src = path;
  arenaArtworkCache.set(path, artwork);
  return artwork;
}

function getRadialTexture(tint) {
  if (radialTextureCache.has(tint)) return radialTextureCache.get(tint);
  const size = 96;
  let surface = null;
  if (typeof OffscreenCanvas !== "undefined") {
    surface = new OffscreenCanvas(size, size);
  } else if (typeof document !== "undefined") {
    surface = document.createElement("canvas");
    surface.width = size;
    surface.height = size;
  }
  if (!surface) return null;
  const textureCtx = surface.getContext("2d");
  if (!textureCtx) return null;
  const center = size / 2;
  const gradient = textureCtx.createRadialGradient(center, center, 0, center, center, center);
  gradient.addColorStop(0, `rgba(${tint},1)`);
  gradient.addColorStop(0.55, `rgba(${tint},0.42)`);
  gradient.addColorStop(1, `rgba(${tint},0)`);
  textureCtx.fillStyle = gradient;
  textureCtx.fillRect(0, 0, size, size);
  radialTextureCache.set(tint, surface);
  return surface;
}

function reflectRange(value, min, max) {
  let v = value;
  while (v < min || v > max) {
    if (v < min) v = min + (min - v);
    if (v > max) v = max - (v - max);
  }
  return v;
}

export function predictLanding(ball) {
  if (!ball || ball.vz >= 0) return null;
  const g = BALANCE.ballGravity;
  const disc = ball.vz * ball.vz + 2 * g * Math.max(0, ball.z);
  if (!(disc > 0)) return null;
  const t = (ball.vz + Math.sqrt(disc)) / g;
  if (t < 0.06 || t > 2.4) return null;
  const drag = Math.pow(BALANCE.airDrag, t * 60);
  const x = reflectRange(ball.x + ball.vx * drag * t, COURT.left + 12, COURT.right - 12);
  const y = reflectRange(ball.y + ball.vy * drag * t, COURT.top + 12, COURT.bottom - 12);
  return { x, y, t };
}

export function roundedRect(ctx, x, y, width, height, radius) {
  const safeRadius = Math.min(radius, width / 2, height / 2);
  ctx.beginPath();
  ctx.moveTo(x + safeRadius, y);
  ctx.lineTo(x + width - safeRadius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + safeRadius);
  ctx.lineTo(x + width, y + height - safeRadius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - safeRadius, y + height);
  ctx.lineTo(x + safeRadius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + safeRadius);
  ctx.lineTo(x, y + safeRadius);
  ctx.quadraticCurveTo(x, y, x + safeRadius, y);
  ctx.closePath();
}

function drawGear(ctx, x, y, radius, teeth, color, rotation = 0) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.fillStyle = color;
  ctx.strokeStyle = "rgba(0,0,0,0.35)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  for (let i = 0; i < teeth * 2; i += 1) {
    const angle = (Math.PI * i) / teeth;
    const r = i % 2 === 0 ? radius : radius * 0.72;
    const px = Math.cos(angle) * r;
    const py = Math.sin(angle) * r;
    if (i === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.beginPath();
  ctx.arc(0, 0, radius * 0.28, 0, Math.PI * 2);
  ctx.fillStyle = "rgba(0,0,0,0.25)";
  ctx.fill();
  ctx.restore();
}

function drawSteamPuff(ctx, x, y, size, alpha) {
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = "rgba(200,220,230,0.5)";
  ctx.beginPath();
  ctx.arc(x, y, size, 0, Math.PI * 2);
  ctx.arc(x + size * 0.8, y - size * 0.4, size * 0.7, 0, Math.PI * 2);
  ctx.arc(x - size * 0.6, y - size * 0.2, size * 0.55, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawCloud(ctx, x, y, scale = 1) {
  ctx.save();
  ctx.fillStyle = "rgba(255,255,255,0.86)";
  ctx.beginPath();
  ctx.arc(x, y, 20 * scale, 0, Math.PI * 2);
  ctx.arc(x + 23 * scale, y - 10 * scale, 27 * scale, 0, Math.PI * 2);
  ctx.arc(x + 52 * scale, y, 20 * scale, 0, Math.PI * 2);
  ctx.arc(x + 73 * scale, y + 7 * scale, 14 * scale, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawTree(ctx, x, y, scale, hue) {
  ctx.save();
  ctx.fillStyle = "#7e4b31";
  ctx.fillRect(x - 6 * scale, y, 12 * scale, 55 * scale);
  ctx.fillStyle = hue;
  [[-18, 3, 24], [10, -9, 28], [30, 12, 22], [-5, -22, 27]].forEach(([dx, dy, r]) => {
    ctx.beginPath();
    ctx.arc(x + dx * scale, y + dy * scale, r * scale, 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.fillStyle = "rgba(255,255,255,0.2)";
  ctx.beginPath();
  ctx.arc(x - 9 * scale, y - 9 * scale, 10 * scale, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawSpectators(ctx, x, y, width, rows) {
  const colors = ["#ffcf46", "#ff6d70", "#5ee9ff", "#8de06a", "#ffffff"];
  ctx.save();
  for (let row = 0; row < rows; row += 1) {
    const step = 19 - row * 2;
    for (let px = x + 8 + row * 5; px < x + width - 8; px += step) {
      const bob = Math.sin(px * 0.19 + row) * 2;
      ctx.fillStyle = colors[(Math.floor(px / step) + row * 2) % colors.length];
      ctx.beginPath();
      ctx.arc(px, y + row * 14 + bob, 4.5 - row * 0.45, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(29,62,92,0.58)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(px - 4, y + row * 14 + 7 + bob);
      ctx.lineTo(px - 6, y + row * 14 + 13 + bob);
      ctx.moveTo(px + 4, y + row * 14 + 7 + bob);
      ctx.lineTo(px + 7, y + row * 14 + 12 + bob);
      ctx.stroke();
    }
  }
  ctx.restore();
}

function drawFloodlight(ctx, x, y, flip = 1) {
  ctx.save();
  ctx.strokeStyle = "#35536e";
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(x, y + 122);
  ctx.lineTo(x + flip * 15, y + 20);
  ctx.stroke();
  ctx.fillStyle = "#233e5c";
  roundedRect(ctx, x + flip * 2 - 18, y, 36, 20, 3);
  ctx.fill();
  ctx.fillStyle = "#fff5b0";
  for (let i = 0; i < 3; i += 1) {
    ctx.fillRect(x + flip * 2 - 13 + i * 9, y + 5, 6, 9);
  }
  ctx.restore();
}

function drawLocomotiveDepotBackdrop(ctx, canvas, time) {
  const sky = ctx.createLinearGradient(0, 0, 0, canvas.height);
  sky.addColorStop(0, "#071526");
  sky.addColorStop(0.46, "#1b4d5d");
  sky.addColorStop(0.47, "#5c5b50");
  sky.addColorStop(1, "#37444d");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.strokeStyle = "#172c3d";
  ctx.lineWidth = 12;
  for (let x = -42; x < canvas.width + 48; x += 132) {
    ctx.beginPath();
    ctx.moveTo(x, 0); ctx.lineTo(x + 62, 265); ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x + 92, 0); ctx.lineTo(x + 35, 265); ctx.stroke();
  }
  ctx.strokeStyle = "rgba(120,201,218,0.25)";
  ctx.lineWidth = 4;
  for (let y = 34; y < 180; y += 48) {
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke();
  }

  // Locomotiva dietro il vetro: rimane ambientazione, non invade il piano di gioco.
  ctx.fillStyle = "#123f46";
  roundedRect(ctx, 321, 58, 318, 38, 8); ctx.fill();
  ctx.fillStyle = "#1c6870";
  roundedRect(ctx, 407, 27, 108, 44, 6); ctx.fill();
  ctx.fillStyle = "#0e2831";
  roundedRect(ctx, 529, 35, 98, 43, 18); ctx.fill();
  ctx.fillStyle = "#d3a44c";
  roundedRect(ctx, 618, 40, 14, 31, 3); ctx.fill();
  ctx.fillStyle = "#17313b";
  roundedRect(ctx, 387, 8, 24, 62, 4); ctx.fill();
  ctx.fillStyle = "rgba(234,245,245,0.72)";
  roundedRect(ctx, 425, 36, 46, 19, 2); ctx.fill();
  [366, 435, 504, 573].forEach((x) => {
    ctx.fillStyle = "#091820";
    ctx.beginPath(); ctx.arc(x, 96, 18, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = "#c99942"; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.arc(x, 96, 11, 0, Math.PI * 2); ctx.stroke();
  });
  drawSteamPuff(ctx, 400, 18 + Math.sin(time * 1.5) * 5, 20, 0.35);
  drawSteamPuff(ctx, 425, 7 + Math.sin(time * 1.3) * 7, 15, 0.22);

  ctx.strokeStyle = "#1c2732";
  ctx.lineWidth = 8;
  [-1, 1].forEach((side) => {
    ctx.beginPath(); ctx.moveTo(480 + side * 70, 250); ctx.lineTo(480 + side * 420, canvas.height); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(480 + side * 95, 250); ctx.lineTo(480 + side * 455, canvas.height); ctx.stroke();
  });
  [102, 858].forEach((x) => {
    ctx.fillStyle = "#132638";
    roundedRect(ctx, x - 7, 131, 14, 84, 3); ctx.fill();
    ctx.fillStyle = "#f4bd48";
    ctx.beginPath(); ctx.arc(x, 126, 12, 0, Math.PI * 2); ctx.fill();
  });
}

function drawClockworkFactoryBackdrop(ctx, canvas, time) {
  const sky = ctx.createLinearGradient(0, 0, 0, canvas.height);
  sky.addColorStop(0, "#160f31");
  sky.addColorStop(0.45, "#3b2048");
  sky.addColorStop(0.46, "#7b465b");
  sky.addColorStop(1, "#33214b");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.strokeStyle = "#261d36";
  ctx.lineWidth = 18;
  for (let x = 48; x < canvas.width; x += 148) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x - 38, 276); ctx.stroke();
  }
  ctx.strokeStyle = "rgba(236,170,67,0.45)";
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.arc(480, 135, 137, Math.PI, 0); ctx.stroke();

  ctx.fillStyle = "#d4a64c";
  ctx.beginPath(); ctx.arc(480, 121, 72, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = "#f5d98b";
  ctx.beginPath(); ctx.arc(480, 121, 58, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = "#472d39";
  ctx.lineWidth = 4;
  for (let angle = 0; angle < Math.PI * 2; angle += Math.PI / 6) {
    ctx.beginPath();
    ctx.moveTo(480 + Math.cos(angle) * 48, 121 + Math.sin(angle) * 48);
    ctx.lineTo(480 + Math.cos(angle) * 57, 121 + Math.sin(angle) * 57);
    ctx.stroke();
  }
  ctx.lineWidth = 6;
  ctx.beginPath(); ctx.moveTo(480, 121); ctx.lineTo(480 + Math.cos(time * 0.4) * 38, 121 + Math.sin(time * 0.4) * 38); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(480, 121); ctx.lineTo(480 + Math.cos(-time * 0.7) * 22, 121 + Math.sin(-time * 0.7) * 22); ctx.stroke();

  drawGear(ctx, 256, 166, 47, 11, "#c68737", time * 0.25);
  drawGear(ctx, 691, 177, 53, 12, "#c68737", -time * 0.21);
  drawGear(ctx, 150, 250, 36, 10, "#b52b65", -time * 0.31);
  drawGear(ctx, 812, 244, 36, 10, "#b52b65", time * 0.31);
  ctx.strokeStyle = "#d2a24a";
  ctx.lineWidth = 7;
  ctx.beginPath(); ctx.moveTo(480, 193); ctx.lineTo(480, 252); ctx.stroke();
  ctx.fillStyle = "#d2a24a";
  ctx.beginPath(); ctx.arc(480 + Math.sin(time * 1.2) * 14, 267, 18, 0, Math.PI * 2); ctx.fill();
  [[95, 113], [860, 111], [194, 84], [764, 84]].forEach(([x, y]) => {
    ctx.fillStyle = "#ff4b9a";
    roundedRect(ctx, x - 8, y - 16, 16, 32, 4); ctx.fill();
    ctx.fillStyle = "rgba(255,221,246,0.72)";
    roundedRect(ctx, x - 4, y - 11, 8, 20, 2); ctx.fill();
  });
}

function steamLayerPuff(ctx, x, y, size, alpha, tint = "205,222,232") {
  const texture = getRadialTexture(tint);
  ctx.save();
  ctx.globalAlpha = alpha;
  if (texture) {
    ctx.drawImage(texture, x - size, y - size, size * 2, size * 2);
  } else {
    ctx.fillStyle = `rgba(${tint},${alpha})`;
    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawAmbientSteam(ctx, canvas, scene, time, accentTint) {
  const tint = accentTint ?? "205,222,232";
  const layers = [
    { rows: 4, yBase: 118, yAmp: 44, size: [34, 62], alpha: 0.055, drift: 5, speed: 0.14 },
    { rows: 5, yBase: 258, yAmp: 76, size: [52, 95], alpha: 0.038, drift: 9, speed: 0.09 },
    { rows: 4, yBase: 470, yAmp: 118, size: [90, 168], alpha: 0.026, drift: 16, speed: 0.06 },
  ];
  const span = canvas.width + 260;
  for (const layer of layers) {
    for (let i = 0; i < layer.rows; i += 1) {
      const phase = i * 1.31 + layer.speed * 13;
      const raw = i * 263.7 + Math.sin(time * layer.speed + phase) * 90 + time * layer.drift * 30;
      const x = ((raw % span) + span) % span - 130;
      const y = layer.yBase + Math.sin(time * 0.22 + phase) * layer.yAmp * 0.5 + i * 26;
      const size = layer.size[0] + (Math.sin(i * 2.9 + time) * 0.5 + 0.5) * (layer.size[1] - layer.size[0]);
      steamLayerPuff(ctx, x, y, size, layer.alpha, tint);
    }
  }
  // Braci luminose che salgono dagli ingranaggi (arena a orologeria).
  if (scene === "clockwork") {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    for (let i = 0; i < 6; i += 1) {
      const x = ((i * 151.7 + Math.sin(time * 0.5 + i * 2) * 70 + time * 22) % 960 + 960) % 960;
      const y = 150 + (i % 3) * 110 + Math.sin(time * 0.9 + i) * 30;
      const glow = 0.5 + 0.5 * Math.sin(time * (1.5 + i * 0.4) + i);
      ctx.globalAlpha = 0.05 + glow * 0.09;
      ctx.fillStyle = i % 2 ? "#ffd166" : "#ff8f5c";
      ctx.beginPath();
      ctx.arc(x, y, 2 + (i % 2), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
}

function drawCrowdBehind(ctx, time, scene) {
  // Pubblico animato dietro il vetro per le arene indoor.
  if (scene === "officina") return;
  const colors = ["#ffcf46", "#ff6d70", "#5ee9ff", "#8de06a", "#ffffff", "#ff9ad5"];
  ctx.save();
  for (let row = 0; row < 2; row += 1) {
    for (let x = 205; x < 755; x += 16) {
      const bob = Math.sin(time * 2.1 + x * 0.085 + row * 1.9) * 2.6;
      const color = colors[Math.floor(x / 16 + row * 3) % colors.length];
      ctx.globalAlpha = 0.7;
      ctx.fillStyle = "#0f2740";
      ctx.fillRect(x - 5, 46 + row * 15 + bob, 10, 11);
      ctx.globalAlpha = 0.9;
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(x, 42 + row * 15 + bob, 4, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();
}

function drawGlassSheen(ctx, time) {
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  const offset = Math.sin(time * 0.5) * 70;
  const sheen = ctx.createLinearGradient(240 + offset, 40, 470 + offset, 210);
  sheen.addColorStop(0, "rgba(255,255,255,0)");
  sheen.addColorStop(0.5, "rgba(255,255,255,0.1)");
  sheen.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = sheen;
  ctx.fillRect(170, 34, 630, 180);
  ctx.strokeStyle = "rgba(255,255,255,0.05)";
  ctx.lineWidth = 2;
  for (let i = 0; i < 3; i += 1) {
    const yy = 55 + i * 26 + Math.sin(time * 0.9 + i * 1.3) * 4;
    ctx.beginPath();
    ctx.moveTo(205 + (i % 2) * 30, yy);
    ctx.lineTo(752 - (i % 2) * 22, yy + 26);
    ctx.stroke();
  }
  for (const sx of [40, 848]) {
    const grad = ctx.createLinearGradient(sx, 160, sx + 34, 380);
    grad.addColorStop(0, "rgba(255,255,255,0)");
    grad.addColorStop(0.5, `rgba(255,255,255,${0.05 + 0.04 * Math.sin(time * 0.7 + sx)})`);
    grad.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = grad;
    ctx.fillRect(sx, 160, 34, 240);
  }
  ctx.restore();
}

function lightCone(ctx, sx, sy, tx, ty, halfWidth, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(sx, sy);
  ctx.lineTo(tx - halfWidth, ty);
  ctx.lineTo(tx + halfWidth, ty);
  ctx.closePath();
  ctx.fill();
}

function drawVolumetricLights(ctx, canvas, scene, time) {
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  const pulse = 0.7 + 0.3 * Math.sin(time * 1.4);
  if (scene === "officina") {
    lightCone(ctx, 196, 116, 190, 620, 34, `rgba(255,246,190,${0.045 * pulse})`);
    lightCone(ctx, 196, 116, 340, 480, 46, `rgba(255,246,190,${0.03 * pulse})`);
    lightCone(ctx, 764, 119, 770, 620, 34, `rgba(255,246,190,${0.045 * pulse})`);
    lightCone(ctx, 764, 119, 620, 480, 46, `rgba(255,246,190,${0.03 * pulse})`);
  } else {
    lightCone(ctx, 400, -10, 190, 560, 120, `rgba(190,235,255,${0.032 * pulse})`);
    lightCone(ctx, 560, -10, 770, 560, 120, `rgba(190,235,255,${0.032 * pulse})`);
    lightCone(ctx, 480, -10, 480, 420, 90, `rgba(255,235,190,${0.04 * pulse})`);
  }
  ctx.restore();
}

function drawCourtDepth(ctx, topLeft, topRight, bottomLeft, bottomRight) {
  const gloss = ctx.createLinearGradient(480, 100, 480, 700);
  gloss.addColorStop(0, "rgba(255,255,255,0.1)");
  gloss.addColorStop(0.35, "rgba(255,255,255,0.02)");
  gloss.addColorStop(1, "rgba(0,0,0,0.14)");
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(topLeft.x, topLeft.y);
  ctx.lineTo(topRight.x, topRight.y);
  ctx.lineTo(bottomRight.x, bottomRight.y);
  ctx.lineTo(bottomLeft.x, bottomLeft.y);
  ctx.closePath();
  ctx.clip();
  ctx.fillStyle = gloss;
  ctx.fillRect(0, 0, 960, 700);
  ctx.restore();
}

function drawArenaArtwork(ctx, canvas, imagePath, time) {
  const artwork = lazyArenaArtwork(imagePath);
  if (!artwork?.complete || !artwork.naturalWidth) return;
  const sourceRatio = artwork.naturalWidth / artwork.naturalHeight;
  const targetRatio = canvas.width / canvas.height;
  let sx = 0;
  let sy = 0;
  let sw = artwork.naturalWidth;
  let sh = artwork.naturalHeight;
  if (sourceRatio > targetRatio) {
    sw = artwork.naturalHeight * targetRatio;
    sx = (artwork.naturalWidth - sw) / 2 + Math.sin(time * 0.08) * 10;
  } else {
    sh = artwork.naturalWidth / targetRatio;
    sy = Math.max(0, (artwork.naturalHeight - sh) * 0.32);
  }
  ctx.save();
  ctx.globalAlpha = 0.82;
  ctx.filter = "saturate(1.2) contrast(1.08) brightness(0.82)";
  ctx.drawImage(artwork, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
  ctx.filter = "none";
  const veil = ctx.createLinearGradient(0, 0, 0, canvas.height);
  veil.addColorStop(0, "rgba(2,7,22,0.08)");
  veil.addColorStop(0.52, "rgba(2,7,22,0.2)");
  veil.addColorStop(1, "rgba(2,7,22,0.52)");
  ctx.fillStyle = veil;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.restore();
}

function clipArenaScenery(ctx) {
  // Positive safe zones only: the upper proscenium and the two wedges outside
  // the glass cage. Keeping the playable trapezoid out of the path avoids the
  // inconsistent inverse/even-odd clipping seen on some Canvas implementations.
  ctx.beginPath();
  ctx.rect(0, 0, 960, 96);
  ctx.moveTo(0, 96);
  ctx.lineTo(210, 96);
  ctx.lineTo(48, 700);
  ctx.lineTo(0, 700);
  ctx.closePath();
  ctx.moveTo(750, 96);
  ctx.lineTo(960, 96);
  ctx.lineTo(960, 700);
  ctx.lineTo(912, 700);
  ctx.closePath();
  ctx.clip();
}

function drawFantasyArenaBackdrop(ctx, canvas, scene, time, imagePath) {
  const themes = {
    tempesta: { top: "#07142f", bottom: "#287eb0", glow: "#79eeff" },
    abissale: { top: "#020b1d", bottom: "#086474", glow: "#42fff2" },
    caldera: { top: "#160b10", bottom: "#7b2817", glow: "#ff7138" },
    orrery: { top: "#080722", bottom: "#30246a", glow: "#b595ff" },
  };
  const theme = themes[scene];
  if (!theme) return false;
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, theme.top);
  gradient.addColorStop(1, theme.bottom);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  // La locandina entra in memoria soltanto quando quest'arena viene disegnata.
  // Il campo resta procedurale, ma ambiente, macchinari e profondita' sono gli
  // stessi promessi dalla card di selezione.
  drawArenaArtwork(ctx, canvas, imagePath, time);
  ctx.save();
  clipArenaScenery(ctx);
  ctx.globalCompositeOperation = "lighter";
  ctx.strokeStyle = theme.glow;
  ctx.fillStyle = theme.glow;
  if (scene === "tempesta") {
    ctx.globalAlpha = 0.42 + Math.sin(time * 3.7) * 0.08;
    for (const x of [170, 785]) {
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(x, 0); ctx.lineTo(x - 34, 48); ctx.lineTo(x + 8, 91); ctx.lineTo(x - 22, 145);
      ctx.stroke();
    }
  } else if (scene === "abissale") {
    ctx.globalAlpha = 0.16;
    for (let i = 0; i < 18; i += 1) {
      const x = (i * 157 + time * (8 + i % 4)) % canvas.width;
      const y = 20 + (i * 47) % 235;
      ctx.beginPath(); ctx.arc(x, y, 2 + (i % 4), 0, Math.PI * 2); ctx.fill();
    }
  } else if (scene === "caldera") {
    const lava = ctx.createLinearGradient(0, 190, 0, 355);
    lava.addColorStop(0, "rgba(255,90,30,0)");
    lava.addColorStop(1, "rgba(255,95,20,0.48)");
    ctx.globalAlpha = 0.9;
    ctx.fillStyle = lava;
    ctx.fillRect(0, 175, canvas.width, 190);
  } else {
    ctx.globalAlpha = 0.44;
    ctx.lineWidth = 5;
    for (const radius of [58, 104, 154]) {
      ctx.beginPath(); ctx.ellipse(480, 116, radius * 1.75, radius * 0.48, time * 0.018, 0, Math.PI * 2); ctx.stroke();
    }
    for (let i = 0; i < 34; i += 1) {
      ctx.globalAlpha = 0.12 + (i % 4) * 0.06;
      ctx.fillRect((i * 83) % canvas.width, (i * 37) % 230, 2, 2);
    }
  }
  ctx.restore();
  return true;
}

function drawFantasyArenaProps(ctx, scene, time) {
  if (!["tempesta", "abissale", "caldera", "orrery"].includes(scene)) return;
  ctx.save();
  // Gli oggetti ambientali vivono oltre la gabbia: nessuna orbita, tubatura o
  // statua deve attraversare la superficie di gioco e confondersi con la palla.
  clipArenaScenery(ctx);
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  if (scene === "tempesta") {
    // Scafi di due dirigibili, eliche e catene sospese oltre i vetri laterali.
    for (const side of [-1, 1]) {
      const x = side < 0 ? 72 : 888;
      const drift = Math.sin(time * 0.32 + side) * 4;
      ctx.fillStyle = "rgba(23,34,52,0.72)";
      ctx.strokeStyle = "#b47b35";
      ctx.lineWidth = 5;
      ctx.beginPath(); ctx.ellipse(x, 238 + drift, 105, 42, side * 0.12, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = "rgba(92,220,255,0.55)";
      for (let i = -1; i <= 1; i += 1) {
        ctx.beginPath(); ctx.arc(x + i * 37, 235 + drift, 7, 0, Math.PI * 2); ctx.fill();
      }
      drawGear(ctx, x - side * 18, 356, 42, 14, "#a96f2d", time * side * 0.7);
      ctx.strokeStyle = "rgba(205,151,72,0.75)";
      ctx.lineWidth = 4;
      for (let i = 0; i < 3; i += 1) {
        ctx.beginPath();
        ctx.moveTo(x + side * (22 + i * 18), 274 + drift);
        ctx.lineTo(x + side * (70 + i * 25), 560);
        ctx.stroke();
      }
    }
  } else if (scene === "abissale") {
    // Cupola pressurizzata, oblò e vita abissale oltre il vetro.
    ctx.strokeStyle = "rgba(193,132,64,0.88)";
    ctx.lineWidth = 14;
    ctx.beginPath(); ctx.arc(480, 218, 438, Math.PI, Math.PI * 2); ctx.stroke();
    for (const x of [78, 882]) {
      ctx.fillStyle = "rgba(84,53,31,0.72)";
      roundedRect(ctx, x - 38, 270, 76, 315, 26); ctx.fill();
      ctx.strokeStyle = "#cf9950";
      ctx.lineWidth = 6;
      for (const y of [328, 430, 532]) {
        ctx.beginPath(); ctx.arc(x, y, 24, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = "rgba(56,235,229,0.18)"; ctx.fill();
      }
    }
    ctx.fillStyle = "rgba(5,18,36,0.72)";
    ctx.beginPath();
    ctx.moveTo(280, 64); ctx.quadraticCurveTo(466, 12, 650, 70); ctx.quadraticCurveTo(482, 46, 280, 64); ctx.fill();
    ctx.strokeStyle = "rgba(62,255,239,0.65)";
    ctx.lineWidth = 3;
    for (let i = 0; i < 12; i += 1) {
      const x = 35 + (i * 83 + time * (5 + i % 3)) % 890;
      const y = 170 + (i * 47) % 420;
      ctx.beginPath(); ctx.arc(x, y, 3 + i % 4, 0, Math.PI * 2); ctx.stroke();
    }
  } else if (scene === "caldera") {
    // Canali di lava ai lati, teste dei Titani e pistoni della fonderia.
    for (const side of [-1, 1]) {
      const inner = side < 0 ? 150 : 810;
      const outer = side < 0 ? 0 : 960;
      const lava = ctx.createLinearGradient(inner, 300, outer, 620);
      lava.addColorStop(0, "rgba(255,72,22,0.08)");
      lava.addColorStop(1, "rgba(255,135,35,0.58)");
      ctx.fillStyle = lava;
      ctx.beginPath();
      ctx.moveTo(inner, 292); ctx.lineTo(outer, 265); ctx.lineTo(outer, 700); ctx.lineTo(inner + side * 90, 700); ctx.closePath(); ctx.fill();
      ctx.fillStyle = "rgba(33,25,26,0.74)";
      ctx.strokeStyle = "#a2492c";
      ctx.lineWidth = 6;
      ctx.beginPath(); ctx.arc(side < 0 ? 92 : 868, 212, 58, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = `rgba(255,95,35,${0.65 + Math.sin(time * 2.2 + side) * 0.15})`;
      ctx.fillRect(side < 0 ? 71 : 847, 203, 42, 13);
      drawGear(ctx, side < 0 ? 76 : 884, 445, 45, 16, "#73321f", time * side * 0.42);
      ctx.fillStyle = "rgba(18,14,15,0.88)";
      for (let i = 0; i < 5; i += 1) {
        const baseX = outer + (inner - outer) * (0.12 + i * 0.16);
        const baseY = 590 + (i % 2) * 42;
        ctx.beginPath();
        ctx.moveTo(baseX - 38, 700); ctx.lineTo(baseX - 22, baseY);
        ctx.lineTo(baseX, baseY - 48 - (i % 3) * 18); ctx.lineTo(baseX + 26, baseY + 5);
        ctx.lineTo(baseX + 45, 700); ctx.closePath(); ctx.fill();
      }
      ctx.strokeStyle = "rgba(128,70,45,0.9)";
      ctx.lineWidth = 8;
      for (let i = 0; i < 3; i += 1) {
        const chainX = side < 0 ? 22 + i * 38 : 938 - i * 38;
        ctx.beginPath(); ctx.moveTo(chainX, 272); ctx.lineTo(chainX + side * 55, 635); ctx.stroke();
      }
    }
    ctx.strokeStyle = "rgba(255,120,52,0.65)";
    ctx.lineWidth = 2;
    for (let i = 0; i < 15; i += 1) {
      const x = (i * 137 + 41) % 960;
      const y = 255 + ((i * 83 - time * (25 + i % 5)) % 360 + 360) % 360;
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 3, y - 9); ctx.stroke();
    }
  } else {
    // Planetario tridimensionale: colonne, orbite e pianeti davanti al cielo.
    ctx.strokeStyle = "rgba(225,181,83,0.84)";
    ctx.lineWidth = 7;
    for (const radius of [78, 125, 178]) {
      ctx.beginPath();
      ctx.ellipse(480, 105, radius * 1.65, radius * 0.48, time * 0.025 + radius * 0.002, 0, Math.PI * 2);
      ctx.stroke();
    }
    const planets = [
      [116, 250, 34, "#50d8ff", 0.24],
      [844, 306, 43, "#d17cff", -0.19],
      [84, 492, 25, "#e2b653", 0.38],
      [882, 535, 30, "#6e8dff", -0.31],
    ];
    for (const [x, y, radius, color, speed] of planets) {
      const bob = Math.sin(time * speed + x) * 7;
      ctx.fillStyle = color;
      ctx.shadowColor = color;
      ctx.shadowBlur = 18;
      ctx.beginPath(); ctx.arc(x, y + bob, radius, 0, Math.PI * 2); ctx.fill();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = "rgba(228,190,103,0.85)";
      ctx.lineWidth = 5;
      ctx.beginPath(); ctx.ellipse(x, y + bob, radius * 1.7, radius * 0.42, 0.3, 0, Math.PI * 2); ctx.stroke();
    }
    for (const x of [62, 898]) {
      ctx.fillStyle = "rgba(43,36,69,0.72)";
      ctx.strokeStyle = "#c69a49";
      ctx.lineWidth = 6;
      roundedRect(ctx, x - 31, 205, 62, 420, 18); ctx.fill(); ctx.stroke();
      drawGear(ctx, x, 350, 35, 14, "#9b7137", time * (x < 480 ? 0.32 : -0.32));
    }
  }
  ctx.restore();
}

export function drawArena(ctx, canvas, arena, time) {
  const { palette } = arena;
  const scene = arena.id ?? "officina";
  const sceneFamily = scene === "cattedrale"
    ? "locomotive"
    : scene === "forgia"
      ? "clockwork"
      : scene;
  if (drawFantasyArenaBackdrop(ctx, canvas, scene, time, arena.image)) {
    // Le arene finali hanno un fondale proprio; il campo e la gabbia sono comuni.
  } else if (sceneFamily === "locomotive") {
    drawLocomotiveDepotBackdrop(ctx, canvas, time);
  } else if (sceneFamily === "clockwork") {
    drawClockworkFactoryBackdrop(ctx, canvas, time);
  } else {
    const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
    gradient.addColorStop(0, "#51c6f4");
    gradient.addColorStop(0.48, "#c8f1ff");
    gradient.addColorStop(0.49, "#f5a277");
    gradient.addColorStop(1, "#e57958");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    drawCloud(ctx, 84, 62, 0.94);
    drawCloud(ctx, 382, 37, 0.64);
    drawCloud(ctx, 725, 70, 0.92);
    drawTree(ctx, 70, 174, 1.32, "#72b94d");
    drawTree(ctx, 165, 172, 0.94, "#4f9f56");
    drawTree(ctx, 867, 168, 1.16, "#5aa956");
    drawTree(ctx, 786, 177, 0.87, "#86be51");
    drawFloodlight(ctx, 188, 92, 1);
    drawFloodlight(ctx, 769, 95, -1);
    ctx.fillStyle = "#f8d5a9";
    roundedRect(ctx, 694, 128, 190, 103, 5); ctx.fill();
    ctx.fillStyle = "#d46653";
    ctx.beginPath(); ctx.moveTo(680, 130); ctx.lineTo(785, 91); ctx.lineTo(900, 130); ctx.closePath(); ctx.fill();
    ctx.fillStyle = "#77c9e5";
    for (let i = 0; i < 4; i += 1) roundedRect(ctx, 711 + i * 38, 151, 25, 42, 2), ctx.fill();
    ctx.fillStyle = "rgba(15,55,89,0.5)";
    roundedRect(ctx, 626, 194, 135, 56, 3); ctx.fill();
    drawSpectators(ctx, 638, 202, 111, 2);
  }

  const topLeft = { x: 210, y: 100 };
  const topRight = { x: 750, y: 100 };
  const bottomLeft = { x: 48, y: canvas.height - 13 };
  const bottomRight = { x: 912, y: canvas.height - 13 };
  const point = (x, y) => {
    const u = (x - COURT.left) / (COURT.right - COURT.left);
    const v = (y - COURT.top) / (COURT.bottom - COURT.top);
    // Put the net slightly deeper in the shot so the player's half reads as spacious.
    const depth = v <= 0.5 ? v * 0.88 : 0.44 + (v - 0.5) * 1.12;
    const lx = topLeft.x + (bottomLeft.x - topLeft.x) * depth;
    const ly = topLeft.y + (bottomLeft.y - topLeft.y) * depth;
    const rx = topRight.x + (bottomRight.x - topRight.x) * depth;
    const ry = topRight.y + (bottomRight.y - topRight.y) * depth;
    return { x: lx + (rx - lx) * u, y: ly + (ry - ly) * u, scale: 0.58 + depth * 0.62 };
  };
  const polygon = (points, fill, stroke, lineWidth = 1) => {
    ctx.beginPath();
    points.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
    ctx.closePath();
    if (fill) { ctx.fillStyle = fill; ctx.fill(); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lineWidth; ctx.stroke(); }
  };

  // The exterior floor and cage first; the court remains the bright focal plane.
  const exteriorFloor = scene === "tempesta" ? "rgba(23,37,60,0.44)"
    : scene === "abissale" ? "rgba(11,48,56,0.42)"
      : scene === "caldera" ? "rgba(60,33,29,0.4)"
        : scene === "orrery" ? "rgba(36,29,75,0.4)"
          : scene === "cattedrale" ? "#312b4f"
    : scene === "forgia" ? "#42272b"
      : sceneFamily === "locomotive" ? "#4f5552"
        : sceneFamily === "clockwork" ? "#4c344d" : "#e78c68";
  const courtFloor = scene === "tempesta" ? "#174d80"
    : scene === "abissale" ? "#12667a"
      : scene === "caldera" ? "#303741"
        : scene === "orrery" ? "#1c3475"
          : scene === "cattedrale" ? "#254c98"
    : scene === "forgia" ? "#49333e"
      : sceneFamily === "locomotive" ? "#1579a8"
        : sceneFamily === "clockwork" ? "#314d9b" : "#138fd7";
  const courtStroke = scene === "tempesta" ? "#4fbdd8"
    : scene === "abissale" ? "#208f98"
      : scene === "caldera" ? "#a24c2f"
        : scene === "orrery" ? "#7869bd"
          : scene === "cattedrale" ? "#574d8e"
    : scene === "forgia" ? "#7d3d43"
      : sceneFamily === "clockwork" ? "#181c55" : "#184d79";
  polygon([{ x: 0, y: 282 }, { x: 960, y: 282 }, { x: 960, y: canvas.height }, { x: 0, y: canvas.height }], exteriorFloor);
  polygon([topLeft, topRight, bottomRight, bottomLeft], courtFloor, courtStroke, 8);
  drawCourtDepth(ctx, topLeft, topRight, bottomLeft, bottomRight);
  drawFantasyArenaProps(ctx, scene, time);
  polygon([{ x: 100, y: 123 }, topLeft, bottomLeft, { x: 0, y: 537 }], "rgba(173,235,255,0.35)", "#173f63", 6);
  polygon([topRight, { x: 860, y: 123 }, { x: 960, y: 537 }, bottomRight], "rgba(173,235,255,0.35)", "#173f63", 6);

  drawCrowdBehind(ctx, time, scene);

  // Rear glass wall rises behind the far baseline instead of reading as flat court paint.
  const backWallTopY = 35;
  polygon(
    [{ x: topLeft.x, y: backWallTopY }, { x: topRight.x, y: backWallTopY }, topRight, topLeft],
    "rgba(184,235,250,0.2)",
    "#173f63",
    5,
  );
  ctx.strokeStyle = "rgba(29,76,111,0.86)";
  ctx.lineWidth = 3;
  for (let i = 1; i < 6; i += 1) {
    const x = topLeft.x + ((topRight.x - topLeft.x) * i) / 6;
    ctx.beginPath(); ctx.moveTo(x, backWallTopY); ctx.lineTo(x, topLeft.y); ctx.stroke();
  }
  ctx.strokeStyle = "rgba(225,248,255,0.46)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(topLeft.x, backWallTopY + 31);
  ctx.lineTo(topRight.x, backWallTopY + 31);
  ctx.stroke();
  ctx.strokeStyle = "#244d70";
  ctx.lineWidth = 7;
  ctx.beginPath(); ctx.moveTo(topLeft.x, backWallTopY); ctx.lineTo(topRight.x, backWallTopY); ctx.stroke();

  // Court markings and alternating blue panels.
  const serviceTop = COURT.netY - 126;
  const serviceBottom = COURT.netY + 126;
  polygon([point(COURT.left, serviceTop), point(COURT.right, serviceTop), point(COURT.right, COURT.netY), point(COURT.left, COURT.netY)], "rgba(0,55,145,0.17)");
  polygon([point(COURT.left, COURT.netY), point(COURT.right, COURT.netY), point(COURT.right, serviceBottom), point(COURT.left, serviceBottom)], "rgba(0,55,145,0.12)");
  ctx.strokeStyle = "rgba(255,255,255,0.92)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  [serviceTop, serviceBottom].forEach((y) => { const a = point(COURT.left, y); const b = point(COURT.right, y); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); });
  const midTop = point(COURT.left + (COURT.right - COURT.left) / 2, COURT.top);
  const midBottom = point(COURT.left + (COURT.right - COURT.left) / 2, COURT.bottom);
  ctx.moveTo(midTop.x, midTop.y); ctx.lineTo(midBottom.x, midBottom.y);
  ctx.stroke();

  const steamTint = scene === "tempesta" ? "145,225,255"
    : scene === "abissale" ? "80,235,225"
      : scene === "caldera" ? "255,125,70"
        : scene === "orrery" ? "190,165,255"
          : scene === "clockwork" ? "196,150,216"
    : scene === "locomotive" ? "186,200,210"
      : scene === "cattedrale" ? "200,190,255"
        : scene === "forgia" ? "255,165,120" : "205,222,232";
  drawAmbientSteam(ctx, canvas, scene, time, steamTint);
  drawVolumetricLights(ctx, canvas, scene, time);

  // Tall transparent walls and lateral mesh: recognisable padel enclosure.
  ctx.strokeStyle = "rgba(20,56,84,0.9)";
  ctx.lineWidth = 3;
  for (let i = 0; i <= 9; i += 1) {
    const x = i / 9;
    const topX = topLeft.x + (topRight.x - topLeft.x) * x;
    const bottomX = bottomLeft.x + (bottomRight.x - bottomLeft.x) * x;
    ctx.beginPath(); ctx.moveTo(topX, topLeft.y); ctx.lineTo(bottomX, bottomLeft.y); ctx.stroke();
  }
  for (let i = 1; i < 5; i += 1) {
    const y = i / 5;
    ctx.beginPath();
    ctx.moveTo(topLeft.x + (bottomLeft.x - topLeft.x) * y, topLeft.y + (bottomLeft.y - topLeft.y) * y);
    ctx.lineTo(topRight.x + (bottomRight.x - topRight.x) * y, topRight.y + (bottomRight.y - topRight.y) * y);
    ctx.stroke();
  }
  ctx.strokeStyle = "rgba(255,255,255,0.35)";
  ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(topLeft.x, topLeft.y); ctx.lineTo(topRight.x, topRight.y); ctx.stroke();
  drawGlassSheen(ctx, time);
  // Le insegne pubblicitarie sui vetri sono state rimosse: aggiungevano rumore
  // visivo su un campo che deve restare leggibile durante lo scambio.

  // A full padel net: dark mesh, white tape and substantial padded posts.
  const netLeft = point(COURT.left, COURT.netY);
  const netRight = point(COURT.right, COURT.netY);
  const netBottomLeft = { x: netLeft.x + 3, y: netLeft.y + 43 };
  const netBottomRight = { x: netRight.x - 3, y: netRight.y + 43 };
  polygon([netLeft, netRight, netBottomRight, netBottomLeft], "rgba(8,38,66,0.68)");
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(netLeft.x, netLeft.y);
  ctx.lineTo(netRight.x, netRight.y);
  ctx.lineTo(netBottomRight.x, netBottomRight.y);
  ctx.lineTo(netBottomLeft.x, netBottomLeft.y);
  ctx.closePath();
  ctx.clip();
  ctx.strokeStyle = "rgba(224,245,255,0.52)";
  ctx.lineWidth = 1.2;
  for (let x = netLeft.x - 10; x < netRight.x + 10; x += 12) {
    ctx.beginPath(); ctx.moveTo(x, netLeft.y - 2); ctx.lineTo(x + 4, netBottomLeft.y + 3); ctx.stroke();
  }
  for (let y = netLeft.y + 10; y < netBottomLeft.y; y += 9) {
    ctx.beginPath(); ctx.moveTo(netLeft.x - 3, y); ctx.lineTo(netRight.x + 3, y); ctx.stroke();
  }
  ctx.restore();
  [netLeft, netRight].forEach((post) => {
    ctx.fillStyle = "#244d70";
    roundedRect(ctx, post.x - 9, post.y - 47, 18, 93, 4); ctx.fill();
    ctx.fillStyle = "#6f9fbc";
    roundedRect(ctx, post.x - 4, post.y - 42, 7, 79, 2); ctx.fill();
  });
  ctx.strokeStyle = "#f7fbff";
  ctx.lineWidth = 11;
  ctx.lineCap = "round";
  ctx.beginPath(); ctx.moveTo(netLeft.x - 5, netLeft.y); ctx.lineTo(netRight.x + 5, netRight.y); ctx.stroke();
  ctx.strokeStyle = "rgba(25,67,100,0.35)";
  ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(netLeft.x - 4, netLeft.y + 3); ctx.lineTo(netRight.x + 4, netRight.y + 3); ctx.stroke();

  ctx.fillStyle = "rgba(8,40,70,0.76)";
  roundedRect(ctx, 390, 120, 180, 27, 5); ctx.fill();
  ctx.fillStyle = palette.accent;
  ctx.font = "900 13px Nunito, sans-serif";
  ctx.textAlign = "center";
  const arenaNameKey = `arena_${scene}_name`;
  ctx.fillText(t(arenaNameKey).toUpperCase(), 480, 139);

  // Store projection for the sprites drawn after the court.
  ctx.__padelProject = point;
}

export function drawHitZone(ctx, paddle, color) {
  const p = ctx.__padelProject ? ctx.__padelProject(paddle.x, paddle.y) : paddle;
  ctx.save();
  ctx.strokeStyle = color;
  ctx.globalAlpha = 0.25;
  ctx.lineWidth = 2;
  ctx.setLineDash([8, 8]);
  ctx.beginPath();
  ctx.ellipse(p.x, p.y, paddle.w * 0.62 * p.scale, paddle.reach * 0.52 * p.scale, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.restore();
}

export function drawTeamGeometry(ctx, state) {
  if (!ctx.__padelProject || state.coop) return;
  const active = state[state.activePlayerKey];
  const mate = state.activePlayerKey === "player" ? state.playerMate : state.player;
  const a = ctx.__padelProject(active.x, active.y);
  const b = ctx.__padelProject(mate.x, mate.y);
  const center = ctx.__padelProject((active.x + mate.x) / 2, (active.y + mate.y) / 2);
  const overlap = state.shotRead?.overlap;
  ctx.save();
  ctx.setLineDash([7, 7]);
  ctx.lineWidth = 2;
  ctx.strokeStyle = overlap ? "rgba(255,112,96,0.9)" : "rgba(120,232,255,0.38)";
  ctx.beginPath();
  ctx.moveTo(a.x, a.y - 18 * a.scale);
  ctx.lineTo(b.x, b.y - 18 * b.scale);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = overlap ? "rgba(255,112,96,0.9)" : "rgba(120,232,255,0.5)";
  ctx.beginPath();
  ctx.arc(center.x, center.y - 14 * center.scale, 5 * center.scale, 0, Math.PI * 2);
  ctx.fill();
  if (overlap) {
    ctx.font = "800 11px system-ui, sans-serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "#ffb09a";
    ctx.fillText("COPRI IL CENTRO", center.x, center.y - 30 * center.scale);
  }
  ctx.restore();
}

export function drawActiveIndicator(
  ctx,
  paddle,
  tallSprite = false,
  charge = 0,
  smashChargeThreshold = 0.78,
  smashIntent = false,
  rallyEnergy = 1,
  smashStatus = "",
) {
  const p = ctx.__padelProject ? ctx.__padelProject(paddle.x, paddle.y) : paddle;
  const scale = p.scale ?? 1;
  const cursorY = p.y - (tallSprite ? 139 : 80) * scale;
  ctx.save();

  // FIFA-style selection cursor: compact, readable and clear of the player's feet.
  ctx.shadowColor = "rgba(255, 243, 106, 0.72)";
  ctx.shadowBlur = 9 * scale;
  ctx.fillStyle = "#fff36a";
  ctx.strokeStyle = "#102b50";
  ctx.lineWidth = Math.max(1.5, 2 * scale);
  ctx.beginPath();
  ctx.moveTo(p.x, cursorY + 13 * scale);
  ctx.lineTo(p.x - 9 * scale, cursorY);
  ctx.lineTo(p.x + 9 * scale, cursorY);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.shadowBlur = 0;

  if (charge > 0.015) {
    const width = 70 * scale;
    const height = Math.max(6, 7 * scale);
    const x = p.x - width / 2;
    const y = p.y + 43 * scale;
    const fillWidth = Math.max(0, Math.min(width, width * charge));

    ctx.fillStyle = "rgba(4, 14, 32, 0.88)";
    ctx.strokeStyle = smashIntent && charge >= smashChargeThreshold ? "#ff9a5c" : "#8eefff";
    ctx.lineWidth = Math.max(1, 1.5 * scale);
    ctx.beginPath();
    ctx.roundRect(x - 2 * scale, y - 2 * scale, width + 4 * scale, height + 4 * scale, 4 * scale);
    ctx.fill();
    ctx.stroke();

    const gradient = ctx.createLinearGradient(x, y, x + width, y);
    gradient.addColorStop(0, "#28d7e8");
    gradient.addColorStop(0.58, "#9ef05b");
    gradient.addColorStop(0.8, "#fff36a");
    gradient.addColorStop(1, "#ff7048");
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.roundRect(x, y, fillWidth, height, 2 * scale);
    ctx.fill();

    const thresholdX = x + width * Math.max(0, Math.min(1, smashChargeThreshold));
    ctx.strokeStyle = "rgba(255,255,255,0.92)";
    ctx.lineWidth = Math.max(1, 1.4 * scale);
    ctx.beginPath();
    ctx.moveTo(thresholdX, y - 2 * scale);
    ctx.lineTo(thresholdX, y + height + 2 * scale);
    ctx.stroke();

    if (smashIntent && smashStatus) {
      ctx.font = `700 ${Math.max(8, 9 * scale)}px system-ui, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "bottom";
      ctx.fillStyle = charge >= smashChargeThreshold ? "#fff36a" : "#dffaff";
      ctx.strokeStyle = "rgba(4, 14, 32, 0.92)";
      ctx.lineWidth = Math.max(2, 3 * scale);
      ctx.strokeText(smashStatus, p.x, y - 5 * scale);
      ctx.fillText(smashStatus, p.x, y - 5 * scale);
    }
  }

  const energyWidth = 52 * scale;
  const energyX = p.x - energyWidth / 2;
  const energyY = p.y + 54 * scale;
  ctx.fillStyle = "rgba(4, 14, 32, 0.72)";
  ctx.fillRect(energyX - scale, energyY - scale, energyWidth + 2 * scale, 4 * scale);
  ctx.fillStyle = rallyEnergy > 0.55 ? "#56e8d8" : rallyEnergy > 0.3 ? "#ffd45c" : "#ff6b64";
  ctx.fillRect(energyX, energyY, energyWidth * clamp(rallyEnergy, 0, 1), 2 * scale);
  ctx.restore();
}

export function drawShotFeedback(ctx, state) {
  const feedback = state.shotFeedback;
  if (!feedback?.life) return;
  const paddle = state[feedback.paddleKey];
  if (!paddle) return;
  const p = ctx.__padelProject ? ctx.__padelProject(paddle.x, paddle.y) : paddle;
  const alpha = clamp(feedback.life / 0.28, 0, 1);
  const colors = {
    perfect: "#74ffba",
    good: "#77e7ff",
    early: "#ffd45c",
    late: "#ff8b70",
  };
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.lineJoin = "round";
  ctx.font = "700 14px system-ui, sans-serif";
  ctx.lineWidth = 5;
  ctx.strokeStyle = "rgba(4, 14, 32, 0.9)";
  const y = p.y - 105 * (p.scale ?? 1) - (0.78 - feedback.life) * 18;
  ctx.strokeText(feedback.text, p.x, y);
  ctx.fillStyle = colors[feedback.grade] ?? "#ffffff";
  ctx.fillText(feedback.text, p.x, y);
  ctx.font = "600 9px system-ui, sans-serif";
  ctx.fillStyle = "rgba(255,255,255,0.9)";
  ctx.fillText(feedback.mode, p.x, y + 15);
  ctx.restore();
}

function drawHairBack(ctx, style, hair, facing) {
  ctx.fillStyle = hair;
  ctx.strokeStyle = hair;
  ctx.lineCap = "round";
  if (style === "long-pony") {
    ctx.lineWidth = 15;
    ctx.beginPath();
    ctx.moveTo(-facing * 11, -69);
    ctx.quadraticCurveTo(-facing * 38, -78, -facing * 51, -58);
    ctx.quadraticCurveTo(-facing * 63, -39, -facing * 76, -48);
    ctx.stroke();
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-facing * 19, -72); ctx.quadraticCurveTo(-facing * 53, -91, -facing * 70, -60);
    ctx.moveTo(-facing * 17, -67); ctx.quadraticCurveTo(-facing * 54, -58, -facing * 69, -39);
    ctx.stroke();
  } else if (style === "curly-pony") {
    [[-20, -76, 12], [-31, -82, 11], [-41, -73, 12], [-35, -61, 10], [-51, -64, 9], [-24, -91, 9]].forEach(([x, y, r]) => {
      ctx.beginPath();
      ctx.arc(x * facing, y, r, 0, Math.PI * 2);
      ctx.fill();
    });
  }
}

function drawHairFront(ctx, style, hair, facing) {
  ctx.fillStyle = hair;
  if (style === "spiked") {
    ctx.beginPath();
    ctx.moveTo(-19, -66); ctx.lineTo(-15, -84); ctx.lineTo(-7, -73);
    ctx.lineTo(0, -88); ctx.lineTo(6, -73); ctx.lineTo(16, -84);
    ctx.lineTo(18, -63); ctx.closePath(); ctx.fill();
  } else {
    ctx.beginPath();
    ctx.arc(-3 * facing, -64, style === "curly-pony" ? 19 : 18, Math.PI, Math.PI * 2);
    ctx.fill();
    if (style === "curly-pony") {
      [-14, -5, 6, 15].forEach((x, index) => {
        ctx.beginPath(); ctx.arc(x * facing, -70 - (index % 2) * 4, 7, 0, Math.PI * 2); ctx.fill();
      });
    }
  }
}

function actionFrameForIntent(intent) {
  if (intent?.startsWith("smash")) return 0;
  if (["vibora", "slice", "bandeja", "wall-angle"].includes(intent)) return 1;
  if (["lob", "defensive-lob"].includes(intent)) return 2;
  if (intent === "serve") return 3;
  return null;
}

function spriteDisplayWidth(isPlayer, useActionSprite, useRunSprite, actionFrame, appearance) {
  if (useRunSprite) {
    const calibrated = isPlayer ? appearance?.runDisplay?.back : appearance?.runDisplay?.front;
    return calibrated ?? (isPlayer ? 114 : 144);
  }
  // Back-facing human-team action sheets were already authored at the correct visual scale.
  if (isPlayer) return useActionSprite ? 118 : 112;

  // Front-facing run/action sheets leave more transparent space around the opponent.
  // Compensate only that artwork so advancing toward the net keeps a stable body size.
  if (useActionSprite) return [112, 122, 108, 128][actionFrame] ?? 112;
  return 112;
}

export function drawPaddle(ctx, paddle, color, isPlayer, swing, charge = 0, appearance = null, sprite = null, actionSprite = null, runSprite = null, time = 0) {
  const projected = ctx.__padelProject ? ctx.__padelProject(paddle.x, paddle.y) : { ...paddle, scale: 1 };

  const actionFrame = paddle.actionPose > 0 ? actionFrameForIntent(paddle.actionIntent) : null;
  const useActionSprite = actionFrame !== null && actionSprite?.complete && actionSprite.naturalWidth > 0;
  const useRunSprite = !useActionSprite
    && charge <= 0.08
    && paddle.motion > 0.12
    && runSprite?.complete
    && runSprite.naturalWidth > 0;
  const activeSprite = useActionSprite ? actionSprite : useRunSprite ? runSprite : sprite;

  if (activeSprite?.complete && activeSprite.naturalWidth > 0) {
    const frameCount = useRunSprite ? appearance?.runFrames ?? 4 : 4;
    const frameWidth = activeSprite.naturalWidth / frameCount;
    const frame = useActionSprite
      ? actionFrame
      : useRunSprite
        ? Math.floor(paddle.runPhase ?? 0) % frameCount
      : charge > 0.08 ? 2 : swing > 0.08 ? 3 : paddle.motion > 0.12 ? 1 : 0;
    const destWidth = spriteDisplayWidth(isPlayer, useActionSprite, useRunSprite, actionFrame, appearance) * projected.scale;
    const destHeight = (destWidth / projected.scale) * (activeSprite.naturalHeight / frameWidth) * projected.scale;
    const feetY = projected.y + 46 * projected.scale;
    const transparentFootMargin = destHeight * (useRunSprite ? 0.04 : 0.085);

    ctx.save();
    ctx.fillStyle = "rgba(5, 28, 55, 0.18)";
    ctx.beginPath();
    ctx.ellipse(projected.x, feetY + projected.scale, 30 * projected.scale, 6 * projected.scale, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(3, 20, 39, 0.42)";
    ctx.beginPath();
    ctx.ellipse(projected.x, feetY, 17 * projected.scale, 3 * projected.scale, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(3, 18, 36, 0.16)";
    ctx.beginPath();
    ctx.ellipse(projected.x - 9 * projected.scale, feetY + 4 * projected.scale, 24 * projected.scale, 4.5 * projected.scale, 0.18, 0, Math.PI * 2);
    ctx.fill();
    const drawFrame = (frameIndex) => {
      ctx.drawImage(
        activeSprite,
        frameIndex * frameWidth,
        0,
        frameWidth,
        activeSprite.naturalHeight,
        projected.x - destWidth / 2,
        feetY - destHeight + transparentFootMargin,
        destWidth,
        destHeight,
      );
    };
    drawFrame(frame);
    ctx.restore();
    return;
  }

  ctx.save();
  ctx.translate(projected.x, projected.y);
  ctx.scale(projected.scale * 1.04, projected.scale * 1.04);

  const facing = isPlayer ? 1 : -1;
  const windup = clamp(charge, 0, 1);
  const impact = clamp(swing, 0, 1);
  const followThrough = impact > 0 ? Math.sin((1 - impact) * Math.PI) : 0;
  const swingSide = paddle.swingSide ?? 1;
  const bodyTurn = facing * (-windup * 0.1 + impact * 0.08 + followThrough * 0.07);
  const step = followThrough * 7;
  const visual = appearance?.visual ?? {};
  const skin = visual.skin ?? (isPlayer ? "#d9976e" : "#d68d68");
  const hair = visual.hair ?? (isPlayer ? "#4b2b24" : "#29213c");
  const shorts = visual.secondary ?? (isPlayer ? "#1b4d9c" : "#314362");
  const kit = visual.kit ?? color;
  const accent = visual.accent ?? "#ffd54a";
  const shoeColor = visual.shoes ?? "#173a6d";
  const frame = visual.frame ?? "athletic";
  const bodyWidth = frame === "broad" ? 64 : frame === "slim" ? 48 : 56;
  const limbWidth = frame === "broad" ? 18 : frame === "slim" ? 14 : 16;
  const shoulderX = bodyWidth / 2 - 6;

  ctx.rotate(bodyTurn);

  // Larger cartoon athletes stay readable from the near and far end of the court.
  ctx.fillStyle = "rgba(5, 28, 55, 0.28)";
  ctx.beginPath();
  ctx.ellipse(0, 42, 39, 9, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "rgba(3, 16, 34, 0.15)";
  ctx.beginPath();
  ctx.ellipse(-10, 47, 30, 6.5, 0.18, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = shorts;
  ctx.lineWidth = limbWidth;
  ctx.lineCap = "round";
  ctx.beginPath();
  ctx.moveTo(-12, 14); ctx.lineTo(-31 - step, 31); ctx.lineTo(-19 - step, 42);
  ctx.moveTo(12, 14); ctx.lineTo(30 + step, 40);
  ctx.stroke();

  ctx.strokeStyle = "#ffffff";
  ctx.lineWidth = 11;
  ctx.beginPath();
  ctx.moveTo(-19 - step, 42); ctx.lineTo(-29 - step, 44);
  ctx.moveTo(30 + step, 40); ctx.lineTo(39 + step, 43);
  ctx.stroke();
  ctx.strokeStyle = shoeColor;
  ctx.lineWidth = 9;
  ctx.beginPath();
  ctx.moveTo(-33 - step, 45); ctx.lineTo(-20 - step, 45);
  ctx.moveTo(29 + step, 44); ctx.lineTo(42 + step, 44);
  ctx.stroke();

  ctx.fillStyle = shorts;
  if (frame === "slim") {
    ctx.beginPath();
    ctx.moveTo(-21, 0); ctx.lineTo(21, 0); ctx.lineTo(27, 23); ctx.lineTo(-27, 23); ctx.closePath();
    ctx.fill();
  } else {
    roundedRect(ctx, -bodyWidth * 0.38, 1, bodyWidth * 0.76, 23, 6);
    ctx.fill();
  }

  ctx.fillStyle = kit;
  roundedRect(ctx, -bodyWidth / 2, -34, bodyWidth, 42, frame === "broad" ? 11 : 13);
  ctx.fill();
  ctx.fillStyle = visual.secondary ?? "rgba(255,255,255,0.22)";
  if (visual.kitStyle === "side" || visual.kitStyle === "raglan") {
    ctx.beginPath();
    ctx.moveTo(-bodyWidth / 2, -30); ctx.lineTo(-bodyWidth / 2 + 12, -34); ctx.lineTo(-bodyWidth / 2 + 15, 8); ctx.lineTo(-bodyWidth / 2, 6); ctx.closePath();
    ctx.moveTo(bodyWidth / 2, -30); ctx.lineTo(bodyWidth / 2 - 12, -34); ctx.lineTo(bodyWidth / 2 - 15, 8); ctx.lineTo(bodyWidth / 2, 6); ctx.closePath();
    ctx.fill();
  } else {
    ctx.fillStyle = "rgba(255,255,255,0.22)";
    roundedRect(ctx, -bodyWidth / 2 + 8, -28, 13, 29, 4); ctx.fill();
  }
  if (visual.kitStyle === "diagonal" || !visual.kitStyle) {
    ctx.fillStyle = accent;
    ctx.beginPath();
    ctx.moveTo(-bodyWidth / 2 + 2, -18); ctx.lineTo(bodyWidth / 2 - 2, -5);
    ctx.lineTo(bodyWidth / 2 - 2, 3); ctx.lineTo(-bodyWidth / 2 + 2, -10); ctx.closePath();
    ctx.fill();
  }
  ctx.strokeStyle = "rgba(10,46,91,0.5)";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(-26, -2); ctx.lineTo(26, -2);
  ctx.stroke();

  ctx.strokeStyle = skin;
  ctx.lineWidth = 11;
  ctx.beginPath();
  const supportHandX = -facing * (43 - impact * 13);
  const supportHandY = -5 - impact * 22;
  const racketHandX = facing * (48 - windup * 57 + impact * 24) - swingSide * followThrough * 45;
  const racketHandY = -48 + windup * 18 - impact * 18 + followThrough * 21;
  ctx.moveTo(-facing * shoulderX, -24); ctx.lineTo(supportHandX, supportHandY);
  ctx.moveTo(facing * shoulderX, -24); ctx.lineTo(racketHandX, racketHandY);
  ctx.stroke();

  drawHairBack(ctx, visual.hairStyle, hair, facing);
  ctx.fillStyle = skin;
  ctx.beginPath();
  ctx.ellipse(facing * 2, -57, 17, 19, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(facing * 17, -58); ctx.lineTo(facing * 25, -54); ctx.lineTo(facing * 17, -51); ctx.closePath();
  ctx.fill();
  drawHairFront(ctx, visual.hairStyle, hair, facing);
  const headband = Object.prototype.hasOwnProperty.call(visual, "headband") ? visual.headband : (isPlayer ? "#e3f7ff" : "#ffcd3c");
  if (headband) {
    ctx.strokeStyle = headband;
    ctx.lineWidth = 6;
    ctx.beginPath(); ctx.moveTo(-16, -59); ctx.lineTo(16, -59); ctx.stroke();
  }
  if (visual.beard) {
    ctx.strokeStyle = "rgba(67,37,27,0.72)";
    ctx.lineWidth = 4;
    ctx.beginPath(); ctx.arc(facing * 2, -55, 13, 0.15, Math.PI - 0.15); ctx.stroke();
  }
  ctx.fillStyle = "#20334a";
  ctx.beginPath();
  ctx.arc(facing * 8, -56, 1.9, 0, Math.PI * 2);
  ctx.fill();

  const racketX = racketHandX + facing * (20 + impact * 8) - swingSide * followThrough * 15;
  const racketY = racketHandY - 13 + followThrough * 8;

  if (impact > 0.08) {
    ctx.save();
    ctx.strokeStyle = `rgba(215, 255, 246, ${0.22 + impact * 0.42})`;
    ctx.lineWidth = 7;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(facing * 8, -34, 67, -1.3 + facing * 0.18, 0.45 + followThrough * 0.35);
    ctx.stroke();
    ctx.restore();
  }

  ctx.strokeStyle = "#1b385c";
  ctx.lineWidth = 9;
  ctx.beginPath();
  ctx.moveTo(racketHandX, racketHandY);
  ctx.lineTo(racketX, racketY + 13);
  ctx.stroke();
  ctx.fillStyle = appearance ? "#f4c73f" : "#12c8e3";
  ctx.strokeStyle = appearance ? "#1b385c" : "#f4c73f";
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.ellipse(racketX, racketY, 20, 27, facing * (0.4 - followThrough * 0.55), 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = "rgba(22, 62, 102, 0.7)";
  for (let row = -1; row <= 1; row += 1) {
    for (let col = -1; col <= 1; col += 1) {
      ctx.beginPath();
      ctx.arc(racketX + col * 9, racketY + row * 9, 2.2, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.restore();
}

export function drawBall(ctx, ball, flash = 0) {
  const project = ctx.__padelProject;
  const projected = project ? project(ball.x, ball.y) : { ...ball, scale: 1 };
  // Keep the collision radius generous for playability, but render a padel-sized ball.
  const visualRadius = Math.max(5.4, ball.r * 0.56);
  const hitFlash = ball.hitFlash ?? 0;
  const hitPulse = ball.hitPulse ?? 0;
  const speed = Math.hypot(ball.vx ?? 0, ball.vy ?? 0);
  const fast = speed > 620;
  const spin = (ball.topspin ?? 0) > 0.5 || (ball.backspin ?? 0) > 0.5;
  const airborneY = projected.y - (ball.z ?? 0) * projected.scale;

  const ring = ball.landRing ?? 0;
  if (ring > 0) {
    const life = clamp(ring / 0.5, 0, 1);
    const r = (0.5 - ring) * 150 * projected.scale + visualRadius;
    ctx.save();
    ctx.globalAlpha = life * 0.5;
    ctx.strokeStyle = "#eaffff";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.ellipse(projected.x, projected.y, r, r * 0.42, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = life * 0.22;
    ctx.fillStyle = "#d8ff5f";
    ctx.beginPath();
    ctx.ellipse(projected.x, projected.y, r * 0.7, r * 0.3, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Flash di contatto: anello che si espande + alone, composito "lighter".
  if (hitFlash > 0) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    const life = clamp(hitFlash, 0, 1);
    const ringR = visualRadius * (1 + (1 - life) * 2.8) * projected.scale + 16;
    ctx.globalAlpha = Math.min(1, life * 0.9);
    ctx.strokeStyle = "#fff3a0";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.ellipse(projected.x, airborneY, ringR, ringR * 0.55, 0, 0, Math.PI * 2);
    ctx.stroke();
    const glowR = ringR * 2;
    const g = ctx.createRadialGradient(projected.x, airborneY, 0, projected.x, airborneY, glowR);
    g.addColorStop(0, `rgba(255,246,180,${0.42 * life})`);
    g.addColorStop(0.5, `rgba(255,222,130,${0.18 * life})`);
    g.addColorStop(1, "rgba(255,222,130,0)");
    ctx.fillStyle = g;
    ctx.fillRect(projected.x - glowR, airborneY - glowR, glowR * 2, glowR * 2);
    ctx.restore();
  }

  // Trail credibile: coda soffice/elastica calibrata su velocità, smash e spin.
  if (ball.trail?.length) {
    const n = ball.trail.length;
    const dirX = speed > 1 ? (ball.vx ?? 0) / speed : 0;
    const dirY = speed > 1 ? (ball.vy ?? 0) / speed : 0;
    for (let i = 0; i < n; i += 1) {
      const point = ball.trail[i];
      const t = project ? project(point.x, point.y) : { ...point, scale: 1 };
      const idx = Math.max(0, Math.min(1, i / Math.max(1, n - 1)));
      const life = clamp((point.life ?? 0) / 0.3, 0, 1);
      const lift = (point.z ?? 0) * t.scale;
      const alpha = life * (fast ? 0.5 : 0.32);
      let color = "198,240,106";
      if (spin) color = "94,233,255";
      if (fast && spin) color = "255,224,102";
      if (fast && flash > 0) color = "255,246,160";
      const r = visualRadius * (0.32 + 0.42 * idx) * (fast ? 1.22 : 1);
      const stretch = fast ? 1.5 + idx * 1.6 : 1;
      const texture = getRadialTexture(color);
      ctx.save();
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = alpha;
      ctx.translate(t.x, t.y - lift);
      if (fast) ctx.rotate(Math.atan2(dirY, dirX));
      ctx.scale(stretch, 1);
      if (texture) {
        ctx.drawImage(texture, -r, -r, r * 2, r * 2);
      } else {
        ctx.fillStyle = `rgba(${color},${alpha})`;
        ctx.beginPath();
        ctx.arc(0, 0, r, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
  }

  // Ombra proiettiva. Cresceva del 30% su tutta l'escursione e non cambiava
  // mai opacita': l'altezza si leggeva a fatica proprio ora che decide quali
  // colpi hai disponibili. Palla bassa = ombra piccola e nera sotto i piedi,
  // palla alta = ombra larga, sbiadita e spostata.
  {
    const z = Math.max(0, ball.z ?? 0);
    const lift = clamp(z / BALANCE.playableHitHeight, 0, 1.8);
    const spread = z * projected.scale;
    const grow = 1 + lift * 0.95;
    const fade = 1 - clamp(lift, 0, 1) * 0.58;
    ctx.fillStyle = `rgba(0,0,0,${(0.18 * fade).toFixed(3)})`;
    ctx.beginPath();
    ctx.ellipse(
      projected.x + spread * 0.16,
      projected.y + 6 + spread * 0.04,
      8 * projected.scale * grow,
      3.4 * projected.scale * grow,
      0, 0, Math.PI * 2,
    );
    ctx.fill();
    ctx.fillStyle = `rgba(0,0,0,${(0.34 * fade).toFixed(3)})`;
    ctx.beginPath();
    ctx.ellipse(
      projected.x + spread * 0.22,
      projected.y + 5 + spread * 0.06,
      5.5 * projected.scale * grow,
      2.6 * projected.scale * grow,
      0, 0, Math.PI * 2,
    );
    ctx.fill();
  }

  // Fascia di altezza sulla palla in arrivo: dice a colpo d'occhio quale colpo
  // e' disponibile, senza che il giocatore debba stimare la quota.
  if ((ball.vy ?? 0) > 40) {
    const z = ball.z ?? 0;
    const banda = z > BALANCE.playableHitHeight
      ? "rgba(150,166,186,0.85)"
      : z >= BALANCE.smashMinHeight
        ? "rgba(255,193,84,0.9)"
        : z >= 42
          ? "rgba(126,243,255,0.85)"
          : null;
    if (banda) {
      ctx.save();
      ctx.strokeStyle = banda;
      ctx.lineWidth = 1.6 * projected.scale;
      ctx.beginPath();
      ctx.arc(projected.x, airborneY, visualRadius * projected.scale + 4.5 * projected.scale, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
  }

  const bouncePulse = clamp(ball.bouncePulse ?? 0, 0, 1);
  const motionStretch = clamp(speed / 620, 0, 1) * 0.16;
  const squash = clamp(hitPulse, 0, 1);
  const motionAngle = Math.atan2(ball.vy ?? 0, ball.vx ?? 0);

  ctx.save();
  ctx.translate(projected.x, projected.y - (ball.z ?? 0) * projected.scale);
  ctx.rotate(motionAngle);
  ctx.scale(
    projected.scale * (1 + bouncePulse * 0.08) * (1 + motionStretch + squash * 0.24),
    projected.scale * (1 - bouncePulse * 0.07) * (1 - motionStretch * 0.45 - squash * 0.14),
  );
  ctx.rotate(-motionAngle);

  const ballColor = (ball.netCord ?? 0) > 0 ? "#ffffff" : (flash > 0 || hitFlash > 0) ? "#fff6a0" : "#d8ff5f";
  const bodyG = ctx.createRadialGradient(
    -visualRadius * 0.35,
    -visualRadius * 0.4,
    visualRadius * 0.15,
    0, 0, visualRadius * 1.12,
  );
  bodyG.addColorStop(0, "#ffffff");
  bodyG.addColorStop(0.35, ballColor);
  bodyG.addColorStop(1, "rgba(150,200,90,0.95)");
  ctx.fillStyle = bodyG;
  ctx.beginPath();
  ctx.arc(0, 0, visualRadius, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = "rgba(9,13,18,0.45)";
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.arc(0, 0, visualRadius - 2, -1, 1);
  ctx.stroke();
  if ((ball.netCord ?? 0) > 0) {
    ctx.strokeStyle = `rgba(255, 255, 255, ${Math.min(1, ball.netCord)})`;
    ctx.lineWidth = 1.8;
    ctx.setLineDash([]);
    ctx.beginPath();
    ctx.arc(0, 0, visualRadius + 4, 0, Math.PI * 2);
    ctx.stroke();
  }
  if ((ball.backspin ?? 0) > 0.08) {
    ctx.strokeStyle = "rgba(69, 224, 255, 0.9)";
    ctx.lineWidth = 1.4;
    ctx.setLineDash([3, 2]);
    ctx.beginPath();
    ctx.arc(0, 0, visualRadius + 3, 0.25, Math.PI * 1.75);
    ctx.stroke();
    ctx.setLineDash([]);
  }
  ctx.restore();
}

export function drawFx(ctx, state) {
  const fx = state.fx;
  const project = ctx.__padelProject;
  if (!fx || !fx.particles.length || !project) return;
  for (const p of fx.particles) {
    const t = project(p.x, p.y);
    const lift = p.z * t.scale;
    const alpha = Math.max(0, p.life / p.maxLife);
    ctx.save();
    ctx.globalAlpha = alpha * 0.85;
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(t.x, t.y - lift, Math.max(1.5, p.size * t.scale), 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

export function drawLandingMarker(ctx, ball, time) {
  const landing = predictLanding(ball);
  const project = ctx.__padelProject;
  if (!landing || !project) return;
  const p = project(landing.x, landing.y);
  const pulse = 0.5 + 0.5 * Math.sin(time * 7);
  ctx.save();
  ctx.globalAlpha = 0.16 + pulse * 0.14;
  ctx.strokeStyle = "#fff36a";
  ctx.lineWidth = 2;
  ctx.setLineDash([7, 6]);
  ctx.beginPath();
  ctx.ellipse(p.x, p.y, 34 * p.scale, 14 * p.scale, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.globalAlpha = 0.1 + pulse * 0.1;
  ctx.fill();
  ctx.restore();
}

export function drawServeBox(ctx, state, time) {
  const project = ctx.__padelProject;
  if (!project || !state.serving) return;
  const { ball } = state;
  const half = (COURT.left + COURT.right) / 2;
  const isLeft = ball.serveTargetSide === "left";
  const x1 = isLeft ? COURT.left : half;
  const x2 = isLeft ? half : COURT.right;
  const receiverIsAi = state.serveSide === "player";
  const y1 = receiverIsAi ? COURT.netY - SERV_LINE : COURT.netY;
  const y2 = receiverIsAi ? COURT.netY : COURT.netY + SERV_LINE;
  const a = project(x1, y1);
  const b = project(x2, y1);
  const c = project(x2, y2);
  const d = project(x1, y2);
  const pulse = 0.5 + 0.5 * Math.sin(time * 6);
  ctx.save();
  ctx.globalAlpha = 0.14 + pulse * 0.08;
  ctx.fillStyle = state.arena.palette.accent;
  ctx.beginPath();
  ctx.moveTo(a.x, a.y);
  ctx.lineTo(b.x, b.y);
  ctx.lineTo(c.x, c.y);
  ctx.lineTo(d.x, d.y);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

export function drawMenuPreview(ctx, canvas, time) {
  // Reuse the full-size arena artwork in the compact menu canvas.
  ctx.save();
  ctx.scale(canvas.width / 960, canvas.height / 620);
  drawArena(ctx, { width: 960, height: 620 }, {
    palette: { floor: "#1a2840", accent: "#00e5ff", gear: "#c89000" },
  }, time);
  ctx.restore();

  const cx = canvas.width / 2;
  const cy = canvas.height / 2;
  ctx.fillStyle = "#d8ff5f";
  ctx.beginPath();
  ctx.arc(cx + Math.sin(time * 1.5) * 80, cy + Math.cos(time * 2) * 40, 8, 0, Math.PI * 2);
  ctx.fill();

  ctx.font = "800 22px 'Lilita One', cursive";
  ctx.fillStyle = "#fff";
  ctx.textAlign = "center";
  ctx.fillText("STEAM CIRCUIT", cx, canvas.height - 28);
}

export function drawTimingHud(ctx, state, time) {
  const project = ctx.__padelProject;
  if (!project) return;
  const active = state[state.activePlayerKey];
  if (!active) return;
  const p = project(active.x, active.y);
  const scale = p.scale ?? 1;
  const read = state.shotRead;

  // Anello di timing attorno al cursore mentre si carica il colpo.
  if ((state.shotCharge ?? 0) > 0.05 && read?.active) {
    const cy = p.y - 96 * scale;
    const r = 20 * scale;
    const frac = clamp(1 - read.eta / 0.55, 0, 1);
    const inWindow = Math.abs(read.eta) <= (read.perfectWindow ?? 0.055);
    ctx.save();
    ctx.translate(p.x, cy);
    ctx.rotate(-Math.PI / 2);
    ctx.strokeStyle = "rgba(255,255,255,0.22)";
    ctx.lineWidth = 3 * scale;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 1.85);
    ctx.stroke();
    const grad = ctx.createLinearGradient(0, 0, r, 0);
    grad.addColorStop(0, "#28d7e8");
    grad.addColorStop(0.72, "#9ef05b");
    grad.addColorStop(0.86, "#fff36a");
    grad.addColorStop(1, "#ff7048");
    ctx.strokeStyle = grad;
    ctx.lineWidth = 3.4 * scale;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 1.6 * clamp(frac, 0, 1));
    ctx.stroke();
    if (inWindow) {
      const blink = 0.5 + 0.5 * Math.sin(time * 18);
      ctx.fillStyle = `rgba(120,255,190,${0.12 + 0.1 * blink})`;
      ctx.strokeStyle = `rgba(140,255,200,${0.55 + 0.4 * blink})`;
      ctx.lineWidth = 2 * scale;
      ctx.beginPath();
      ctx.arc(0, 0, r + 5 * scale, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }
    ctx.restore();
  }

  // Corsa di RT durante la carica: dice quanto rischio stai impegnando, non
  // dove andra' la palla. Il punto di caduta resta una lettura del giocatore.
  const precision = read?.precision ?? 0;
  if ((state.shotCharge ?? 0) > 0.05 && precision > 0.04) {
    const tight = read?.tight ?? 0;
    const w = 46 * scale;
    const h = 5 * scale;
    const x = p.x - w / 2;
    const y = p.y - 64 * scale;
    ctx.save();
    ctx.fillStyle = "rgba(4,14,32,0.78)";
    ctx.strokeStyle = "rgba(126,243,255,0.35)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(x - 1, y - 1, w + 2, h + 2, 3);
    ctx.fill();
    ctx.stroke();
    // Ciano finche' la soglia non scatta, ambra/rosso quando l'angolo e' armato.
    const armed = tight > 0.02;
    const pulse = armed ? 0.62 + 0.38 * Math.sin(time * 16) : 1;
    ctx.fillStyle = armed
      ? `rgba(${Math.round(255)},${Math.round(190 - tight * 120)},70,${pulse})`
      : "rgba(126,243,255,0.75)";
    ctx.beginPath();
    ctx.roundRect(x, y, Math.max(2, w * clamp(precision, 0, 1)), h, 2);
    ctx.fill();
    if (armed) {
      ctx.font = `800 ${9 * scale}px system-ui, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "bottom";
      ctx.fillStyle = `rgba(255,214,120,${pulse})`;
      ctx.fillText(t("hudTightAngle"), p.x, y - 3 * scale);
    }
    ctx.restore();
  }

  // Consiglio tattico a bordo campo, sopra il giocatore attivo.
  if (!state.serving && !(state.pointPause > 0)) {
    const label = t(`shotAdvice_${state.shotRead?.advice ?? "read"}`).toUpperCase();
    const x = p.x;
    const y = p.y - 132 * scale;
    ctx.save();
    ctx.font = `800 ${11 * scale}px system-ui, sans-serif`;
    const tw = ctx.measureText(label).width;
    const w = tw + 22;
    const h = 20;
    ctx.fillStyle = "rgba(4,14,32,0.82)";
    ctx.strokeStyle = "rgba(126,243,255,0.5)";
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.roundRect(x - w / 2, y - h / 2, w, h, 6);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = state.shotRead?.profile === "aggressive" ? "#ffd46a" : "#8fffd0";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(label, x, y + 0.5);
    ctx.restore();
  }
}
