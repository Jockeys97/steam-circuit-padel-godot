// Pure first-bounce planner; mirrored by godot/src/sim/ai_contact.gd.
export function planAiContact(p, b, court, balance) {
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  const out = { wait: false, reason: "emergency", x: b.x, y: b.y };
  if (b.serve || b.fault || !b.incoming) return { ...out, reason: "not-playable" };
  if (b.bounces > 0) return { ...out, reason: "bounced" };
  const lateral = Math.abs(b.x - p.x) / Math.max(1, p.width);
  if (court.netY - p.y < 130 + p.skill * 20 && b.z >= 30 && b.z <= 74 && lateral < 0.60 + p.skill * 0.12)
    return { ...out, reason: "volley" };
  const gravity = balance.ballGravity;
  const impact = Math.sqrt(Math.max(0, b.vz * b.vz + 2 * gravity * Math.max(0, b.z)));
  const groundTime = (b.vz + impact) / gravity;
  const landingY = b.y + b.vy * groundTime;
  if (b.vz < 0 && b.z >= 58 && court.netY - p.y < 170 && lateral < 1.2 && landingY > court.netY - 126)
    return { ...out, reason: "overhead" };
  if (groundTime <= 0 || groundTime > 0.65) return out;
  const slice = clamp(b.backspin, 0, 1.2), topspin = clamp(b.topspin, 0, 1.3);
  const restitution = (balance.groundRestitution + balance.groundRestitutionBoost * clamp(impact / 520, 0, 1)) * (1 - slice * 0.28) + topspin * 0.12;
  const rebound = Math.max(balance.minimumBounceVz * (1 - slice * 0.26), impact * restitution);
  const after = Math.min(0.18, rebound / gravity);
  const height = rebound * after - 0.5 * gravity * after * after;
  if (height < 12 || height > balance.playableHitHeight) return out;
  const x = b.x + b.vx * groundTime + (b.vx + b.spin * balance.groundSpinTransfer) * balance.groundTangentialDamping * after;
  const y = b.y + b.vy * groundTime + b.vy * balance.groundTangentialDamping * (1 - slice * 0.14) * (1 + topspin * 0.08) * after;
  if (x < court.left + 76 || x > court.right - 76 || y < court.top + 84 || y > court.netY - 42) return out;
  const available = groundTime + after - p.reaction - 0.10;
  const travelX = Math.max(0, Math.abs(x - p.x) - p.width * 0.45) / Math.max(1, p.speed);
  const travelY = Math.max(0, Math.abs(y - p.y) - p.depth * 0.45) / Math.max(1, p.speed * 0.56);
  return available > 0 && Math.max(travelX, travelY) < available
    ? { wait: true, reason: "reachable-bounce", x, y } : out;
}
