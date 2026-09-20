import { planAiContact } from "./ai-contact.js?v=20260920-fluidity-v1";
import { BALANCE, COURT, EVENT_LINES, ROSTER_AVERAGE } from "./data.js?v=20260910-sprite-gate-v41";
import { clamp } from "./render.js?v=20260910-sprite-gate-v41";
import { sfx } from "./audio.js?v=20260910-sprite-gate-v41";
import { t } from "./i18n.js?v=20260910-sprite-gate-v41";
import {
  emitBurst,
  emitDust,
  emitSparks,
  emitSteam,
  isReduceMotion,
  resetFx,
  updateFx,
} from "./fx.js?v=20260910-sprite-gate-v41";

/**
 * Generatore pseudocasuale tenuto DENTRO lo stato. Serve a tre cose: rendere la
 * partita riproducibile, permettere di salvare e ripristinare la simulazione, e
 * togliere la dipendenza da `Math.random` globale. Il seme iniziale viene
 * comunque da `Math.random`, cosi' ogni partita e' diversa e gli script di
 * misura che sostituiscono `Math.random` continuano a funzionare.
 */
export function nextRandom(state) {
  let a = (state.rngState + 0x6D2B79F5) | 0;
  state.rngState = a;
  let t = Math.imul(a ^ (a >>> 15), 1 | a);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

const SERVICE_LINE_OFFSET = 126;
const SERVICE_TOP = COURT.netY - SERVICE_LINE_OFFSET;
const SERVICE_BOTTOM = COURT.netY + SERVICE_LINE_OFFSET;
const POINTS = ["0", "15", "30", "40"];

export function createPaddle(x, y, isPlayer, profile) {
  const stats = profile.stats ?? { speed: 1, control: 1, reach: 1 };
  return {
    x,
    y,
    // Le racchette avversarie prendono larghezza e allungo dall'atleta scelto,
    // gia' normalizzati sulla media del roster. Sulla larghezza il rapporto
    // entra a meta' peso: la larghezza e' la probabilita' stessa di arrivare
    // sulla palla, e a peso pieno un avversario di controllo sarebbe diventato
    // un secondo livello di difficolta'.
    w: BALANCE.basePaddleWidth * (isPlayer ? 0.86 + stats.control * 0.14 : 0.94 * (profile.widthRatio ?? 1)),
    h: 16,
    speed: profile.speed ?? BALANCE.basePaddleSpeed * stats.speed,
    reach: 46 * (isPlayer ? stats.reach ?? 1 : profile.reachRatio ?? 1),
    swing: 0,
    swingSide: 1,
    actionPose: 0,
    actionIntent: "drive",
    motion: 0,
    moveRatio: 0,
    runPhase: 0,
    isPlayer,
    dashTimer: 0,
    hitCooldown: 0,
    controlled: profile.controlled ?? false,
    role: profile.role ?? "back",
    skill: profile.skill ?? 1,
    key: profile.key ?? null,
    charge: 0,
    aim: 0,
    aimY: 0,
    swingBuffer: 0,
    queuedShot: null,
    shotIntent: "drive",
    splitStep: 0,
    sprinting: 0,
  };
}

export function createBall() {
  return {
    x: (COURT.left + COURT.right) / 2,
    y: COURT.bottom - 80,
    z: 36,
    r: 11,
    vx: 0,
    vy: 0,
    vz: 0,
    spin: 0,
    backspin: 0,
    topspin: 0,
    shotType: "serve",
    smashStage: 0,
    smashTargetSide: null,
    postGlassSide: null,
    wallAngleResolved: false,
    bouncePulse: 0,
    netCord: 0,
    netFaultOwner: null,
    crossedNet: true,
    serveTouchedNet: false,
    served: false,
    serveInFlight: false,
    serveTargetSide: "left",
    serveTargetX: (COURT.left + COURT.right) / 2,
    serveTargetY: COURT.netY,
    bounces: { player: 0, ai: 0 },
    trail: [],
    trailTime: 0,
    landRing: 0,
    hitFlash: 0,
    hitPulse: 0,
  };
}

function other(side) {
  return side === "player" ? "ai" : "player";
}

function courtSide(y) {
  return y > COURT.netY ? "player" : "ai";
}

function ballPlayableDirection(side, ball) {
  const incoming = side === "player" ? ball.vy > 0 : ball.vy < 0;
  const returningFromOwnGlass = ball.postGlassSide === side && courtSide(ball.y) === side;
  return incoming || returningFromOwnGlass;
}

function pointLabel(own, opponent) {
  if (own >= 3 && opponent >= 3) {
    if (own === opponent) return "40";
    return own > opponent ? "AD" : "40";
  }
  return POINTS[Math.min(own, 3)];
}

function syncPointDisplay(state) {
  if (state.pointsToWin) {
    state.playerScore = String(state.points.player);
    state.aiScore = String(state.points.ai);
    return;
  }
  state.playerScore = state.tieBreak ? String(state.tieBreakPoints.player) : pointLabel(state.points.player, state.points.ai);
  state.aiScore = state.tieBreak ? String(state.tieBreakPoints.ai) : pointLabel(state.points.ai, state.points.player);
}

/**
 * Chi gioca in ciascuna delle quattro posizioni.
 *
 * Prima il compagno riceveva `athlete.stats`, cioe' era un clone statistico del
 * giocatore con un'altra faccia, e i due avversari non avevano statistiche
 * affatto: contavano solo `skill` e `speed` del livello di difficolta'. La
 * scelta della squadra esisteva solo come grafica.
 *
 * `player` non e' negoziabile: e' l'atleta con cui si gioca. Gli altri tre
 * possono mancare, e in quel caso si ricade sul comportamento di prima — e'
 * cosi' che gli audit continuano a misurare la difficolta' e non la formazione.
 */
function buildLineup(athlete, lineup = {}) {
  return {
    player: athlete,
    playerMate: lineup.playerMate ?? null,
    opponent: lineup.opponent ?? null,
    opponentMate: lineup.opponentMate ?? null,
  };
}

/** L'atleta di quella racchetta, o quello del giocatore se non e' stato scelto. */
export function athleteFor(state, paddle) {
  return state.lineup?.[paddle?.key] ?? state.athlete;
}

/**
 * Statistica di un atleta come rapporto sulla media del roster. Un atleta medio
 * restituisce 1,00, quindi moltiplicare per questo valore da' carattere alla
 * racchetta senza spostare il livello di difficolta' scelto.
 */
function statRatio(chosen, key, spread = 1) {
  if (!chosen) return 1;
  const ratio = chosen.stats[key] / ROSTER_AVERAGE[key];
  return 1 + (ratio - 1) * spread;
}

/** Come sopra, ma per la racchetta: sceglie l'atleta e applica il rapporto. */
function paddleRatio(state, paddle, key, spread = 1) {
  return statRatio(state.lineup?.[paddle?.key], key, spread);
}

export function createMatchState(mode, athlete, arena, aiProfile, tournamentRound = 0, options = {}) {
  const humanMode = options.humanMode ?? "solo";
  const lineup = buildLineup(athlete, options.lineup);
  const mateStats = (lineup.playerMate ?? athlete).stats;
  const state = {
    lineup,
    mode,
    athlete,
    arena,
    ai: aiProfile,
    tournamentRound,
    humanMode,
    coop: humanMode === "coop",
    pvp: humanMode === "pvp",
    pvpActiveKey: "opponent",
    pvpSwitchCooldown: 0,
    pvpSwitchFlash: 0,
    pvpAthlete: null,
    scoring: "tennis",
    pointsToWin: null,
    points: { player: 0, ai: 0 },
    games: { player: 0, ai: 0 },
    sets: { player: 0, ai: 0 },
    tieBreak: false,
    tieBreakPoints: { player: 0, ai: 0 },
    // I game di ogni set concluso: "6-4, 7-5". Vedi `finishSet`.
    setScores: [],
    playerScore: "0",
    aiScore: "0",
    combo: 1,
    rallyHits: 0,
    rallyEnergy: { player: 1, ai: 1 },
    // Seme iniziale da Math.random: ogni partita e' diversa, ma da qui in poi
    // la simulazione avanza solo con nextRandom(state).
    rngState: (Math.random() * 0xffffffff) | 0,
    shotFeedback: null,
    shotRead: { active: false, eta: null, perfectWindow: 0.055, advice: "read", profile: "control", overlap: false },
    specialCooldown: 0,
    specialReady: 1,
    serveSide: "player",
    serveCourt: "right",
    serveAttempts: 0,
    serving: true,
    serveTimer: 0.9,
    serviceReceiverKey: null,
    aiServiceReceiverKey: null,
    pointPause: 0,
    hitStop: 0,
    pointMessage: "",
    lastHitterSide: null,
    flash: 0,
    shieldTimer: 0,
    wallEventTimer: 0,
    paused: false,
    running: false,
    lastTime: 0,
    elapsed: 0,
    events: [],
    result: null,
    player: createPaddle((COURT.left + COURT.right) / 2, COURT.bottom - 52, true, { stats: athlete.stats, controlled: true, key: "player" }),
    playerMate: createPaddle((COURT.left + COURT.right) / 2, COURT.netY + 88, true, { stats: mateStats, role: "net", key: "playerMate" }),
    opponent: createPaddle((COURT.left + COURT.right) / 2, COURT.top + 76, false, {
      speed: aiProfile.speed * (0.86 + aiProfile.skill * 0.1) * statRatio(lineup.opponent, "speed"),
      skill: aiProfile.skill,
      reachRatio: statRatio(lineup.opponent, "reach"),
      widthRatio: statRatio(lineup.opponent, "control", 0.5),
      role: "back",
      key: "opponent",
    }),
    opponentMate: createPaddle((COURT.left + COURT.right) / 2, COURT.netY - 84, false, {
      speed: aiProfile.speed * (0.9 + aiProfile.skill * 0.1) * statRatio(lineup.opponentMate, "speed"),
      skill: aiProfile.skill,
      reachRatio: statRatio(lineup.opponentMate, "reach"),
      widthRatio: statRatio(lineup.opponentMate, "control", 0.5),
      role: "net",
      key: "opponentMate",
    }),
    ball: createBall(),
    aiTargetX: (COURT.left + COURT.right) / 2,
    aiReactionDelay: 0,
    aiPrimaryKey: "opponent",
    aiReceiverLocked: false,
    aiShotPressure: 0,
    aiRecoveryMode: false,
    aiTeamShape: "defend",
    playerTeamTactic: "balanced",
    tacticFlash: 0,
    aiX3Recovery: 0,
    playerX3Recovery: 0,
    playerSwingBuffer: 0,
    queuedShotPower: 1,
    queuedShotAim: 0,
    queuedShotAimY: 0,
    queuedShotSlice: false,
    queuedShotVariant: "auto",
    queuedShotAge: 0,
    queuedShotCharge: 0,
    smashPrimed: false,
    cutVolleyPrimed: false,
    cutVolleyTapWindow: 0,
    globoPrimed: false,
    globoTapWindow: 0,
    smashTapWindow: 0,
    smashContactGrace: 0,
    smashContactFallback: false,
    shotCharge: 0,
    shotAim: 0,
    shotAimY: 0,
    shotIntent: "drive",
    activePlayerKey: "player",
    controlMode: "semi",
    switchCooldown: 0,
    receiverLocked: false,
    manualReceiverOverride: false,
    manualMovementTimer: 0,
    receiverSwitchFlash: 0,
    manualSwitchFlash: 0,
    hapticPulse: null,
    stats: {
      pointsWon: { player: 0, ai: 0 },
      aces: { player: 0, ai: 0 },
      winners: { player: 0, ai: 0 },
      errors: { player: 0, ai: 0 },
      smashWinners: { player: 0, ai: 0 },
      doubleFaults: { player: 0, ai: 0 },
      longestRally: 0,
      totalRallyHits: 0,
      rallyCount: 0,
    },
    replayFrames: [],
    replayMax: 720,
  };
  if (state.coop) {
    state.player.controlled = true;
    state.playerMate.controlled = true;
    state.activePlayerKey = "player";
  } else if (state.pvp) {
    state.opponent.controlled = true;
  }
  resetFx(state);
  prepareServe(state);
  return state;
}

export function addEvent(state, message) {
  state.events.unshift(message);
  if (state.events.length > 5) state.events.pop();
}

/** Azzera il buffer del replay all'inizio di ogni nuovo punto. */
export function resetReplayBuffer(state) {
  state.replayFrames = [];
}

function captureReplayFrame(state) {
  const { ball } = state;
  const snap = {
    serveSide: state.serveSide,
    serveCourt: state.serveCourt,
    activePlayerKey: state.activePlayerKey,
    ball: {
      x: ball.x, y: ball.y, z: ball.z,
      vx: ball.vx, vy: ball.vy, vz: ball.vz,
      spin: ball.spin, topspin: ball.topspin, backspin: ball.backspin,
      shotType: ball.shotType,
      serveInFlight: ball.serveInFlight,
      serveTouchedNet: ball.serveTouchedNet,
      bouncePulse: ball.bouncePulse,
      landRing: ball.landRing,
      hitFlash: ball.hitFlash ?? 0,
      hitPulse: ball.hitPulse ?? 0,
      trail: ball.trail.map((point) => ({ ...point })),
    },
    pads: [state.player, state.playerMate, state.opponent, state.opponentMate].map((p) => ({
      x: p.x, y: p.y, swing: p.swing, swingSide: p.swingSide,
      motion: p.motion, charge: p.charge, runPhase: p.runPhase,
      actionPose: p.actionPose, actionIntent: p.actionIntent, moveRatio: p.moveRatio,
    })),
  };
  state.replayFrames.push(snap);
  if (state.replayFrames.length > state.replayMax) state.replayFrames.splice(0, state.replayFrames.length - state.replayMax);
}

function serveTargetX(state) {
  const width = COURT.right - COURT.left;
  const isRightCourt = state.serveCourt === "right";
  return COURT.left + width * (isRightCourt ? 0.28 : 0.72);
}

function serviceOriginX(state) {
  const width = COURT.right - COURT.left;
  // Il battitore parte vicino alla T: resta nel proprio quadrante, ma non serve dalla recinzione laterale.
  return COURT.left + width * (state.serveCourt === "right" ? 0.61 : 0.39);
}

function serviceCourtBounds(state, paddle) {
  const middle = (COURT.left + COURT.right) / 2;
  const padding = paddle.w / 2 + 14;
  return state.serveCourt === "right"
    ? { min: middle + padding, max: COURT.right - padding }
    : { min: COURT.left + padding, max: middle - padding };
}

function partnerServiceX(state) {
  const width = COURT.right - COURT.left;
  return COURT.left + width * (state.serveCourt === "right" ? 0.31 : 0.69);
}

function resetPaddleForServe(paddle, x, y) {
  paddle.x = x;
  paddle.y = y;
  paddle.dashTimer = 0;
  paddle.hitCooldown = 0;
  paddle.swing = 0;
  paddle.swingSide = 1;
  paddle.motion = 0;
  paddle.moveRatio = 0;
}

function serviceReceiverKey(state) {
  return state.ball.serveTargetSide === "left" ? "player" : "playerMate";
}

function prepareOpponentServeReception(state) {
  const width = COURT.right - COURT.left;
  const leftX = COURT.left + width * 0.28;
  const rightX = COURT.left + width * 0.72;

  // In doubles each receiver owns one diagonal for the whole game.
  resetPaddleForServe(state.player, leftX, COURT.bottom - 74);
  resetPaddleForServe(state.playerMate, rightX, COURT.bottom - 74);
  state.serviceReceiverKey = serviceReceiverKey(state);

  if (state.activePlayerKey !== state.serviceReceiverKey) {
    setActivePlayer(state, state.serviceReceiverKey);
    state.receiverSwitchFlash = 0.65;
  }
  state.receiverLocked = true;
  state.manualReceiverOverride = false;
}

function prepareAiServeReception(state) {
  const width = COURT.right - COURT.left;
  resetPaddleForServe(state.opponent, COURT.left + width * 0.28, COURT.top + 74);
  resetPaddleForServe(state.opponentMate, COURT.left + width * 0.72, COURT.top + 74);
  state.aiServiceReceiverKey = state.ball.serveTargetSide === "left" ? "opponent" : "opponentMate";
  if (state.pvp) setPvpActive(state, state.aiServiceReceiverKey);
}

function preparePlayerServeFormation(state) {
  resetPaddleForServe(state.player, serviceOriginX(state), COURT.bottom - 78);
  resetPaddleForServe(state.playerMate, partnerServiceX(state), COURT.netY + 62);
  if (state.activePlayerKey !== "player") setActivePlayer(state, "player");
}

function prepareAiServeFormation(state) {
  resetPaddleForServe(state.opponent, serviceOriginX(state), COURT.top + 78);
  resetPaddleForServe(state.opponentMate, partnerServiceX(state), COURT.netY - 62);
}

function activePlayer(state) {
  return state[state.activePlayerKey];
}

function setActivePlayer(state, key, manual = false) {
  if (state.coop) return;
  if (state.activePlayerKey === key) return;
  state.activePlayerKey = key;
  state.player.controlled = key === "player";
  state.playerMate.controlled = key === "playerMate";
  state.switchCooldown = manual ? 0.7 : 0.28;
  const position = state[key].y > COURT.netY + 150 ? t("roleBackPos") : t("roleNetPos");
  addEvent(state, t("controlMsg", { position }));
}

function reflectedCourtX(x) {
  const min = COURT.left + 24;
  const max = COURT.right - 24;
  let reflected = x;
  while (reflected < min || reflected > max) {
    if (reflected < min) reflected = min + (min - reflected);
    if (reflected > max) reflected = max - (reflected - max);
  }
  return reflected;
}

/**
 * Quanto larga e' la fascia entro cui una racchetta arriva sulla palla.
 *
 * Erano due numeri scritti qui dentro, e dicevano una cosa che nessuno aveva
 * mai misurato: il giocatore copriva 0,78 della propria racchetta, l'IA fra
 * 0,50 e 0,64 della propria. Circa 196 px di fascia contro 150 della Leggenda —
 * il 30% di raggio in piu' per chi gioca, prima ancora di muoversi. E' da li'
 * che veniva la sensazione che ogni palla fosse raggiungibile.
 */
function contactWidth(paddle, ball) {
  if (paddle.isPlayer) return paddle.w * BALANCE.playerContactReach + ball.r;
  const skillReach = BALANCE.aiContactReachBase
    + clamp(paddle.skill, 0, 1) * BALANCE.aiContactReachSkill;
  return paddle.w * skillReach + ball.r;
}

function responderForecast(paddle, ball) {
  // Restituisce `contactX` in tutti i rami, come fa gia' `aiResponderForecast`.
  // Il valore veniva calcolato e poi buttato: chi leggeva questo oggetto per
  // posizionarsi trovava `undefined` e propagava un NaN nella coordinata della
  // racchetta. Le due funzioni sono gemelle e devono avere la stessa forma.
  if (!ballPlayableDirection("player", ball)) {
    return { score: Infinity, reachable: false, contactX: paddle.x };
  }
  const contactY = clamp(paddle.y, COURT.netY + 42, COURT.bottom - 42);
  const time = (contactY - ball.y) / ball.vy;
  if (time < 0.04 || time > 1.65) return { score: Infinity, reachable: false, contactX: paddle.x };

  const contactX = reflectedCourtX(ball.x + ball.vx * time);
  const contactZ = Math.max(0, ball.z + ball.vz * time - 0.5 * BALANCE.ballGravity * time * time);
  const horizontalReach = contactWidth(paddle, ball);
  const travelDistance = Math.max(0, Math.abs(contactX - paddle.x) - horizontalReach);
  const travelTime = travelDistance / paddle.speed;
  const lateBy = Math.max(0, travelTime - time);
  const heightPenalty = contactZ > BALANCE.playableHitHeight
    ? 1.4 + (contactZ - BALANCE.playableHitHeight) / 80
    : 0;

  return {
    score: travelTime + lateBy * 3.2 + heightPenalty,
    reachable: lateBy <= 0.1 && contactZ <= BALANCE.playableHitHeight + 12,
    contactX,
  };
}

function aiResponderForecast(paddle, ball) {
  if (!ballPlayableDirection("ai", ball)) {
    return { score: Infinity, reachable: false, contactX: paddle.x };
  }
  const contactY = clamp(paddle.y, COURT.top + 42, COURT.netY - 42);
  const time = (contactY - ball.y) / ball.vy;
  if (time < 0.04 || time > 1.8) return { score: Infinity, reachable: false, contactX: paddle.x };

  const contactX = reflectedCourtX(ball.x + ball.vx * time);
  const contactZ = Math.max(0, ball.z + ball.vz * time - 0.5 * BALANCE.ballGravity * time * time);
  const horizontalReach = contactWidth(paddle, ball);
  const travelDistance = Math.max(0, Math.abs(contactX - paddle.x) - horizontalReach);
  const travelTime = travelDistance / paddle.speed;
  const lateBy = Math.max(0, travelTime - time);
  const heightPenalty = contactZ > BALANCE.playableHitHeight
    ? 1.4 + (contactZ - BALANCE.playableHitHeight) / 80
    : 0;

  return {
    score: travelTime + lateBy * 3.2 + heightPenalty,
    reachable: lateBy <= 0.12 && contactZ <= BALANCE.playableHitHeight + 12,
    contactX,
  };
}

function bestResponder(state) {
  const back = responderForecast(state.player, state.ball);
  const net = responderForecast(state.playerMate, state.ball);
  return back.score <= net.score
    ? { key: "player", forecast: back, alternate: net }
    : { key: "playerMate", forecast: net, alternate: back };
}

function lockReceiverForIncomingShot(state, isServe = false) {
  if (state.coop) {
    state.receiverLocked = false;
    state.manualReceiverOverride = false;
    return;
  }
  if (!ballPlayableDirection("player", state.ball)) return;
  const choice = bestResponder(state);
  const controlMode = state.controlMode ?? "semi";
  let key = isServe ? (state.serviceReceiverKey ?? serviceReceiverKey(state)) : choice.key;
  const currentForecast = responderForecast(activePlayer(state), state.ball);
  const isCloseDecision = currentForecast.score <= choice.forecast.score + 0.1;
  if (!isServe) {
    if (controlMode === "manual") {
      state.receiverLocked = false;
      state.manualReceiverOverride = true;
      return;
    }
    if (controlMode === "semi") {
      const decisiveAdvantage = choice.forecast.score + 0.32 < currentForecast.score;
      const rescueNeeded = !currentForecast.reachable && choice.forecast.reachable;
      key = decisiveAdvantage || rescueNeeded ? choice.key : state.activePlayerKey;
    } else if (state.manualMovementTimer > 0 && currentForecast.reachable && isCloseDecision) {
      key = state.activePlayerKey;
    }
  }
  if (key !== state.activePlayerKey) {
    setActivePlayer(state, key);
    state.receiverSwitchFlash = 0.65;
  }
  state.receiverLocked = true;
  state.manualReceiverOverride = false;
}

function lockAiReceiverForIncomingShot(state, isServe = false) {
  if (!ballPlayableDirection("ai", state.ball)) return;
  const pace = Math.hypot(state.ball.vx, state.ball.vy);
  const pacePressure = clamp((pace - 250) / 270, 0, 1);
  const anglePressure = clamp(Math.abs(state.ball.vx) / 380, 0, 1);
  state.aiShotPressure = pacePressure * 0.55 + anglePressure * 0.45;
  let key = state.aiServiceReceiverKey;
  let forecast;
  if (isServe && key) {
    forecast = aiResponderForecast(state[key], state.ball);
  } else {
    const back = aiResponderForecast(state.opponent, state.ball);
    const mate = aiResponderForecast(state.opponentMate, state.ball);
    const bestKey = back.score <= mate.score ? "opponent" : "opponentMate";
    const bestForecast = bestKey === "opponent" ? back : mate;
    const committedKey = state.aiPrimaryKey;
    const committedForecast = committedKey === "opponent" ? back : mate;
    const commitmentChance = (1 - state.ai.skill) * (0.1 + state.aiShotPressure * 0.35);
    const canBeWrongFooted = committedKey !== bestKey
      && committedForecast.score <= bestForecast.score + 0.75;
    if (canBeWrongFooted && nextRandom(state) < commitmentChance) {
      key = committedKey;
      forecast = committedForecast;
    } else if (back.score <= mate.score) {
      key = "opponent";
      forecast = back;
    } else {
      key = "opponentMate";
      forecast = mate;
    }
  }
  state.aiPrimaryKey = key ?? "opponent";
  state.aiTargetX = forecast?.contactX ?? state[state.aiPrimaryKey].x;
  state.aiReceiverLocked = true;
  // La prontezza di riflessi e' separata dalla lettura di gioco. Sopra 0.78 di
  // reattivita' l'IA intercetta lo smash prima che tocchi il vetro e lo x2
  // smette di esistere: lo scalino sta fra 85 e 83 ms di reazione, due
  // millesimi. Un avversario piu' forte deve sbagliare meno e scegliere meglio,
  // non avere riflessi disumani.
  const reactionSkill = state.ai.reactionSkill ?? state.ai.skill;
  const baseReaction = 0.28 - reactionSkill * 0.25;
  // Anche questi due sono prontezza, non lettura: quanto la pressione la
  // rallenta e quanto facilmente resta controtempo.
  const pressurePenalty = state.aiShotPressure * (1 - reactionSkill) * 0.42;
  const wrongFootedChance = isServe
    ? 0
    : clamp(
      (state.aiShotPressure - 0.25) * (2 - reactionSkill * 1.8),
      0,
      0.7,
    );
  const wrongFooted = nextRandom(state) < wrongFootedChance;
  const wrongFootedDelay = wrongFooted ? 0.28 + state.aiShotPressure * 0.22 : 0;
  state.aiReactionDelay = isServe
    ? 0
    : clamp(baseReaction + pressurePenalty, 0.07, 0.42) + wrongFootedDelay;
  if (wrongFooted) addEvent(state, t("evCounter"));
}

function updateActivePlayer(state, dt, forceSwitch, switchDirection = null) {
  state.switchCooldown = Math.max(0, state.switchCooldown - dt);
  if (!forceSwitch && !switchDirection) return;
  if (state.serviceReceiverKey) {
    addEvent(state, t("evReceiverLock"));
    return;
  }
  const otherKey = state.activePlayerKey === "player" ? "playerMate" : "player";
  if (switchDirection) {
    const current = activePlayer(state);
    const alternate = state[otherKey];
    const dx = alternate.x - current.x;
    const dy = alternate.y - current.y;
    const length = Math.hypot(dx, dy) || 1;
    const directionLength = Math.hypot(switchDirection.x, switchDirection.y) || 1;
    const alignment = (dx / length) * (switchDirection.x / directionLength)
      + (dy / length) * (switchDirection.y / directionLength);
    if (alignment < 0.2) return;
  }
  setActivePlayer(state, otherKey, true);
  state.receiverSwitchFlash = 0;
  state.manualSwitchFlash = 0.55;
  if (state.receiverLocked || state.ball.vy > 0) {
    state.receiverLocked = true;
    state.manualReceiverOverride = true;
  }
}

export function prepareServe(state) {
  const isPlayer = state.serveSide === "player";
  state.serviceReceiverKey = null;
  state.aiServiceReceiverKey = null;
  state.receiverLocked = false;
  state.manualReceiverOverride = false;
  state.aiReceiverLocked = false;
  state.aiReactionDelay = 0;
  state.aiShotPressure = 0;
  state.aiRecoveryMode = false;
  state.smashPrimed = false;
  state.smashTapWindow = 0;
  state.cutVolleyPrimed = false;
  state.cutVolleyTapWindow = 0;
  state.globoPrimed = false;
  state.globoTapWindow = 0;
  state.smashContactGrace = 0;
  state.smashContactFallback = false;
  state.playerSwingBuffer = 0;
  state.queuedShotVariant = "auto";
  state.hitStop = 0;
  for (const paddle of [state.player, state.playerMate, state.opponent, state.opponentMate]) {
    paddle.smashPrimed = false;
    paddle.smashTapWindow = 0;
    paddle.smashContactGrace = 0;
    paddle.smashContactFallback = false;
    paddle.swingBuffer = 0;
    paddle.queuedShot = null;
  }
  state.ball = createBall();
  state.ball.serveTargetSide = state.serveCourt === "right" ? "left" : "right";
  if (isPlayer) {
    preparePlayerServeFormation(state);
    prepareAiServeReception(state);
  } else {
    prepareAiServeFormation(state);
    prepareOpponentServeReception(state);
  }
  const server = isPlayer ? state.player : state.opponent;
  state.ball.x = server.x + (isPlayer ? 28 : -28);
  state.ball.y = isPlayer ? server.y - 24 : server.y + 24;
  state.ball.z = 34;
  state.serving = true;
  state.serveTimer = state.serveSide === "ai" ? 0.75 : 0;
}

export function performServe(state, requestedCharge = null, slice = false) {
  const { ball } = state;
  const isPlayer = state.serveSide === "player";
  const server = isPlayer ? state.player : state.opponent;
  const charge = clamp(requestedCharge ?? (isPlayer ? state.shotCharge : 0.62), 0, 1);
  // Dispersione di esecuzione: senza di questa il servizio centrava sempre il
  // riquadro e seconda palla, doppio fallo e `serveAttempts` erano irraggiungibili.
  // Cresce con la carica e cala con il controllo dell'atleta; la seconda palla
  // e' piu' prudente, come farebbe chiunque dopo un errore.
  const serverControl = isPlayer
    ? athleteFor(state, server).stats.control
    : (0.92 + state.ai.skill * 0.1) * paddleRatio(state, server, "control", 0.6);
  const secondServe = state.serveAttempts > 0;
  const spread = BALANCE.serveSpread
    * (BALANCE.serveSpreadBase + charge * charge * (1 - BALANCE.serveSpreadBase))
    * clamp(1.62 - serverControl, 0.3, 1.0)
    * (secondServe ? BALANCE.serveSecondSafety : 1);
  const depthError = (nextRandom(state) - 0.5) * 2 * spread * BALANCE.serveDepthSpread;
  const lateralError = (nextRandom(state) - 0.5) * 2 * spread;
  const serviceBoxDepth = SERVICE_LINE_OFFSET * (0.24 + charge * 0.52) + depthError;
  const targetY = isPlayer ? COURT.netY - serviceBoxDepth : COURT.netY + serviceBoxDepth;
  // Il servizio deve aprire lo scambio, non chiuderlo: tempo di volo tenuto
  // sopra quello di un drive anche a carica piena.
  const time = BALANCE.serveFlightBase - charge * BALANCE.serveFlightGain;
  const dragRate = -60 * Math.log(BALANCE.airDrag);
  const dragDistanceFactor = dragRate > 0.0001
    ? (1 - Math.exp(-dragRate * time)) / (dragRate * time)
    : 1;
  const dragCompensation = 1 / dragDistanceFactor;
  const targetX = serveTargetX(state) + lateralError;
  ball.serveTargetSide = state.serveCourt === "right" ? "left" : "right";
  ball.serveTargetX = targetX;
  ball.serveTargetY = targetY;
  if (isPlayer) prepareAiServeReception(state);
  else prepareOpponentServeReception(state);
  sfx.serve();
  emitSteam(state, ball.x, ball.y, ball.z);
  ball.vx = ((targetX - ball.x) / time) * dragCompensation;
  ball.vy = ((targetY - ball.y) / time) * dragCompensation;
  ball.vz = BALANCE.ballGravity * time * 0.5 - ball.z / time + 18 + (1 - charge) * 18;
  ball.spin = (state.serveCourt === "right" ? -1 : 1) * 14;
  ball.backspin = slice ? 0.75 : 0;
  if (slice) ball.spin *= 1.8;
  ball.served = true;
  ball.serveInFlight = true;
  ball.serveTouchedNet = false;
  ball.netFaultOwner = null;
  ball.bounces = { player: 0, ai: 0 };
  ball.crossedNet = false;
  state.lastHitterSide = state.serveSide;
  ball.trail = [];
  ball.trailTime = 0;
  ball.landRing = 0;
  state.serving = false;
  state.rallyHits = 0;
  state.combo = 1;
  server.shotIntent = "serve";
  server.actionIntent = "serve";
  server.actionPose = 0.46;
  server.swing = 1;
  server.swingSide = state.serveCourt === "right" ? -1 : 1;
  if (isPlayer) lockAiReceiverForIncomingShot(state, true);
  else lockReceiverForIncomingShot(state, true);
}

function canHit(paddle, ball) {
  // The returner must let a serve bounce in the diagonal service box.
  if (ball.serveInFlight || ball.netFaultOwner) return false;
  const withinX = Math.abs(ball.x - paddle.x) < contactWidth(paddle, ball);
  // Profondita' della finestra di contatto. Era 1,3 dell'allungo per tutti, e
  // in pixel faceva 134 su una meta' campo profonda 254: si colpiva una palla
  // lontana piu' di mezza profondita' di campo. In orizzontale la fascia e' il
  // 22% della larghezza, in verticale era il 53% — di qui la sensazione che il
  // colpo venisse dato buono anche stando distanti.
  const withinY = Math.abs(ball.y - paddle.y) < paddle.reach * (paddle.isPlayer
    ? BALANCE.playerDepthReach
    : BALANCE.aiDepthReach);
  const side = paddle.isPlayer ? "player" : "ai";
  return withinX && withinY && ballPlayableDirection(side, ball)
    && ball.z <= BALANCE.playableHitHeight;
}

function crossedPaddle(paddle, ball, previousBall) {
  if (!previousBall || ball.z > BALANCE.playableHitHeight) return false;
  const side = paddle.isPlayer ? "player" : "ai";
  if (!ballPlayableDirection(side, ball)) return false;
  const crossedY = (previousBall.y - paddle.y) * (ball.y - paddle.y) <= 0;
  if (!crossedY) return false;
  const distance = ball.y - previousBall.y;
  if (Math.abs(distance) < 0.001) return false;
  const t = clamp((paddle.y - previousBall.y) / distance, 0, 1);
  const contactX = previousBall.x + (ball.x - previousBall.x) * t;
  return Math.abs(contactX - paddle.x) <= contactWidth(paddle, ball);
}

function hitPowerProfile(paddle, state, power) {
  if (paddle.isPlayer) return power * athleteFor(state, paddle).stats.power;
  if (state.pvp && paddle.controlled) return power * (state.pvpAthlete?.stats.power ?? state.ai.power);
  return power * state.ai.power * paddleRatio(state, paddle, "power");
}

function shotSide(paddle) {
  return paddle.isPlayer ? "player" : "ai";
}

function shotMode(charge) {
  if (charge < 0.2) return "control";
  if (charge > 0.7) return "power";
  return "balanced";
}

function shotProfile(charge, aim, quality) {
  const aggression = charge * 0.72 + Math.abs(aim) * 0.28;
  if (aggression > 0.88 && quality >= 0.62) return "risk";
  if (aggression > 0.42) return "attack";
  return "control";
}

/**
 * Finestra perfetta contestuale: corsa, energia e uscita dal vetro la
 * restringono, lo split-step la allarga. Usata sia dal meter a schermo sia dal
 * calcolo del voto, cosi' quello che il giocatore vede e' quello che paga.
 *
 * La carica pesa in modo quadratico: il tocco di controllo e la carica
 * intermedia restano indulgenti, il costo si concentra nella fascia di potenza.
 */
function contextualPerfectWindow(state, paddle, charge = 0) {
  const { ball } = state;
  const side = shotSide(paddle);
  const moving = clamp(paddle.moveRatio ?? paddle.motion ?? 0, 0, 1);
  const energy = clamp(state.rallyEnergy?.[side] ?? 1, 0, 1);
  const glassBall = ball.postGlassSide === side;
  const power = clamp(charge, 0, 1) ** 2;
  return clamp(
    BALANCE.perfectTimingWindow
      - moving * BALANCE.timingWindowRunPenalty
      - Math.max(0, 0.65 - energy) * BALANCE.timingWindowEnergyPenalty
      - (glassBall ? BALANCE.timingWindowGlassPenalty : 0)
      - power * BALANCE.timingWindowChargePenalty
      + clamp(paddle.splitStep ?? 0, 0, 1) * BALANCE.timingWindowSplitStepBonus,
    BALANCE.timingWindowMin,
    BALANCE.timingWindowMax,
  );
}

/**
 * Tempo che manca al primo contatto realmente possibile. Non basta incrociare
 * la linea del giocatore: finche' la palla resta sopra `playableHitHeight` non
 * e' colpibile, quindi su lob e uscite di vetro l'attesa e' quella della
 * discesa sotto il tetto di gioco.
 */
function playableEta(state, paddle) {
  const { ball } = state;
  if (!(ball.vy > 28)) return null;
  const timeToLine = (paddle.y - ball.y) / ball.vy;
  if (!Number.isFinite(timeToLine)) return null;
  const ceiling = BALANCE.playableHitHeight;
  const g = BALANCE.ballGravity;
  const zAtLine = ball.z + ball.vz * timeToLine - 0.5 * g * timeToLine * timeToLine;
  if (zAtLine <= ceiling) return timeToLine;
  // La palla arriva troppo alta: il contatto utile e' la discesa sotto il tetto,
  // che avviene sempre prima del rimbalzo.
  const discriminant = ball.vz * ball.vz + 2 * g * (ball.z - ceiling);
  if (discriminant < 0) return timeToLine;
  const descendingCrossing = (ball.vz + Math.sqrt(discriminant)) / g;
  return Math.max(timeToLine, descendingCrossing);
}

function updateShotRead(state, paddle) {
  const { ball } = state;
  const incoming = ballPlayableDirection("player", ball) && ball.y > COURT.netY;
  const eta = incoming ? playableEta(state, paddle) : null;
  const glassBall = ball.postGlassSide === "player";
  const nearGlass = paddle.y > COURT.bottom - 145 || glassBall;
  const nearNet = paddle.y < COURT.netY + 145;
  const highBall = ball.z >= BALANCE.smashMinHeight;
  const opponentsForward = opponentsNearNet("ai", [state.opponent, state.opponentMate]);
  let advice = "read";
  if (incoming) {
    if (nearGlass && ball.z < 62) advice = opponentsForward ? "lob" : "chiquita";
    else if (nearNet && highBall) advice = "smash";
    else if (nearNet && ball.z >= 42) advice = "vibora";
    else if (opponentsForward && ball.z < 48) advice = "lob";
    else advice = "drive";
  }
  const perfectWindow = contextualPerfectWindow(state, paddle, state.shotCharge ?? 0);
  const moving = clamp(paddle.moveRatio ?? 0, 0, 1);
  const profile = shotProfile(state.shotCharge, state.shotAim, clamp(1 - moving * 0.25, 0, 1));
  const mate = state.playerMate;
  const overlap = Math.abs(paddle.x - mate.x) < (paddle.w + mate.w) * 0.52
    && Math.abs(paddle.y - mate.y) < 92;
  // Anteprima dell'angolo stretto: stessa formula che usera' il colpo, cosi'
  // l'indicatore non promette qualcosa di diverso da quello che accade.
  const aimFreedom = profile === "control" ? 0.78 : profile === "attack" ? 0.96 : 1.1;
  const previewOffset = clamp(
    (state.shotAim ?? 0) * (athleteFor(state, paddle)?.stats.control ?? 1) * aimFreedom,
    -1,
    1,
  );
  const precision = clamp(state.shotPrecision ?? 0, 0, 1);
  const tight = precision * clamp((Math.abs(previewOffset) - 0.55) / 0.35, 0, 1);
  state.shotRead = {
    active: incoming && eta !== null && eta > -0.16 && eta < 1.15,
    eta,
    perfectWindow,
    advice,
    profile,
    overlap,
    precision,
    tight,
  };
}

function evaluateShotQuality(
  state,
  paddle,
  { charge = 0.5, aim = 0, variant = "drive", timingAge = 0, aiTiming = null } = {},
) {
  const { ball } = state;
  const side = shotSide(paddle);
  const passedDistance = Math.max(0, (ball.y - paddle.y) * (paddle.isPlayer ? 1 : -1));
  const lateralDistance = Math.abs(ball.x - paddle.x) / Math.max(1, contactWidth(paddle, ball));
  const longitudinalDistance = Math.abs(ball.y - paddle.y) / Math.max(1, paddle.reach * 1.3);
  const contactDistance = Math.hypot(lateralDistance * 0.82, longitudinalDistance * 0.58);
  const position = clamp(1.08 - contactDistance * 0.58 - passedDistance / 155, 0.18, 1);
  const sprintPenalty = clamp(paddle.sprinting ?? 0, 0, 1) * BALANCE.sprintAccuracyPenalty;
  const splitStepBonus = clamp(paddle.splitStep ?? 0, 0, 1) * BALANCE.splitStepQualityBonus;
  const movementPenalty = clamp(paddle.moveRatio ?? paddle.motion ?? 0, 0, 1) * 0.22 + sprintPenalty;
  const balance = clamp(1 - movementPenalty - Math.max(0, lateralDistance - 0.68) * 0.32, 0.28, 1);
  // La finestra e' la stessa mostrata dal meter: se corsa, energia o vetro la
  // stringono, si comprime anche la discesa verso il voto sufficiente.
  const perfectWindow = aiTiming === null || aiTiming === undefined
    ? contextualPerfectWindow(state, paddle, charge)
    : BALANCE.perfectTimingWindow;
  const windowRatio = perfectWindow / BALANCE.perfectTimingWindow;
  const earlyMiss = Math.max(0, timingAge - perfectWindow)
    / Math.max(0.01, BALANCE.goodTimingWindow * BALANCE.timingDecaySpan * windowRatio);
  const lateMiss = passedDistance / (paddle.reach * BALANCE.lateGraceFactor * 4.6);
  const timing = aiTiming ?? clamp(1 - earlyMiss - lateMiss, 0.18, 1);
  // Lo scarto oltre il corpo era una costante di 12 px: circa un decimo della
  // racchetta, abbastanza da mancare il perfetto anche con un rilascio pulito.
  // Legarlo all'allungo lo rende coerente con la statistica dell'atleta.
  const lateGrace = paddle.reach * BALANCE.lateGraceFactor;
  // Direzione dell'errore, non solo entita': colpire in ritardo allunga il
  // colpo, anticiparlo lo accorcia. Serve a dare un verso alla dispersione.
  const timingBias = aiTiming === null || aiTiming === undefined
    ? clamp(lateMiss - earlyMiss, -1, 1)
    : 0;
  const overhead = variant === "smash" || variant.startsWith("smash-");
  const height = overhead
    ? clamp((ball.z - 42) / 35, 0.2, 1)
    : clamp(1 - Math.max(0, ball.z - 82) / 100, 0.55, 1);
  const energy = clamp(state.rallyEnergy?.[side] ?? 1, BALANCE.rallyEnergyFloor, 1);
  const control = paddle.isPlayer
    ? clamp(athleteFor(state, paddle).stats.control / 1.22, 0.72, 1.05)
    : state.pvp && paddle.controlled
      ? clamp((state.pvpAthlete?.stats.control ?? 1) / 1.22, 0.72, 1.05)
      : clamp((0.72 + state.ai.skill * 0.34) * paddleRatio(state, paddle, "control", 0.6), 0.72, 1.02);
  // Il timing e' la voce dominante, e deve esserlo: e' l'unica interamente in
  // mano al giocatore in quel decimo di secondo. Pesava 0,34 con posizione,
  // equilibrio e altezza a 0,51 sommati — si compensava un contatto in ritardo
  // stando semplicemente fermi nel posto giusto, e la bravura non si sentiva.
  const quality = clamp(
    timing * BALANCE.qualityTimingWeight
      + position * 0.21
      + balance * 0.12
      + height * 0.1
      + energy * 0.08
      + control * 0.05
      + splitStepBonus,
    0,
    1,
  );
  const mode = shotMode(charge);
  const aggression = clamp(
    charge * 0.72 + Math.abs(aim) * 0.28 + (overhead ? 0.16 : 0),
    0,
    1.2,
  );
  const risk = clamp(
    (1 - quality) * (0.48 + aggression * 0.82)
      + Math.max(0, Math.abs(aim) - 0.72) * 0.5
      + (mode === "power" ? Math.max(0, 0.62 - energy) * 0.42 : 0),
    0,
    1.25,
  );
  const profile = shotProfile(charge, aim, quality);
  const grade = timing >= 0.9
    ? "perfect"
    : passedDistance > lateGrace
      ? "late"
      : timing >= 0.7
        ? "good"
        : "early";
  return { quality, timing, timingBias, position, balance, height, energy, aggression, risk, profile, mode, grade };
}

/**
 * Resistenza dell'atleta al lavoro dello scambio. Prima `stats.stamina` viveva
 * in un solo punto del motore — la ricarica dell'abilita' speciale — e non
 * toccava `rallyEnergy`, che invece governa qualita', finestra di timing e
 * tasso d'errore. Il ruolo "Resistenza" non esisteva meccanicamente.
 */
function rallyStamina(state, side) {
  // `rallyEnergy` e' una risorsa di squadra, non di racchetta: si consuma e si
  // recupera per meta' campo. Con due atleti diversi in coppia la resistenza
  // che conta e' quindi la media dei due, non quella di chi tira in quel
  // momento — altrimenti la stessa squadra avrebbe due energie diverse a
  // seconda di chi ha toccato per ultimo.
  const media = (uno, due) => {
    const a = uno?.stats.stamina;
    const b = due?.stats.stamina;
    if (a === undefined && b === undefined) return 1;
    if (a === undefined) return b;
    if (b === undefined) return a;
    return (a + b) / 2;
  };
  if (side !== "player") {
    if (state.pvp) return clamp(state.pvpAthlete?.stats.stamina ?? 1, 0.7, 1.5);
    return clamp(media(state.lineup?.opponent, state.lineup?.opponentMate), 0.7, 1.5);
  }
  return clamp(media(state.athlete, state.lineup?.playerMate), 0.7, 1.5);
}

function consumeRallyEnergy(state, paddle, assessment, variant, slice) {
  const side = shotSide(paddle);
  const isSmash = variant === "smash" || variant.startsWith("smash-");
  const isLob = variant === "lob" || variant === "defensive-lob";
  const baseCost = variant === "globo"
    ? BALANCE.globoEnergyCost
    : variant === "chiquita" ? 0.025 : slice ? 0.035 : isLob ? 0.055 : isSmash ? 0.13 : 0.045;
  const powerCost = assessment.mode === "power" ? 0.095 : assessment.mode === "balanced" ? 0.04 : 0.012;
  const movementCost = (paddle.moveRatio ?? 0) * 0.025;
  state.rallyEnergy[side] = clamp(
    state.rallyEnergy[side] - (baseCost + powerCost + movementCost) / rallyStamina(state, side),
    BALANCE.rallyEnergyFloor,
    1,
  );
}

function showShotFeedback(state, paddle, assessment) {
  if (!paddle.controlled) return;
  // Hit-stop sul contatto perfetto: il colpo si sente prima ancora di leggerlo.
  if (assessment.grade === "perfect" && !isReduceMotion()) {
    state.hitStop = BALANCE.hitStopPerfect;
  }
  const labels = {
    perfect: t("shotPerfect"),
    good: t("shotGood"),
    early: t("shotEarly"),
    late: t("shotLate"),
  };
  state.shotFeedback = {
    text: labels[assessment.grade],
    mode: t(`shotMode${assessment.mode[0].toUpperCase()}${assessment.mode.slice(1)}`),
    profile: assessment.profile,
    grade: assessment.grade,
    quality: assessment.quality,
    life: 0.78,
    paddleKey: paddle.key ?? state.activePlayerKey,
  };
}

function computerProfile(state, paddle) {
  if (!paddle.isPlayer) return state.ai;
  const compagno = athleteFor(state, paddle);
  const control = compagno.stats.control;
  return {
    skill: clamp(0.6 + (control - 0.9) * 0.34, 0.58, 0.78),
    power: compagno.stats.power,
    speed: paddle.speed,
  };
}

function targetYForSide(side, depth) {
  return side === "ai" ? COURT.netY - depth : COURT.netY + depth;
}

function opponentsNearNet(opponentSide, opponents) {
  const averageY = (opponents[0].y + opponents[1].y) / 2;
  return opponentSide === "ai"
    ? averageY > COURT.netY - 132
    : averageY < COURT.netY + 132;
}

/**
 * Quanto e' avanti la coppia avversaria: 0 sul proprio fondo, 1 sotto rete.
 *
 * `opponentsNearNet` risponde si' o no, con la soglia a meta' campo, e da quel
 * si' o no dipendeva se pallonettare. Misurato: contro un giocatore incollato
 * alla rete la Leggenda alzava la palla nel 45% dei casi, contro uno a meta'
 * campo nello 0%. Bastava staccarsi di venti pixel dalla soglia per non essere
 * mai piu' pallonettati — e prendere il centro del campo diventava gratis, che
 * e' il contrario di come si gioca a padel.
 */
function opponentsForwardness(opponentSide, opponents) {
  const averageY = (opponents[0].y + opponents[1].y) / 2;
  const profondita = COURT.bottom - COURT.netY - 40;
  const distanzaDallaRete = opponentSide === "ai"
    ? COURT.netY - averageY
    : averageY - COURT.netY;
  return clamp(1 - distanzaDallaRete / profondita, 0, 1);
}

function paddleUnderPressure(paddle) {
  return paddle.isPlayer
    ? paddle.y > COURT.netY + 168
    : paddle.y < COURT.netY - 168;
}

/**
 * Quanto e' attaccabile la palla in arrivo, da 0 a 1. Guarda l'altezza reale
 * del contatto (non quella gia' schiacciata dal clamp di lancio), quanto la
 * palla e' lenta e quanto avanti la si puo' prendere. Un pallonetto corto e
 * molle punteggia alto; una palla tesa e profonda punteggia basso.
 */
function attackRead(state, paddle, contactHeight) {
  const { ball } = state;
  const height = clamp(
    (contactHeight - BALANCE.attackReadHeightLo)
      / (BALANCE.attackReadHeightHi - BALANCE.attackReadHeightLo),
    0,
    1,
  );
  const speed = Math.hypot(ball.vx, ball.vy);
  const slow = clamp(
    1 - (speed - BALANCE.attackReadSlowSpeed)
      / (BALANCE.attackReadFastSpeed - BALANCE.attackReadSlowSpeed),
    0,
    1,
  );
  const reach = BALANCE.attackReadAdvance;
  const advance = paddle.isPlayer
    ? clamp((COURT.netY + reach - paddle.y) / reach, 0, 1)
    : clamp((paddle.y - (COURT.netY - reach)) / reach, 0, 1);
  return clamp(
    height * BALANCE.attackReadWeightHeight
      + slow * BALANCE.attackReadWeightSlow
      + advance * BALANCE.attackReadWeightAdvance,
    0,
    1,
  );
}

function chooseComputerShot(state, paddle, profile, contactHeight = 0, aiTiming = 1) {
  const opponentSide = paddle.isPlayer ? "ai" : "player";
  const opponents = opponentSide === "ai"
    ? [state.opponent, state.opponentMate]
    : [state.player, state.playerMate];
  const coverageX = (opponents[0].x + opponents[1].x) / 2;
  const centerX = (COURT.left + COURT.right) / 2;
  const sideBias = coverageX <= centerX ? 1 : -1;
  const accuracyError = (1 - profile.skill) * 44;
  const atNet = paddle.isPlayer
    ? paddle.y < COURT.netY + 126
    : paddle.y > COURT.netY - 126;
  const pressured = paddleUnderPressure(paddle) || state.ball.z < 38;
  const opponentsAreForward = opponentsNearNet(opponentSide, opponents);
  // Quanto conviene alzarla: cresce con quanto sono avanti gli avversari e con
  // la bravura di chi tira. Prima era una soglia secca sulla posizione e una
  // probabilita' fissa, quindi il pallonetto spariva del tutto appena il
  // giocatore arretrava di poco. Un avversario sotto pressione la alza comunque:
  // e' la palla di emergenza.
  const avanzamento = Math.max(
    opponentsForwardness(opponentSide, opponents),
    pressured ? BALANCE.aiLobPressure : 0,
  );
  const lobChance = clamp(
    BALANCE.aiLobBase
      + avanzamento * (BALANCE.aiLobForward + profile.skill * BALANCE.aiLobSkill),
    0,
    0.85,
  );
  const choice = nextRandom(state);
  const overheadReady = atNet && contactHeight >= 58 && state.rallyHits > 0;
  // Su una palla attaccabile la frequenza dello smash sale, e sale di piu' con
  // la difficolta': e' li' che il Campione deve distinguersi dal Rivale.
  const attack = attackRead(state, paddle, contactHeight);
  const smashChance = clamp(
    0.08 + profile.skill * 0.14
      + attack * (BALANCE.attackReadSmashGain + profile.skill * BALANCE.attackReadSmashSkillGain),
    0,
    BALANCE.attackReadSmashCap,
  );

  // Rispondendo a uno smash: se l'ha letto bene puo' controbattere e restare
  // in attacco, altrimenti e' costretta a rimetterla alta e ricominciare.
  const returningSmash = isSmashShot(state.incomingShot);
  if (returningSmash && aiTiming < BALANCE.smashReturnCounterTiming) {
    return {
      kind: "lob",
      x: clamp(centerX + (nextRandom(state) - 0.5) * 180, COURT.left + 120, COURT.right - 120),
      y: targetYForSide(opponentSide, 196),
      flightTime: 1.34,
    };
  }
  let kind = "drive";
  if (overheadReady && choice < smashChance) {
    const x3Chance = clamp((profile.skill - 0.48) * 0.55, 0.02, 0.16);
    kind = nextRandom(state) < x3Chance ? "smash-x3" : "smash-x2";
  } else if (!(atNet && contactHeight >= 46)
    && choice < lobChance) {
    // Pallonettare stando a rete su una palla alta e' gioco sbagliato.
    kind = "lob";
  } else if (atNet && state.ball.z > 42 && choice < 0.78 + attack * BALANCE.attackReadVolleyGain) {
    kind = nextRandom(state) < 0.28 + profile.skill * 0.12 ? "vibora" : "volley";
  }

  const shotSetups = {
    lob: { depth: 202, lateral: 76, margin: 92, flightTime: 1.28 },
    "smash-x2": { depth: 222, lateral: 52, margin: 82, flightTime: 0.62 },
    "smash-x3": { depth: 218, lateral: 260, margin: 48, flightTime: 0.66 },
    vibora: { depth: 154, lateral: 184, margin: 68, flightTime: 0.84 },
    volley: { depth: 132, lateral: 142, margin: 76, flightTime: 0.8 },
    drive: { depth: 168, lateral: 126, margin: 84, flightTime: 0.98 },
  };
  const setup = shotSetups[kind] ?? shotSetups.drive;
  // Quanto largo mira, non quanto sbaglia. Erano due cose confuse in una: il
  // bersaglio stava a `lateral` fisso dal centro — 126 px per il drive su una
  // semi-larghezza di 400, cioe' il 31% — e l'unica cosa che cambiava con la
  // bravura era la dispersione, che *cala*. Ne seguiva che la Leggenda fosse
  // piu' centrale dell'Ingegnere: misurato, i suoi colpi cadevano nel terzo
  // centrale nel 100% dei casi contro l'83%, e mai uno vicino alla riga.
  // Adesso l'ampiezza della mira cresce con la difficolta'; la precisione con
  // cui la rispetta continua a crescere per conto suo.
  const ampiezza = BALANCE.aiAimWidthBase + profile.skill * BALANCE.aiAimWidthSkill;
  const x = clamp(
    centerX + sideBias * setup.lateral * ampiezza + (nextRandom(state) - 0.5) * accuracyError,
    COURT.left + setup.margin,
    COURT.right - setup.margin,
  );
  return {
    kind,
    x,
    y: targetYForSide(opponentSide, setup.depth),
    flightTime: setup.flightTime * (1.06 - profile.skill * 0.08),
  };
}

function aiShotError(state, profile, assessment, kind = "drive") {
  // Gli errori derivano da pressione, energia e qualità del contatto, come per il giocatore.
  const rally = Math.min(1, Math.max(0, (state.rallyHits - 2) / 10));
  const aggressive = kind === "smash-x2" || kind === "smash-x3" || kind === "vibora";
  // Il dado sulla difficolta' pesava sette volte l'esecuzione: gli errori
  // dell'IA non corrispondevano a nulla di visibile. Ora la quota maggiore
  // viene da quanto ha eseguito male, con la stessa soglia del giocatore.
  const executionMiss = clamp(
    (BALANCE.shotErrorThreshold - assessment.quality) / BALANCE.shotErrorSpan,
    0,
    1,
  );
  const chance = clamp(
    ((1 - profile.skill) ** 2) * BALANCE.aiErrorSkillWeight
      + executionMiss ** BALANCE.shotErrorCurve * BALANCE.aiErrorExecutionWeight
      + assessment.risk * (1 - profile.skill) * 0.1
      + rally * (1 - assessment.energy) * 0.12
      + (aggressive ? 0.025 : 0),
    0.02,
    0.38,
  );
  const roll = nextRandom(state);
  if (roll < chance * (aggressive ? 0.34 : 0.16)) return { type: "out" };
  return roll < chance ? { type: "short" } : null;
}

/**
 * Errore del giocatore: stessa forma di `aiShotError`, cioe' una decisione
 * unica presa al momento del colpo e non una probabilita' rivalutata a ogni
 * fotogramma. Il tipo segue la causa, cosi' l'errore resta leggibile: in
 * ritardo si allunga, in anticipo si affossa, con la mira estrema si esce.
 */
function rollShotError(state, assessment, aimedOffset, tight = 0, tightDepth = 0) {
  const miss = clamp(
    (BALANCE.shotErrorThreshold - assessment.quality) / BALANCE.shotErrorSpan,
    0,
    1,
  );
  if (miss <= 0) return null;
  const chance = miss ** BALANCE.shotErrorCurve * BALANCE.shotErrorMaxChance;
  if (nextRandom(state) >= chance) return null;
  // Con l'angolo stretto l'errore esce di lato: e' la direzione coerente con
  // quello che stavi tentando, non una deviazione qualsiasi.
  const wideShare = BALANCE.shotErrorWideShare
    + clamp(tight, 0, 1) * (BALANCE.tightAngleWideShare - BALANCE.shotErrorWideShare);
  // Cercando la profondita' estrema l'errore esce lungo, non di lato.
  if (tightDepth > 0.02 && nextRandom(state) < clamp(tightDepth, 0, 1) * BALANCE.tightDepthLongShare) {
    return { type: "long" };
  }
  if (Math.abs(aimedOffset) >= BALANCE.shotErrorWideAim && nextRandom(state) < wideShare) {
    return { type: "wide" };
  }
  return assessment.timingBias > 0.05 ? { type: "long" } : { type: "net" };
}

function reportShotError(state, paddle, shotError) {
  if (!paddle.controlled) return;
  addEvent(state, t(
    shotError.type === "long" ? "evShotLong"
      : shotError.type === "wide" ? "evShotWide"
        : "evShotNet",
  ));
}

/** Il colpo in arrivo era uno smash? Va letto prima che hitBall lo sovrascriva. */
/**
 * Distanza dalla rete misurata dal lato giusto. Il ramo del giocatore usava una
 * formula scritta per il campo basso: in pvp il secondo umano controlla un
 * paddle del lato opposto, dove risultava sempre "vicino a rete" — quindi aveva
 * smash e vibora disponibili anche incollato al vetro di fondo.
 */
function withinNetRange(paddle, window) {
  return paddle.isPlayer
    ? paddle.y <= COURT.netY + window
    : paddle.y >= COURT.netY - window;
}

function isSmashShot(shotType) {
  return shotType === "smash"
    || shotType === "smash-x2"
    || shotType === "smash-x3"
    || shotType === "smash-flat";
}

function setComputerTrajectory(ball, targetX, targetY, flightTime) {
  const dragRate = -60 * Math.log(BALANCE.airDrag);
  const dragDistanceFactor = dragRate > 0.0001
    ? (1 - Math.exp(-dragRate * flightTime)) / (dragRate * flightTime)
    : 1;
  const dragCompensation = 1 / dragDistanceFactor;
  ball.vx = ((targetX - ball.x) / flightTime) * dragCompensation;
  ball.vy = ((targetY - ball.y) / flightTime) * dragCompensation;
  ball.vz = (BALANCE.ballGravity * flightTime * flightTime * 0.5 - ball.z) / flightTime;
}

function applyComputerShot(state, paddle, contactHeight = 0) {
  const { ball } = state;
  ball.backspin = 0;
  const opponentSide = paddle.isPlayer ? "ai" : "player";
  const centerX = (COURT.left + COURT.right) / 2;
  const profile = computerProfile(state, paddle);
  // Il timing viene estratto PRIMA della scelta: rispondendo a uno smash l'IA
  // deve sapere quanto bene lo sta leggendo, altrimenti non puo' decidere se
  // difendersi o controbattere.
  const pressure = paddle.isPlayer ? 0 : state.aiShotPressure;
  // La difficolta' agisce sull'esecuzione: un avversario debole non tira un
  // dado d'errore, colpisce peggio e piu' irregolarmente. Distribuzioni che si
  // sovrapponevano quasi del tutto strozzavano errori, controbattuta e lettura.
  const timingVariance = (nextRandom(state) - 0.5)
    * Math.max(0.05, BALANCE.aiTimingSpread - profile.skill * BALANCE.aiTimingSpreadSkill);
  const aiTiming = clamp(
    BALANCE.aiTimingBase + profile.skill * BALANCE.aiTimingSkill
      - pressure * 0.25 + timingVariance,
    0.25,
    1,
  );
  const target = chooseComputerShot(state, paddle, profile, contactHeight, aiTiming);
  const aiCharge = target.kind === "lob" || target.kind === "drive"
    ? 0.38 + profile.skill * 0.34
    : 0.62 + profile.skill * 0.28;
  const targetAim = clamp(
    (target.x - centerX) / ((COURT.right - COURT.left) * 0.42),
    -1,
    1,
  );
  const assessment = evaluateShotQuality(state, paddle, {
    charge: aiCharge,
    aim: targetAim,
    variant: target.kind,
    aiTiming,
  });
  const error = aiShotError(state, profile, assessment, target.kind);
  consumeRallyEnergy(state, paddle, assessment, target.kind, target.kind === "vibora");

  if (error?.type === "out") {
    const targetY = opponentSide === "ai" ? COURT.top - 34 : COURT.bottom + 34;
    setComputerTrajectory(ball, centerX + (nextRandom(state) - 0.5) * 260, targetY, 0.78);
    ball.shotType = "error";
    if (!paddle.isPlayer) addEvent(state, t("evAiForced"));
    return;
  }

  if (error?.type === "short") {
    // Palla debole ma valida: resta oltre la rete e offre tempo per attaccare.
    const variant = nextRandom(state);
    let targetX;
    let targetY;
    let flightTime;
    if (variant < 0.45) {
      // Lob lento centrale a mezzo campo.
      targetX = centerX + (nextRandom(state) - 0.5) * 220;
      targetY = targetYForSide(opponentSide, 142);
      flightTime = 1.16;
    } else if (variant < 0.75) {
      // Palla larga vicino al vetro: scomoda ma recuperabile.
      targetX = nextRandom(state) < 0.5 ? COURT.left + 82 : COURT.right - 82;
      targetY = targetYForSide(opponentSide, 176);
      flightTime = 1.08;
    } else {
      // Smorzata troppo alta: invito a scendere a rete.
      targetX = centerX + (nextRandom(state) - 0.5) * 130;
      targetY = targetYForSide(opponentSide, 78);
      flightTime = 1.02;
    }
    setComputerTrajectory(ball, targetX, targetY, flightTime);
    ball.backspin = 0.3;
    ball.spin = clamp(ball.vx * 0.05, -18, 18);
    if (!paddle.isPlayer) {
      state.aiRecoveryMode = true;
      addEvent(state, t("evOppOutOfPos"));
    }
    return;
  }

  const powerScale = clamp(profile.power, 0.84, 1.08);
  // La potenza dell'IA non e' un moltiplicatore sulla palla: e' il tempo di volo
  // della traiettoria. Nella formula qui sotto `powerScale` — che porta la
  // difficolta' — pesa l'8% sui colpi da fondo, quindi un avversario "potente"
  // cambiava la propria racchetta senza cambiare il peso dei propri colpi:
  // misurati 336,1 contro 331,2, l'1,5%, sotto la soglia del percettibile.
  //
  // La potenza dell'atleta scelto entra percio' a parte e a peso pieno, che e'
  // esattamente il trattamento che il giocatore riceve da `hitPowerProfile`.
  // Tenerle separate e' il punto: la taratura della difficolta' non si muove
  // (senza formazione il rapporto vale 1), e la scelta dell'avversario si sente.
  const atletaPower = clamp(paddleRatio(state, paddle, "power"), 0.85, 1.2);
  const executionSpread = assessment.risk * (1 - profile.skill * 0.45);
  target.x += (nextRandom(state) - 0.5) * executionSpread * 150;
  target.y += (nextRandom(state) - 0.45) * executionSpread * 105;
  if (target.kind === "smash-x2" || target.kind === "smash-x3") {
    const targetY = opponentSide === "ai" ? COURT.top + 44 : COURT.bottom - 44;
    setComputerTrajectory(ball, target.x, targetY, target.flightTime / (powerScale * atletaPower));
    ball.shotType = target.kind;
    ball.smashTargetSide = opponentSide;
    ball.topspin = target.kind === "smash-x3" ? 1.12 : 0.98;
    ball.spin = target.kind === "smash-x3"
      ? Math.sign(target.x - centerX || 1) * 76
      : clamp(ball.vx * 0.04, -24, 24);
  } else {
    setComputerTrajectory(ball, target.x, target.y, target.flightTime / ((0.92 + powerScale * 0.08) * atletaPower));
    ball.shotType = target.kind;
    ball.spin = clamp(ball.vx * (target.kind === "vibora" ? 0.2 : 0.08), -72, 72);
    if (target.kind === "vibora") ball.backspin = 0.76;
  }
  if (!paddle.isPlayer) {
    state.aiRecoveryMode = false;
    if (target.kind === "lob") addEvent(state, t("evOppLob"));
    else if (target.kind === "volley") addEvent(state, t("evCoverCenter"));
    else if (target.kind === "vibora") addEvent(state, t("evOppVibora"));
    else if (target.kind === "smash-x2") addEvent(state, t("evOppSmashX2"));
    else if (target.kind === "smash-x3") addEvent(state, t("evOppSmashX3"));
  }
}

export function hitBall(
  state,
  paddle,
  power = 1,
  isSpecial = false,
  forceContact = false,
  aim = 0,
  slice = false,
  shotVariant = "auto",
  aimY = 0,
  timingAge = 0,
  precision = 0,
) {
  const { ball, athlete } = state;
  if (paddle.hitCooldown > 0 || (!forceContact && !canHit(paddle, ball))) return false;

  const contactHeight = ball.z;
  const offset = clamp((ball.x - paddle.x) / (paddle.w / 2), -1, 1);
  const rawCharge = clamp((power - 0.4) / 0.95, 0, 1);
  const assessment = evaluateShotQuality(state, paddle, {
    charge: rawCharge,
    aim,
    variant: shotVariant,
    timingAge,
  });
  const powerMul = hitPowerProfile(paddle, state, power);
  const control = paddle.isPlayer
    ? athleteFor(state, paddle).stats.control
    : state.pvp && paddle.controlled
      ? (state.pvpAthlete?.stats.control ?? 0.92 + state.ai.skill * 0.1)
      : (0.92 + state.ai.skill * 0.1) * paddleRatio(state, paddle, "control", 0.6);
  const direction = paddle.isPlayer ? -1 : 1;
  ball.y = paddle.y + direction * (ball.r + 6);
  ball.z = Math.max(22, Math.min(ball.z, 74));
  ball.topspin = 0;
  // Va letto prima di sovrascriverlo: serve sia al giocatore sia all'IA per
  // sapere che stanno rispondendo a uno smash.
  state.incomingShot = ball.shotType;
  ball.wallKill = 0;
  const returningSmash = isSmashShot(state.incomingShot);
  ball.shotType = "drive";
  ball.smashStage = 0;
  ball.smashTargetSide = null;
  ball.postGlassSide = null;
  ball.wallAngleResolved = false;
  if (paddle.controlled) {
    const shotPower = clamp(powerMul, 0.34, 1.5);
    // Risposta a uno smash: solo un contatto perfetto lascia controbattere.
    // Un contatto buono obbliga a difendere, uno sbagliato regala la palla.
    // Controbattere uno smash non deve chiedere la stessa precisione dell'hit
    // stop: rispondendo si e' sempre in corsa, e li' il perfetto vale due
    // fotogrammi. Lo split-step allarga la finestra a cinque, quindi diventa
    // lui la chiave — leggi lo smash, piantati, e puoi rientrare in attacco.
    const readSmash = assessment.grade === "perfect"
      || (assessment.grade === "good"
        && (paddle.splitStep ?? 0) >= BALANCE.smashCounterSplitStep);
    const smashDefence = returningSmash && !readSmash;
    const scrambled = returningSmash
      && assessment.grade !== "perfect"
      && assessment.grade !== "good";
    const aimFreedom = (assessment.profile === "control"
      ? 0.78
      : assessment.profile === "attack"
        ? 0.96
        : 1.1) * (scrambled ? BALANCE.smashReturnScrambleAim : smashDefence ? BALANCE.smashReturnDefenceAim : 1);
    const aimedOffset = clamp(aim * control * aimFreedom + offset * 0.24, -1, 1);
    const aimedDepth = clamp(aimY, -1, 1);
    const centerX = (COURT.left + COURT.right) / 2;
    const nearNet = withinNetRange(paddle, BALANCE.smashNetWindow);
    // Una vibora chiesta con il modificatore tecnico resta una scelta del
    // giocatore e mantiene il raggio ampio; e' la conversione automatica dello
    // slice che va tenuta stretta, altrimenti lo slice puro non esiste.
    const viboraRange = withinNetRange(paddle, shotVariant === "vibora"
      ? BALANCE.smashNetWindow
      : BALANCE.viboraNetWindow);
    const explicitSmash = shotVariant === "smash";
    // La risposta al servizio non puo' essere uno smash: `rallyHits` e' 0 solo
    // sul primo colpo del punto, che e' sempre la risposta. Uno smash chiesto
    // esplicitamente li' diventa una bandeja, come in ogni altro contesto
    // in cui la finestra non e' aperta.
    const serviceReturn = state.rallyHits === 0;
    const smashReady = !slice
      && (explicitSmash || shotVariant === "auto")
      && !serviceReturn
      && nearNet
      && contactHeight >= BALANCE.smashMinHeight
      && shotPower >= BALANCE.smashMinPower;
    let smashType = null;
    if (smashReady && explicitSmash) {
      if (aimedDepth <= -0.28) {
        smashType = Math.abs(aimedOffset) >= 0.42 ? "smash-x3" : "smash-x2";
      } else if (aimedDepth >= 0.32) {
        smashType = "bandeja";
      } else {
        smashType = "smash-flat";
      }
    } else if (smashReady) {
      smashType = Math.abs(aimedOffset) >= 0.52 ? "smash-x3" : "smash-x2";
    } else if (explicitSmash) {
      smashType = "bandeja";
    }
    const seeksSideGlass = !smashType
      && !slice
      && shotVariant !== "lob"
      && Math.abs(aimedOffset) >= 0.72;
    const safePower = 1.16 + (control - 1) * 0.16;
    const overchargeRisk = Math.max(0, shotPower - safePower);
    const controlRisk = clamp(1.3 - control, 0.06, 0.46);
    const profileRisk = assessment.profile === "risk" ? 1.34 : assessment.profile === "attack" ? 1 : 0.62;
    // Angolo stretto: RT allunga la portata della mira fin contro il vetro e
    // riduce la dispersione, perche' stai mirando di proposito. Non aggiunge
    // casualita' — sposta il bersaglio dentro il margine d'errore che gia' hai.
    // Asse dominante: la diagonale non somma i due rischi, vale solo la
    // direzione su cui hai spinto di piu'. Cosi' l'angolo del campo non e' ne'
    // il colpo migliore del gioco ne' una perdita garantita.
    const rtTravel = clamp(precision, 0, 1);
    const lateralDominant = Math.abs(aimedOffset) >= Math.abs(aimedDepth);
    const tight = lateralDominant
      ? rtTravel * clamp((Math.abs(aimedOffset) - 0.55) / 0.35, 0, 1)
      : 0;
    // Solo la levetta in avanti allunga: tirare indietro accorcia e non puo'
    // finire sul vetro di fondo, quindi non deve portare rischio.
    const tightDepth = lateralDominant
      ? 0
      : rtTravel * clamp((-aimedDepth - 0.55) / 0.35, 0, 1);
    const aimReach = 0.42 + tight * BALANCE.tightAngleReachGain;
    const executionRisk = assessment.risk * (0.72 + controlRisk * 0.7) * profileRisk;
    // L'angolo stretto riduce la dispersione dovuta all'esecuzione, ma ne
    // aggiunge una incomprimibile: mirare a ridosso del vetro resta un azzardo
    // anche colpendo perfettamente. Il controllo dell'atleta la contiene.
    const tightSpread = tight * BALANCE.tightAngleMinSpread / Math.max(0.6, control);
    const lateralJitter = (nextRandom(state) - 0.5)
      * ((overchargeRisk * controlRisk * 300 + executionRisk * 170)
        * (1 - clamp(precision, 0, 1) * BALANCE.tightAngleJitterCut)
        + tightSpread);
    const depthJitter = (nextRandom(state) - 0.44)
      * (overchargeRisk * controlRisk * 480 + executionRisk * 210);
    const targetMargin = seeksSideGlass || tight > 0.2
      ? Math.round(30 - tight * (30 - BALANCE.tightAngleMargin))
      : assessment.profile === "control" ? 108 : assessment.profile === "attack" ? 72 : 48;
    // Quanto l'esecuzione e' sotto la soglia oltre la quale il colpo sbaglia
    // davvero. Si arriva a 1 solo sommando timing, posizione, energia e mira.
    const executionMiss = clamp(
      (BALANCE.shotErrorThreshold - assessment.quality) / BALANCE.shotErrorSpan,
      0,
      1,
    );
    // L'errore vero e' una decisione presa una volta per colpo, non una somma
    // di perturbazioni che sperano di superare una soglia geometrica.
    const shotError = rollShotError(state, assessment, aimedOffset, tight, tightDepth);
    const rawTargetX = centerX + aimedOffset * (COURT.right - COURT.left) * aimReach
      + lateralJitter;
    const targetX = shotError?.type === "wide"
      ? centerX + (Math.sign(aimedOffset) || 1) * ((COURT.right - COURT.left) * 0.5 + 52)
      : overchargeRisk > 0.04 || executionRisk > 0.34
        ? clamp(rawTargetX, COURT.left - 24, COURT.right + 24)
        : clamp(rawTargetX, COURT.left + targetMargin, COURT.right - targetMargin);
    const baseTargetDepth = slice
      ? 78 + shotPower * 46
      : 72 + shotPower * 78;
    const targetDepth = clamp(
      baseTargetDepth
        - aimedDepth * 42
        + overchargeRisk * 70
        + depthJitter
        - executionMiss * BALANCE.shotErrorShort
        + executionMiss * assessment.timingBias * BALANCE.shotErrorDepth
        - (scrambled ? BALANCE.smashReturnScrambleDepth
          : smashDefence ? BALANCE.smashReturnDefenceDepth : 0)
        // Angolo stretto in profondita': stesso patto di quello laterale, con
        // il vetro di fondo al posto di quello laterale.
        + tightDepth * BALANCE.tightDepthReachGain
        + (nextRandom(state) - 0.5) * tightDepth
          * BALANCE.tightDepthMinSpread / Math.max(0.6, control),
      62,
      BALANCE.shotErrorMaxDepth,
    );
    const opponentSide = paddle.isPlayer ? "ai" : "player";
    const targetY = shotError?.type === "long"
      ? (opponentSide === "ai" ? COURT.top - 30 : COURT.bottom + 30)
      : targetYForSide(opponentSide, targetDepth);
    // Da 0,88 + 0,14: fra un contatto perfetto e uno mediocre correvano quattro
    // punti percentuali di velocita' — sotto la soglia del percettibile. La
    // qualita' deve arrivare alla palla, non solo al voto sull'HUD.
    const qualityPace = BALANCE.qualityPaceBase + assessment.quality * BALANCE.qualityPaceSpan;
    // L'apice dipende solo dal tempo di volo, quindi un colpo piu' lento e'
    // per forza piu' alto: il taglio non puo' comprare tempo restando basso.
    // La sua moneta e' un'altra: rimbalzo schiacciato e poca spesa, in cambio
    // di meno profondita' e meno spinta. Il piatto resta il colpo di pressione.
    // Difendendo si alza l'arco: piu' tempo per rientrare, ma palla leggibile.
    const defenceArc = scrambled
      ? BALANCE.smashReturnScrambleArc
      : smashDefence ? BALANCE.smashReturnDefenceArc : 0;
    const flightTime = ((slice
      ? 1.14 - shotPower * 0.20
      : 1.12 - shotPower * 0.26) + defenceArc) / qualityPace;
    if (shotError?.type === "net") {
      // Colpo affossato: il bersaglio cade sulla rete, che diventa il contatto.
      setComputerTrajectory(ball, targetX, COURT.netY, flightTime * 0.66);
    } else {
      setComputerTrajectory(ball, targetX, targetY, flightTime);
    }
    ball.spin = aimedOffset * 45 * control;
    ball.backspin = slice ? 0.65 + shotPower * 0.35 : 0;
    if (shotVariant === "chiquita") {
      const chiquitaX = clamp(
        centerX + aimedOffset * (COURT.right - COURT.left) * 0.3,
        COURT.left + 62,
        COURT.right - 62,
      );
      const chiquitaDepth = 62 + shotPower * 34 - aimedDepth * 18;
      setComputerTrajectory(
        ball,
        chiquitaX,
        targetYForSide(paddle.isPlayer ? "ai" : "player", chiquitaDepth),
        1.02,
      );
      // Deve morire sui piedi di chi sta a rete: con il topspin si rialzava
      // piu' di un drive, cioe' faceva l'opposto del proprio scopo.
      ball.backspin = 0.55;
      ball.spin = aimedOffset * 30 * control;
      ball.shotType = "chiquita";
      addEvent(state, t("evChiquita"));
    } else if (shotVariant === "lob" || shotVariant === "defensive-lob") {
      const defensiveLob = shotVariant === "defensive-lob";
      const powerRatio = clamp((shotPower - 0.34) / 1.16, 0, 1);
      const safePower = 1.12 + (control - 1) * 0.18;
      const overcharge = Math.max(0, shotPower - safePower);
      const controlError = clamp(1.28 - control, 0.05, 0.42);
      const lobRisk = assessment.risk * (0.7 + overcharge * 0.8);
      const lateralError = (nextRandom(state) - 0.5)
        * (overcharge * controlError * 340 + lobRisk * 150);
      const depthError = (nextRandom(state) - 0.46)
        * (overcharge * controlError * 320 + lobRisk * 190);
      const lobTargetX = centerX
        + aimedOffset * (COURT.right - COURT.left) * (0.31 + overcharge * 0.12)
        + lateralError;
      const lobDepth = (defensiveLob ? 112 : 96) + powerRatio * (defensiveLob ? 98 : 118) - aimedDepth * 24
        + overcharge * 70 + depthError;
      const lobTargetY = targetYForSide(paddle.isPlayer ? "ai" : "player", lobDepth);
      const lobFlightTime = (defensiveLob ? 1.68 : 1.5) - powerRatio * (defensiveLob ? 0.12 : 0.18);
      setComputerTrajectory(ball, lobTargetX, lobTargetY, lobFlightTime);
      ball.shotType = defensiveLob ? "defensive-lob" : "lob";
      addEvent(state, overcharge > 0.06
        ? t("evLobOver")
        : powerRatio < 0.3
          ? t("evLobShort")
          : t(defensiveLob ? "evDefensiveLob" : "evLobHigh"));
    } else if (smashType === "smash-x3" && assessment.quality >= BALANCE.smashX3MinQuality) {
      const side = Math.sign(aimedOffset) || (paddle.x < centerX ? 1 : -1);
      const smashTargetX = centerX + side * (COURT.right - COURT.left) * 0.34;
      setComputerTrajectory(ball, smashTargetX, COURT.top + 50, 0.62);
      ball.topspin = 1.15;
      ball.spin = side * 82 * control;
      ball.shotType = "smash-x3";
      ball.smashTargetSide = "ai";
      addEvent(state, t("evSmashX3"));
    } else if (smashType === "smash-x3" && assessment.quality >= BALANCE.smashX2MinQuality) {
      const smashTargetX = centerX + aimedOffset * (COURT.right - COURT.left) * 0.12;
      setComputerTrajectory(ball, smashTargetX, COURT.top + 44, 0.61);
      ball.topspin = 0.96;
      ball.spin = aimedOffset * 25;
      ball.shotType = "smash-x2";
      ball.smashTargetSide = "ai";
      addEvent(state, t("evSmashX3Downgrade"));
    } else if (smashType === "smash-x2" && assessment.quality >= BALANCE.smashX2MinQuality) {
      const smashTargetX = centerX + aimedOffset * (COURT.right - COURT.left) * 0.12;
      setComputerTrajectory(ball, smashTargetX, COURT.top + 44, 0.58);
      ball.topspin = 1;
      ball.spin = aimedOffset * 28;
      ball.shotType = "smash-x2";
      ball.smashTargetSide = "ai";
      addEvent(state, t("evSmashX2Deep"));
    } else if (smashReady && smashType && assessment.quality >= BALANCE.smashFlatMinQuality) {
      const flatTargetX = clamp(
        centerX + aimedOffset * (COURT.right - COURT.left) * 0.24,
        COURT.left + 76,
        COURT.right - 76,
      );
      setComputerTrajectory(ball, flatTargetX, COURT.netY - 174, 0.61);
      ball.topspin = 0.72;
      ball.shotType = "smash-flat";
      addEvent(state, smashType === "smash-flat" ? t("evSmashCenter") : t("evSmashFlatFallback"));
    } else if (smashType) {
      const bandejaSide = Math.sign(aimedOffset) || 1;
      const bandejaTargetX = centerX + bandejaSide * (COURT.right - COURT.left) * 0.22;
      setComputerTrajectory(ball, bandejaTargetX, COURT.netY - 152, 1.02);
      ball.backspin = 0.58;
      ball.spin = bandejaSide * 48;
      ball.shotType = "bandeja";
      addEvent(state, explicitSmash && (!smashReady || assessment.quality < BALANCE.smashX2MinQuality)
        ? t("evBandejaConverted")
        : t("evBandeja"));
    } else if (seeksSideGlass) {
      ball.shotType = "wall-angle";
      ball.spin = aimedOffset * 68 * control;
      addEvent(state, t("evAngleWall"));
    } else if (shotVariant === "globo") {
      // Il globo riuscito e' altissimo e va a morire in fondo: la coppia
      // avversaria non puo' restare a rete. Quello sbagliato resta corto e alto,
      // cioe' esattamente cio' che `attackRead` giudica piu' attaccabile: se ne
      // abusi senza costruirlo, te lo smashano. L'antiabuso e' il gioco stesso.
      const globoRiuscito = assessment.quality >= BALANCE.globoMinQuality;
      const globoDepth = globoRiuscito ? BALANCE.globoDepth : BALANCE.globoFailDepth;
      setComputerTrajectory(
        ball,
        clamp(centerX + aimedOffset * (COURT.right - COURT.left) * 0.26,
          COURT.left + 96, COURT.right - 96),
        targetYForSide(paddle.isPlayer ? "ai" : "player", globoDepth),
        globoRiuscito ? BALANCE.globoFlightTime : BALANCE.globoFailFlightTime,
      );
      ball.shotType = globoRiuscito ? "globo" : "lob";
      if (globoRiuscito && paddle.isPlayer) state.aiRecoveryMode = true;
      addEvent(state, t(globoRiuscito ? "evGlobo" : "evGloboShort"));
    } else if (shotVariant === "cut-volley" && assessment.quality >= BALANCE.cutVolleyMinQuality) {
      // Volee profonda e molto tagliata: rimbalza e va a morire sul vetro di
      // fondo. `wallKill` porta la forza dell'effetto fino al contatto con la
      // parete, dove diventa una spinta verso il basso.
      const cutSide = Math.sign(aimedOffset) || 1;
      setComputerTrajectory(
        ball,
        clamp(centerX + aimedOffset * (COURT.right - COURT.left) * 0.3,
          COURT.left + 70, COURT.right - 70),
        targetYForSide(paddle.isPlayer ? "ai" : "player", BALANCE.cutVolleyDepth),
        BALANCE.cutVolleyFlightTime,
      );
      ball.backspin = BALANCE.cutVolleyBackspin;
      ball.spin = cutSide * 52 * control;
      ball.shotType = "cut-volley";
      ball.wallKill = clamp(assessment.quality, 0, 1);
      addEvent(state, t("evCutVolley"));
    } else if (slice) {
      if (viboraRange && contactHeight >= (shotVariant === "vibora" ? 42 : 48)) {
        const viboraSide = Math.sign(aimedOffset) || 1;
        const viboraDepth = 132 + shotPower * 28 + overchargeRisk * 96;
        setComputerTrajectory(
          ball,
          centerX + viboraSide * (COURT.right - COURT.left) * 0.31,
          targetYForSide(paddle.isPlayer ? "ai" : "player", viboraDepth),
          0.82,
        );
        ball.backspin = 0.82;
        ball.spin = viboraSide * 76;
        ball.shotType = "vibora";
        addEvent(state, t("evVibora"));
      } else {
        ball.shotType = "slice";
        addEvent(state, t("evSlice"));
      }
    }
    // Lob, chiquita e smash ricalcolano la traiettoria e hanno un loro modello
    // di rischio: l'errore vale solo se il colpo base e' sopravvissuto.
    if (shotError
      && (ball.shotType === "drive" || ball.shotType === "slice" || ball.shotType === "wall-angle")) {
      reportShotError(state, paddle, shotError);
    }
    if (isSpecial) applySpecial(state, aimedOffset, paddle);
    consumeRallyEnergy(state, paddle, assessment, shotVariant, slice);
    showShotFeedback(state, paddle, assessment);
    if (explicitSmash && state.shotFeedback) {
      const successfulSmash = ball.shotType.startsWith("smash-");
      state.shotFeedback.text = successfulSmash
        ? t(`shot${ball.shotType === "smash-x3" ? "SmashX3" : ball.shotType === "smash-x2" ? "SmashX2" : "SmashFlat"}`)
        : t("shotBandejaFallback");
      state.shotFeedback.mode = successfulSmash ? assessment.grade.toUpperCase() : t("smashNotReady");
    }
    state.receiverLocked = false;
    state.manualReceiverOverride = false;
    state.serviceReceiverKey = null;
    if (!paddle.isPlayer) state.aiServiceReceiverKey = null;
  } else {
    applyComputerShot(state, paddle, contactHeight);
    if (!paddle.isPlayer) {
      state.aiPrimaryKey = paddle === state.opponent ? "opponent" : "opponentMate";
      state.aiServiceReceiverKey = null;
      state.aiReceiverLocked = false;
      state.aiReactionDelay = 0;
      lockReceiverForIncomingShot(state);
    }
  }
  if (paddle.isPlayer) {
    lockAiReceiverForIncomingShot(state);
    if (state.specialReadPenalty) {
      state.aiReactionDelay += state.specialReadPenalty;
      state.specialReadPenalty = 0;
    }
    if (ball.shotType === "smash-x2" || ball.shotType === "smash-x3") {
      // Leggere in anticipo uno smash e' intelligenza, non riflessi: dipende da
      // `skill`, non da `reactionSkill`. Senza questa lettura l'intercettazione
      // era una funzione a gradino — nessuno ci arrivava mai, oppure sempre —
      // perche' bastava scendere sotto ~610 ms di ritardo totale.
      const letto = nextRandom(state) < clamp(
        BALANCE.smashInterceptBase + state.ai.skill * BALANCE.smashInterceptSkill,
        0,
        BALANCE.smashInterceptCap,
      );
      const smashReadPenalty = letto
        ? BALANCE.smashInterceptPenalty
        : ball.shotType === "smash-x2" ? 0.48 : 0.18;
      if (letto) addEvent(state, t("evSmashIntercepted"));
      state.aiReactionDelay += smashReadPenalty
        + (1 - (state.ai.reactionSkill ?? state.ai.skill)) * 0.16;
      if (ball.shotType === "smash-x3") state.aiX3Recovery = 0.9 + state.ai.skill * 0.22;
    } else if (ball.shotType === "lob") {
      state.aiReactionDelay = Math.max(0.04, state.aiReactionDelay - state.ai.skill * 0.08);
    }
  } else if (ball.shotType === "smash-x3") {
    // Simmetrico: uno x3 avversario apre una finestra di recupero anche per il
    // giocatore, cosi' il punto si perde per posizione e non per regola.
    state.playerX3Recovery = BALANCE.playerX3RecoveryWindow;
  }
  ball.serveInFlight = false;
  ball.serveTouchedNet = false;
  ball.netFaultOwner = null;
  ball.netCord = 0;
  ball.crossedNet = false;
  state.lastHitterSide = paddle.isPlayer ? "player" : "ai";
  ball.bounces = { player: 0, ai: 0 };

  paddle.shotIntent = ball.shotType;
  paddle.actionIntent = ball.shotType;
  paddle.actionPose = 0.42;
  paddle.swing = 1;
  paddle.swingSide = (paddle.controlled ? aim : offset) < -0.08 ? -1 : 1;
  paddle.hitCooldown = paddle.isPlayer ? BALANCE.hitCooldownPlayer : BALANCE.hitCooldownAi;
  sfx.hit();
  ball.hitFlash = 1;
  ball.hitPulse = 1;
  const finishingShot = ball.shotType === "smash-x2" || ball.shotType === "smash-x3" || ball.shotType === "smash" || ball.shotType === "smash-flat" || ball.shotType === "vibora";
  if (isSpecial) {
    sfx.special();
    emitBurst(state, ball.x, ball.y, ball.z, { count: 18, color: state.athlete.color, speed: 210, size: 6, life: 0.4 });
  } else {
    emitBurst(state, ball.x, ball.y, ball.z, { count: 8, color: "#d8ff5f", speed: 130, size: 6, life: 0.32 });
  }
  if (finishingShot) {
    emitBurst(state, ball.x, ball.y, ball.z, { count: 10, color: "#fff3a0", speed: 240, size: 5, life: 0.34 });
    ball.hitFlash = 1.35;
    ball.hitPulse = 1.25;
  }
  state.rallyHits += 1;
  state.combo = Math.min(BALANCE.comboMax, 1 + Math.floor(state.rallyHits / BALANCE.comboStep));
  state.flash = 0.65;
  if (paddle.controlled) {
    const finishingShot = ball.shotType === "smash-x2" || ball.shotType === "smash-x3";
    state.hapticPulse = finishingShot
      ? { duration: 120, strong: 0.82, weak: 0.48 }
      : ball.shotType === "smash-flat" || ball.shotType === "vibora"
        ? { duration: 82, strong: 0.58, weak: 0.38 }
        : { duration: 48, strong: 0.26, weak: 0.3 };
  }
  if (state.rallyHits > 0 && state.rallyHits % 5 === 0) addEvent(state, t(`eventLine${Math.floor(nextRandom(state) * EVENT_LINES.length)}`));
  return true;
}

function applySpecial(state, offset, paddle) {
  const { athlete, ball } = state;
  if (athlete.id === "maestro") {
    ball.vx = offset * 480;
    ball.vy = -470;
    ball.vz = 325;
    // La sua scheda promette "palla difficile da leggere" e non c'era nulla.
    // Meta' del ritardo dell'Oracolo, che di lettura fa il proprio mestiere.
    state.specialReadPenalty = 0.13;
    addEvent(state, t("evPrecision"));
  } else if (athlete.id === "pantera") {
    paddle.dashTimer = 0.26;
    ball.vy = -455;
    ball.vz = 300;
    addEvent(state, t("evLightningDash"));
  } else if (athlete.id === "steamer") {
    // "Potenza massima con effetto wall": la parte wall non esisteva. Ora la
    // palla cerca il vetro laterale e riparte verso il centro, che e' proprio
    // il colpo descritto dalla sua scheda.
    const wallSide = Math.sign(offset) || (paddle.x < (COURT.left + COURT.right) / 2 ? 1 : -1);
    ball.vx = wallSide * 470;
    ball.vy = -520;
    ball.vz = 410;
    ball.spin = wallSide * 74;
    ball.shotType = "wall-angle";
    addEvent(state, t("evSteamSmash"));
  } else if (athlete.id === "fiamma") {
    state.shieldTimer = 2.2;
    ball.vy = -410;
    ball.vz = 280;
    addEvent(state, t("evSteamShield"));
  } else if (athlete.id === "oracolo") {
    // "Visione Perfetta": angolo calcolato al millimetro e traiettoria difficile
    // da leggere, che ritarda la reazione avversaria invece di aggiungere forza.
    // Aveva piu' angolo, un effetto in piu' e un cooldown piu' corto del
    // Maestro: lo dominava su ogni asse. Ora paga l'angolo in velocita'.
    ball.vx = offset * 505;
    ball.vy = -412;
    ball.vz = 315;
    ball.spin = offset * 92;
    // Applicato dopo il lock del ricevitore, che altrimenti lo sovrascrive.
    state.specialReadPenalty = 0.26;
    addEvent(state, t("evPerfectVision"));
  } else if (athlete.id === "colosso") {
    // "Martello a Vapore": la variante pesante dello Steamer, piu' potente ma
    // piu' centrale, cosi' la forza bruta non porta anche l'angolo.
    ball.vx = offset * 190;
    ball.vy = -560;
    ball.vz = 430;
    ball.topspin = 0.9;
    state.fx.shake = Math.max(state.fx.shake ?? 0, 1.1);
    addEvent(state, t("evSteamHammer"));
  }
}

export function trySpecial(state) {
  if (state.specialCooldown > 0 || state.specialReady < BALANCE.specialMinCharge) return;
  const hit = hitBall(state, activePlayer(state), 1.15, true);
  if (hit) {
    state.specialCooldown = state.athlete.special.cooldown;
    state.specialReady = 0;
  } else if (state.athlete.id === "fiamma" && state.ball.vy > 0) {
    state.shieldTimer = 2.4;
    state.specialCooldown = state.athlete.special.cooldown;
    state.specialReady = 0;
    addEvent(state, t("evSteamShieldAbsorb"));
  }
}

function gameWon(points, opponent) {
  return points >= 4 && points - opponent >= 2;
}

/**
 * Il formato della partita, in un posto solo.
 *
 * Erano numeri fissi dentro `finishGame` e `finishSet`: sei game per set,
 * margine di due, tie-break sul 6-6, e i set da vincere dedotti dalla modalita'.
 * Bastavano finche' i formati erano due; per i formati brevi del padel — al
 * meglio di tre o di cinque game — servono parametri. I valori qui sotto sono
 * esattamente quelli di prima, quindi una partita che non li imposta si comporta
 * come si e' sempre comportata.
 */
function matchFormat(state) {
  return {
    gamesToWin: state.gamesToWin ?? 6,
    gameMargin: state.gameMargin ?? 2,
    // `null` significa nessun tie-break: nei formati brevi il margine e' uno e
    // il set si chiude al primo game utile, quindi il 6-6 non si presenta.
    tieBreakAt: state.tieBreakAt === undefined ? 6 : state.tieBreakAt,
    setsToWin: state.setsToWin ?? (state.mode === "tournament" ? 2 : 1),
  };
}

function finishSet(state, winner) {
  state.sets[winner] += 1;
  // Il punteggio del set va salvato prima di azzerare i game, altrimenti a fine
  // partita non esiste piu': `endMatch` registrava i set, e con i formati a un
  // set solo ogni partita finiva in archivio come "1-0" — che sia stata 2-0 o
  // 6-4. Un tabellone di padel e' fatto di game, non di set.
  state.setScores = state.setScores ?? [];
  state.setScores.push({ player: state.games.player, ai: state.games.ai });
  state.games = { player: 0, ai: 0 };
  state.tieBreak = false;
  state.tieBreakPoints = { player: 0, ai: 0 };
  addEvent(state, winner === "player" ? t("setToYou") : t("setToCircuit"));
  if (state.sets[winner] >= matchFormat(state).setsToWin) state.result = { winner };
}

function finishGame(state, winner) {
  state.games[winner] += 1;
  state.points = { player: 0, ai: 0 };
  const loser = other(winner);
  const { gamesToWin, gameMargin, tieBreakAt } = matchFormat(state);
  if (state.games[winner] >= gamesToWin && state.games[winner] - state.games[loser] >= gameMargin) {
    finishSet(state, winner);
  } else if (tieBreakAt !== null && state.games.player === tieBreakAt && state.games.ai === tieBreakAt) {
    state.tieBreak = true;
    state.tieBreakPoints = { player: 0, ai: 0 };
    addEvent(state, t("tieBreak"));
  }
  state.serveSide = other(state.serveSide);
  state.serveCourt = "right";
}

/**
 * Categoria del punto. La decide chi lo assegna, non un'analisi del messaggio:
 * prima `recordPointStats` deduceva "colpo vincente" ed "errore" con una regex
 * sul testo *gia' tradotto*, quindi in inglese non corrispondeva quasi niente e
 * `errors` restava a zero per l'intera partita. Un obiettivo di carriera come
 * "meno di N errori" diventava una stella regalata, e "N colpi vincenti"
 * irraggiungibile.
 */
const POINT_WINNER = "winner";
const POINT_ERROR = "error";

function recordPointStats(state, winner, kind) {
  const stats = state.stats;
  if (!stats) return;
  const loser = other(winner);
  stats.pointsWon[winner] += 1;
  stats.longestRally = Math.max(stats.longestRally, state.rallyHits);
  stats.totalRallyHits += state.rallyHits;
  stats.rallyCount += 1;
  const isWinnerShot = kind === POINT_WINNER;
  const isError = kind === POINT_ERROR;
  if (isWinnerShot) stats.winners[winner] += 1;
  if (isError) stats.errors[loser] += 1;
  if (state.ball.shotType === "smash-x2" || state.ball.shotType === "smash-x3") stats.smashWinners[winner] += 1;
  if (state.doubleFaultFlag) stats.doubleFaults[loser] += 1;
  if (isWinnerShot && winner === state.serveSide && state.rallyHits === 0) {
    stats.aces[winner] += 1;
  }
}

function scorePoint(state, winner, reason, kind = null) {
  const receiver = other(state.serveSide);
  if (reason) addEvent(state, reason);
  recordPointStats(state, winner, kind);
  if (state.tieBreak) {
    state.tieBreakPoints[winner] += 1;
    if (state.tieBreakPoints[winner] >= 7 && state.tieBreakPoints[winner] - state.tieBreakPoints[other(winner)] >= 2) finishSet(state, winner);
  } else if (state.pointsToWin) {
    state.points[winner] += 1;
    if (state.points[winner] >= state.pointsToWin) state.result = { winner };
  } else {
    state.points[winner] += 1;
    if (gameWon(state.points[winner], state.points[other(winner)])) finishGame(state, winner);
  }
  if (state.pointsToWin && !state.result) state.serveSide = other(state.serveSide);
  state.combo = 1;
  state.rallyHits = 0;
  state.rallyEnergy = { player: 1, ai: 1 };
  state.shotFeedback = null;
  state.receiverLocked = false;
  state.manualReceiverOverride = false;
  state.serviceReceiverKey = null;
  state.aiServiceReceiverKey = null;
  state.aiReceiverLocked = false;
  state.aiReactionDelay = 0;
  state.aiShotPressure = 0;
  state.aiRecoveryMode = false;
  state.serveAttempts = 0;
  state.serveCourt = state.serveCourt === "right" ? "left" : "right";
  syncPointDisplay(state);
  if (!state.result) {
    state.pointPause = 1.4;
    state.pointMessage = `${winner === "player" ? t("pointYou") : t("pointOpp")}${reason ? ` · ${reason}` : ""}`;
    sfx.point(winner === "player");
  } else if (winner === "player") {
    sfx.victoryMatch();
  } else {
    sfx.defeatMatch();
  }
  return receiver;
}

function serveFault(state, reason) {
  if (state.serveAttempts === 0) {
    state.serveAttempts = 1;
    addEvent(state, `${reason} ${t("secondServeSuffix")}`);
    prepareServe(state);
    return;
  }
  state.doubleFaultFlag = true;
  scorePoint(state, other(state.serveSide), t("doubleFault", { reason: reason.toLowerCase() }), POINT_ERROR);
  state.doubleFaultFlag = false;
}

function serveLet(state) {
  state.ball.serveInFlight = false;
  state.pointPause = 1;
  state.pointMessage = "LET · Servizio da ripetere";
  addEvent(state, t("evLet"));
}

function validServiceBounce(state, side) {
  const { ball } = state;
  const receiver = other(state.serveSide);
  if (side !== receiver) return false;
  const inDepth = receiver === "ai"
    ? ball.y >= SERVICE_TOP && ball.y < COURT.netY
    : ball.y > COURT.netY && ball.y <= SERVICE_BOTTOM;
  const isLeft = ball.x < (COURT.left + COURT.right) / 2;
  return inDepth && (ball.serveTargetSide === "left" ? isLeft : !isLeft);
}

function handleGroundBounce(state, impactVz, remainingTime) {
  const { ball } = state;
  const side = courtSide(ball.y);
  if (ball.netFaultOwner) {
    scorePoint(state, other(ball.netFaultOwner), t("msgNetFault"), POINT_ERROR);
    return true;
  }
  if (ball.y < COURT.top || ball.y > COURT.bottom) {
    scorePoint(state, other(side), t("msgOut"), POINT_ERROR);
    return true;
  }
  if (ball.serveInFlight) {
    if (!validServiceBounce(state, side)) {
      serveFault(state, t("serveOutBox"));
      return true;
    }
    if (ball.serveTouchedNet) {
      serveLet(state);
      return true;
    }
    ball.serveInFlight = false;
    ball.bounces[side] = 1;
    addEvent(state, t("evServeValid"));
  } else {
    if (state.lastHitterSide === side && !ball.crossedNet) {
      scorePoint(state, other(side), t("msgNetShort"), POINT_ERROR);
      return true;
    }
    ball.bounces[side] += 1;
    if (ball.bounces[side] > 1) {
      scorePoint(state, other(side), t("msgDoubleBounce"), POINT_WINNER);
      return true;
    }
  }
  const impactSpeed = Math.abs(impactVz);
  const speedFactor = clamp(impactSpeed / 520, 0, 1);
  const sliceAmount = clamp(ball.backspin ?? 0, 0, 1.2);
  const topspinAmount = clamp(ball.topspin ?? 0, 0, 1.3);
  const restitution = (BALANCE.groundRestitution + BALANCE.groundRestitutionBoost * speedFactor)
    * (1 - sliceAmount * 0.28)
    + topspinAmount * 0.12;
  const minimumBounce = BALANCE.minimumBounceVz * (1 - sliceAmount * 0.26);
  const reboundVz = Math.max(minimumBounce, impactSpeed * restitution);
  ball.vx = (ball.vx + ball.spin * BALANCE.groundSpinTransfer) * BALANCE.groundTangentialDamping;
  ball.vy *= BALANCE.groundTangentialDamping
    * (1 - sliceAmount * 0.14)
    * (1 + topspinAmount * 0.08);
  ball.spin *= 0.7;
  ball.backspin *= 0.35;
  ball.topspin *= 0.72;
  if ((ball.shotType === "smash-x2" || ball.shotType === "smash-x3")
    && side === ball.smashTargetSide) {
    ball.smashStage = Math.max(ball.smashStage, 1);
    addEvent(state, t("evSmashValid"));
  }
  ball.z = Math.max(0, reboundVz * remainingTime - 0.5 * BALANCE.ballGravity * remainingTime * remainingTime);
  ball.vz = reboundVz - BALANCE.ballGravity * remainingTime;
  ball.bouncePulse = 1;
  ball.landRing = 0.5;
  sfx.bounce();
  emitDust(state, ball.x, ball.y, 6);
  return false;
}

function handleWalls(state) {
  const { ball } = state;
  const side = courtSide(ball.y);
  const hasBounced = ball.bounces[side] > 0;
  const hitSideWall = ball.x - ball.r < COURT.left || ball.x + ball.r > COURT.right;
  const hitBackWall = ball.y - ball.r < COURT.top || ball.y + ball.r > COURT.bottom;
  if (!hitSideWall && !hitBackWall) return false;
  if (!hasBounced) {
    if (ball.serveInFlight) {
      serveFault(state, t("serveWallFault"));
      return true;
    }
    if (state.lastHitterSide !== side || ball.crossedNet) {
      scorePoint(state, side, t("msgWallNoBounce"), POINT_WINNER);
      return true;
    }
    addEvent(state, t("evOwnWallOut"));
  }
  if (hitSideWall && ball.shotType === "smash-x3" && ball.smashStage >= 2) {
    const defenders = side === "ai" ? [state.opponent, state.opponentMate] : [state.player, state.playerMate];
    const recovery = defenders
      .map((paddle) => ({ paddle, distance: Math.hypot(paddle.x - ball.x, paddle.y - ball.y) }))
      .sort((a, b) => a.distance - b.distance)[0];
    // La finestra esisteva solo per il lato IA: uno x3 avversario era un punto
    // automatico per costruzione, non perche' fossi fuori posizione.
    const read = (side === "ai" ? state.aiX3Recovery : state.playerX3Recovery) > 0;
    const backLimit = side === "ai" ? COURT.top + 158 : COURT.bottom - 158;
    const inBack = side === "ai"
      ? recovery.paddle.y < backLimit
      : recovery.paddle.y > backLimit;
    // Il recupero era irraggiungibile: raggio 111 px contro una distanza mediana
    // di 235. Misurato su 200 tentativi, scattava zero volte — una meccanica
    // scritta e mai tarata. Ne seguiva che uno x3 arrivato al vetro fosse punto
    // garantito a ogni livello: Campione 53%, Leggenda 51%, cioe' sul colpo che
    // decide i punti l'ultimo gradino di difficolta' non esisteva.
    //
    // Allargare il raggio da solo non basta: la distanza si concentra attorno ai
    // 230 px, quindi il raggio si comporta da interruttore — provato, e la
    // Leggenda passava da 51% a 0% mentre Difficile restava a 53%. E' lo stesso
    // effetto a gradino che questo progetto ha gia' corretto altre due volte.
    //
    // Quindi: la geometria dice se il recupero e' *possibile*, la bravura se
    // riesce. Un solo tiro di dado per colpo, da `nextRandom`, quindi
    // riproducibile come tutto il resto.
    const raggio = recovery.paddle.reach * BALANCE.x3RecoveryReach;
    const inRaggio = recovery.distance <= raggio;
    // Solo il lato IA scala con la difficolta': la difesa del giocatore sta
    // nelle sue mani, non in un numero.
    const abilita = side === "ai"
      ? clamp(BALANCE.x3RecoveryChanceBase + state.ai.skill * BALANCE.x3RecoveryChanceSkill, 0, 0.95)
      : 1;
    const recovered = read && inBack && inRaggio && nextRandom(state) < abilita;
    if (!recovered) {
      scorePoint(state, state.lastHitterSide, t("msgSmashX3Wall"), POINT_WINNER);
      return true;
    }
    // The defender has read the exit and plays it off the side glass instead of granting an automatic winner.
    ball.x = clamp(ball.x, COURT.left + ball.r, COURT.right - ball.r);
    ball.vx *= -state.arena.wallBounce * 0.72;
    ball.vy = Math.max(180, Math.abs(ball.vy) * 0.7);
    ball.vz = Math.max(160, ball.vz * 0.62);
    ball.shotType = "x3-recovered";
    ball.smashStage = 0;
    state.aiX3Recovery = 0;
    state.playerX3Recovery = 0;
    addEvent(state, t("evX3Recovered"));
    return false;
  }
  if (hitSideWall) {
    ball.x = clamp(ball.x, COURT.left + ball.r, COURT.right - ball.r);
    ball.vx *= -state.arena.wallBounce;
    ball.vy *= BALANCE.wallTangentialDamping;
    if (hasBounced && ball.shotType === "wall-angle" && !ball.wallAngleResolved) {
      ball.vx *= 1.08;
      ball.wallAngleResolved = true;
      state.aiReactionDelay += (1 - state.ai.skill) * 0.22;
      addEvent(state, t("evSideWallCenter"));
    }
  }
  if (hitBackWall) {
    ball.y = clamp(ball.y, COURT.top + ball.r, COURT.bottom - ball.r);
    ball.vy *= -state.arena.wallBounce;
    ball.vx *= BALANCE.wallTangentialDamping;
    // Volee tagliata: il vetro di fondo non restituisce piu' la palla, la
    // schiaccia a terra. E' l'unico punto del gioco in cui una parete tocca
    // `vz` fuori dagli smash, ed e' cio' che toglie il tempo di recupero.
    if (hasBounced && (ball.wallKill ?? 0) > 0) {
      const readSkill = side === "ai" ? state.ai.skill : 0.6;
      const letta = nextRandom(state)
        < clamp(BALANCE.cutVolleyReadBase + readSkill * BALANCE.cutVolleyReadSkill, 0, 0.85)
          * (1 - ball.wallKill * BALANCE.cutVolleyReadSuppress);
      if (!letta) {
        ball.vz = BALANCE.cutVolleyKillVz * ball.wallKill;
        ball.vy *= BALANCE.cutVolleyKillDamp;
        ball.vx *= BALANCE.cutVolleyKillDamp;
        addEvent(state, t("evCutVolleyKill"));
      } else {
        addEvent(state, t("evCutVolleyRead"));
      }
      ball.wallKill = 0;
    }
    if (hasBounced && ball.shotType === "smash-x3" && side === ball.smashTargetSide) {
      const outward = Math.sign(ball.vx || ball.spin) || 1;
      ball.vx = outward * Math.max(275, Math.abs(ball.vx));
      ball.vy = (side === "ai" ? 1 : -1) * Math.max(115, Math.abs(ball.vy) * 0.46);
      ball.vz = Math.max(245, ball.vz);
      ball.smashStage = 2;
      addEvent(state, t("evSmashX3Grid"));
    } else if (hasBounced && ball.shotType === "smash-x2" && side === ball.smashTargetSide) {
      // L'esito dello x2 era una corsa geometrica: o il difensore arrivava o
      // no, e pochi punti di velocita' ribaltavano tutto (a 520 il livello
      // facile passava dal 18% al 100%). Ora e' una lettura decisa una volta
      // sola all'uscita dal vetro, come gli altri errori del gioco.
      const defenders = side === "ai"
        ? [state.opponent, state.opponentMate]
        : [state.player, state.playerMate];
      const nearest = defenders
        .map((pad) => ({ pad, distance: Math.hypot(pad.x - ball.x, pad.y - ball.y) }))
        .sort((a, b) => a.distance - b.distance)[0];
      const readSkill = side === "ai"
        ? state.ai.skill
        : computerProfile(state, state.player).skill;
      const proximity = clamp(1 - nearest.distance / BALANCE.smashX2ReadRange, 0, 1);
      const chance = clamp(
        BALANCE.smashX2ReadBase
          + readSkill * BALANCE.smashX2ReadSkill
          + proximity * BALANCE.smashX2ReadProximity,
        0,
        BALANCE.smashX2ReadCap,
      );
      const read = nextRandom(state) < chance;
      // La lettura non teletrasporta nessuno: smorza l'uscita quel tanto che
      // basta perche' la rincorsa sia possibile, e la resta da giocare.
      // Il ramo letto e' una frenata vera, non un massimo con la velocita' in
      // arrivo: altrimenti i due esiti si somigliavano e la lettura non decideva.
      ball.vy = (side === "ai" ? 1 : -1) * (read
        ? BALANCE.smashX2ReadVy
        : Math.max(BALANCE.smashX2ReturnVy, Math.abs(ball.vy) * 1.08));
      ball.vz = read ? BALANCE.smashX2ReadVz : Math.max(BALANCE.smashX2ReturnVz, ball.vz);
      ball.smashStage = 2;
      addEvent(state, t(read ? "evSmashX2Read" : "evSmashX2"));
    }
  }
  if (hasBounced) {
    ball.postGlassSide = side;
    if (side === "ai") lockAiReceiverForIncomingShot(state);
    else lockReceiverForIncomingShot(state);
  }
  ball.spin *= -0.45;
  sfx.wall();
  emitSparks(state, ball.x, ball.y, ball.z);
  if (state.wallEventTimer <= 0) {
    addEvent(state, t("evWallValid"));
    state.wallEventTimer = BALANCE.wallEventCooldown;
  }
  return false;
}

function handleNetCollision(state, previousBall) {
  const { ball } = state;
  const deltaY = ball.y - previousBall.y;
  const crossed = (previousBall.y - COURT.netY) * (ball.y - COURT.netY) <= 0;
  if (!crossed || Math.abs(deltaY) < 0.01) return false;

  const crossingT = clamp((COURT.netY - previousBall.y) / deltaY, 0, 1);
  const contactZ = previousBall.z + (ball.z - previousBall.z) * crossingT;
  const touchesNet = contactZ <= BALANCE.netClearance + ball.r * 0.35;
  if (!touchesNet) return false;
  sfx.net();
  emitDust(state, ball.x, contactZ + 2);

  const direction = Math.sign(deltaY) || Math.sign(ball.vy) || 1;
  const speed = Math.abs(ball.vy);
  const tapeContact = contactZ >= BALANCE.netClearance - 6 && speed >= 250;
  ball.netCord = 1;
  ball.bouncePulse = Math.max(ball.bouncePulse, 0.72);

  if (tapeContact) {
    ball.y = COURT.netY + direction * (ball.r + 2);
    ball.z = Math.max(BALANCE.netClearance - 2, contactZ);
    ball.vx *= 0.78;
    ball.vy *= 0.48;
    ball.vz = Math.max(42, ball.vz * 0.3);
    if (ball.serveInFlight) ball.serveTouchedNet = true;
    addEvent(state, t("evTape"));
    return false;
  }

  ball.y = COURT.netY - direction * (ball.r + 2);
  ball.z = Math.max(2, contactZ);
  ball.vx *= 0.58;
  ball.vy *= -0.18;
  ball.vz = Math.max(20, Math.abs(ball.vz) * 0.14);
  if (ball.serveInFlight) {
    ball.serveTouchedNet = true;
  } else {
    ball.netFaultOwner = direction < 0 ? "player" : "ai";
  }
  addEvent(state, t("evNetRebound"));
  return false;
}

function roleBounds(paddle) {
  if (paddle.isPlayer) {
    return paddle.role === "net"
      ? { minY: COURT.netY + 42, maxY: COURT.netY + 158 }
      : { minY: COURT.netY + 158, maxY: COURT.bottom - 42 };
  }
  return paddle.role === "net"
    ? { minY: COURT.netY - 158, maxY: COURT.netY - 42 }
    : { minY: COURT.top + 42, maxY: COURT.netY - 158 };
}

function paddleDistance(paddle, ball) {
  return Math.abs(paddle.x - ball.x) + Math.abs(paddle.y - ball.y) * 1.35;
}

function moveComputerPaddle(state, paddle, ball, dt, homeY, accuracy) {
  const startX = paddle.x;
  const startY = paddle.y;
  const side = paddle.isPlayer ? "player" : "ai";
  const incoming = ballPlayableDirection(side, ball);
  const { minY, maxY } = roleBounds(paddle);
  const ballOnOwnSide = paddle.isPlayer ? ball.y > COURT.netY : ball.y < COURT.netY;
  const shift = paddle.isPlayer ? -16 : 16;
  const targetY = incoming && ballOnOwnSide ? clamp(ball.y + shift, minY, maxY) : homeY;
  const targetX = incoming && ballOnOwnSide
    ? ball.x + (nextRandom(state) - 0.5) * (1 - accuracy) * 20
    : (COURT.left + COURT.right) / 2;
  paddle.x = clamp(paddle.x + clamp(targetX - paddle.x, -paddle.speed * dt, paddle.speed * dt), COURT.left + paddle.w / 2, COURT.right - paddle.w / 2);
  paddle.y = clamp(paddle.y + clamp(targetY - paddle.y, -paddle.speed * 0.56 * dt, paddle.speed * 0.56 * dt), minY, maxY);
  paddle.motion = Math.abs(paddle.x - startX) + Math.abs(paddle.y - startY) > 0.4
    ? 1
    : Math.max(0, paddle.motion - dt * 7);
  paddle.moveRatio = clamp(
    Math.hypot(paddle.x - startX, paddle.y - startY) / Math.max(1, paddle.speed * dt),
    0,
    1,
  );
}

function movePaddleTo(paddle, targetX, targetY, dt) {
  const startX = paddle.x;
  const startY = paddle.y;
  paddle.x = clamp(
    paddle.x + clamp(targetX - paddle.x, -paddle.speed * dt, paddle.speed * dt),
    COURT.left + paddle.w / 2,
    COURT.right - paddle.w / 2,
  );
  paddle.y = clamp(
    paddle.y + clamp(targetY - paddle.y, -paddle.speed * 0.56 * dt, paddle.speed * 0.56 * dt),
    COURT.top + 42,
    COURT.netY - 42,
  );
  paddle.motion = Math.abs(paddle.x - startX) + Math.abs(paddle.y - startY) > 0.4
    ? 1
    : Math.max(0, paddle.motion - dt * 7);
  paddle.moveRatio = clamp(
    Math.hypot(paddle.x - startX, paddle.y - startY) / Math.max(1, paddle.speed * dt),
    0,
    1,
  );
}

function aiContactPlan(state, paddle, ball) {
  return planAiContact({ x: paddle.x, y: paddle.y, speed: paddle.speed, skill: paddle.skill,
    width: contactWidth(paddle, ball), depth: paddle.reach * BALANCE.aiDepthReach, reaction: state.aiReactionDelay },
    { x: ball.x, y: ball.y, z: ball.z, vx: ball.vx, vy: ball.vy, vz: ball.vz,
      spin: ball.spin, backspin: ball.backspin, topspin: ball.topspin,
      bounces: ball.bounces.ai, serve: ball.serveInFlight, fault: ball.netFaultOwner != null,
      incoming: ballPlayableDirection("ai", ball) }, COURT, BALANCE);
}

function moveOpponentTeam(state, dt) {
  const { ball, opponent, opponentMate } = state;
  const centerX = (COURT.left + COURT.right) / 2;
  const courtWidth = COURT.right - COURT.left;
  const livePrediction = clamp(ball.x + ball.vx * 0.2, COURT.left + 72, COURT.right - 72);
  const aiDefendingDirection = ballPlayableDirection("ai", ball);
  const predictedX = state.aiReceiverLocked && aiDefendingDirection
    ? clamp(state.aiTargetX, COURT.left + 72, COURT.right - 72)
    : livePrediction;
  const primary = state[state.aiPrimaryKey] ?? opponent;
  const support = primary === opponent ? opponentMate : opponent;
  const ballOnAiSide = ball.y < COURT.netY;
  const defending = ballOnAiSide && aiDefendingDirection;
  const attacking = !state.aiRecoveryMode
    && !ballOnAiSide
    && ball.vy > 0
    && (state.rallyHits > 0 || ball.served)
    && ball.z < 165;
  const minSeparation = courtWidth * 0.24;
  let primaryTargetX = predictedX;
  let supportTargetX = predictedX < centerX
    ? centerX + courtWidth * 0.2
    : centerX - courtWidth * 0.2;

  if (Math.abs(primaryTargetX - supportTargetX) < minSeparation) {
    const coverDirection = primaryTargetX < centerX ? 1 : -1;
    supportTargetX = clamp(
      primaryTargetX + coverDirection * minSeparation,
      COURT.left + 72,
      COURT.right - 72,
    );
  }

  let primaryTargetY;
  let supportTargetY;
  if (defending) {
    // Difesa di coppia: entrambi dietro, su due corsie e quasi sulla stessa linea.
    const glassReturnOffset = ball.postGlassSide === "ai" ? 42 : -18;
    const x3Read = state.aiX3Recovery > 0 && ball.shotType === "smash-x3";
    primaryTargetY = x3Read
      ? COURT.top + 66
      : clamp(ball.y + glassReturnOffset, COURT.top + 76, COURT.netY - 104);
    supportTargetY = x3Read ? COURT.top + 98 : clamp(primaryTargetY - 10, COURT.top + 70, COURT.netY - 112);
    if (x3Read) {
      primaryTargetX = clamp(ball.x - ball.vx * 0.12, COURT.left + 58, COURT.right - 58);
      supportTargetX = primaryTargetX < centerX ? centerX + courtWidth * 0.24 : centerX - courtWidth * 0.24;
    }
    state.aiTeamShape = "defend";
  } else if (attacking) {
    // Dopo un buon colpo avanzano insieme, mantenendo il centro coperto.
    primaryTargetY = COURT.netY - 70;
    supportTargetY = COURT.netY - 78;
    state.aiTeamShape = "attack";
  } else {
    primaryTargetY = COURT.top + 92;
    supportTargetY = COURT.top + 84;
    state.aiTeamShape = "reset";
  }

  if (defending) {
    const plan = aiContactPlan(state, primary, ball);
    if (plan.wait) { primaryTargetX = plan.x; primaryTargetY = plan.y; }
  }
  const readingIncomingShot = defending && state.aiReceiverLocked && state.aiReactionDelay > 0;
  if (!readingIncomingShot) movePaddleTo(primary, primaryTargetX, primaryTargetY, dt);
  else primary.motion = Math.max(0, primary.motion - dt * 7);
  movePaddleTo(support, supportTargetX, supportTargetY, dt);
}

function updateDoublesAI(state, dt) {
  if (state.serving) return;
  const { ball, opponent, opponentMate, ai } = state;
  state.aiReactionDelay = Math.max(0, state.aiReactionDelay - dt);
  const inactiveTeamMate = state.activePlayerKey === "player" ? state.playerMate : state.player;
  const inactiveHomeY = inactiveTeamMate.role === "net" ? COURT.netY + 92 : COURT.bottom - 86;
  if (!state.coop) {
    if (state.serviceReceiverKey) {
      const width = COURT.right - COURT.left;
      const receptionX = inactiveTeamMate === state.player
        ? COURT.left + width * 0.28
        : COURT.left + width * 0.72;
      const receptionY = COURT.bottom - 74;
      inactiveTeamMate.x += clamp(receptionX - inactiveTeamMate.x, -inactiveTeamMate.speed * dt, inactiveTeamMate.speed * dt);
      inactiveTeamMate.y += clamp(receptionY - inactiveTeamMate.y, -inactiveTeamMate.speed * 0.56 * dt, inactiveTeamMate.speed * 0.56 * dt);
    } else moveTacticalMate(state, inactiveTeamMate, dt);
  }
  if (state.pvp) {
    const inactivePvp = state.pvpActiveKey === "opponent" ? opponentMate : opponent;
    const pvpHomeY = inactivePvp.role === "net" ? COURT.netY - 84 : COURT.top + 76;
    if (state.aiServiceReceiverKey) {
      const width = COURT.right - COURT.left;
      const receiver = state[state.aiServiceReceiverKey];
      const receptionX = inactivePvp === opponent
        ? COURT.left + width * 0.28
        : COURT.left + width * 0.72;
      const targetX = inactivePvp === receiver && !ball.serveInFlight ? ball.x : receptionX;
      const receptionY = COURT.top + 74;
      inactivePvp.x += clamp(targetX - inactivePvp.x, -inactivePvp.speed * dt, inactivePvp.speed * dt);
      inactivePvp.y += clamp(receptionY - inactivePvp.y, -inactivePvp.speed * 0.56 * dt, inactivePvp.speed * 0.56 * dt);
    } else {
      moveComputerPaddle(state, inactivePvp, ball, dt, pvpHomeY, state.pvpAthlete?.stats.control ?? ai.skill);
    }
    return;
  }
  if (state.aiServiceReceiverKey) {
    const width = COURT.right - COURT.left;
    const receiver = state[state.aiServiceReceiverKey];
    [opponent, opponentMate].forEach((paddle) => {
      const receptionX = paddle === opponent
        ? COURT.left + width * 0.28
        : COURT.left + width * 0.72;
      const targetX = paddle === receiver && !ball.serveInFlight ? ball.x : receptionX;
      const receptionY = COURT.top + 74;
      paddle.x += clamp(targetX - paddle.x, -paddle.speed * dt, paddle.speed * dt);
      paddle.y += clamp(receptionY - paddle.y, -paddle.speed * 0.56 * dt, paddle.speed * 0.56 * dt);
    });
  } else {
    moveOpponentTeam(state, dt);
  }

  const controllableHeight = ball.z <= BALANCE.playableHitHeight;
  const defenders = state.aiReceiverLocked
    ? [state[state.aiPrimaryKey]]
    : [opponent, opponentMate].sort((a, b) => paddleDistance(a, ball) - paddleDistance(b, ball));
  const responder = defenders.find((paddle) => canHit(paddle, ball));
  if (responder && controllableHeight && state.aiReactionDelay <= 0 && !aiContactPlan(state, responder, ball).wait) {
    hitBall(state, responder, 0.88 + ai.skill * 0.12);
  }
}

function updateServing(state, dt, input, second = EMPTY_INPUT) {
  const isPlayer = state.serveSide === "player";
  if (isPlayer && state.activePlayerKey !== "player") setActivePlayer(state, "player");
  const server = isPlayer ? activePlayer(state) : state.opponent;
  if (isPlayer) {
    const startX = server.x;
    const startY = server.y;
    const moveX = clamp(input.moveX ?? ((input.left ? -1 : 0) + (input.right ? 1 : 0)), -1, 1);
    const moveY = clamp(input.moveY ?? ((input.up ? -1 : 0) + (input.down ? 1 : 0)), -1, 1);
    server.x += moveX * server.speed * dt;
    server.y += moveY * server.speed * 0.58 * dt;
    const serviceBounds = serviceCourtBounds(state, server);
    server.x = clamp(server.x, serviceBounds.min, serviceBounds.max);
    // The server must remain behind the service line until the ball is struck.
    server.y = clamp(server.y, SERVICE_BOTTOM + 28, COURT.bottom - 42);
    server.motion = Math.abs(server.x - startX) + Math.abs(server.y - startY) > 0.4
      ? 1
      : Math.max(0, server.motion - dt * 7);
    state.ball.x = server.x + 28;
    state.ball.y = server.y - 24;
    if (input.hit || input.special) {
      performServe(state, state.shotCharge, input.slice);
      state.shotCharge = 0;
      state.shotAim = 0;
      state.shotAimY = 0;
      addEvent(state, t("serveHint", {
        ordinal: t(state.serveAttempts ? "serveOrdSecond" : "serveOrdFirst"),
        suffix: input.slice ? t("serveSliceSuffix") : "",
      }));
    }
  } else if (state.humanMode === "pvp") {
    if (state.pvpActiveKey !== "opponent") setPvpActive(state, "opponent");
    state.serveTimer = 0;
    const startX = server.x;
    const startY = server.y;
    const moveX = clamp(second.moveX ?? 0, -1, 1);
    const moveY = clamp(second.moveY ?? 0, -1, 1);
    server.x += moveX * server.speed * dt;
    server.y += moveY * server.speed * 0.58 * dt;
    const serviceBounds = serviceCourtBounds(state, server);
    server.x = clamp(server.x, serviceBounds.min, serviceBounds.max);
    server.y = clamp(server.y, COURT.top + 28, SERVICE_TOP - 42);
    server.motion = Math.abs(server.x - startX) + Math.abs(server.y - startY) > 0.4
      ? 1
      : Math.max(0, server.motion - dt * 7);
    state.ball.x = server.x - 28;
    state.ball.y = server.y + 24;
    controlPaddleCharge(state, server, second, dt);
    if (second.hit) {
      performServe(state, server.charge, second.slice);
      server.charge = 0;
      server.aim = 0;
      server.aimY = 0;
      addEvent(state, t("serveHint", {
        ordinal: t(state.serveAttempts ? "serveOrdSecond" : "serveOrdFirst"),
        suffix: second.slice ? t("serveSliceSuffix") : "",
      }));
    }
  } else {
    state.serveTimer -= dt;
    server.x += (serviceOriginX(state) - server.x) * Math.min(1, dt * 4);
    state.ball.x = server.x - 28;
    state.ball.y = server.y + 24;
    if (state.serveTimer <= 0) {
      performServe(state);
      addEvent(state, t("evOppServe"));
    }
  }
}

function updateShotControl(state, dt, input) {
  if (input.analogAim) {
    state.shotAim = clamp(input.aim ?? 0, -1, 1);
    state.shotAimY = clamp(input.aimY ?? 0, -1, 1);
  }
  if (!input.charging) {
    if (!input.hit) {
      state.shotAim *= Math.max(0, 1 - dt * 8);
      state.shotAimY *= Math.max(0, 1 - dt * 8);
    }
    return;
  }
  state.shotCharge = Math.min(1, state.shotCharge + dt / 1.05);
  if (!input.analogAim) {
    const aimDirection = input.left ? -1 : input.right ? 1 : 0;
    state.shotAim = clamp(state.shotAim + aimDirection * dt * 1.9, -1, 1);
  }
  // RT durante la carica: e' l'ampiezza dell'angolo, unico mestiere che gli resta
  // analogica dell'angolo stretto, cosi' il rischio si dosa col grilletto.
  state.shotPrecision = clamp(input.sprint ?? 0, 0, 1);
  state.shotIntent = input.shotVariant ?? (input.slice ? "slice" : "drive");
}

function queueChargedShot(state, slice = false, variant = "auto") {
  state.queuedShotPower = 0.4 + state.shotCharge * 0.95;
  state.queuedShotCharge = state.shotCharge;
  state.queuedShotAge = 0;
  state.queuedShotAim = state.shotAim;
  state.queuedShotAimY = state.shotAimY;
  state.queuedShotSlice = slice;
  state.queuedShotVariant = variant;
  state.queuedShotPrecision = state.shotPrecision ?? 0;
  state.shotPrecision = 0;
  state.shotCharge = 0;
  state.shotAim = 0;
  state.shotAimY = 0;
}

const EMPTY_INPUT = {
  left: false,
  right: false,
  up: false,
  down: false,
  moveX: 0,
  moveY: 0,
  charging: false,
  hit: false,
  slice: false,
  shotVariant: null,
  special: false,
  switchPlayer: false,
  switchDirection: null,
  aim: 0,
  aimY: 0,
  analogAim: false,
  splitStep: 0,
  sprint: 0,
  technicalModifier: false,
  teamTactic: null,
  cutVolley: false,
  globo: false,
};

function moveHumanPaddle(state, paddle, input, dt) {
  const digitalX = (input.left ? -1 : 0) + (input.right ? 1 : 0);
  const digitalY = (input.up ? -1 : 0) + (input.down ? 1 : 0);
  const moveX = clamp(input.moveX ?? digitalX, -1, 1);
  const moveY = clamp(input.moveY ?? digitalY, -1, 1);
  const splitStep = input.charging ? 0 : clamp(input.splitStep ?? 0, 0, 1);
  // RT non muove piu' la racchetta: era troppo forte, e soprattutto lo stesso
  // grilletto governava due cose diverse — la corsa qui e l'angolo stretto in
  // `shotPrecision`. Un comando che fa due mestieri non se ne puo' dosare
  // nessuno: si scattava per correre e ci si ritrovava la mira stretta, o si
  // stringeva la mira e si partiva in corsa. Ora RT e' solo la direzione.
  const chargeMovement = input.charging ? 0.32 : 1;
  const movementMultiplier = chargeMovement
    * (1 - splitStep * (1 - BALANCE.splitStepSpeed));
  paddle.splitStep = splitStep;
  paddle.sprinting = 0;
  const startX = paddle.x;
  const startY = paddle.y;
  paddle.x += moveX * paddle.speed * movementMultiplier * dt;
  paddle.y += moveY * paddle.speed * 0.68 * movementMultiplier * dt;
  if (paddle.dashTimer > 0) {
    paddle.x += moveX * 260 * dt;
    paddle.dashTimer -= dt;
  }
  paddle.x = clamp(paddle.x, COURT.left + paddle.w / 2, COURT.right - paddle.w / 2);
  const receiverKey = paddle.isPlayer ? state.serviceReceiverKey : state.aiServiceReceiverKey;
  let minY;
  let maxY;
  if (paddle.isPlayer) {
    minY = COURT.netY + 42;
    maxY = COURT.bottom - 42;
    if (receiverKey === paddle.key) minY = SERVICE_BOTTOM + 20;
  } else {
    minY = COURT.top + 42;
    maxY = COURT.netY - 42;
    if (receiverKey === paddle.key) maxY = SERVICE_TOP - 20;
  }
  paddle.y = clamp(paddle.y, minY, maxY);
  paddle.motion = Math.abs(paddle.x - startX) + Math.abs(paddle.y - startY) > 0.4
    ? 1
    : Math.max(0, paddle.motion - dt * 7);
  paddle.moveRatio = clamp(
    Math.hypot(paddle.x - startX, paddle.y - startY) / Math.max(1, paddle.speed * dt),
    0,
    1,
  );
  paddle.hitCooldown = Math.max(0, paddle.hitCooldown - dt);
}

function setPlayerTeamTactic(state, tactic) {
  if (!tactic || state.playerTeamTactic === tactic) return;
  state.playerTeamTactic = tactic;
  state.tacticFlash = 1.1;
  addEvent(state, t(`tactic_${tactic}`));
}

function tacticalMateTarget(state, mate) {
  const active = activePlayer(state);
  const width = COURT.right - COURT.left;
  const leftLane = COURT.left + width * 0.28;
  const rightLane = COURT.left + width * 0.72;
  const oppositeLane = active.x < (COURT.left + COURT.right) / 2 ? rightLane : leftLane;
  const tactic = state.playerTeamTactic ?? "balanced";
  if (tactic === "attack") return { x: oppositeLane, y: COURT.netY + 78 };
  if (tactic === "defend") return { x: oppositeLane, y: COURT.bottom - 76 };
  if (tactic === "staggered") {
    const activeAtNet = active.y < COURT.netY + 150;
    return { x: oppositeLane, y: activeAtNet ? COURT.bottom - 92 : COURT.netY + 88 };
  }
  const incoming = ballPlayableDirection("player", state.ball) && state.ball.y > COURT.netY;
  return {
    x: incoming ? clamp(state.ball.x < active.x ? rightLane : leftLane, COURT.left + 72, COURT.right - 72) : oppositeLane,
    y: active.y < COURT.netY + 145 ? COURT.netY + 88 : COURT.bottom - 92,
  };
}

function moveTacticalMate(state, mate, dt) {
  const target = tacticalMateTarget(state, mate);
  const startX = mate.x;
  const startY = mate.y;
  mate.x = clamp(mate.x + clamp(target.x - mate.x, -mate.speed * dt, mate.speed * dt), COURT.left + mate.w / 2, COURT.right - mate.w / 2);
  mate.y = clamp(mate.y + clamp(target.y - mate.y, -mate.speed * 0.56 * dt, mate.speed * 0.56 * dt), COURT.netY + 42, COURT.bottom - 42);
  mate.motion = Math.abs(mate.x - startX) + Math.abs(mate.y - startY) > 0.4 ? 1 : Math.max(0, mate.motion - dt * 7);
  mate.moveRatio = clamp(Math.hypot(mate.x - startX, mate.y - startY) / Math.max(1, mate.speed * dt), 0, 1);
}

function controlPaddleCharge(state, paddle, input, dt) {
  if (input.analogAim) {
    paddle.aim = clamp(input.aim ?? 0, -1, 1);
    paddle.aimY = clamp(input.aimY ?? 0, -1, 1);
  }
  if (input.charging) {
    paddle.charge = Math.min(1, paddle.charge + dt / 1.05);
    if (!input.analogAim) {
      const aimDirection = input.left ? -1 : input.right ? 1 : 0;
      paddle.aim = clamp(paddle.aim + aimDirection * dt * 1.9, -1, 1);
    }
    paddle.shotIntent = input.shotVariant ?? (input.slice ? "slice" : "drive");
  } else if (!input.hit) {
    paddle.aim *= Math.max(0, 1 - dt * 8);
    paddle.aimY *= Math.max(0, 1 - dt * 8);
  }
}

function queuePaddleHit(state, paddle, input) {
  if (input.smashUpgrade && paddle.smashPrimed && paddle.queuedShot) {
    paddle.queuedShot.variant = "smash";
    paddle.queuedShot.aim = clamp(input.aim ?? paddle.queuedShot.aim, -1, 1);
    paddle.queuedShot.aimY = clamp(input.aimY ?? paddle.queuedShot.aimY, -1, 1);
    paddle.queuedShot.age = 0;
    paddle.smashPrimed = false;
    paddle.smashTapWindow = 0;
    paddle.shotIntent = "smash";
    addEvent(state, t("evSmashTapConfirmed"));
    return;
  }
  if (!input.hit) return;
  paddle.queuedShot = {
    power: 0.4 + paddle.charge * 0.95,
    charge: paddle.charge,
    aim: paddle.aim,
    aimY: paddle.aimY,
    slice: input.slice,
    variant: input.shotVariant ?? (input.slice ? "slice" : "auto"),
    precision: clamp(input.sprint ?? 0, 0, 1),
    age: 0,
  };
  const nearNet = withinNetRange(paddle, BALANCE.smashNetWindow);
  const canPrimeSmash = paddle.queuedShot.variant === "drive"
    && !paddle.queuedShot.slice
    && state.rallyHits > 0
    && nearNet
    && state.ball.z >= BALANCE.smashMinHeight - 8
    && hitPowerProfile(paddle, state, paddle.queuedShot.power) >= BALANCE.smashMinPower;
  paddle.smashPrimed = canPrimeSmash;
  paddle.smashTapWindow = canPrimeSmash ? BALANCE.smashDoubleTapWindow : 0;
  paddle.swingBuffer = canPrimeSmash ? BALANCE.smashBufferWindow : BALANCE.shotBufferWindow;
  if (canPrimeSmash) addEvent(state, t("evSmashPrimed"));
  paddle.charge = 0;
  paddle.aim = 0;
  paddle.aimY = 0;
}

function decayHumanSwing(state, paddle, dt) {
  if (paddle.swingBuffer <= 0) return;
  const hadContactGrace = (paddle.smashContactGrace ?? 0) > 0;
  paddle.smashContactGrace = Math.max(0, (paddle.smashContactGrace ?? 0) - dt);
  if (hadContactGrace && paddle.smashContactGrace === 0 && paddle.smashPrimed) {
    paddle.smashPrimed = false;
    paddle.smashTapWindow = 0;
    paddle.smashContactFallback = true;
    addEvent(state, t("evSmashTapExpired"));
  }
  if (paddle.smashPrimed) {
    paddle.smashTapWindow = Math.max(0, paddle.smashTapWindow - dt);
    if (paddle.smashTapWindow === 0) {
      paddle.smashPrimed = false;
      addEvent(state, t("evSmashTapExpired"));
    }
  }
  if (paddle.queuedShot) paddle.queuedShot.age += dt;
  paddle.swingBuffer = Math.max(0, paddle.swingBuffer - dt);
  if (paddle.swingBuffer === 0 && paddle.queuedShot?.variant === "smash") {
    state.shotFeedback = {
      text: t("smashMissedContact"),
      mode: t("smashMissedHint"),
      grade: "early",
      quality: 0,
      life: 1.05,
      paddleKey: paddle.key,
    };
    paddle.queuedShot = null;
  }
}

function attemptHumanSwing(state, paddle, previousBall) {
  if (paddle.swingBuffer <= 0 || !paddle.queuedShot) return;
  const contactNow = canHit(paddle, state.ball) || crossedPaddle(paddle, state.ball, previousBall);
  if (paddle.smashPrimed && contactNow) {
    paddle.smashContactGrace = Math.max(
      paddle.smashContactGrace ?? 0,
      BALANCE.smashContactGrace,
    );
    return;
  }
  if (paddle.smashPrimed) return;
  if (!contactNow && !paddle.smashContactFallback && !(paddle.smashContactGrace > 0)) return;
  const q = paddle.queuedShot;
  if (hitBall(
    state,
    paddle,
    q.power,
    false,
    true,
    q.aim,
    q.slice,
    q.variant,
    q.aimY,
    q.variant === "smash" ? Math.min(q.age, BALANCE.smashTimingAgeCap) : q.age,
    q.precision ?? 0,
  )) {
    paddle.swingBuffer = 0;
    paddle.queuedShot = null;
    paddle.smashContactGrace = 0;
    paddle.smashContactFallback = false;
  }
}

function setPvpActive(state, key) {
  if (state.pvpActiveKey === key) return;
  state.pvpActiveKey = key;
  state.opponent.controlled = key === "opponent";
  state.opponentMate.controlled = key === "opponentMate";
  state.pvpSwitchCooldown = 0.28;
}

function updatePvpActive(state, dt, forceSwitch, switchDirection = null) {
  state.pvpSwitchCooldown = Math.max(0, state.pvpSwitchCooldown - dt);
  if (!forceSwitch && !switchDirection) return;
  if (state.aiServiceReceiverKey) return;
  const otherKey = state.pvpActiveKey === "opponent" ? "opponentMate" : "opponent";
  if (switchDirection) {
    const current = state[state.pvpActiveKey];
    const alternate = state[otherKey];
    const dx = alternate.x - current.x;
    const dy = alternate.y - current.y;
    const length = Math.hypot(dx, dy) || 1;
    const directionLength = Math.hypot(switchDirection.x, switchDirection.y) || 1;
    const alignment = (dx / length) * (switchDirection.x / directionLength)
      + (dy / length) * (switchDirection.y / directionLength);
    if (alignment < 0.2) return;
  }
  setPvpActive(state, otherKey);
  state.pvpSwitchFlash = 0.55;
}

export function updateMatch(state, dt, input, input2 = null) {
  const second = input2 ?? EMPTY_INPUT;
  if (state.paused || !state.running) return null;
  state.elapsed += dt;
  state.receiverSwitchFlash = Math.max(0, state.receiverSwitchFlash - dt);
  state.manualSwitchFlash = Math.max(0, state.manualSwitchFlash - dt);
  state.pvpSwitchFlash = Math.max(0, state.pvpSwitchFlash - dt);
  state.tacticFlash = Math.max(0, state.tacticFlash - dt);
  state.aiX3Recovery = Math.max(0, state.aiX3Recovery - dt);
  state.playerX3Recovery = Math.max(0, (state.playerX3Recovery ?? 0) - dt);
  setPlayerTeamTactic(state, input.teamTactic);
  if (state.shotFeedback) {
    state.shotFeedback.life = Math.max(0, state.shotFeedback.life - dt);
    if (state.shotFeedback.life === 0) state.shotFeedback = null;
  }
  updateFx(state, dt);
  for (const paddle of [state.player, state.playerMate, state.opponent, state.opponentMate]) {
    paddle.actionPose = Math.max(0, paddle.actionPose - dt);
    if (paddle.motion > 0.12) {
      const pace = 7.5
        + (paddle.moveRatio ?? 0.6) * 3.5
        + (paddle.sprinting ?? 0) * 1.0;
      const splitStepFactor = 1 - (paddle.splitStep ?? 0) * 0.22;
      paddle.runPhase = (paddle.runPhase + dt * pace * splitStepFactor) % 8;
    }
  }
  if (state.pointPause > 0) {
    for (const paddle of [state.player, state.playerMate, state.opponent, state.opponentMate]) {
      paddle.motion = 0;
      paddle.moveRatio = 0;
    }
    state.pointPause = Math.max(0, state.pointPause - dt);
    if (state.pointPause === 0 && !state.result) {
      resetReplayBuffer(state);
      prepareServe(state);
    }
    return state.result;
  }
  // Da qui in poi la simulazione: durante l'hit-stop rallenta, mentre effetti,
  // animazioni e timer di interfaccia sopra restano a velocita' reale.
  if (state.hitStop > 0) {
    state.hitStop = Math.max(0, state.hitStop - dt);
    dt *= BALANCE.hitStopTimeScale;
  }
  if (state.humanMode !== "coop" || state.serving) {
    updateShotControl(state, dt, input);
  }
  const { ball } = state;
  if (state.serving) {
    updateServing(state, dt, input, second);
    captureReplayFrame(state);
    return state.result;
  }

  let player = activePlayer(state);
  if (state.humanMode === "coop") {
    controlPaddleCharge(state, player, input, dt);
    queuePaddleHit(state, player, input);
    moveHumanPaddle(state, player, input, dt);
    decayHumanSwing(state, player, dt);
    controlPaddleCharge(state, state.playerMate, second, dt);
    queuePaddleHit(state, state.playerMate, second);
    moveHumanPaddle(state, state.playerMate, second, dt);
    decayHumanSwing(state, state.playerMate, dt);
    state.opponent.hitCooldown = Math.max(0, state.opponent.hitCooldown - dt);
    state.opponentMate.hitCooldown = Math.max(0, state.opponentMate.hitCooldown - dt);
    state.wallEventTimer = Math.max(0, state.wallEventTimer - dt);
    const hadSmashContactGrace = state.smashContactGrace > 0;
    state.smashContactGrace = Math.max(0, state.smashContactGrace - dt);
    if (hadSmashContactGrace && state.smashContactGrace === 0 && state.smashPrimed) {
      state.smashPrimed = false;
      state.smashTapWindow = 0;
      state.smashContactFallback = true;
      addEvent(state, t("evSmashTapExpired"));
    }
    if (input.special) {
      state.playerSwingBuffer = 0.24;
      trySpecial(state);
    }
    state.shotCharge = player.charge;
    state.shotAim = player.aim;
    state.shotAimY = player.aimY;
  } else {
    const digitalMoveX = (input.left ? -1 : 0) + (input.right ? 1 : 0);
    const digitalMoveY = (input.up ? -1 : 0) + (input.down ? 1 : 0);
    const moveX = clamp(input.moveX ?? digitalMoveX, -1, 1);
    const moveY = clamp(input.moveY ?? digitalMoveY, -1, 1);
    const movementIntent = Math.hypot(moveX, moveY) > 0.08;
    state.manualMovementTimer = movementIntent
      ? 0.18
      : Math.max(0, state.manualMovementTimer - dt);
    updateActivePlayer(state, dt, input.switchPlayer, input.switchDirection);
    player = activePlayer(state);
    const playerStartX = player.x;
    const playerStartY = player.y;

    const splitStep = input.charging ? 0 : clamp(input.splitStep ?? 0, 0, 1);
    // Nessuna corsa: RT governa solo l'angolo del colpo. Vedi `moveHumanPaddle`.
    // In padel the player can adjust the feet while preparing: slower, but never frozen.
    const chargeMovement = input.charging ? 0.58 : 1;
    const movementMultiplier = chargeMovement
      * (1 - splitStep * (1 - BALANCE.splitStepSpeed));
    player.splitStep = splitStep;
    player.sprinting = 0;
    player.x += moveX * player.speed * movementMultiplier * dt;
    player.y += moveY * player.speed * 0.68 * movementMultiplier * dt;
    if (player.dashTimer > 0) {
      player.x += moveX * 260 * dt;
      player.dashTimer -= dt;
    }
    player.x = clamp(player.x, COURT.left + player.w / 2, COURT.right - player.w / 2);
    const playerMinY = state.serviceReceiverKey ? SERVICE_BOTTOM + 20 : COURT.netY + 42;
    player.y = clamp(player.y, playerMinY, COURT.bottom - 42);
    player.motion = Math.abs(player.x - playerStartX) + Math.abs(player.y - playerStartY) > 0.4
      ? 1
      : Math.max(0, player.motion - dt * 7);
    player.moveRatio = clamp(
      Math.hypot(player.x - playerStartX, player.y - playerStartY) / Math.max(1, player.speed * dt),
      0,
      1,
    );
    player.hitCooldown = Math.max(0, player.hitCooldown - dt);
    state.playerMate.hitCooldown = Math.max(0, state.playerMate.hitCooldown - dt);
    state.opponent.hitCooldown = Math.max(0, state.opponent.hitCooldown - dt);
    state.opponentMate.hitCooldown = Math.max(0, state.opponentMate.hitCooldown - dt);
    state.wallEventTimer = Math.max(0, state.wallEventTimer - dt);
    if (state.smashPrimed) {
      state.smashTapWindow = Math.max(0, state.smashTapWindow - dt);
      if (state.smashTapWindow === 0) {
        state.smashPrimed = false;
        addEvent(state, t("evSmashTapExpired"));
      }
    }
    if (state.cutVolleyPrimed) {
      state.cutVolleyTapWindow = Math.max(0, state.cutVolleyTapWindow - dt);
      if (state.cutVolleyTapWindow === 0) state.cutVolleyPrimed = false;
    }
    if (state.globoPrimed) {
      state.globoTapWindow = Math.max(0, state.globoTapWindow - dt);
      if (state.globoTapWindow === 0) state.globoPrimed = false;
    }
    if (input.hit) {
      queueChargedShot(state, input.slice, input.shotVariant ?? (input.slice ? "slice" : "auto"));
      const queuedPower = state.queuedShotPower * state.athlete.stats.power;
      const canPrimeSmash = state.queuedShotVariant === "drive"
        && !state.queuedShotSlice
        && state.rallyHits > 0
        && withinNetRange(player, BALANCE.smashNetWindow)
        && ball.z >= BALANCE.smashMinHeight - 8
        && queuedPower >= BALANCE.smashMinPower;
      // Volee tagliata: stessa grammatica dello smash ma su X. Richiede una
      // volee vera, cioe' che la palla non abbia ancora rimbalzato dalla mia
      // parte, e la stessa vicinanza a rete della vibora.
      const canPrimeCutVolley = !canPrimeSmash
        && state.queuedShotSlice
        && state.rallyHits > 0
        && ball.bounces.player === 0
        && withinNetRange(player, BALANCE.viboraNetWindow)
        && ball.z >= BALANCE.cutVolleyMinHeight;
      state.smashPrimed = canPrimeSmash;
      state.smashTapWindow = canPrimeSmash ? BALANCE.smashDoubleTapWindow : 0;
      // Globo: serve una carica sostanziosa e una palla non troppo alta, perche'
      // il globo si costruisce da sotto.
      const canPrimeGlobo = !canPrimeSmash
        && !canPrimeCutVolley
        && state.queuedShotVariant === "lob"
        && state.queuedShotCharge >= BALANCE.globoMinCharge
        && ball.z <= BALANCE.globoMaxHeight;
      state.cutVolleyPrimed = canPrimeCutVolley;
      state.cutVolleyTapWindow = canPrimeCutVolley ? BALANCE.cutVolleyTapWindow : 0;
      state.globoPrimed = canPrimeGlobo;
      state.globoTapWindow = canPrimeGlobo ? BALANCE.globoTapWindow : 0;
      state.playerSwingBuffer = canPrimeSmash
        ? BALANCE.smashBufferWindow
        : canPrimeCutVolley
          ? BALANCE.cutVolleyBufferWindow
          : canPrimeGlobo
            ? BALANCE.globoBufferWindow
            : BALANCE.shotBufferWindow;
      if (canPrimeSmash) addEvent(state, t("evSmashPrimed"));
      else if (canPrimeCutVolley) addEvent(state, t("evCutVolleyPrimed"));
      else if (canPrimeGlobo) addEvent(state, t("evGloboPrimed"));
    }
    if (input.globo && state.globoPrimed && state.playerSwingBuffer > 0) {
      state.queuedShotVariant = "globo";
      state.queuedShotAim = clamp(input.aim ?? state.queuedShotAim, -1, 1);
      state.queuedShotAge = 0;
      state.shotIntent = "globo";
      state.globoPrimed = false;
      state.globoTapWindow = 0;
      addEvent(state, t("evGloboConfirmed"));
    }
    if (input.cutVolley && state.cutVolleyPrimed && state.playerSwingBuffer > 0) {
      state.queuedShotVariant = "cut-volley";
      state.queuedShotAim = clamp(input.aim ?? state.queuedShotAim, -1, 1);
      state.queuedShotAge = 0;
      state.shotIntent = "cut-volley";
      state.cutVolleyPrimed = false;
      state.cutVolleyTapWindow = 0;
      addEvent(state, t("evCutVolleyConfirmed"));
    }
    if (input.smashUpgrade && state.smashPrimed && state.playerSwingBuffer > 0) {
      state.queuedShotVariant = "smash";
      state.queuedShotAim = clamp(input.aim ?? state.queuedShotAim, -1, 1);
      state.queuedShotAimY = clamp(input.aimY ?? state.queuedShotAimY, -1, 1);
      state.queuedShotAge = 0;
      state.shotIntent = "smash";
      state.smashPrimed = false;
      state.smashTapWindow = 0;
      addEvent(state, t("evSmashTapConfirmed"));
    }
    const hadSwingBuffer = state.playerSwingBuffer > 0;
    if (state.playerSwingBuffer > 0) state.queuedShotAge += dt;
    state.playerSwingBuffer = Math.max(0, state.playerSwingBuffer - dt);
    if (hadSwingBuffer && state.playerSwingBuffer === 0 && state.queuedShotVariant === "smash") {
      state.shotFeedback = {
        text: t("smashMissedContact"),
        mode: t("smashMissedHint"),
        grade: "early",
        quality: 0,
        life: 1.05,
        paddleKey: state.activePlayerKey,
      };
      state.queuedShotAge = 0;
      state.queuedShotVariant = "auto";
    }
    if (input.special) {
      state.playerSwingBuffer = 0.24;
      trySpecial(state);
    }
  }
  if (state.humanMode === "pvp") {
    updatePvpActive(state, dt, second.switchPlayer, second.switchDirection);
    const p2 = state[state.pvpActiveKey];
    controlPaddleCharge(state, p2, second, dt);
    queuePaddleHit(state, p2, second);
    moveHumanPaddle(state, p2, second, dt);
    decayHumanSwing(state, p2, dt);
  }

  if (state.shieldTimer > 0 && ball.vy > 0) ball.vy *= 1 - dt * 0.55;
  state.shieldTimer = Math.max(0, state.shieldTimer - dt);
  const humanSprintLoad = state.humanMode === "coop"
    ? Math.max(state.player.sprinting ?? 0, state.playerMate.sprinting ?? 0)
    : player.sprinting ?? 0;
  const playerStamina = rallyStamina(state, "player");
  state.rallyEnergy.player = clamp(
    state.rallyEnergy.player
      + dt * BALANCE.rallyEnergyRecovery * (1 - player.moveRatio * 0.7) * playerStamina
      - dt * BALANCE.sprintEnergyDrain * clamp(humanSprintLoad, 0, 1) * player.moveRatio
        / playerStamina,
    BALANCE.rallyEnergyFloor,
    1,
  );
  state.rallyEnergy.ai = clamp(
    state.rallyEnergy.ai + dt * BALANCE.rallyEnergyRecovery * 0.72,
    BALANCE.rallyEnergyFloor,
    1,
  );

  updateShotRead(state, activePlayer(state));

  const previousBall = { x: ball.x, y: ball.y, z: ball.z };
  const previousVz = ball.vz;
  ball.x += ball.vx * dt;
  ball.y += ball.vy * dt;
  ball.z += previousVz * dt - 0.5 * BALANCE.ballGravity * dt * dt;
  ball.vz = previousVz - BALANCE.ballGravity * dt;
  const airDrag = Math.pow(BALANCE.airDrag, dt * 60);
  ball.vx = (ball.vx + ball.spin * BALANCE.airSpinCurve * dt) * airDrag;
  ball.vy *= airDrag;
  ball.spin *= BALANCE.spinDecay;
  ball.backspin *= Math.pow(0.996, dt * 60);
  ball.topspin *= Math.pow(0.995, dt * 60);
  ball.bouncePulse = Math.max(0, (ball.bouncePulse ?? 0) - dt * 8.5);
  ball.hitFlash = Math.max(0, (ball.hitFlash ?? 0) - dt * 4.2);
  ball.hitPulse = Math.max(0, (ball.hitPulse ?? 0) - dt * 5.5);
  ball.netCord = Math.max(0, (ball.netCord ?? 0) - dt * 5.5);
  ball.landRing = Math.max(0, (ball.landRing ?? 0) - dt);

  if (!state.serving) {
    ball.trailTime -= dt;
    if (ball.trailTime <= 0 && Math.hypot(ball.vx, ball.vy) > 80) {
      ball.trail.push({ x: ball.x, y: ball.y, z: ball.z, life: 0.3 });
      if (ball.trail.length > 10) ball.trail.shift();
      ball.trailTime = 0.022;
    }
    for (const point of ball.trail) point.life -= dt;
    if (ball.trail.length && ball.trail[0].life <= 0) ball.trail.shift();
  } else {
    ball.trail = [];
  }

  const playerContactNow = canHit(player, ball) || crossedPaddle(player, ball, previousBall);
  if (state.playerSwingBuffer > 0 && state.smashPrimed && playerContactNow) {
    state.smashContactGrace = Math.max(state.smashContactGrace, BALANCE.smashContactGrace);
  }
  if (state.playerSwingBuffer > 0
    && !state.smashPrimed
    && (playerContactNow || state.smashContactGrace > 0 || state.smashContactFallback)) {
    if (hitBall(
      state,
      player,
      state.queuedShotPower,
      false,
      true,
      state.queuedShotAim,
      state.queuedShotSlice,
      state.queuedShotVariant,
      state.queuedShotAimY,
      state.queuedShotVariant === "smash"
        ? Math.min(state.queuedShotAge, BALANCE.smashTimingAgeCap)
        : state.queuedShotAge,
      state.queuedShotPrecision ?? 0,
    )) {
      state.playerSwingBuffer = 0;
      state.queuedShotAge = 0;
      state.queuedShotSlice = false;
      state.queuedShotVariant = "auto";
      state.smashPrimed = false;
      state.smashTapWindow = 0;
      state.smashContactGrace = 0;
      state.smashContactFallback = false;
    }
  }
  if (state.humanMode === "coop") {
    attemptHumanSwing(state, state.player, previousBall);
    attemptHumanSwing(state, state.playerMate, previousBall);
  } else if (state.humanMode === "pvp") {
    attemptHumanSwing(state, state[state.pvpActiveKey], previousBall);
  }
  if (handleNetCollision(state, previousBall)) return state.result;
  const smashReturnsOverNet = ball.shotType === "smash-x2"
    && ball.smashStage >= 2
    && ((state.lastHitterSide === "player"
      && previousBall.y < COURT.netY
      && ball.y >= COURT.netY
      && ball.vy > 0)
      || (state.lastHitterSide === "ai"
        && previousBall.y > COURT.netY
        && ball.y <= COURT.netY
        && ball.vy < 0));
  if (smashReturnsOverNet) {
    scorePoint(state, state.lastHitterSide, t("msgSmashReturned"), POINT_WINNER);
    return state.result;
  }
  if (!ball.crossedNet
    && (previousBall.y - COURT.netY) * (ball.y - COURT.netY) <= 0
    && Math.abs(ball.y - previousBall.y) > 0.01) {
    ball.crossedNet = true;
  }
  if (ball.z <= 0) {
    const discriminant = Math.max(0, previousVz * previousVz + 2 * BALANCE.ballGravity * Math.max(0, previousBall.z));
    const impactTime = clamp((previousVz + Math.sqrt(discriminant)) / BALANCE.ballGravity, 0, dt);
    const impactVz = previousVz - BALANCE.ballGravity * impactTime;
    if (handleGroundBounce(state, impactVz, dt - impactTime)) return state.result;
  }
  if (handleWalls(state)) return state.result;
  updateDoublesAI(state, dt);

  player.swing = Math.max(0, player.swing - dt * 5);
  state.playerMate.swing = Math.max(0, state.playerMate.swing - dt * 5);
  state.opponent.swing = Math.max(0, state.opponent.swing - dt * 5);
  state.opponentMate.swing = Math.max(0, state.opponentMate.swing - dt * 5);
  state.specialCooldown = Math.max(0, state.specialCooldown - dt);
  if (state.specialCooldown <= 0) state.specialReady = Math.min(1, state.specialReady + dt * BALANCE.specialRegen * state.athlete.stats.stamina);
  state.flash = Math.max(0, state.flash - dt * 3);
  captureReplayFrame(state);
  return state.result;
}

export function getMatchInfo(state) {
  const match = state.mode === "tournament"
    ? `${t("tournamentMatch")} ${state.tournamentRound + 1}/3`
    : state.mode === "career"
      ? `${t("careerMatch")} · ${t("careerSeason", { n: state.careerSeason })}`
      : t("quickMatch");
  const hm = state.humanMode === "coop" ? t("hmCoop") : state.humanMode === "pvp" ? t("hmPvp") : "";
  const base = hm ? `${match} · ${hm}` : match;
  if (state.pointsToWin) {
    return `${base} · ${t("ptsToWin", { n: state.pointsToWin })}`;
  }
  const games = state.tieBreak
    ? `${t("tieBreakShort")} ${state.tieBreakPoints.player}-${state.tieBreakPoints.ai}`
    : `${t("setLbl")} ${state.sets.player + state.sets.ai + 1} · ${t("gamesLbl")} ${state.games.player}-${state.games.ai}`;
  return `${base} · ${games}`;
}
