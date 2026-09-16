import { BALANCE, COURT, AI_OPPONENTS } from "./data.js?v=20260814-feedback-confirm-v39";
import { createMatchState, hitBall, prepareServe, updateMatch } from "./game.js?v=20260814-feedback-confirm-v39";

/**
 * Allenamento.
 *
 * Prima questo file era un secondo motore: gravita' propria, misuratore proprio,
 * un "perfetto" fissato a 0.62 che nel gioco non esiste. Si allenava quindi una
 * fisica immaginaria — nessuna finestra di timing, nessuna qualita' del colpo,
 * nessuna energia dello scambio, nessuna statistica dell'atleta, nessun vetro —
 * e quello che si imparava qui non si trasferiva in partita.
 *
 * Ora l'allenamento *e'* una partita: `createMatchState` costruisce lo stato
 * vero e `updateMatch` lo fa avanzare. Questo file fa solo le due cose che il
 * match non fa — mandare la palla e dare un punteggio agli obiettivi — cosi'
 * ogni meccanica arriva gratis, comprese quelle che verranno ritarate domani.
 */

/** Bersaglio: raggio, e quanto stretto e' il centro. */
const TARGET_R = 46;
const BULLSEYE = 0.42;

/**
 * Riferimenti per il "rimbalzo schiacciato", in |vz| all'impatto — il numero da
 * cui il motore ricava l'altezza del rimbalzo.
 *
 * Misurati sul motore, 30 prove per livello di carica: il piatto atterra fra 227
 * e 259, il taglio fra 181 e 221. Non si sovrappongono, ma il divario e' di sole
 * 6 unita': una soglia secca li' in mezzo sarebbe un interruttore, e il documento
 * di design dice che una soglia geometrica non si tara. Il punteggio e' quindi
 * *continuo* fra questi due riferimenti, cosi' premia il grado di esecuzione e
 * non un si'/no.
 *
 * Si misura all'impatto e non al secondo rimbalzo perche' il secondo rimbalzo non
 * e' osservabile dal drill: il punto viene assegnato prima, e durante
 * `pointPause` la fisica non avanza.
 */
const SQUASH_FLAT = 255;
const SQUASH_LOW = 185;

/**
 * Gli avversari si congelano alzando il loro `hitCooldown`: `hitBall` rifiuta il
 * colpo quando e' positivo e lo swing dell'IA non forza il contatto. Cosi' il
 * tiro al bersaglio si allena senza che qualcuno intercetti, e `game.js` resta
 * intatto — nessuna modalita' speciale da mantenere nel motore.
 */
const FREEZE = 5;

/**
 * Gli esercizi. `feed` decide come arriva la palla, `rivals` se la coppia
 * avversaria gioca, `targets` se si segnano zone a terra.
 */
export const DRILL_EXERCISES = [
  {
    id: "precision",
    feed: "flat",
    rivals: false,
    targets: true,
    // Due bersagli con richieste opposte: quello corto si prende solo con un
    // rimbalzo schiacciato (taglio), quello profondo con la spinta (piatto). E'
    // il compromesso descritto nel documento di design, che l'allenamento non
    // toccava in alcun modo.
    kinds: ["short", "deep"],
  },
  { id: "smash", feed: "lob", rivals: true, targets: false, kinds: [] },
  { id: "rally", feed: "flat", rivals: true, targets: false, kinds: [] },
  // Il servizio non riceve una palla: la mette in gioco. Da quando esiste la
  // dispersione d'esecuzione, seconda palla e doppio fallo sono percorsi veri del
  // motore, e fuori da una partita non c'era modo di provarli.
  { id: "serve", feed: "serve", rivals: true, targets: false, kinds: [] },
];

export function exerciseById(id) {
  return DRILL_EXERCISES.find((e) => e.id === id) ?? DRILL_EXERCISES[0];
}

/** Posizioni di partenza: giocatore a fondo campo, coppia avversaria a rete. */
function placeTeams(state) {
  const midX = (COURT.left + COURT.right) / 2;
  Object.assign(state.player, { x: midX, y: COURT.netY + 150, hitCooldown: 0 });
  Object.assign(state.playerMate, { x: midX + 190, y: COURT.netY + 120, hitCooldown: 0 });
  Object.assign(state.opponent, { x: midX - 150, y: COURT.top + 120, hitCooldown: 0 });
  Object.assign(state.opponentMate, { x: midX + 150, y: COURT.top + 150, hitCooldown: 0 });
}

export function createDrill(exerciseId, athlete, arena, aiProfile = AI_OPPONENTS[1], lineup = {}) {
  const exercise = exerciseById(exerciseId);
  const state = createMatchState("drill", athlete, arena, aiProfile, 0, { lineup });
  Object.assign(state, {
    running: true,
    serving: false,
    pointPause: 0,
    // A punti, con un traguardo inarrivabile: in allenamento nessun punto deve
    // chiudere qualcosa, e cosi' la macchina di game/set/tie-break non entra
    // mai in gioco.
    scoring: "points",
    pointsToWin: Number.MAX_SAFE_INTEGER,
    lastHitterSide: "ai",
  });
  // Il disegno della scena legge questi campi per sapere che faccia dare a ogni
  // racchetta: in partita li riempie `startMatch`. Senza, l'allenamento
  // tornerebbe a mostrare quattro volte lo stesso atleta. La formazione arriva
  // da fuori perche' risolverla richiede l'interfaccia, e questo file deve
  // restare eseguibile senza DOM.
  state.playerMateAthlete = state.lineup.playerMate ?? athlete;
  state.opponentAthlete = state.lineup.opponent ?? athlete;
  state.opponentMateAthlete = state.lineup.opponentMate ?? athlete;
  placeTeams(state);
  return {
    exercise,
    state,
    phase: "ready",
    round: 0,
    attempts: 0,
    hits: 0,
    score: 0,
    best: 0,
    streak: 0,
    points: 0,
    grade: null,
    gradeLife: 0,
    resultTimer: 0,
    target: { x: 0, y: 0, r: TARGET_R, kind: "short", active: false },
    landing: null,
    // Metriche dello scambio: nell'esercizio "rally" non ci sono bersagli e cio'
    // che conta e' quanto si regge. `lowEnergyTime` e `splitSteps` stavano qui
    // senza che nessuno li leggesse — lo stesso schema di `stats.stamina`, una
    // statistica che compare in un punto solo e non fa niente.
    rallyHits: 0,
    bestRally: 0,
    // L'ultimo colpo *del giocatore*: serve a valutare lo smash senza
    // confonderlo con la risposta avversaria.
    lastPlayerShot: null,
    // Perche' il tentativo e' andato come e' andato. Il drill dava voto e punti
    // senza dire mai *cosa* fosse sbagliato: un esercizio che valuta e non
    // diagnostica insegna a metà.
    diagnosis: null,
    // |vz| all'impatto: quanto schiacciato e' il rimbalzo che si e' prodotto.
    impactVz: 0,
    squash: 0,
    // Servizio: a quale tentativo si e' chiuso, e se e' finito in doppio fallo.
    serveAttempt: 0,
    doubleFaults: 0,
    running: true,
  };
}

/** Bersaglio nella meta' avversaria. Il tipo alterna, non e' casuale. */
function placeTarget(drill) {
  const { exercise } = drill;
  const kind = exercise.kinds.length
    ? exercise.kinds[drill.round % exercise.kinds.length]
    : "short";
  const pad = 90;
  const x = COURT.left + pad + Math.random() * (COURT.right - COURT.left - pad * 2);
  // Corto: appena oltre la rete, dove resta giocabile solo una palla che
  // rimbalza bassa. Profondo: contro il vetro di fondo, che chiede spinta.
  const y = kind === "short"
    ? COURT.netY - 130 - Math.random() * 50
    : COURT.top + 60 + Math.random() * 50;
  Object.assign(drill.target, { x, y, r: TARGET_R, kind, active: true });
}

function clampAim(value) {
  return Math.max(-1, Math.min(1, value));
}

/**
 * Manda la palla con il motore, non a mano: colpisce l'avversario con
 * `forceContact`, quindi quello che arriva e' un colpo vero del gioco — con la
 * sua dispersione, il suo effetto e la fisica dell'arena scelta.
 */
function feedBall(drill) {
  const { state, exercise } = drill;
  if (exercise.feed === "serve") {
    // Al servizio la palla la mette in gioco il giocatore: `prepareServe`
    // ricostruisce la posa e `updateMatch` gestisce carica, fallo e seconda
    // palla, cosi' l'esercizio usa le regole vere e non una loro imitazione.
    state.serveSide = "player";
    state.serveAttempts = 0;
    state.serving = true;
    prepareServe(state);
    state.lastHitterSide = null;
    drill.landing = null;
    return;
  }
  const feeder = state.opponent;
  const midX = (COURT.left + COURT.right) / 2;
  Object.assign(state.ball, {
    x: feeder.x,
    y: feeder.y + 10,
    z: exercise.feed === "lob" ? 96 : 70,
    vx: 0,
    vy: 0,
    vz: 0,
    bounces: { player: 0, ai: 0 },
    serveInFlight: false,
    serveTouchedNet: false,
    netFaultOwner: null,
    crossedNet: false,
    shotType: null,
    smashStage: 0,
    backspin: 0,
    topspin: 0,
  });
  feeder.hitCooldown = 0;
  const mira = clampAim((midX - feeder.x) / ((COURT.right - COURT.left) / 2));
  if (exercise.feed === "lob") {
    // Palla alta e molle a meta' campo: il punteggio di attaccabilita' la legge
    // come smashabile, che e' la situazione da allenare.
    hitBall(state, feeder, 0.62, false, true, mira, false, "lob");
  } else {
    hitBall(state, feeder, 0.86, false, true, mira, false, "auto");
  }
  state.lastHitterSide = "ai";
  drill.landing = null;
}

function startRound(drill) {
  if (drill.exercise.targets) placeTarget(drill);
  else drill.target.active = false;
  drill.phase = "live";
  drill.grade = null;
  drill.gradeLife = 0;
  drill.rallyHits = 0;
  drill.lastPlayerShot = null;
  drill.diagnosis = null;
  drill.impactVz = 0;
  drill.squash = 0;
  drill.serveAttempt = 0;
  feedBall(drill);
}

export function resetDrill(drill) {
  drill.phase = "ready";
  drill.grade = null;
  drill.gradeLife = 0;
  drill.landing = null;
  drill.target.active = false;
  drill.resultTimer = 0;
  placeTeams(drill.state);
}

/**
 * Chiude il tentativo e assegna il punteggio. Il voto di esecuzione non viene
 * inventato qui: arriva da `state.shotFeedback`, la stessa valutazione del
 * motore che in partita governa qualita' del colpo e finestra di timing.
 */
function closeAttempt(drill, { inZone, tier, diagnosis = null }) {
  const grade = drill.grade ?? "good";
  const gradeMult = grade === "perfect" ? 1 : grade === "good" ? 0.72 : 0.45;
  drill.points = Math.round(10 * tier * gradeMult);
  drill.attempts += 1;
  if (inZone) drill.hits += 1;
  drill.score += drill.points;
  drill.streak = inZone ? drill.streak + 1 : 0;
  drill.best = Math.max(drill.best, drill.score);
  drill.diagnosis = diagnosis;
  drill.round += 1;
  drill.phase = "result";
  drill.resultTimer = 1.6;
}

/**
 * Quanto e' schiacciato il rimbalzo prodotto, da 0 a 1.
 *
 * Continuo, non a soglia: fra i riferimenti misurati il valore scorre, quindi un
 * taglio mal eseguito prende meno di uno riuscito invece di passare comunque.
 */
function squashQuality(impactVz) {
  const q = (SQUASH_FLAT - impactVz) / (SQUASH_FLAT - SQUASH_LOW);
  return Math.max(0, Math.min(1, q));
}

/**
 * Il bersaglio corto vuole un rimbalzo schiacciato, il profondo la spinta.
 *
 * La coerenza del colpo non si giudica piu' dalla bandierina `backspin`, che
 * diceva soltanto "hai premuto X": si giudica dall'esito, cioe' da quanto basso
 * rimbalza la palla che hai prodotto. E' quello che il taglio compra secondo il
 * documento di design, ed e' quello che ora va dimostrato.
 */
function targetTier(drill, ball) {
  const dist = Math.hypot(ball.x - drill.target.x, ball.y - drill.target.y);
  const corto = drill.target.kind === "short";
  if (dist > drill.target.r) {
    // La diagnosi guarda la direzione dell'errore: il verso di `y` cresce
    // allontanandosi dal fondo, quindi piu' grande vuol dire piu' corto.
    const lontanoX = Math.abs(ball.x - drill.target.x) > drill.target.r;
    const diagnosis = lontanoX
      ? "drillWhyWide"
      : ball.y > drill.target.y ? "drillWhyShort" : "drillWhyDeep";
    return { inZone: false, tier: 0.2, diagnosis };
  }
  const centrato = dist < drill.target.r * BULLSEYE;
  const base = centrato ? 1 : 0.6;
  const q = drill.squash;
  // Il corto premia il rimbalzo basso, il profondo la spinta: sono la stessa
  // scala letta nei due versi.
  const esecuzione = corto ? q : 1 - q;
  if (esecuzione < 0.35) {
    return {
      inZone: true,
      tier: base * 0.5,
      diagnosis: corto ? "drillWhyTooBouncy" : "drillWhyTooSoft",
    };
  }
  return {
    inZone: true,
    tier: base * (0.62 + esecuzione * 0.38),
    diagnosis: centrato ? "drillWhyBullseye" : "drillWhyInZone",
  };
}

/** Il punto e' finito: `updateMatch` ha messo un esito o una pausa. */
function puntoChiuso(state) {
  return Boolean(state.result) || state.pointPause > 0;
}

/** Riazzera l'esito perche' l'allenamento non ha un punteggio da difendere. */
function consumaEsito(state) {
  state.result = null;
  state.pointPause = 0;
}

export function updateDrill(drill, dt, input) {
  if (!drill.running) return;
  const { state, exercise } = drill;
  drill.gradeLife = Math.max(0, drill.gradeLife - dt);

  if (drill.phase === "ready") {
    if (input.hit) startRound(drill);
    return;
  }

  if (drill.phase === "result") {
    drill.resultTimer = Math.max(0, drill.resultTimer - dt);
    if (input.hit || drill.resultTimer === 0) {
      resetDrill(drill);
      startRound(drill);
    }
    return;
  }

  if (drill.phase !== "live") return;

  // Gli avversari restano immobili solo dove l'esercizio lo richiede.
  if (!exercise.rivals) {
    state.opponent.hitCooldown = FREEZE;
    state.opponentMate.hitCooldown = FREEZE;
  }

  const colpiPrima = state.rallyHits;
  const puntiPrima = state.stats.pointsWon.player;
  const falliPrima = state.stats.doubleFaults.player;
  const zPrima = state.ball.z;
  // La velocita' verticale *prima* del passo: dopo l'impatto il motore l'ha gia'
  // riflessa e attenuata, quindi letta dopo non direbbe piu' con quanta forza la
  // palla e' arrivata a terra.
  const vzPrima = state.ball.vz;
  updateMatch(state, dt, input);

  // Il voto arriva dal motore, ma solo quello del giocatore: `shotFeedback` e'
  // condiviso e senza il filtro su `paddleKey` l'allenamento mostrerebbe la
  // valutazione del colpo avversario come se fosse la propria.
  const feedback = state.shotFeedback;
  if (feedback?.grade && (feedback.paddleKey === "player" || feedback.paddleKey === state.activePlayerKey)) {
    drill.grade = feedback.grade;
    drill.gradeLife = 1.2;
  }
  if (state.rallyHits > colpiPrima) {
    drill.rallyHits += 1;
    drill.bestRally = Math.max(drill.bestRally, drill.rallyHits);
    // Il tipo di colpo va preso *ora*, mentre l'ha appena battuto il giocatore.
    // Leggerlo a punto chiuso, com'era prima, restituiva il colpo di chi aveva
    // toccato per ultimo: misurato su cinque partenze, lo smash risultava
    // "drive" tre volte su cinque perche' nel frattempo aveva risposto
    // l'avversario, e il punteggio finiva sempre allo scalino piu' basso.
    if (state.lastHitterSide === "player") drill.lastPlayerShot = state.ball.shotType;
  }

  const ball = state.ball;
  const atterrata = zPrima > 0 && ball.z <= 0;
  if (atterrata) {
    drill.impactVz = Math.abs(vzPrima);
    drill.squash = squashQuality(drill.impactVz);
  }

  if (exercise.targets) {
    if (atterrata && drill.target.active) {
      drill.landing = { x: ball.x, y: ball.y };
      // Solo un rimbalzo nella meta' avversaria e' un tiro al bersaglio; nella
      // propria meta' la palla e' morta e il tentativo e' mancato.
      closeAttempt(drill, ball.y < COURT.netY
        ? targetTier(drill, ball)
        : { inZone: false, tier: 0, diagnosis: "drillWhyOwnHalf" });
    } else if (puntoChiuso(state)) {
      consumaEsito(state);
      closeAttempt(drill, { inZone: false, tier: 0, diagnosis: "drillWhyMissed" });
    }
    return;
  }

  if (exercise.id === "serve") {
    // Il doppio fallo lo dichiara il motore; la seconda palla si legge da
    // `serveAttempts`, che era un percorso irraggiungibile prima della
    // dispersione d'esecuzione.
    drill.serveAttempt = state.serveAttempts;
    if (state.stats.doubleFaults.player > falliPrima) {
      drill.doubleFaults += 1;
      consumaEsito(state);
      closeAttempt(drill, { inZone: false, tier: 0, diagnosis: "drillWhyDoubleFault" });
      return;
    }
    if (!puntoChiuso(state)) return;
    // Servizio andato a segno: la prima palla vale piena, la seconda meno,
    // l'ace di piu'. Non e' il punto a contare, e' aver messo dentro il servizio.
    const ace = state.stats.aces.player > 0;
    const prima = drill.serveAttempt === 0;
    const tier = ace ? 1.5 : prima ? 1 : 0.6;
    consumaEsito(state);
    state.stats.aces.player = 0;
    closeAttempt(drill, {
      inZone: true,
      tier,
      diagnosis: ace ? "drillWhyAce" : prima ? "drillWhyFirstServe" : "drillWhySecondServe",
    });
    return;
  }

  if (!puntoChiuso(state)) return;

  if (exercise.id === "smash") {
    // Lo x2 e lo x3 valgono se sopravvivono: l'esito lo decide il motore, non
    // il momento in cui parte il colpo.
    const vinto = state.stats.pointsWon.player > puntiPrima;
    const colpo = drill.lastPlayerShot;
    const smashato = colpo === "smash-x2" || colpo === "smash-x3";
    const tier = colpo === "smash-x3" ? 1.4 : colpo === "smash-x2" ? 1 : 0.35;
    consumaEsito(state);
    closeAttempt(drill, {
      inZone: vinto,
      tier: vinto ? tier : 0.2,
      diagnosis: !smashato
        ? "drillWhyNoSmash"
        : vinto ? (colpo === "smash-x3" ? "drillWhyX3" : "drillWhyX2") : "drillWhyDefended",
    });
    return;
  }

  // Scambio: il tentativo dura quanto il punto, e il punteggio premia la
  // lunghezza invece del singolo colpo.
  const tenuto = drill.rallyHits;
  const energia = state.rallyEnergy?.player ?? 1;
  consumaEsito(state);
  closeAttempt(drill, {
    inZone: tenuto >= 4,
    tier: Math.min(1.5, 0.25 + tenuto * 0.18),
    diagnosis: tenuto < 2
      ? "drillWhyRallyShort"
      : energia < BALANCE.rallyEnergyFloor + 0.2 ? "drillWhyDrained" : "drillWhyRallyHeld",
  });
}

/** Riga di esito per l'interfaccia. */
export function drillScoreLine(drill) {
  if (!drill.grade) return "—";
  // Le quattro classi sono quelle del motore: perfect, good, early, late.
  const etichette = { perfect: "PERFECT ⭐", good: "GOOD", early: "EARLY", late: "LATE" };
  const etichetta = etichette[drill.grade] ?? "—";
  return `${etichetta} · ${drill.points}`;
}

/** Le quattro metriche dell'HUD, diverse per esercizio. */
export function drillMetrics(drill) {
  if (drill.exercise.id === "rally") {
    return [
      { key: "drillScore", value: String(drill.score) },
      { key: "drillBestRally", value: String(drill.bestRally) },
      { key: "drillEnergy", value: `${Math.round((drill.state.rallyEnergy?.player ?? 1) * 100)}%` },
      { key: "drillBest", value: String(drill.best) },
    ];
  }
  if (drill.exercise.id === "serve") {
    return [
      { key: "drillScore", value: String(drill.score) },
      { key: "drillBest", value: String(drill.best) },
      { key: "drillIn", value: `${drill.hits}/${drill.attempts}` },
      { key: "drillDoubleFaults", value: String(drill.doubleFaults) },
    ];
  }
  return [
    { key: "drillScore", value: String(drill.score) },
    { key: "drillBest", value: String(drill.best) },
    { key: "drillHits", value: `${drill.hits}/${drill.attempts}` },
    { key: "drillStreak", value: String(drill.streak) },
  ];
}
