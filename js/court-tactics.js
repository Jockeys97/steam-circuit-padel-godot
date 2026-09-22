// Mirrored by godot/src/sim/court_tactics.gd. No skill buffs or random draws.
export function courtStyle(id) {
  if (['fiamma', 'pantera'].includes(id)) return { id: 'attack', lob: -0.04, smash: 0.04, net_depth: 62 };
  if (['oracolo', 'steamer'].includes(id)) return { id: 'patient', lob: 0.06, smash: -0.03, net_depth: 94 };
  return { id: 'balanced', lob: 0, smash: 0, net_depth: 70 };
}
export function coverLane(activeX, mateX, left, right) {
  const width = right - left, centre = (left + right) * 0.5;
  let coverRight = mateX >= centre;
  if (activeX < centre - width * 0.08) coverRight = true;
  else if (activeX > centre + width * 0.08) coverRight = false;
  return left + width * (coverRight ? 0.72 : 0.28);
}
export function safeCoverY(activeX, activeY, mateX, mateY, targetX, targetY, bottom) {
  const crossing = (mateX - activeX) * (targetX - activeX) <= 0;
  if (crossing && Math.abs(mateY - activeY) < 90) {
    if (activeY + 68 > bottom - 42) return activeY - 68;
    return Math.max(targetY, activeY + 68);
  }
  return targetY;
}
