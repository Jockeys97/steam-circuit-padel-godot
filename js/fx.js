const MAX_PARTICLES = 240;
let reducedMotion = false;

export function setReduceMotion(enabled) {
  reducedMotion = Boolean(enabled);
}

export function isReduceMotion() {
  return reducedMotion;
}

export function resetFx(state) {
  state.fx = { particles: [], shake: 0 };
}

export function emitBurst(state, x, y, z, {
  count = 10,
  color = "#d8ff5f",
  speed = 120,
  size = 6,
  life = 0.5,
  vz = 60,
} = {}) {
  const fx = state.fx;
  if (!fx) return;
  if (reducedMotion) count = Math.max(2, Math.round(count * 0.35));
  for (let i = 0; i < count; i += 1) {
    if (fx.particles.length >= MAX_PARTICLES) fx.particles.shift();
    const angle = Math.random() * Math.PI * 2;
    const s = speed * (0.4 + Math.random() * 0.8);
    fx.particles.push({
      x,
      y,
      z,
      vx: Math.cos(angle) * s,
      vy: Math.sin(angle) * s,
      vz: vz * (0.4 + Math.random() * 0.9),
      life: life * (0.6 + Math.random() * 0.6),
      maxLife: life,
      color,
      size: size * (0.6 + Math.random() * 0.8),
      gravity: 260,
    });
  }
}

export function emitSparks(state, x, y, z) {
  emitBurst(state, x, y, z, { count: 14, color: "#ffd54a", speed: 190, size: 5, life: 0.4, vz: 120 });
  emitBurst(state, x, y, z, { count: 6, color: "#ffffff", speed: 120, size: 4, life: 0.3, vz: 80 });
}

export function emitDust(state, x, y, z) {
  emitBurst(state, x, y, z, { count: 8, color: "#bcd6e8", speed: 70, size: 5, life: 0.4, vz: 30 });
}

export function emitSteam(state, x, y, z) {
  emitBurst(state, x, y, z, { count: 12, color: "#cfe3ea", speed: 60, size: 9, life: 0.7, vz: 60 });
}

export function updateFx(state, dt) {
  const fx = state.fx;
  if (!fx) return;
  if (reducedMotion) fx.shake = Math.min(fx.shake ?? 0, 0.5);
  fx.shake = Math.max(0, (fx.shake ?? 0) - dt * 2.4);
  const list = fx.particles;
  for (let i = list.length - 1; i >= 0; i -= 1) {
    const p = list[i];
    p.life -= dt;
    if (p.life <= 0) {
      list.splice(i, 1);
      continue;
    }
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vz -= p.gravity * dt;
    p.z = Math.max(0, p.z + p.vz * dt);
  }
}