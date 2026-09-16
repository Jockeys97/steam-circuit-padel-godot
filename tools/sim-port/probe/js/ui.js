import { ATHLETES, ARENAS, AI_OPPONENTS, COURT, isUnlocked, outfitChallengeMet, seasonObjectives, matchObjective, OBJECTIVE_DEFS, UNLOCK_CODE, outfitsForAthlete, SEASON_METRIC_AGG, emptySeasonProgress, CAREER_MATCHES, CAREER_PROMOTION_WINS, CAREER_FINAL_SEASON, careerAiProfile, careerFixture, tournamentFixture, VERSION, FEEDBACK, FEEDBACK_TOPICS } from "./data.js?v=20260814-feedback-confirm-v39";
import { getMatchInfo } from "./game.js?v=20260814-feedback-confirm-v39";
import { getVolume, isMuted } from "./audio.js?v=20260814-feedback-confirm-v39";
import { getLang, t } from "./i18n.js?v=20260814-feedback-confirm-v39";
import { IS_DEMO, DEMO_CONTENT, demoFilter, demoLocked } from "./build.js?v=20260814-feedback-confirm-v39";

const PREFS_KEY = "padel.prefs";
const HISTORY_KEY = "padel.history";
const DRILL_KEY = "padel.drill";
const FEEDBACK_KEY = "padel.feedback";
const CAREER_KEY = "padel.career";
const DEFAULT_CAREER = {
  season: 1,
  matchIndex: 0,
  wins: 0,
  losses: 0,
  trophies: 0,
  stars: 0,
  seasonObjectives: [],
  seasonStars: 0,
  rivalStreak: 0,
  // Vittorie nella stagione in corso: decide se si avanza, se si vince il
  // trofeo o se la stagione va rigiocata.
  seasonWins: 0,
  // Totale delle metriche sui match della stagione: gli obiettivi di stagione si
  // misurano qui, non sull'ultima partita.
  seasonProgress: emptySeasonProgress(),
  // Obiettivi di stagione gia' premiati, per stagione: "3" -> ["winners", ...].
  // Ripetere una stagione non deve poter ridare la stessa stella.
  claimedObjectives: {},
  // Stagione piu' alta raggiunta: il finale si vede una volta sola.
  bestSeason: 1,
  finaleSeen: false,
  unlockAll: false,
  equippedOutfits: {},
};

export function loadCareer() {
  try {
    const raw = localStorage.getItem(CAREER_KEY);
    if (raw) return { ...DEFAULT_CAREER, ...JSON.parse(raw) };
  } catch {
    // persistenza non disponibile
  }
  return { ...DEFAULT_CAREER };
}

export function saveCareer(career) {
  try {
    localStorage.setItem(CAREER_KEY, JSON.stringify(career));
  } catch {
    // persistenza non disponibile
  }
}

/** Assicura che gli obiettivi della stagione corrente siano inizializzati. */
/** Firma di una terna di obiettivi: cambia se cambiano gli id o i target. */
function objectivesSignature(objectives) {
  return (objectives ?? []).map((o) => `${o.id}:${o.target}`).join("|");
}

export function ensureSeasonObjectives() {
  const career = ui.career;
  const attesi = seasonObjectives(career.season);
  // Gli obiettivi vivono in `localStorage`, e prima si rigeneravano solo quando
  // l'elenco era vuoto: una partita a stagione iniziata si portava dietro i
  // target del salvataggio anche dopo una ritaratura. Con la vecchia formula
  // questo teneva in vita gli obiettivi impossibili — `winPoints` da 26 punti in
  // match da 11 — proprio nei salvataggi che dovevano essere riparati.
  const daRigenerare = !career.seasonObjectives?.length
    || objectivesSignature(career.seasonObjectives) !== objectivesSignature(attesi);
  if (daRigenerare) {
    // `claimed` distingue "da centrare" da "gia' pagato in un tentativo
    // precedente di questa stagione": il secondo si centra ancora, ma non da'
    // un'altra stella. Sopravvive alla rigenerazione, altrimenti ritarare gli
    // obiettivi regalerebbe di nuovo le stelle gia' riscosse.
    const claimed = new Set(career.claimedObjectives?.[career.season] ?? []);
    career.seasonObjectives = attesi.map((o) => ({ ...o, done: false, claimed: claimed.has(o.id) }));
    career.seasonStars = 0;
    saveCareer(career);
  }
  return career.seasonObjectives;
}

/**
 * Riduce i stats di un match alla mappa piatta `metrica -> valore` con cui si
 * misurano gli obiettivi. Match e stagione usano cosi' la stessa forma: prima la
 * valutazione leggeva direttamente `stats.x.player` e il totale di stagione non
 * aveva modo di passare da li'.
 */
export function matchProgress(stats) {
  return {
    pointsWon: stats.pointsWon.player,
    winners: stats.winners.player,
    smashWinners: stats.smashWinners.player,
    errors: stats.errors.player,
    doubleFaults: stats.doubleFaults.player,
    longestRally: stats.longestRally,
  };
}

/**
 * Somma un match nel totale della stagione. Gli obiettivi di stagione si
 * valutano su questo, non sull'ultima partita giocata.
 */
export function accumulateSeasonProgress(stats) {
  const career = ui.career;
  const totals = { ...emptySeasonProgress(), ...(career.seasonProgress ?? {}) };
  const match = matchProgress(stats);
  Object.entries(SEASON_METRIC_AGG).forEach(([metric, agg]) => {
    totals[metric] = agg === "max"
      ? Math.max(totals[metric] ?? 0, match[metric])
      : (totals[metric] ?? 0) + match[metric];
  });
  career.seasonProgress = totals;
  return totals;
}

/** Il totale di stagione, anche prima che sia stato giocato un match. */
export function seasonProgress() {
  return { ...emptySeasonProgress(), ...(ui.career.seasonProgress ?? {}) };
}

function objectiveMet(defId, target, progress) {
  const metric = OBJECTIVE_DEFS[defId]?.metric;
  const value = progress?.[metric] ?? 0;
  return OBJECTIVE_DEFS[defId]?.unit === "max" ? value <= target : value >= target;
}

/** Valuta un obiettivo su una mappa di progresso e ritorna { done, progress, target }. */
export function objectiveStatus(objective, progress) {
  const metric = OBJECTIVE_DEFS[objective.id]?.metric;
  return {
    done: objectiveMet(objective.id, objective.target, progress),
    progress: progress?.[metric] ?? 0,
    target: objective.target,
  };
}

/**
 * Premia le stelle a fine match di carriera.
 * Ritorna { seasonDone: [...], matchDone: bool, stars: n } per il riepilogo.
 */
export function awardObjectives(state) {
  const career = ui.career;
  const stats = state.stats;
  const result = { seasonDone: [], matchDone: false, stars: 0 };
  if (!stats) return result;

  // L'obiettivo bonus vive dentro il singolo match: si valuta su quello.
  const mo = matchObjective(career.season, career.matchIndex);
  if (objectiveMet(mo.id, mo.target, matchProgress(stats))) {
    result.matchDone = true;
    result.stars += 1;
  }

  // Gli obiettivi di stagione si valutano sul totale accumulato, e una stella
  // per obiettivo si prende una volta per stagione: `claimedObjectives` lo
  // ricorda anche quando la stagione viene rigiocata. Prima le stelle si
  // riazzeravano a ogni ripetizione, quindi perdendo di proposito si restava in
  // stagione 1 e si rifarmavano le stesse tre stelle all'infinito — 60 stelle in
  // dieci cicli, abbastanza per tutto cio' che le stelle sbloccano.
  const totals = accumulateSeasonProgress(stats);
  const claimed = new Set(career.claimedObjectives?.[career.season] ?? []);
  ensureSeasonObjectives().forEach((o) => {
    if (!objectiveMet(o.id, o.target, totals)) return;
    o.done = true;
    if (claimed.has(o.id)) return;
    claimed.add(o.id);
    result.seasonDone.push(o.id);
    result.stars += 1;
  });
  career.claimedObjectives = { ...(career.claimedObjectives ?? {}), [career.season]: [...claimed] };

  career.stars += result.stars;
  career.seasonStars += result.stars;
  saveCareer(career);
  return result;
}

/**
 * Azzera lo stato di stagione: obiettivi e totali ripartono da zero. Le stelle
 * gia' riscosse no — quelle vivono in `career.claimedObjectives`, che sopravvive
 * alla ripetizione della stagione.
 */
export function resetSeasonObjectives() {
  ui.career.seasonObjectives = [];
  ui.career.seasonStars = 0;
  ui.career.seasonProgress = emptySeasonProgress();
  ensureSeasonObjectives();
  saveCareer(ui.career);
}

/**
 * Record dell'allenamento, uno per esercizio.
 *
 * Il record viveva sull'oggetto del drill e moriva con la sessione: non restava
 * niente per cui tornare, mentre la carriera i suoi progressi li conserva. Sta
 * qui e non in `drill.js` perche' quel file deve restare eseguibile senza DOM —
 * lo importa l'audit in Node, dove `localStorage` non esiste.
 *
 * La chiave e' per esercizio: i punteggi non sono confrontabili fra un tiro al
 * bersaglio e uno scambio, e un record unico avrebbe premiato solo il piu'
 * generoso.
 */
export function loadDrillRecords() {
  try {
    const raw = localStorage.getItem(DRILL_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

export function drillRecord(exerciseId) {
  return loadDrillRecords()[exerciseId] ?? 0;
}

/** Salva solo se e' un miglioramento, e ritorna il record aggiornato. */
export function saveDrillRecord(exerciseId, score) {
  const records = loadDrillRecords();
  if (score <= (records[exerciseId] ?? 0)) return records[exerciseId] ?? 0;
  records[exerciseId] = score;
  try {
    localStorage.setItem(DRILL_KEY, JSON.stringify(records));
  } catch {
    // persistenza non disponibile: il record vale per questa sessione
  }
  return score;
}

/**
 * Feedback dei giocatori.
 *
 * Il valore non sta nel testo libero: sta in cio' che gli si allega. "Lo smash e'
 * troppo forte" non si puo' usare senza sapere con quale atleta, in quale arena, a
 * quale difficolta' e — soprattutto — con quale taratura di `BALANCE` in vigore.
 * Quei dati il gioco li ha gia' tutti; qui vengono solo raccolti.
 *
 * La coda locale e' la rete di sicurezza: si scrive **prima** di qualunque
 * tentativo di invio, perche' su Steam si gioca anche offline e una POST fallita
 * perderebbe il messaggio senza che nessuno se ne accorga.
 */
export function loadFeedbackQueue() {
  try {
    const raw = localStorage.getItem(FEEDBACK_KEY);
    const list = raw ? JSON.parse(raw) : [];
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

function saveFeedbackQueue(list) {
  try {
    localStorage.setItem(FEEDBACK_KEY, JSON.stringify(list.slice(0, FEEDBACK.maxQueued)));
  } catch {
    // persistenza non disponibile: il messaggio vale per questa sessione
  }
}

/**
 * Il contesto tecnico che accompagna il messaggio.
 *
 * Niente qui viene inventato o dedotto dall'utente: sono lo stato del gioco e le
 * capacita' del browser. Il giocatore puo' rifiutarlo — `renderFeedback` mostra
 * esattamente questo oggetto prima dell'invio, perche' allegare dati senza farli
 * vedere non e' accettabile e su Steam richiederebbe un'informativa a parte.
 */
export function feedbackDiagnostics() {
  const history = loadHistory();
  const career = ui.career;
  return {
    version: VERSION.build,
    balance: VERSION.balance,
    lang: getLang(),
    demo: IS_DEMO,
    // Utile per i reclami su prestazioni e input, che senza questi sono ciechi.
    platform: typeof navigator === "undefined" ? null : navigator.platform ?? null,
    screen: typeof window === "undefined" ? null : `${window.innerWidth}x${window.innerHeight}`,
    gamepad: ui.lastGamepadId ?? null,
    controlMode: ui.controlMode ?? null,
    reduceMotion: Boolean(ui.reduceMotion),
    settings: {
      difficulty: ui.aiDifficulty ?? null,
      matchLength: ui.matchLength ?? null,
      drillDifficulty: ui.drillDifficulty ?? null,
    },
    career: {
      season: career?.season ?? null,
      trophies: career?.trophies ?? null,
      stars: career?.stars ?? null,
      wins: career?.wins ?? null,
      losses: career?.losses ?? null,
    },
    drillRecords: loadDrillRecords(),
    // Le ultime partite: e' il contesto che rende leggibile un reclamo di
    // bilanciamento. Tre bastano — la coda deve restare una casella di posta.
    recentMatches: history.slice(0, 3).map((m) => ({
      mode: m.mode,
      winner: m.winner,
      score: m.score,
      athlete: m.athlete,
      opponent: m.opponent,
      arena: m.arena,
      difficulty: m.difficulty,
    })),
    matchesPlayed: history.length,
  };
}

/**
 * Accoda un feedback. Ritorna la voce salvata, cosi' chi chiama puo' copiarla
 * negli appunti o tentare l'invio senza ricostruirla.
 */
export function queueFeedback({ topic, message, contact = "", attach = true }) {
  const scelto = FEEDBACK_TOPICS.includes(topic) ? topic : "other";
  const entry = {
    id: `fb-${Date.now().toString(36)}`,
    ts: new Date().toISOString(),
    topic: scelto,
    message: String(message ?? "").slice(0, FEEDBACK.maxMessage),
    // Il contatto e' facoltativo e resta come l'ha scritto il giocatore: serve
    // solo se vuole una risposta.
    contact: String(contact ?? "").slice(0, 120),
    diagnostics: attach ? feedbackDiagnostics() : null,
    sent: false,
  };
  const list = loadFeedbackQueue();
  list.unshift(entry);
  saveFeedbackQueue(list);
  return entry;
}

/** Segna come inviate le voci indicate, senza cancellarle. */
export function markFeedbackSent(ids) {
  const da = new Set(ids);
  const list = loadFeedbackQueue().map((e) => (da.has(e.id) ? { ...e, sent: true } : e));
  saveFeedbackQueue(list);
  return list;
}

/**
 * Prova a spedire le voci non ancora inviate.
 *
 * Senza `endpoint` configurato non fallisce e non finge: dichiara che non c'e'
 * nulla da spedire, e il messaggio resta in coda per la copia manuale. Cosi' il
 * giorno in cui l'endpoint esistera' bastera' riempire quel campo.
 */
export async function flushFeedback(
  fetchImpl = typeof fetch === "function" ? fetch : null,
  endpoint = FEEDBACK.endpoint,
) {
  const pending = loadFeedbackQueue().filter((e) => !e.sent);
  // `endpoint` e `fetchImpl` sono parametri e non costanti lette qui dentro
  // perche' altrimenti, con l'endpoint ancora da configurare, i rami "rifiutato"
  // e "offline" sarebbero irraggiungibili: si scoprirebbe se funzionano il giorno
  // in cui vanno in produzione. E' lo stesso difetto del servizio che non poteva
  // fallire — un percorso che il documento prevede e che nessuna prova esegue.
  if (!endpoint || !fetchImpl) {
    return { ok: false, reason: "no-endpoint", pending: pending.length };
  }
  if (!pending.length) return { ok: true, sent: 0, pending: 0 };
  try {
    const response = await fetchImpl(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ entries: pending }),
    });
    if (!response?.ok) return { ok: false, reason: "rejected", pending: pending.length };
    markFeedbackSent(pending.map((e) => e.id));
    return { ok: true, sent: pending.length, pending: 0 };
  } catch {
    // La rete puo' mancare: la coda resta intatta e si riprova alla prossima.
    return { ok: false, reason: "offline", pending: pending.length };
  }
}

/**
 * Il `mailto:` con cui il giocatore spedisce il messaggio dal proprio client.
 *
 * E' l'unico recapito raggiungibile senza un server: dal browser non si spedisce
 * posta. Il corpo viene troncato perche' `mailto:` passa dalla barra degli
 * indirizzi e alcuni client tagliano i testi lunghi — la copia intera resta in
 * coda, quindi nulla va perduto comunque.
 */
export function feedbackMailto(entry, email = FEEDBACK.email) {
  if (!email) return null;
  const oggetto = `[padel] ${entry.topic} · ${VERSION.build} · balance ${VERSION.balance}`;
  const corpo = feedbackAsText(entry).slice(0, FEEDBACK.maxMailBody);
  return `mailto:${email}?subject=${encodeURIComponent(oggetto)}&body=${encodeURIComponent(corpo)}`;
}

/** Il testo da incollare in una discussione, quando l'invio non c'e'. */
export function feedbackAsText(entry) {
  const righe = [
    `[${entry.topic}] ${VERSION.build} · balance ${VERSION.balance}`,
    entry.message,
  ];
  if (entry.contact) righe.push(`contatto: ${entry.contact}`);
  if (entry.diagnostics) righe.push("", "--- contesto tecnico ---", JSON.stringify(entry.diagnostics, null, 2));
  return righe.join("\n");
}

export function loadPrefs() {
  try {
    const raw = localStorage.getItem(PREFS_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

export function savePrefs(prefs) {
  try {
    localStorage.setItem(PREFS_KEY, JSON.stringify(prefs));
  } catch {
    // persistenza non disponibile: nessun blocco
  }
}

export function collectPrefs() {
  return {
    athleteId: ui.selectedAthlete?.id ?? null,
    arenaId: ui.selectedArena?.id ?? null,
    mode: ui.selectedMode ?? null,
    tournamentRound: ui.selectedMode === "tournament" ? ui.tournamentRound : 0,
    muted: isMuted(),
    controlMode: ui.controlMode,
    gamepadDeadzone: ui.gamepadDeadzone,
    vibration: ui.vibration,
    aiDifficulty: ui.aiDifficulty,
    matchLength: ui.matchLength,
    volume: getVolume(),
    reduceMotion: ui.reduceMotion,
    matchPanel: ui.matchPanel,
    colorblind: ui.colorblind,
    lang: ui.lang,
    playerMode: ui.playerMode,
    lineup: ui.lineup,
  };
}

const screens = {
  menu: document.getElementById("screen-menu"),
  characters: document.getElementById("screen-characters"),
  modes: document.getElementById("screen-modes"),
  arena: document.getElementById("screen-arena"),
  help: document.getElementById("screen-help"),
  history: document.getElementById("screen-history"),
  challenges: document.getElementById("screen-challenges"),
  profile: document.getElementById("screen-profile"),
  drill: document.getElementById("screen-drill"),
  feedback: document.getElementById("screen-feedback"),
  settings: document.getElementById("screen-settings"),
  game: document.getElementById("screen-game"),
  result: document.getElementById("screen-result"),
};

export const ui = {
  selectedAthlete: null,
  selectedMode: null,
  selectedArena: null,
  tournamentRound: 0,
  pendingContinue: false,
  controlMode: "semi",
  gamepadDeadzone: 0.15,
  vibration: true,
  aiDifficulty: "easy",
  matchLength: "points11",
  reduceMotion: false,
  // Vista immersiva: il campo riempie lo schermo, la fascia sotto e' opzionale.
  matchPanel: false,
  colorblind: false,
  lang: "en",
  playerMode: "solo",
  // Chi occupa le altre tre posizioni: identificativi, non oggetti, perche'
  // vengono salvati fra una sessione e l'altra. `null` significa "scegli tu",
  // ed e' il valore con cui il gioco parte.
  lineup: { playerMate: null, opponent: null, opponentMate: null },
  career: loadCareer(),
};

/** Gli atleti effettivamente schierabili: niente bloccati, niente fuori demo. */
export function selectableAthletes() {
  return demoFilter(ATHLETES, DEMO_CONTENT.athletes).filter((a) => isUnlocked(a, ui.career));
}

/** Le arene giocabili, con lo stesso criterio degli atleti. */
export function selectableArenas() {
  return demoFilter(ARENAS, DEMO_CONTENT.arenas).filter((a) => isUnlocked(a, ui.career));
}

/**
 * Il turno di calendario in corso: quale arena e quale rivale. In carriera l'arena
 * la decide il circuito, non il menu — tre match nello stesso campo scelto da te
 * erano tre match indistinguibili, e non davano nessun motivo per giocare l'arena
 * difficile.
 */
export function currentFixture() {
  return careerFixture(ui.career.season, ui.career.matchIndex, selectableArenas());
}

/** Il campo del turno di torneo in corso, deciso dal tabellone. */
export function currentTournamentFixture() {
  return tournamentFixture(ui.tournamentRound, selectableArenas());
}

/**
 * Da tre identificativi alle tre formazioni complete.
 *
 * Le posizioni non scelte vengono riempite con i primi atleti disponibili, che
 * e' esattamente cio' che il gioco faceva prima in automatico. Serve anche a
 * reggere i casi limite senza schermate d'errore: nella demo ci sono due soli
 * atleti, e un identificativo salvato puo' riferirsi a un atleta non ancora
 * sbloccato in questa carriera.
 */
/**
 * Chi ti tocca affrontare, quando non lo decidi tu.
 *
 * In carriera il rivale e il suo livello vengono dal calendario — la schermata
 * lo nomina pure — e in torneo dal tabellone. Scegliersi anche gli avversari
 * significherebbe scegliersi il sorteggio: la progressione perde il suo senso
 * se il gradino successivo se lo compone il giocatore. Restituisce `null` per
 * la partita rapida, dove invece e' giusto scegliere tutto.
 *
 * La coppia e' derivata dal punto del circuito in cui ci si trova, quindi e'
 * sempre la stessa per quella giornata: la si puo' preparare, e ripetere un
 * match perso non rimescola l'avversario.
 */
export function dictatedRivals(esclusi = []) {
  const seme = ui.selectedMode === "career"
    ? ui.career.season * CAREER_MATCHES + ui.career.matchIndex
    : ui.selectedMode === "tournament"
      ? ui.tournamentRound + 1
      : null;
  if (seme === null) return null;
  const pool = ATHLETES.filter((a) => !esclusi.includes(a.id));
  if (pool.length < 2) return null;
  const primo = pool[seme % pool.length];
  const resto = pool.filter((a) => a.id !== primo.id);
  return {
    opponent: primo,
    opponentMate: resto[(seme * 3 + 1) % resto.length],
  };
}

export function resolveLineup(athlete) {
  const disponibili = selectableAthletes();
  const scelto = (id) => (id ? disponibili.find((a) => a.id === id) : null) ?? null;
  // Si sceglie solo fra gli atleti disponibili, ma il ripiego pesca dal roster
  // intero: nella demo si gioca con due atleti e si affrontano gli altri, che e'
  // esattamente cio' che accadeva prima. Restringere anche il ripiego avrebbe
  // messo lo stesso avversario in tutte e tre le posizioni.
  // Un identificativo vale solo se l'atleta e' disponibile, non e' quello con
  // cui si gioca e non e' gia' schierato altrove: cambiando atleta principale
  // ci si ritroverebbe altrimenti due volte lo stesso in campo.
  const lineup = { playerMate: null, opponent: null, opponentMate: null };
  const usati = new Set([athlete.id]);
  // Il secondo giocatore si sceglie sempre: e' la tua meta' campo.
  const candidatoMate = scelto(ui.lineup.playerMate);
  if (candidatoMate && !usati.has(candidatoMate.id)) {
    lineup.playerMate = candidatoMate;
    usati.add(candidatoMate.id);
  }
  // Gli avversari li sceglie il calendario o il tabellone, quando ce n'e' uno.
  const dettati = dictatedRivals([athlete.id, lineup.playerMate?.id].filter(Boolean));
  for (const ruolo of ["opponent", "opponentMate"]) {
    const candidato = dettati ? dettati[ruolo] : scelto(ui.lineup[ruolo]);
    if (candidato && !usati.has(candidato.id)) {
      lineup[ruolo] = candidato;
      usati.add(candidato.id);
    }
  }
  // Il ripiego non ripesca chi e' gia' in campo, cosi' una partita fra quattro
  // atleti diversi resta il caso normale anche senza scegliere niente.
  const riserve = ATHLETES.filter((a) => a.id !== athlete.id);
  const libero = () => {
    const occupati = new Set([athlete.id, ...Object.values(lineup).filter(Boolean).map((a) => a.id)]);
    return riserve.find((a) => !occupati.has(a.id)) ?? riserve[0] ?? athlete;
  };
  for (const ruolo of ["playerMate", "opponent", "opponentMate"]) {
    if (!lineup[ruolo]) lineup[ruolo] = libero();
  }
  // Il completo e' una proprieta' dell'atleta, non della casella: e' salvato in
  // `equippedOutfits[id]`. Applicarlo qui, in un punto solo, e' cio' che fa
  // combaciare quello che si vede nel pannello con quello che scende in campo —
  // prima il completo lo riceveva soltanto l'atleta del giocatore.
  for (const ruolo of ["playerMate", "opponent", "opponentMate"]) {
    lineup[ruolo] = athleteWithOutfit(lineup[ruolo]);
  }
  return lineup;
}

export function showScreen(name) {
  // Un nome non registrato spegneva tutte le schermate senza accenderne nessuna:
  // pagina bianca, nessun errore, e nulla che dicesse dove guardare. Meglio
  // restare dove si e' e lasciare una traccia leggibile.
  if (!screens[name]) {
    console.warn(`showScreen: schermata "${name}" non registrata in screens`);
    return;
  }
  Object.entries(screens).forEach(([key, el]) => {
    el?.classList.toggle("screen--active", key === name);
  });
  window.scrollTo(0, 0);
}

function selectedOutfit(athlete, career = ui.career) {
  const outfits = outfitsForAthlete(athlete?.id);
  if (!outfits.length) return null;
  const selectedId = career.equippedOutfits?.[athlete.id] ?? "base";
  const candidate = outfits.find((outfit) => outfit.id === selectedId);
  return candidate && isUnlocked(candidate, career) ? candidate : outfits[0];
}

/** Restituisce un profilo di gara con una sola variazione estetica, mai di gameplay. */
/**
 * Valuta le sfide dei completi alla fine di una partita e sblocca quelle
 * superate. Vale in ogni modalita': la Carriera da' la progressione, ma un
 * completo si puo' inseguire anche in partita rapida, scegliendo apposta
 * l'atleta e la difficolta'. Restituisce i completi appena vinti, perche' vanno
 * mostrati subito — uno sblocco che il giocatore non vede non premia niente.
 */
export function awardOutfitChallenges(state, won) {
  const atleta = state.athlete;
  if (!atleta) return [];
  const career = ui.career;
  career.outfitsWon = career.outfitsWon ?? {};
  career.athleteWins = career.athleteWins ?? {};
  if (won) career.athleteWins[atleta.id] = (career.athleteWins[atleta.id] ?? 0) + 1;

  const contesto = {
    stats: state.stats,
    won,
    skill: state.ai?.skill ?? 0,
    athleteWins: career.athleteWins[atleta.id] ?? 0,
  };
  const vinti = [];
  for (const completo of outfitsForAthlete(atleta.id)) {
    if (!completo.challenge || career.outfitsWon[completo.unlockKey]) continue;
    if (!outfitChallengeMet(completo.challenge, contesto)) continue;
    career.outfitsWon[completo.unlockKey] = true;
    vinti.push(completo);
  }
  if (vinti.length || won) saveCareer(career);
  return vinti;
}

export function athleteWithOutfit(athlete, career = ui.career) {
  const outfit = selectedOutfit(athlete, career);
  if (!outfit) return athlete;
  return {
    ...athlete,
    ...(outfit.sprites ?? {}),
    outfit,
    outfitId: outfit.id,
    color: outfit.colors?.[0] ?? athlete.color,
  };
}

/**
 * La sfida di un completo, come sequenza di condizioni separate da un punto.
 *
 * A frase intera diventava contorta in due lingue ("Vinci una partita in cui non
 * commetti piu' di due errori contro un avversario di livello difficile o
 * superiore"); a condizioni staccate si legge in un colpo d'occhio e si traduce
 * senza acrobazie grammaticali.
 */
function challengeLabel(challenge) {
  const parte = (prova) => {
    if (prova.metric === "longestRally") return t("chRally", { n: prova.target });
    if (prova.metric === "totalRallyHits") return t("chTotalHits", { n: prova.target });
    if (prova.metric === "wins") return t("chWins", { n: prova.target });
    const cosa = t(`metric_${prova.metric}`);
    if (prova.atMost) {
      return prova.target === 0 ? t("chNone", { what: cosa }) : t("chAtMost", { n: prova.target, what: cosa });
    }
    return t("chAtLeast", { n: prova.target, what: cosa });
  };
  const parti = [];
  if (challenge.win) parti.push(t("chWin"));
  parti.push(parte(challenge));
  if (challenge.also) parti.push(parte(challenge.also));
  if (challenge.minSkill >= 0.85) parti.push(t("chSkillLegend"));
  else if (challenge.minSkill) parti.push(t("chSkillHard"));
  return parti.join(" · ");
}

function lockLabel(unlock) {
  // Il singolare va scelto: "1 trofei" si leggeva nella griglia delle arene e
  // sulle card degli atleti bloccati.
  const parts = [];
  if (unlock?.trophies) {
    parts.push(t("unlockTrophies", { n: unlock.trophies, word: t(unlock.trophies === 1 ? "trophyOne" : "trophyMany") }));
  }
  if (unlock?.stars) {
    parts.push(t("unlockStars", { n: unlock.stars, word: t(unlock.stars === 1 ? "starOne" : "starMany") }));
  }
  return parts.join(" · ");
}

const UNLOCK_TAPS = 3;
const UNLOCK_TAP_WINDOW = 1400;
let unlockTaps = 0;
let unlockTapTime = 0;

/**
 * Tre tocchi su una card bloccata entro la finestra chiedono il codice di
 * sblocco. Restituisce true solo se lo sblocco e' appena avvenuto, cosi' il
 * chiamante sa se deve ridisegnare la griglia.
 */
function promptUnlockCode() {
  if (ui.career.unlockAll) return false;
  const now = Date.now();
  unlockTaps = now - unlockTapTime > UNLOCK_TAP_WINDOW ? 1 : unlockTaps + 1;
  unlockTapTime = now;
  if (unlockTaps < UNLOCK_TAPS) return false;
  unlockTaps = 0;
  const risposta = window.prompt(t("unlockPrompt"));
  if (risposta === null) return false;
  if (risposta.trim().toUpperCase() !== UNLOCK_CODE) {
    window.alert(t("unlockWrong"));
    return false;
  }
  ui.career.unlockAll = true;
  saveCareer(ui.career);
  window.alert(t("unlockDone"));
  return true;
}

/**
 * Limiti della demo applicati all'interfaccia. Le modalita' escluse restano
 * visibili ma bloccate: vedere cosa manca vende piu' che nasconderlo. Riusa
 * `mode-card--locked`, che la navigazione da controller gia' salta.
 */
export function applyDemoLimits() {
  if (!IS_DEMO) return;
  document.body.classList.add("is-demo");
  document.querySelectorAll(".mode-card").forEach((card) => {
    if (DEMO_CONTENT.modes.includes(card.dataset.mode)) return;
    card.classList.add("mode-card--locked", "mode-card--demo");
    const tag = card.querySelector(".mode-card__tag");
    if (tag) {
      tag.textContent = t("demoLockedMode");
      tag.classList.remove("mode-card__tag--ready");
    }
  });
  // La demo gira su una sola difficolta': il facile fa sembrare il gioco banale,
  // il difficile respinge chi ha in mano il controller da tre minuti.
  ui.aiDifficulty = DEMO_CONTENT.difficulty;
  ui.selectedMode = DEMO_CONTENT.modes[0];
  document.querySelectorAll("#difficultySeg button").forEach((button) => {
    if (button.dataset.value !== DEMO_CONTENT.difficulty) button.disabled = true;
  });
}

/**
 * Cosa e' successo alla stagione. Da quando la sconfitta fa avanzare comunque
 * il calendario, la fine stagione ha tre esiti e vanno raccontati: altrimenti
 * il giocatore non capisce perche' a volte avanza e a volte no.
 */
function careerOutcomeText(state, won) {
  const stagione = state.careerSeason;
  const rivale = state.careerRival ? t(`ai_${state.careerRival.id}_name`) : "";
  switch (ui.careerSeasonOutcome) {
    case "finale": return t("careerFinale", { season: stagione, rival: rivale });
    case "trophy": return t("careerSeasonWin", { season: stagione });
    case "promoted": return t("careerSeasonPromoted", { season: stagione });
    case "repeat": return t("careerSeasonRepeat", { season: stagione });
    default:
      return won
        ? t("careerMatchWin", { season: stagione, match: ui.career.matchIndex })
        : t("careerMatchLoss", { season: stagione, match: ui.career.matchIndex });
  }
}

/**
 * La selezione atleta ha due viste sulla STESSA griglia: prima gli atleti, poi
 * i completi di quello scelto, con la medesima card. Prima il guardaroba stava
 * in una sezione sotto la griglia e bisognava scorrere per vederlo; e ogni card
 * resta un bottone a se', quindi non ci sono bottoni annidati.
 */
/**
 * Le tre statistiche che si sentono in campo, come barrette compatte. Nel
 * pannello squadra la descrizione narrativa non serve: quello che si sta
 * decidendo e' come giochera' quella posizione.
 */
/**
 * Estremi di ogni statistica sul roster. Le barrette servono a confrontare gli
 * atleti fra loro, quindi la scala e' quella reale del roster e non un
 * intervallo scelto a mano: con una scala fissa Il Maestro mostrava una barretta
 * su cinque in potenza e in velocita' pur essendo nella media, perche' l'intero
 * centro del roster finiva schiacciato sul primo gradino.
 */
const STAT_RANGE = (() => {
  const range = {};
  for (const chiave of ["power", "control", "speed"]) {
    const valori = ATHLETES.map((a) => a.stats[chiave]);
    range[chiave] = { min: Math.min(...valori), max: Math.max(...valori) };
  }
  return range;
})();

function statLine(athlete) {
  const barra = (valore, chiave) => {
    const { min, max } = STAT_RANGE[chiave];
    // Il piu' debole del roster tiene comunque una tacca: una barretta vuota
    // sembra un dato mancante, non una statistica bassa.
    const pieni = 1 + Math.round(clampUnit((valore - min) / (max - min || 1)) * 4);
    return `<span class="stat-bar">${"▮".repeat(pieni)}${"▯".repeat(5 - pieni)}</span>`;
  };
  const { power, control, speed } = athlete.stats;
  return `<span class="stat-line">
    ${t("statPower")} ${barra(power, "power")}
    ${t("statControl")} ${barra(control, "control")}
    ${t("statSpeed")} ${barra(speed, "speed")}
  </span>`;
}

function clampUnit(value) {
  return Math.min(1, Math.max(0, value));
}

function athleteCardMarkup(art, color, title, subtitle, description, footer, locked) {
  return `
    <div class="athlete-card__art" style="background-image:linear-gradient(180deg, transparent 48%, rgba(4, 10, 35, 0.5) 100%),url('${art}');border-bottom-color:${color}" aria-hidden="true">${locked ? `<span class="lock-badge">🔒</span>` : ""}</div>
    <div class="athlete-card__body">
      <h3 style="color:${color}">${title}</h3>
      <p class="athlete-card__role">${subtitle}</p>
      <p class="athlete-card__desc">${description}</p>
      <p class="athlete-card__special">${footer}</p>
    </div>
  `;
}

export function renderAthletes(onSelect, selectedId = null) {
  const grid = document.getElementById("athleteGrid");
  const header = document.getElementById("athleteGridHead");

  /**
   * Il guardaroba. `giocatore` e' l'atleta con cui si scende in campo: quando e'
   * diverso da `athlete` si sta vestendo un'altra casella della squadra, quindi
   * non si tocca `ui.selectedAthlete` e si torna al pannello invece che alla
   * griglia degli atleti. I completi restano legati all'atleta, non alla
   * posizione: vestire La Pantera da avversaria la veste anche da compagna.
   */
  const showOutfits = (athlete, giocatore = athlete) => {
    const altraCasella = athlete.id !== giocatore.id;
    const outfits = outfitsForAthlete(athlete.id);
    if (!outfits.length) {
      showTeam(giocatore);
      return;
    }
    if (!altraCasella) ui.selectedAthlete = athlete;
    grid.innerHTML = "";
    if (header) {
      const indietro = t("teamPickBack");
      header.innerHTML = `<button class="btn btn--ghost" type="button" data-outfit-back>${indietro}</button>
        <span class="athlete-grid__hint">${t(`athlete_${athlete.id}_name`)} — ${t("outfitSub")}</span>`;
      header.hidden = false;
      header.querySelector("[data-outfit-back]")?.addEventListener("click", () => showTeam(giocatore));
    }
    const equipped = selectedOutfit(athlete);
    outfits.forEach((outfit) => {
      const unlocked = isUnlocked(outfit, ui.career);
      const active = equipped?.id === outfit.id;
      const card = document.createElement("button");
      card.type = "button";
      card.className = "athlete-card";
      if (!unlocked) card.classList.add("athlete-card--locked");
      if (active) card.classList.add("athlete-card--selected");
      card.dataset.outfit = outfit.id;
      const art = outfit.preview ?? athlete.image;
      card.innerHTML = athleteCardMarkup(
        art,
        outfit.colors?.[0] ?? athlete.color,
        t(outfit.nameKey),
        t(`athlete_${athlete.id}_name`),
        unlocked
          ? (active ? t("outfitEquipped") : t("outfitAvailable"))
          : outfit.challenge
            ? `<span class="challenge-line">🎯 ${challengeLabel(outfit.challenge)}</span>`
            : lockLabel(outfit.unlock),
        unlocked ? `▶ ${t("outfitPick")}` : "",
        !unlocked,
      );
      if (unlocked) {
        card.addEventListener("click", () => {
          ui.career.equippedOutfits = { ...(ui.career.equippedOutfits ?? {}), [athlete.id]: outfit.id };
          saveCareer(ui.career);
          showTeam(giocatore);
        });
      } else {
        card.setAttribute("aria-disabled", "true");
      }
      grid.appendChild(card);
    });
  };

  /**
   * Il pannello squadra: quattro caselle nella stessa griglia a quattro colonne
   * delle card, cosi' non serve un layout nuovo e ogni posizione ha la faccia
   * di chi la occupa. Le caselle sono gia' riempite, quindi chi non vuole
   * scegliere preme Conferma e va: la scelta e' un'opzione, non un pedaggio.
   */
  const showTeam = (athlete) => {
    ui.selectedAthlete = athlete;
    const lineup = resolveLineup(athlete);
    // Si salva la formazione risolta, non quella richiesta: quello che si vede
    // nel pannello e' esattamente quello che scendera' in campo.
    ui.lineup = {
      playerMate: lineup.playerMate.id,
      opponent: lineup.opponent.id,
      opponentMate: lineup.opponentMate.id,
    };
    grid.innerHTML = "";
    if (header) {
      // Nessun sottotitolo qui: lo porta gia' l'intestazione della schermata.
      header.innerHTML = `<button class="btn btn--primary" type="button" data-team-confirm>${t("teamConfirm")}</button>`;
      header.hidden = false;
      header.querySelector("[data-team-confirm]")?.addEventListener("click", () => {
        onSelect?.(athleteWithOutfit(athlete));
      });
    }

    // Se il circuito detta gli avversari, le loro caselle non offrono il comando
    // per cambiarli: un bottone che non cambia niente e' peggio di nessun
    // bottone. Il completo resta, perche' e' estetica e vale per quell'atleta
    // ovunque compaia.
    const avversariDettati = dictatedRivals([]) !== null;
    const caselle = [
      { ruolo: "player", atleta: athlete, etichetta: t("slotYou") },
      { ruolo: "playerMate", atleta: lineup.playerMate, etichetta: t("slotPartner") },
      { ruolo: "opponent", atleta: lineup.opponent, etichetta: t("slotOpponent") },
      { ruolo: "opponentMate", atleta: lineup.opponentMate, etichetta: t("slotOpponentNet") },
    ];

    caselle.forEach(({ ruolo, atleta, etichetta }) => {
      // La casella non e' piu' un bottone solo: atleta e completo sono due
      // scelte diverse, e prima il completo si poteva cambiare unicamente al
      // giocatore. Serve quindi un contenitore con due comandi propri.
      const card = document.createElement("div");
      card.className = "athlete-card team-slot";
      if (ruolo === "player") card.classList.add("team-slot--you");
      if (ruolo === "opponent" || ruolo === "opponentMate") card.classList.add("team-slot--rival");
      const completo = selectedOutfit(atleta);
      const haCompleti = outfitsForAthlete(atleta.id).length > 1;
      const dettata = avversariDettati && (ruolo === "opponent" || ruolo === "opponentMate");
      const azioni = [
        dettata ? "" : `<button class="slot-action" type="button" data-azione="atleta">${t("slotChangeAthlete")}</button>`,
        haCompleti ? `<button class="slot-action slot-action--outfit" type="button" data-azione="completo">${t("slotChangeOutfit")}</button>` : "",
      ].filter(Boolean).join("");
      // Stesse informazioni della schermata degli atleti: descrizione e abilita'
      // speciale. Nel pannello si sceglie chi scende in campo, e sceglierlo
      // dalla sola riga di statistiche voleva dire ricordarsi a memoria cosa fa
      // ciascuno. Occupano lo slot della descrizione perche' quello del piede
      // della card ospita ora i due comandi.
      const scheda = `
        <span class="slot-desc">${t(`athlete_${atleta.id}_desc`)}</span>
        <span class="slot-special">⚡ ${t(`athlete_${atleta.id}_special`)}</span>
        ${statLine(atleta)}
      `;
      if (dettata) card.classList.add("team-slot--dettata");
      const tag = dettata
        ? `${etichetta} <em>${ui.selectedMode === "career" ? t("slotByCalendar") : t("slotByBracket")}</em>`
        : etichetta;
      card.innerHTML = athleteCardMarkup(
        completo?.preview ?? atleta.image,
        atleta.color,
        t(`athlete_${atleta.id}_name`),
        completo && completo.id !== "base"
          ? `${t(`athlete_${atleta.id}_role`)} · ${t(completo.nameKey)}`
          : t(`athlete_${atleta.id}_role`),
        scheda,
        azioni,
        false,
      );
      // Tutta la casella apre il selettore, non solo il bottone: un rettangolo
      // grande con la faccia dell'atleta invita al clic, e non rispondere mentre
      // due bottoni piccoli rispondono e' la stessa card che si comporta in due
      // modi diversi. I due comandi restano, e fermano la propagazione perche'
      // "Completo" deve aprire il guardaroba e non il selettore.
      // L'etichetta di posizione vive FUORI dalla card. Dentro era sovrapposta
      // all'immagine, e sulla casella dell'avversario a rete — dove il testo
      // va a capo su due righe — copriva la faccia dell'atleta, che e'
      // esattamente quello che si sta scegliendo.
      const casella = document.createElement("div");
      casella.className = "team-slot-wrap";
      if (ruolo === "player") casella.classList.add("team-slot-wrap--you");
      if (ruolo === "opponent" || ruolo === "opponentMate") casella.classList.add("team-slot-wrap--rival");
      casella.innerHTML = `<span class="team-slot__tag">${tag}</span>`;
      casella.appendChild(card);

      if (!dettata) card.addEventListener("click", () => showPicker(athlete, ruolo));
      card.querySelector('[data-azione="atleta"]')
        ?.addEventListener("click", (evento) => {
          evento.stopPropagation();
          showPicker(athlete, ruolo);
        });
      card.querySelector('[data-azione="completo"]')
        ?.addEventListener("click", (evento) => {
          evento.stopPropagation();
          showOutfits(atleta, athlete);
        });
      grid.appendChild(casella);
    });
  };

  /**
   * La griglia con cui si riempie una casella. Sceglierne uno gia' schierato
   * altrove non e' un errore: le due posizioni si scambiano, che e' quello che
   * uno intende quando sposta un atleta da una parte all'altra della rete.
   */
  /**
   * La griglia con cui si riempie una casella — compresa quella del giocatore.
   *
   * E' l'unica griglia di atleti rimasta: la schermata di selezione separata e
   * il guardaroba raggiungibile solo da li' erano un passaggio in piu' per fare
   * quello che il pannello fa gia'. Di conseguenza qui devono vivere anche gli
   * atleti bloccati e il codice di sblocco, che prima stavano nella schermata
   * che non c'e' piu'.
   */
  const showPicker = (giocatore, ruolo) => {
    const perGiocatore = ruolo === "player";
    grid.innerHTML = "";
    if (header) {
      header.innerHTML = `<button class="btn btn--ghost" type="button" data-team-pick-back>${t("teamPickBack")}</button>
        <span class="athlete-grid__hint">${perGiocatore ? t("teamChooseYou") : t("teamChoose")}</span>`;
      header.hidden = false;
      header.querySelector("[data-team-pick-back]")?.addEventListener("click", () => showTeam(giocatore));
    }
    // Tutti gli atleti, anche quelli che la demo non concede: si mostrano
    // bloccati invece di sparire. Farli sparire lasciava una demo che si
    // contraddiceva — la schermata Obiettivi ne elencava sei e la partita ne
    // schierava in campo di non selezionabili.
    ATHLETES.forEach((candidato) => {
      // Per le caselle avversarie e per il secondo giocatore l'atleta del
      // giocatore non compare: si sposta cambiando "Tu", non da qui.
      if (!perGiocatore && candidato.id === giocatore.id) return;
      const fuoriDemo = demoLocked(candidato, DEMO_CONTENT.athletes);
      const locked = fuoriDemo || !isUnlocked(candidato, ui.career);
      const attivo = perGiocatore
        ? candidato.id === giocatore.id
        : ui.lineup[ruolo] === candidato.id;
      const card = document.createElement("button");
      card.type = "button";
      card.className = "athlete-card";
      if (locked) card.classList.add("athlete-card--locked");
      if (attivo) card.classList.add("athlete-card--selected");
      card.dataset.id = candidato.id;
      const completo = selectedOutfit(candidato);
      card.innerHTML = athleteCardMarkup(
        completo?.preview ?? candidato.image,
        candidato.color,
        t(`athlete_${candidato.id}_name`),
        t(`athlete_${candidato.id}_role`),
        fuoriDemo
          ? t("demoOnlyFull")
          : locked
            ? lockLabel(candidato.unlock)
            : `<span class="slot-desc">${t(`athlete_${candidato.id}_desc`)}</span>${statLine(candidato)}`,
        locked ? "" : `⚡ ${t(`athlete_${candidato.id}_special`)}`,
        locked,
      );
      if (locked) {
        // Niente `disabled`: un bottone disabilitato non emette click e il
        // triplo tocco per il codice di sblocco non arriverebbe mai. Sui
        // bloccati dalla demo il codice non deve valere: quello sblocca la
        // progressione, non il contenuto che la demo non contiene.
        card.setAttribute("aria-disabled", "true");
        card.addEventListener("click", () => {
          if (!fuoriDemo && promptUnlockCode()) showPicker(giocatore, ruolo);
        });
      } else if (perGiocatore) {
        card.addEventListener("click", () => {
          // Se l'atleta scelto era gia' in campo altrove, le due posizioni si
          // scambiano invece di lasciare un doppione da risolvere in silenzio.
          const altrove = Object.keys(ui.lineup).find((k) => ui.lineup[k] === candidato.id);
          if (altrove) ui.lineup[altrove] = giocatore.id;
          ui.selectedAthlete = candidato;
          showTeam(candidato);
        });
      } else {
        card.addEventListener("click", () => {
          const precedente = ui.lineup[ruolo];
          const altrove = Object.keys(ui.lineup).find((k) => k !== ruolo && ui.lineup[k] === candidato.id);
          if (altrove) ui.lineup[altrove] = precedente;
          ui.lineup[ruolo] = candidato.id;
          showTeam(giocatore);
        });
      }
      grid.appendChild(card);
    });
  };

  showTeam(demoFilter(ATHLETES, DEMO_CONTENT.athletes).find((a) => a.id === selectedId && isUnlocked(a, ui.career))
    ?? ui.selectedAthlete
    ?? selectableAthletes()[0]
    ?? ATHLETES[0]);
}

/**
 * Tutto quello che si puo' sbloccare, in un posto solo.
 *
 * Le condizioni erano gia' scritte, ma sparse dove servivano: la sfida di un
 * completo sulla sua card nel guardaroba, il costo di un atleta sulla card
 * bloccata nel selettore, quello di un'arena nella griglia delle arene. Per
 * sapere cosa restava da prendere bisognava girare quattro schermate, e nessuno
 * lo fa: il gioco aveva una lista di obiettivi che non si poteva leggere.
 *
 * Tre sezioni perche' sono tre economie diverse e conviene che si vedano tali:
 * i personaggi e le arene si comprano con la progressione — stelle e trofei — i
 * costumi si vincono con una prova sul campo.
 */
export function renderChallenges() {
  const board = document.getElementById("challengeBoard");
  if (!board) return;
  const career = ui.career;
  const vinti = career.outfitsWon ?? {};
  const tutto = career.unlockAll === true;

  const riga = ({ fatto, nome, come, ruolo, statoFatto, statoDaFare, colore }) => `
    <div class="challenge-row${fatto ? " is-done" : ""}">
      <span class="challenge-row__mark">${fatto ? "🏅" : "🎯"}</span>
      <span class="challenge-row__name"${colore ? ` style="color:${colore}"` : ""}>${nome}${ruolo ? ` <small>${ruolo}</small>` : ""}</span>
      <span class="challenge-row__what">${come}</span>
      <span class="challenge-row__state">${fatto ? statoFatto : statoDaFare}</span>
    </div>`;

  // Quanto manca, non solo quanto costa: "6 stelle" e' un prezzo, "4/6 stelle" e'
  // un obiettivo. La frazione tiene insieme requisito e progresso — appendere
  // i due totali in fondo ("5 trofei · 18 stelle · ne hai 1 · ne hai 4") li
  // staccava da cio' a cui si riferivano.
  const quanti = (avuti, servono, unoKey, tantiKey) =>
    `${Math.min(avuti, servono)}/${servono} ${t(servono === 1 ? unoKey : tantiKey)}`;
  const costo = (unlock) => {
    const parti = [];
    if (unlock?.trophies) parti.push(`🏆 ${quanti(career.trophies ?? 0, unlock.trophies, "trophyOne", "trophyMany")}`);
    if (unlock?.stars) parti.push(`⭐ ${quanti(career.stars ?? 0, unlock.stars, "starOne", "starMany")}`);
    return parti.join(" · ");
  };

  const sezione = (titolo, fatti, totale, corpo) => `
    <section class="challenge-section">
      <h2>${titolo} <span class="challenge-section__count">${fatti}/${totale}</span></h2>
      ${corpo}
    </section>`;

  // --- personaggi ---
  const atletiSbloccabili = ATHLETES.filter((a) => a.unlock);
  const atletiFatti = atletiSbloccabili.filter((a) => isUnlocked(a, career)).length;
  const bloccoAtleti = atletiSbloccabili.map((atleta) => riga({
    fatto: isUnlocked(atleta, career),
    nome: t(`athlete_${atleta.id}_name`),
    ruolo: t(`athlete_${atleta.id}_role`),
    come: costo(atleta.unlock),
    statoFatto: t("challengeUnlocked"),
    statoDaFare: t("challengeLocked"),
    colore: atleta.color,
  })).join("");

  // --- costumi ---
  const completi = ATHLETES.flatMap((a) => outfitsForAthlete(a.id).filter((o) => o.challenge));
  const completiFatti = completi.filter((o) => tutto || vinti[o.unlockKey]).length;
  const bloccoCompleti = ATHLETES.map((atleta) => {
    const suoi = outfitsForAthlete(atleta.id).filter((o) => o.challenge);
    if (!suoi.length) return "";
    return `
      <div class="challenge-group">
        <h3 style="color:${atleta.color}">${t(`athlete_${atleta.id}_name`)}
          <small>${isUnlocked(atleta, career) ? t(`athlete_${atleta.id}_role`) : t("challengeLockedAthlete")}</small>
        </h3>
        ${suoi.map((completo) => riga({
          fatto: tutto || Boolean(vinti[completo.unlockKey]),
          nome: t(completo.nameKey),
          come: challengeLabel(completo.challenge),
          statoFatto: t("challengeDone"),
          statoDaFare: t("challengeTodo"),
        })).join("")}
      </div>`;
  }).join("");

  // --- arene ---
  const areneSbloccabili = ARENAS.filter((a) => a.unlock);
  const areneFatte = areneSbloccabili.filter((a) => isUnlocked(a, career)).length;
  const bloccoArene = areneSbloccabili.map((arena) => riga({
    fatto: isUnlocked(arena, career),
    nome: t(`arena_${arena.id}_name`),
    come: costo(arena.unlock),
    statoFatto: t("challengeUnlocked"),
    statoDaFare: t("challengeLocked"),
    colore: arena.palette?.accent,
  })).join("");

  // In demo personaggi e arene si sbloccano con stelle e trofei, che vengono
  // solo dalla Carriera: senza dirlo quelle due sezioni restano "0 su N" per
  // sempre e sembrano un muro invece di un invito.
  const notaDemo = IS_DEMO
    ? `<p class="challenge-section__nota">${t("demoCareerNote")}</p>`
    : "";

  board.innerHTML =
    sezione(t("sectionAthletes"), atletiFatti, atletiSbloccabili.length, notaDemo + bloccoAtleti)
    + sezione(t("sectionOutfits"), completiFatti, completi.length, bloccoCompleti)
    + sezione(t("sectionArenas"), areneFatte, areneSbloccabili.length, notaDemo + bloccoArene);
}

export function renderArenas(onSelect) {
  const grid = document.getElementById("arenaGrid");
  grid.innerHTML = "";

  // In carriera il campo lo dice il calendario: `startMatch` usa l'arena del
  // fixture e scarta `ui.selectedArena`. La griglia lo lasciava scegliere lo
  // stesso, quindi era una scelta che il gioco buttava via — lo stesso difetto
  // degli avversari. Le altre arene restano visibili, spente: si vede dove si
  // andra' a giocare nelle prossime giornate.
  const dettata = ui.selectedMode === "career"
    ? currentFixture().arena
    : ui.selectedMode === "tournament"
      ? currentTournamentFixture().arena
      : null;

  ARENAS.forEach((arena) => {
    const fuoriDemo = demoLocked(arena, DEMO_CONTENT.arenas);
    const locked = fuoriDemo || !isUnlocked(arena, ui.career);
    const fuoriGiornata = Boolean(dettata) && arena.id !== dettata.id;
    const card = document.createElement("button");
    card.type = "button";
    card.className = "arena-card";
    if (locked) card.classList.add("arena-card--locked");
    if (fuoriGiornata) card.classList.add("arena-card--fuori-giornata");
    if (dettata && !fuoriGiornata) card.classList.add("arena-card--in-programma");
    card.innerHTML = `
      <div class="arena-card__preview" style="--accent:${arena.palette.accent};background-image:linear-gradient(180deg, transparent 45%, rgba(5, 9, 29, 0.7) 100%),url('${arena.image}')" aria-hidden="true">
        <span>${t(`arena_${arena.id}_name`)}</span>
        ${locked ? `<span class="lock-badge">🔒</span>` : ""}
        ${dettata && !fuoriGiornata ? `<span class="arena-card__badge">${ui.selectedMode === "tournament" ? t("arenaByBracket") : t("arenaByCalendar")}</span>` : ""}
      </div>
      <div class="arena-card__body">
        <h3>${t(`arena_${arena.id}_name`)}</h3>
        <p>${fuoriDemo
          ? t("demoOnlyFull")
          : locked
            ? lockLabel(arena.unlock)
          : fuoriGiornata
            ? t(ui.selectedMode === "tournament" ? "arenaOtherRound" : "arenaOtherMatchday")
            : t(`arena_${arena.id}_desc`)}</p>
      </div>
    `;
    if (fuoriGiornata) {
      card.disabled = true;
    } else if (!locked) {
      card.addEventListener("click", () => {
        ui.selectedArena = arena;
        onSelect?.(arena);
      });
    } else {
      card.disabled = true;
    }
    grid.appendChild(card);
  });
}

export function updateHud(state) {
  document.getElementById("playerScore").textContent = String(state.playerScore);
  document.getElementById("aiScore").textContent = String(state.aiScore);
  document.getElementById("playerName").textContent = t(`athlete_${state.athlete.id}_name`).split(" ").pop();
  document.getElementById("aiName").textContent = (state.humanMode === "pvp" && state.opponentAthlete
    ? t(`athlete_${state.opponentAthlete.id}_name`)
    : (state.ai.id ? t(`ai_${state.ai.id}_name`) : state.ai.name)).split(" ").pop();
  document.getElementById("matchInfo").textContent = getMatchInfo(state);
  const activePaddle = state[state.activePlayerKey];
  const activeRole = activePaddle.y > COURT.netY + 150 ? t("roleBack") : t("roleNet");
  const receivingServe = state.serveSide === "ai" && (state.serving || state.ball.serveInFlight);
  const receiverSide = state.ball.serveTargetSide === "left" ? t("sideLeft") : t("sideRight");
  const activePlayerLabel = document.getElementById("activePlayerLabel");
  activePlayerLabel.textContent = receivingServe
    ? t("receiverLbl", { side: receiverSide })
    : state.manualSwitchFlash > 0
      ? `${t("manual")} > ${activeRole}`
    : state.receiverSwitchFlash > 0
    ? t("autoSwitchLbl", { role: activeRole })
    : state.receiverLocked
      ? t("receiveLbl", { role: activeRole })
      : t(state.controlMode === "manual" ? "manualLbl" : "controlLbl", { role: activeRole });
  activePlayerLabel.classList.toggle("is-auto-switch", state.receiverSwitchFlash > 0);
  const tacticLabel = document.getElementById("teamTacticLabel");
  if (tacticLabel) {
    const tactic = state.playerTeamTactic ?? "balanced";
    const movementState = activePaddle.splitStep > 0.15
      ? t("splitStepLbl")
      : activePaddle.sprinting > 0.15
        ? `${t("sprintLbl")} ${Math.round(activePaddle.sprinting * 100)}%`
        : null;
    tacticLabel.textContent = movementState ? movementState.toUpperCase() : t(`tacticHud_${tactic}`);
    tacticLabel.dataset.tactic = tactic;
    tacticLabel.classList.toggle("is-flashing", state.tacticFlash > 0);
  }
  const comboEl = document.getElementById("comboDisplay");
  comboEl.textContent = t("combo", { n: state.combo });
  const comboColors = { 1: "#7ef3ff", 2: "#8fffd0", 3: "#ffe066", 4: "#ff9a5c" };
  comboEl.style.color = comboColors[state.combo] ?? "#ff6d70";
  comboEl.style.textShadow = state.combo >= 4 ? "0 0 10px rgba(255,106,92,0.8)" : "none";
  const minutes = Math.floor(state.elapsed / 60).toString().padStart(2, "0");
  const seconds = Math.floor(state.elapsed % 60).toString().padStart(2, "0");
  document.getElementById("gameTimer").textContent = `${minutes}:${seconds}`;

  const fill = document.getElementById("specialFill");
  fill.style.width = `${Math.round(state.specialReady * 100)}%`;
  fill.style.opacity = state.specialCooldown > 0 ? "0.45" : "1";

  document.getElementById("shotPowerFill").style.width = `${Math.round(state.shotCharge * 100)}%`;
  document.getElementById("shotAimNeedle").style.left = `${50 + state.shotAim * 42}%`;
  const intentLabel = document.getElementById("shotIntentLabel");
  if (intentLabel) {
    const labels = {
      drive: t("driveLbl"),
      slice: t("sliceLbl"),
      lob: t("lobLbl"),
      "defensive-lob": t("defensiveLobLbl"),
      chiquita: t("chiquitaLbl"),
      vibora: t("viboraLbl"),
      smash: t("smashLbl"),
      auto: t("shot"),
    };
    intentLabel.textContent = (labels[state.shotIntent] ?? t("shot")).toUpperCase();
    intentLabel.dataset.intent = state.shotIntent;
  }
  const adviceLabel = document.getElementById("shotAdviceLabel");
  const advice = state.shotRead?.advice ?? "read";
  if (adviceLabel) {
    adviceLabel.textContent = t(`shotAdvice_${advice}`).toUpperCase();
    adviceLabel.dataset.profile = state.shotRead?.profile ?? "control";
  }
  const timingNeedle = document.getElementById("shotTimingNeedle");
  const timingPerfect = document.getElementById("shotTimingPerfect");
  if (timingNeedle && timingPerfect) {
    const timing = state.shotRead;
    const eta = timing?.active ? timing.eta : null;
    // The meter is a forecast: the cursor reaches the green zone when the ball reaches the contact plane.
    const position = eta === null ? -8 : Math.max(-8, Math.min(108, 52 - eta * 72));
    const width = Math.max(5, Math.min(17, (timing?.perfectWindow ?? 0.055) * 155));
    timingNeedle.style.left = `${position}%`;
    timingPerfect.style.left = `${52 - width / 2}%`;
    timingPerfect.style.width = `${width}%`;
  }

  const banner = document.getElementById("serveBanner");
  const betweenPoints = state.pointPause > 0;
  banner.classList.toggle("is-visible", state.serving || betweenPoints);
  banner.classList.toggle("serve-banner--point", betweenPoints);
  banner.textContent = betweenPoints
    ? state.pointMessage
    : state.serveSide === "player"
      ? state.serveAttempts ? t("serveSecond") : t("serveFirst")
      : t("serveOpp");

  const log = document.getElementById("eventLog");
  log.innerHTML = state.events.map((e) => `<li>${e}</li>`).join("");
}

function statRow(label, player, ai, lowerBetter = false) {
  const playerBetter = lowerBetter ? player < ai : player > ai;
  const aiBetter = lowerBetter ? ai < player : ai > player;
  return `
    <div class="result-stats__row">
      <span class="result-stats__val${playerBetter ? " is-better" : ""}">${player}</span>
      <span class="result-stats__label">${label}</span>
      <span class="result-stats__val${aiBetter ? " is-better" : ""}">${ai}</span>
    </div>
  `;
}

export function renderMatchStats(state) {
  const el = document.getElementById("resultStats");
  if (!el) return;
  const s = state.stats;
  if (!s) {
    el.innerHTML = "";
    return;
  }
  const avgRally = s.rallyCount ? (s.totalRallyHits / s.rallyCount).toFixed(1) : "0";
  el.innerHTML = `
    <div class="result-stats__head"><span>${t("statYou")}</span><span>${t("statStats")}</span><span>${t("statOpp")}</span></div>
    ${statRow(t("statPoints"), s.pointsWon.player, s.pointsWon.ai)}
    ${statRow(t("statAces"), s.aces.player, s.aces.ai)}
    ${statRow(t("statWinners"), s.winners.player, s.winners.ai)}
    ${statRow(t("statErrors"), s.errors.player, s.errors.ai, true)}
    <div class="result-stats__foot">
      <span>${t("statLongest")} <b>${s.longestRally}</b></span>
      <span>${t("statAvgRally")} <b>${avgRally}</b></span>
    </div>
  `;
}

/**
 * Testo narrativo del rivale. Ora il rivale ha un nome — quello del gradino di
 * calendario — perche' lo streak raccontava un antagonista che nel codice non
 * esisteva come entita'.
 */
function rivalNarrative(won, rival) {
  const streak = ui.career.rivalStreak ?? 0;
  const nome = rival ? t(`ai_${rival.id}_name`) : t("rivalGeneric");
  if (won && streak >= 2) return t("rivalStreakWin", { n: streak, rival: nome });
  if (!won && streak <= -2) return t("rivalStreakLoss", { n: -streak, rival: nome });
  return "";
}

/**
 * L'etichetta dipende dallo scopo: gli obiettivi di stagione dicono "nella
 * stagione", il bonus della partita no. Con una stringa sola per entrambi il
 * bonus di match si annunciava come "Max 0 doppi falli in ogni partita", che
 * descrive la regola di stagione e non quella che si stava giocando.
 */
function objectiveLabel(id, target, scope = "season") {
  const key = scope === "match" ? `objMatch_${id}` : `obj_${id}`;
  return t(key, { n: target });
}

/** Mostra gli obiettivi di carriera con esito nel riepilogo di fine match. */
export function renderObjectives(state) {
  const el = document.getElementById("resultObjectives");
  if (!el) return;
  if (state.mode !== "career" || !state.stats) {
    el.innerHTML = "";
    return;
  }
  const career = ui.career;
  const rows = [];

  // L'obiettivo bonus si misura sul match, quelli di stagione sul totale.
  const mo = state.matchObjective;
  if (mo) {
    const st = objectiveStatus(mo, matchProgress(state.stats));
    rows.push({ label: objectiveLabel(mo.id, mo.target, "match"), done: st.done, title: t("objMatchTitle"), st });
  }
  const earnedStars = ui.objectiveResult?.stars ?? 0;
  const totals = seasonProgress();
  (career.seasonObjectives ?? []).forEach((o) => {
    const st = objectiveStatus(o, totals);
    rows.push({
      label: objectiveLabel(o.id, o.target),
      done: st.done,
      title: o.claimed && st.done ? t("objAlreadyClaimed") : t("objSeasonTitle"),
      st,
    });
  });

  // I completi appena vinti vanno annunciati qui, dove il giocatore guarda gia'.
  // Uno sblocco che si scopre per caso aprendo il guardaroba non premia niente,
  // e soprattutto non insegna che quella cosa si e' ottenuta facendo quella cosa.
  const vinti = ui.outfitsWonNow ?? [];
  const annuncio = vinti.map((completo) => `
    <div class="result-objectives__row is-done result-objectives__row--outfit">
      <span class="result-objectives__check">🏅</span>
      <span class="result-objectives__label">${t(completo.nameKey)} · ${t(`athlete_${completo.athleteId}_name`)}</span>
      <span class="result-objectives__cat">${t("outfitWonNow")}</span>
    </div>`).join("");

  if (!rows.length && !earnedStars && !vinti.length) {
    el.innerHTML = "";
    return;
  }
  el.innerHTML = annuncio + `
    <div class="result-objectives__head">${t("objTitle")}${earnedStars ? ` &nbsp;·&nbsp; <span class="result-objectives__stars">${t("objStarsEarned", { n: earnedStars })}</span>` : ""}</div>
    ${rows.map((r) => `
      <div class="result-objectives__row${r.done ? " is-done" : ""}">
        <span class="result-objectives__check">${r.done ? "✓" : "○"}</span>
        <span class="result-objectives__label">${r.label}</span>
        <span class="result-objectives__progress">${r.st.progress}/${r.st.target}</span>
        <span class="result-objectives__cat">${r.title}</span>
      </div>`).join("")}
  `;
}

export function showResult(state, winner) {
  const title = document.getElementById("resultTitle");
  const message = document.getElementById("resultMessage");
  if (state.pointsToWin) {
    document.getElementById("resultPlayer").textContent = String(state.points.player);
    document.getElementById("resultAi").textContent = String(state.points.ai);
  } else {
    // Una partita a un set solo si racconta con i game — 6-4 — non con i set,
    // che varrebbero "1-0" per qualunque risultato. Con piu' set il conteggio
    // dei set torna a essere l'informazione giusta.
    const unSetSolo = (state.setsToWin ?? 1) === 1 && (state.setScores ?? []).length === 1;
    const finale = unSetSolo ? state.setScores[0] : state.sets;
    document.getElementById("resultPlayer").textContent = String(finale.player);
    document.getElementById("resultAi").textContent = String(finale.ai);
  }

  if (winner === "player") {
    title.textContent = t("victory");
    if (state.mode === "career") {
      const rival = rivalNarrative(true, state.careerRival);
      message.textContent = careerOutcomeText(state, true) + (rival ? ` ${rival}` : "");
    } else if (state.mode === "tournament" && ui.tournamentRound < 2) {
      // `tournamentRound` e' gia' stato incrementato: l'arena e' quella del turno
      // che sta per iniziare, e il giocatore non ripassa dalla selezione.
      message.textContent = t("tourneyNext", {
        n: ui.tournamentRound,
        arena: t(`arena_${currentTournamentFixture().arena.id}_name`),
      });
    } else if (state.mode === "tournament") {
      message.textContent = t("tourneyWin");
    } else {
      message.textContent = t("winArena", { arena: t(`arena_${state.arena.id}_name`) });
    }
  } else {
    title.textContent = t("defeat");
    const rival = state.mode === "career" ? rivalNarrative(false, state.careerRival) : "";
    message.textContent = (state.mode === "career"
      ? careerOutcomeText(state, false)
      : t("defeatMsg")) + (rival ? ` ${rival}` : "");
  }

  renderObjectives(state);

  const rematchBtn = document.querySelector('[data-action="rematch"]');
  if (rematchBtn) {
    rematchBtn.textContent = ui.pendingContinue ? t("nextMatch") : t("rematch");
  }

  renderMatchStats(state);
  showScreen("result");
}

export function getAiForMatch(mode, round, difficulty = "easy") {
  if (mode === "quick") {
    const index = { easy: 0, medium: 1, hard: 2, legend: 3 }[difficulty] ?? 0;
    return AI_OPPONENTS[index];
  }
  if (mode === "career") {
    return careerAiProfile(ui.career.season, ui.career.matchIndex);
  }
  return AI_OPPONENTS[Math.min(round, AI_OPPONENTS.length - 1)];
}

export function loadHistory() {
  try {
    const raw = localStorage.getItem(HISTORY_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export function saveHistory(list) {
  try {
    localStorage.setItem(HISTORY_KEY, JSON.stringify(list.slice(0, 20)));
  } catch {
    // persistenza non disponibile
  }
}

export function recordMatch(entry) {
  const list = loadHistory();
  list.unshift(entry);
  saveHistory(list);
}

export function renderHistory() {
  const statsEl = document.getElementById("historyStats");
  const listEl = document.getElementById("historyList");
  if (!statsEl || !listEl) return;  const list = loadHistory();
  const wins = list.filter((m) => m.winner === "player").length;
  const losses = list.filter((m) => m.winner !== "player").length;
  const trophies = list.filter((m) => m.trophy || (m.mode === "tournament" && m.winner === "player")).length;
  statsEl.innerHTML = `
    <div class="history-stats__box history-stats__box--wins"><b>${wins}</b><span>${t("histWins")}</span></div>
    <div class="history-stats__box history-stats__box--losses"><b>${losses}</b><span>${t("histLosses")}</span></div>
    <div class="history-stats__box history-stats__box--trophies"><b>${trophies}</b><span>${t("histTrophies")}</span></div>
  `;
  if (!list.length) {
    listEl.innerHTML = `<li class="history-empty">${t("histEmpty")}</li>`;
    return;
  }
  const locale = getLang() === "it" ? "it-IT" : "en-US";
  listEl.innerHTML = list.map((m) => {
    const win = m.winner === "player";
    const date = new Date(m.ts).toLocaleDateString(locale, { day: "2-digit", month: "short" });
    const modeBase = m.mode === "tournament" ? t("tournamentMatch") : m.mode === "career" ? t("careerMatch") : t("quickMatch");
    const hm = m.humanMode === "coop" ? t("hmCoop") : m.humanMode === "pvp" ? t("hmPvp") : "";
    const mode = hm ? `${modeBase} · ${hm}` : modeBase;
    return `<li>
      <span class="history-badge history-badge--${win ? "win" : "loss"}">${win ? t("histWin") : t("histLoss")}</span>
      <div class="history-main">
        <strong>${mode} ${t("histVs")} ${m.opponent || "IA"}</strong>
        <span>${m.athlete} · ${m.arena}</span>
      </div>
      <div class="history-meta"><b>${m.score}</b><span>${date}</span></div>
    </li>`;
  }).join("");
}

export function renderProfile() {
  const statsEl = document.getElementById("profileStats");
  const objEl = document.getElementById("profileObjectives");
  const unlockEl = document.getElementById("profileUnlocks");
  if (!statsEl) return;
  const career = ui.career;
  const total = career.wins + career.losses;
  const winRate = total ? Math.round((career.wins / total) * 100) : 0;
  statsEl.innerHTML = `
    <div class="history-stats__box history-stats__box--wins"><b>${career.wins}</b><span>${t("histWins")}</span></div>
    <div class="history-stats__box history-stats__box--trophies"><b>${career.trophies}</b><span>${t("profileSeasons")}</span></div>
    <div class="history-stats__box history-stats__box--stars"><b>${career.stars}</b><span>${t("profileStars")}</span></div>
    <div class="history-stats__box history-stats__box--rate"><b>${winRate}%</b><span>${t("profileWinRate")}</span></div>
  `;

  if (objEl) {
    const objectives = ensureSeasonObjectives();
    // Il progresso e' il totale della stagione: senza mostrarlo, un obiettivo
    // cumulativo e' indistinguibile da uno da centrare in una partita sola.
    const totals = seasonProgress();
    objEl.innerHTML = objectives.length
      ? objectives.map((o) => {
        const st = objectiveStatus(o, totals);
        const cat = st.done ? t("objDone") : o.claimed ? t("objAlreadyClaimed") : "";
        return `
        <div class="result-objectives__row${st.done ? " is-done" : ""}">
          <span class="result-objectives__check">${st.done ? "✓" : "○"}</span>
          <span class="result-objectives__label">${t(`obj_${o.id}`, { n: o.target })}</span>
          <span class="result-objectives__progress">${st.progress}/${st.target}</span>
          <span class="result-objectives__cat">${cat}</span>
        </div>`;
      }).join("")
      : `<p class="profile-empty">${t("profileNoObjectives")}</p>`;
  }

  if (unlockEl) {
    // Qui c'era l'elenco dei contenuti sbloccabili, e si era rotto in silenzio:
    // filtrava i completi su `outfit.unlock`, campo che non esiste piu' da
    // quando i completi si vincono con una sfida invece di comprarli. Il
    // risultato era un Profilo che mostrava 8 voci mentre gli Obiettivi ne
    // mostravano 28, senza che niente segnalasse i venti costumi mancanti.
    //
    // Non lo rimetto: duplicava una schermata che ora possiede l'argomento per
    // intero — personaggi, costumi e arene, con le tre economie separate. Due
    // elenchi della stessa cosa divergono, e questo aveva gia' divergato.
    const atleti = ATHLETES.filter((a) => a.unlock);
    const arene = ARENAS.filter((a) => a.unlock);
    const completi = ATHLETES.flatMap((a) => outfitsForAthlete(a.id).filter((o) => o.challenge));
    const tutti = [...atleti, ...arene, ...completi];
    const presi = tutti.filter((item) => isUnlocked(item, career)).length;
    unlockEl.innerHTML = `
      <div class="profile-unlocks__summary">
        <span>${t("profileUnlocksCount", { done: presi, total: tutti.length })}</span>
        <button class="btn btn--secondary" type="button" data-action="to-challenges">${t("challenges")}</button>
      </div>`;
  }
}

export function applyLanguage() {
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.dataset.i18n;
    if (!key) return;
    const bold = [...el.querySelectorAll("b")].map((node) => node.outerHTML);
    el.textContent = t(key);
    if (bold.length) el.insertAdjacentHTML("beforeend", bold.join(""));
  });
  document.querySelectorAll("[data-i18n-aria]").forEach((el) => {
    const key = el.dataset.i18nAria;
    if (key) el.setAttribute("aria-label", t(key));
  });
  document.querySelectorAll("[data-i18n-title]").forEach((el) => {
    const key = el.dataset.i18nTitle;
    if (key) el.title = t(key);
  });
  // I segnaposto dei campi di testo: senza questo ramo il modulo di feedback
  // resterebbe con i suggerimenti in italiano anche passando all'inglese.
  document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
    const key = el.dataset.i18nPlaceholder;
    if (key) el.placeholder = t(key);
  });
  document.querySelectorAll("[data-i18n-alt]").forEach((el) => {
    const key = el.dataset.i18nAlt;
    if (key) el.alt = t(key);
  });
  document.title = t("pageTitle");
  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc) metaDesc.content = t("metaDesc");
  renderHistory();
  renderProfile();
}

let navigazioneAgganciata = false;

export function bindNavigation(handlers) {
  // Un ascoltatore solo, sul documento, invece di uno per pulsante.
  //
  // Prima si faceva `querySelectorAll("[data-action]")` una volta all'avvio:
  // funzionava per il markup statico e lasciava muto tutto cio' che nasce dopo.
  // Il pulsante "Obiettivi" del Profilo Carriera e' generato da `renderProfile`,
  // quindi cliccarlo non faceva niente — nessun errore, nessun indizio. Con la
  // delega ogni `data-action` funziona da subito, anche se comparira' domani.
  if (!navigazioneAgganciata) {
    navigazioneAgganciata = true;
    document.addEventListener("click", (evento) => {
      const bersaglio = evento.target?.closest?.("[data-action]");
      if (!bersaglio) return;
      handlers[bersaglio.dataset.action]?.();
    });
  }

  applyDemoLimits();

  document.querySelectorAll(".mode-card:not(.mode-card--locked)").forEach((card) => {
    card.addEventListener("click", () => {
      ui.selectedMode = card.dataset.mode;
      if (ui.selectedMode === "tournament") {
        ui.tournamentRound = 0;
        ui.pendingContinue = false;
      }
      savePrefs(collectPrefs());
      handlers.selectMode?.(ui.selectedMode);
    });
  });
}
