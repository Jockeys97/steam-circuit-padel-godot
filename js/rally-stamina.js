// Mirrored by godot/src/sim/rally_stamina.gd. Energy is per athlete, not controller.
export const STAMINA = Object.freeze({ floor: 0.15, threshold: 0.60, maxSlow: 0.12 });
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
export function fatigue(energy = 1) {
  const t = clamp((STAMINA.threshold - energy) / (STAMINA.threshold - STAMINA.floor), 0, 1);
  return t * t * (3 - 2 * t);
}
export const staminaSpeed = (energy = 1) => 1 - STAMINA.maxSlow * fatigue(energy);
// Feed the existing quality/timing/risk path, without a second RNG or error penalty.
export const assessmentEnergy = (energy = 1) => 1 - 0.60 * fatigue(energy);
export function shotCost(variant = '', slice = false, mode = 'control') {
  let cost = 0.04;
  if (variant.startsWith('smash')) cost = 0.10;
  else if (variant.includes('bandeja')) cost = 0.055;
  else if (variant.includes('vibora')) cost = 0.065;
  else if (slice || variant.includes('slice') || variant === 'cut-volley') cost = 0.035;
  else if (['safe-drive', 'chiquita', 'lob', 'defensive-lob', 'globo'].includes(variant)) cost = 0.025;
  return cost + (mode === 'power' ? 0.025 : mode === 'balanced' ? 0.01 : 0);
}
export function effortEnergy(energy, dt, movement, sprint, stamina = 1) {
  const m = clamp(movement, 0, 1), s = clamp(sprint, 0, 1), resistance = clamp(stamina, 0.7, 1.5);
  const recovery = 0.008 * (1 - m) * resistance;
  const drain = (0.002 + 0.008 * m + 0.016 * m * s) / resistance;
  return clamp(energy + dt * (recovery - drain), STAMINA.floor, 1);
}
