// 🖤🩷 NZ:P reflex brain — pure functions, no DOM, no engine access.
// Input: parsed BOTSTATE (from the QuakeC state export). Output: intents.
// Spec: ../SPEC.md (S1–S8). The LLM is not in this loop, by design.

export const CFG = {
  headOffset: 20,        // units above zombie origin to aim (tuned live later)
  maxEngageDist: 1200,   // Quake units; beyond this, hold fire
  dangerDist: 64,        // nearest zombie closer than this => retreat
  safeReloadDist: 220,   // only elective-reload when nearest zombie is farther
  aimToleranceDeg: 6,    // fire only if current view is within this of target
  thompsonCost: 1200,
  helpDoorCost: 1000,
};

const num = (v) => (v === undefined ? NaN : Number(v));

export function parseBotState(line) {
  if (typeof line !== 'string' || !line.startsWith('BOTSTATE ')) return null;
  const kv = {};
  let zombieRaw = null;
  for (const tok of line.slice('BOTSTATE '.length).trim().split(/\s+/)) {
    const eq = tok.indexOf('=');
    if (eq < 0) continue;
    const k = tok.slice(0, eq), v = tok.slice(eq + 1);
    if (k === 'z') zombieRaw = v; else kv[k] = v;
  }
  const vec = (s) => {
    if (!s) return null;
    const [x, y, z] = s.split(',').map(Number);
    return { x, y, z };
  };
  const ang = (s) => {
    if (!s) return { pitch: 0, yaw: 0 };
    const [pitch, yaw] = s.split(',').map(Number);
    return { pitch, yaw };
  };
  const zombies = [];
  if (zombieRaw) {
    for (const entry of zombieRaw.split(';')) {
      if (!entry) continue;
      const [x, y, z, hp, dist] = entry.split(',').map(Number);
      zombies.push({ x, y, z, hp, dist });
    }
  }
  const player = vec(kv.p);
  if (!player) return null;
  return {
    t: num(kv.t), round: num(kv.round), alive: num(kv.alive ?? 0),
    hp: num(kv.hp), pts: num(kv.pts), mag: num(kv.mag), reserve: num(kv.reserve),
    weapon: kv.weapon || '', player, angles: ang(kv.a), zombies,
  };
}

// Quake/FTE angles: yaw 0 = +X (east), CCW positive; pitch positive = looking DOWN.
export function aimAngles(from, to, headOffset = CFG.headOffset) {
  const dx = to.x - from.x, dy = to.y - from.y;
  const dz = (to.z + headOffset) - from.z;
  const horiz = Math.hypot(dx, dy);
  let yaw = Math.atan2(dy, dx) * 180 / Math.PI;
  if (yaw > 180) yaw -= 360; if (yaw < -180) yaw += 360;
  const pitch = -Math.atan2(dz, horiz) * 180 / Math.PI;
  return { yaw, pitch };
}

function angDiff(a, b) {
  let d = (a - b) % 360;
  if (d > 180) d -= 360; if (d < -180) d += 360;
  return Math.abs(d);
}

export function decide(state, ctx = {}) {
  const out = { fire: false, reload: false, retreat: false, target: null, aim: null, buy: null, moveAwayFrom: null };
  if (!state) return out;
  const zs = [...state.zombies].sort((a, b) => a.dist - b.dist);
  const nearest = zs[0] || null;
  out.target = nearest && nearest.dist <= CFG.maxEngageDist ? nearest : null;

  // S7 — slow strategy intents (checked by caller at low cadence)
  if (ctx.zone === 'help' && !ctx.ownsThompson && state.pts >= CFG.thompsonCost) out.buy = 'thompson';
  else if (!ctx.helpDoorOpen && state.round <= 3 && state.pts >= CFG.helpDoorCost && !nearest) out.buy = 'open_help';

  if (nearest && nearest.dist < CFG.dangerDist) {
    out.retreat = true;
    out.moveAwayFrom = { x: nearest.x, y: nearest.y };
  }

  // S4 — reload discipline
  if (state.mag === 0 && state.reserve > 0) { out.reload = true; return out; }
  if (!out.retreat && state.mag > 0 && nearest && nearest.dist > CFG.safeReloadDist) {
    // elective reload is caller's weapon-size concern; flag when mag is low
    if (state.weapon && state.mag <= 2) out.reload = true;
  }
  if (out.reload) return out;

  // S4/S5 — fire discipline
  if (out.target && state.mag > 0) {
    out.aim = aimAngles(state.player, out.target);
    const err = Math.max(angDiff(state.angles.yaw, out.aim.yaw), angDiff(state.angles.pitch, out.aim.pitch));
    if (err <= CFG.aimToleranceDeg && !out.retreat) out.fire = true;
    // point-blank lane exception: if retreating but target dead ahead, still fire
    if (out.retreat && err <= CFG.aimToleranceDeg) out.fire = true;
  }
  return out;
}
