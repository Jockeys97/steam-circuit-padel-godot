import { ARENAS, ATHLETES, BALANCE, COURT, MATCH_FORMATS, MATCH_FORMAT_IDS, matchObjective, outfitsForAthlete, CAREER_MATCHES, CAREER_POINTS_TO_WIN, CAREER_PROMOTION_WINS, CAREER_FINAL_SEASON, FEEDBACK, FEEDBACK_TOPICS } from "./data.js?v=20260814-feedback-confirm-v39";
import {
  createMatchState,
  resetReplayBuffer,
  updateMatch,
} from "./game.js?v=20260814-feedback-confirm-v39";
import { getVolume, initAudio, isMuted, music, setMuted, setVolume } from "./audio.js?v=20260814-feedback-confirm-v39";
import { setReduceMotion } from "./fx.js?v=20260814-feedback-confirm-v39";
import { createDrill, updateDrill, drillMetrics, DRILL_EXERCISES } from "./drill.js?v=20260814-feedback-confirm-v39";
import { getLang, setLang, t } from "./i18n.js?v=20260814-feedback-confirm-v39";
import { IS_DEMO, DEMO_CONTENT, demoFilter } from "./build.js?v=20260814-feedback-confirm-v39";
import {
  drawArena,
  drawActiveIndicator,
  drawBall,
  drawFx,
  drawHitZone,
  drawLandingMarker,
  drawPaddle,
  drawServeBox,
  drawShotFeedback,
  drawTeamGeometry,
  drawTimingHud,
} from "./render.js?v=20260814-feedback-confirm-v39";
import {
  applyLanguage,
  awardObjectives,
  athleteWithOutfit,
  bindNavigation,
  collectPrefs,
  currentFixture,
  drillRecord,
  feedbackAsText,
  feedbackMailto,
  feedbackDiagnostics,
  flushFeedback,
  loadFeedbackQueue,
  queueFeedback,
  saveDrillRecord,
  ensureSeasonObjectives,
  getAiForMatch,
  loadPrefs,
  recordMatch,
  renderArenas,
  awardOutfitChallenges,
  renderAthletes,
  currentTournamentFixture,
  renderChallenges,
  resolveLineup,
  renderHistory,
  renderProfile,
  resetSeasonObjectives,
  saveCareer,
  savePrefs,
  showResult,
  showScreen,
  ui,
  updateHud,
} from "./ui.js?v=20260814-feedback-confirm-v39";

const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");
const miniMap = document.getElementById("miniMap");
const miniCtx = miniMap.getContext("2d");
const pauseOverlay = document.getElementById("pauseOverlay");
const pauseTabs = [...document.querySelectorAll("[data-pause-tab]")];
const pausePanels = [...document.querySelectorAll("[data-pause-panel]")];
const pauseControlsOverview = document.getElementById("pauseControlsOverview");
const smashTutorial = document.getElementById("smashTutorial");
const openSmashTutorialButton = document.getElementById("openSmashTutorial");
const closeSmashTutorialButton = document.getElementById("closeSmashTutorial");
const trySmashTutorialButton = document.getElementById("trySmashTutorial");
const eventLog = document.getElementById("eventLog");
const eventLogToggle = document.getElementById("eventLogToggle");

function loadOptionalSprite(path) {
  const sprite = new Image();
  sprite.decoding = "async";
  if (path) sprite.src = path;
  return sprite;
}

const athleteAppearances = ATHLETES.flatMap((athlete) => [
  { ...athlete, outfitId: "base" },
  ...outfitsForAthlete(athlete.id)
    .filter((outfit) => outfit.id !== "base" && outfit.sprites)
    .map((outfit) => ({ ...athlete, ...outfit.sprites, outfitId: outfit.id })),
]);

function athleteSpriteKey(athlete) {
  return `${athlete.id}:${athlete.outfitId ?? "base"}`;
}

const appearanceByKey = new Map(athleteAppearances.map((a) => [athleteSpriteKey(a), a]));

/**
 * Gli sprite venivano richiesti tutti all'apertura: sei atleti e ogni loro
 * outfit, anche nella demo che ne mostra due e non ha progressione per
 * sbloccarne. Misurato: 12,55 MB scaricati contro 3,16 utilizzabili, il 75% di
 * spreco. Ora si caricano alla prima richiesta e restano in cache.
 */
function lazySpriteMap(field) {
  const cache = new Map();
  return {
    get(key) {
      let sprite = cache.get(key);
      if (!sprite) {
        sprite = loadOptionalSprite(appearanceByKey.get(key)?.[field]);
        cache.set(key, sprite);
      }
      return sprite;
    },
  };
}

const athleteSprites = lazySpriteMap("sprite");
const athleteBackSprites = lazySpriteMap("backSprite");
const athleteActionSprites = lazySpriteMap("actionSprite");
const athleteBackActionSprites = lazySpriteMap("backActionSprite");
const athleteRunSprites = lazySpriteMap("runSprite");
const athleteBackRunSprites = lazySpriteMap("backRunSprite");

// Gli atleti che questa build espone davvero vengono chiesti subito, cosi' non
// si vede il disegno procedurale nei primi istanti di partita. Gli outfit e gli
// atleti esclusi restano differiti.
demoFilter(ATHLETES, DEMO_CONTENT.athletes).forEach((athlete) => {
  const key = athleteSpriteKey({ ...athlete, outfitId: "base" });
  athleteSprites.get(key);
  athleteBackSprites.get(key);
  athleteActionSprites.get(key);
  athleteBackActionSprites.get(key);
  athleteRunSprites.get(key);
  athleteBackRunSprites.get(key);
});

const keys = new Set();
let hitQueued = false;
let sliceQueued = false;
let shotVariantQueued = null;
let shotAimQueued = null;
let specialQueued = false;
let switchQueued = false;
let switchDirectionQueued = null;
let matchState = null;
let gameLoopGeneration = 0;
let replayActive = false;
let replayIndex = 0;
let replayAccum = 0;
let drillState = null;
let drillLoopGen = 0;
let drillLastTime = 0;
let drillAccumulator = 0;

const GAMEPAD_MENU_DEADZONE = 0.28;
const gamepad = {
  index: null,
  connected: false,
  prevButtons: {},
  move: { x: 0, y: 0 },
  aim: { x: 0, y: 0 },
  chargeAction: null,
  smashTapConsumed: false,
  smashUpgradeQueued: false,
  cutVolleyQueued: false,
  globoQueued: false,
  switchStickLatched: false,
  splitStep: 0,
  sprint: 0,
  technicalModifier: false,
  tacticQueued: null,
  awaitingGameplayRelease: false,
  id: "",
  menuDir: null,
  menuRepeatAt: 0,
};
const gamepad2 = {
  index: null,
  connected: false,
  prevButtons: {},
  move: { x: 0, y: 0 },
  aim: { x: 0, y: 0 },
  chargeAction: null,
  smashTapConsumed: false,
  smashUpgradeQueued: false,
  cutVolleyQueued: false,
  globoQueued: false,
  switchStickLatched: false,
  splitStep: 0,
  sprint: 0,
  technicalModifier: false,
  tacticQueued: null,
  awaitingGameplayRelease: false,
  hitQueued: false,
  sliceQueued: false,
  shotVariantQueued: null,
  shotAimQueued: null,
  specialQueued: false,
  switchQueued: false,
  switchDirectionQueued: null,
};

let menuFocusEl = null;
let activePauseTab = "match";
let quitConfirmArmed = false;
let smashTutorialOpen = false;

function hideSmashTutorial(focusTrigger = false) {
  smashTutorialOpen = false;
  if (pauseControlsOverview) pauseControlsOverview.hidden = false;
  if (smashTutorial) smashTutorial.hidden = true;
  setMenuFocus(null);
  if (focusTrigger && openSmashTutorialButton) {
    requestAnimationFrame(() => setMenuFocus(openSmashTutorialButton));
  }
}

function showSmashTutorial() {
  smashTutorialOpen = true;
  if (pauseControlsOverview) pauseControlsOverview.hidden = true;
  if (smashTutorial) smashTutorial.hidden = false;
  setMenuFocus(null);
  requestAnimationFrame(() => setMenuFocus(closeSmashTutorialButton));
}

function setPauseTab(tabName, focusTab = false) {
  if (smashTutorialOpen) hideSmashTutorial(false);
  activePauseTab = tabName;
  let activeButton = null;
  pauseTabs.forEach((button) => {
    const active = button.dataset.pauseTab === tabName;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-selected", String(active));
    if (active) activeButton = button;
  });
  pausePanels.forEach((panel) => {
    const active = panel.dataset.pausePanel === tabName;
    panel.hidden = !active;
    panel.classList.toggle("is-active", active);
  });
  setMenuFocus(null);
  if (focusTab && gamepad.connected && activeButton) {
    requestAnimationFrame(() => setMenuFocus(activeButton));
  }
}

function gamepadAxis(pad, axis) {
  const v = pad.axes[axis] ?? 0;
  return Math.abs(v) < GAMEPAD_MENU_DEADZONE ? 0 : v;
}

function radialStick(x, y, deadzone = 0.15) {
  const magnitude = Math.min(1, Math.hypot(x, y));
  if (magnitude <= deadzone) return { x: 0, y: 0, magnitude: 0 };
  const normalized = (magnitude - deadzone) / (1 - deadzone);
  const curved = normalized ** 1.28;
  return {
    x: (x / magnitude) * curved,
    y: (y / magnitude) * curved,
    magnitude: curved,
  };
}

function shotAimAxis(value) {
  const clamped = Math.max(-1, Math.min(1, value));
  return Math.sign(clamped) * Math.pow(Math.abs(clamped), 0.72);
}

function isSliceAction(action) {
  return action === "slice" || action === "vibora";
}

function currentPad() {
  if (typeof navigator === "undefined" || !navigator.getGamepads) return null;
  const pads = navigator.getGamepads();
  const selected = gamepad.index !== null ? pads[gamepad.index] : null;
  return selected?.connected ? selected : pads.find((pad) => pad?.connected) ?? null;
}

function pulseGamepad(duration = 55, strong = 0.35, weak = 0.22) {
  if (!ui.vibration) return;
  const actuator = currentPad()?.vibrationActuator;
  actuator?.playEffect?.("dual-rumble", {
    duration,
    strongMagnitude: strong,
    weakMagnitude: weak,
  }).catch(() => {});
}

function releaseGamepadKeys() {
  gamepad.move = { x: 0, y: 0 };
  gamepad.aim = { x: 0, y: 0 };
  gamepad.chargeAction = null;
  gamepad.smashTapConsumed = false;
  gamepad.smashUpgradeQueued = false;
  gamepad.cutVolleyQueued = false;
  gamepad.globoQueued = false;
  gamepad.switchStickLatched = false;
  gamepad.splitStep = 0;
  gamepad.sprint = 0;
  gamepad.technicalModifier = false;
  gamepad.tacticQueued = null;
}

function releaseGamepadKeys2() {
  gamepad2.move = { x: 0, y: 0 };
  gamepad2.aim = { x: 0, y: 0 };
  gamepad2.chargeAction = null;
  gamepad2.smashTapConsumed = false;
  gamepad2.smashUpgradeQueued = false;
  gamepad2.cutVolleyQueued = false;
  gamepad2.globoQueued = false;
  gamepad2.switchStickLatched = false;
  gamepad2.splitStep = 0;
  gamepad2.sprint = 0;
  gamepad2.technicalModifier = false;
  gamepad2.tacticQueued = null;
  gamepad2.hitQueued = false;
  gamepad2.sliceQueued = false;
  gamepad2.shotVariantQueued = null;
  gamepad2.shotAimQueued = null;
  gamepad2.specialQueued = false;
  gamepad2.switchQueued = false;
  gamepad2.switchDirectionQueued = null;
}

function resetTransientInput({ awaitRelease = false, resetButtons = false } = {}) {
  releaseGamepadKeys();
  releaseGamepadKeys2();
  gamepad.awaitingGameplayRelease = awaitRelease;
  gamepad.menuDir = null;
  gamepad.menuRepeatAt = 0;
  if (resetButtons) gamepad.prevButtons = {};
  hitQueued = false;
  sliceQueued = false;
  shotVariantQueued = null;
  shotAimQueued = null;
  specialQueued = false;
  switchQueued = false;
  switchDirectionQueued = null;
  keys.clear();
}

function updateGamepadIndicator(connected, id = "") {
  // Il modello di controller viaggia con i feedback: un reclamo sull'input senza
  // sapere che pad c'era sotto non si puo' riprodurre.
  ui.lastGamepadId = connected ? (id || "sconosciuto") : null;
  const el = document.getElementById("gamepadIndicator");
  if (!el) return;
  el.hidden = !connected;
  const layout = detectControllerLayout(id);
  el.textContent = connected ? layout.badge : "🎮";
  el.dataset.controller = layout.type;
  el.title = connected ? t("gamepadConnected") : t("gamepadDisconnected");
}

function detectControllerLayout(id = "") {
  const value = String(id).toLowerCase();
  if (/xbox|xinput|microsoft/.test(value)) {
    return { type: "xbox", badge: "XBOX", image: "assets/ui/xbox-controller-steam.webp", caption: t("xboxLayout"), keys: ["LS", "RS", "A", "X", "Y", "B", "LB", "LT", "RT", "RB", "D-PAD", "A+A", "☰"] };
  }
  if (/playstation|dualshock|dualsense|sony|ps[345]/.test(value)) {
    return { type: "playstation", badge: "PS", image: "assets/ui/playstation-controller-steam.webp", caption: t("playstationLayout"), keys: ["L3", "R3", "✕", "□", "△", "○", "L1", "L2", "R2", "R1", "D-PAD", "✕+✕", "OPTIONS"] };
  }
  return { type: "generic", badge: "🎮", image: "assets/ui/generic-controller-steam.webp", caption: t("genericControllerLayout"), keys: ["LS", "RS", "1", "3", "4", "2", "LB", "LT", "RT", "RB", "D-PAD", "1+1", "MENU"] };
}

function applyControllerLayout(id = gamepad.id) {
  const layout = detectControllerLayout(id);
  const italian = getLang() === "it";
  const faceHints = layout.type === "playstation"
    ? (italian ? "✕ drive · □ slice · △ lob · ○ speciale" : "✕ drive · □ slice · △ lob · ○ special")
    : layout.type === "generic"
      ? (italian ? "1 drive · 3 slice · 4 lob · 2 speciale" : "1 drive · 3 slice · 4 lob · 2 special")
      : (italian ? "A drive · X slice · Y lob · B speciale" : "A drive · X slice · Y lob · B special");
  const technicalHints = layout.type === "playstation"
    ? (italian ? "✕ chiquita, □ víbora, △ lob difensivo" : "✕ chiquita, □ vibora, △ defensive lob")
    : layout.type === "generic"
      ? (italian ? "1 chiquita, 3 víbora, 4 lob difensivo" : "1 chiquita, 3 vibora, 4 defensive lob")
      : (italian ? "A chiquita, X víbora, Y lob difensivo" : "A chiquita, X vibora, Y defensive lob");
  const smashHint = layout.type === "playstation"
    ? (italian ? "Carica e rilascia, poi premi ✕ all'impatto" : "Charge and release, then press ✕ at contact")
    : layout.type === "generic"
      ? (italian ? "Carica e rilascia, poi premi 1 all'impatto" : "Charge and release, then press 1 at contact")
      : (italian ? "Carica e rilascia, poi premi A all'impatto" : "Charge and release, then press A at contact");
  document.querySelectorAll("[data-controller-image]").forEach((image) => {
    image.src = layout.image;
    image.alt = `${layout.caption} · ${t("controllerDetected")}`;
  });
  document.querySelectorAll("[data-controller-caption]").forEach((caption) => {
    caption.textContent = layout.caption;
  });
  document.querySelectorAll('[data-i18n="padButtons"]').forEach((label) => { label.textContent = faceHints; });
  document.querySelectorAll('[data-i18n="padTechnicalDesc"]').forEach((label) => { label.textContent = technicalHints; });
  document.querySelectorAll('[data-i18n="padSmashDesc"]').forEach((label) => { label.textContent = smashHint; });
  const keycaps = document.querySelectorAll(".controls-guide__legend > div > kbd:first-child, .controls-guide__legend > button > kbd:first-child");
  keycaps.forEach((keycap, index) => {
    if (layout.keys[index]) keycap.textContent = layout.keys[index];
  });
  document.querySelectorAll(".help-controller-legend kbd").forEach((keycap, index) => {
    if (layout.keys[index]) keycap.textContent = layout.keys[index];
  });
  document.querySelectorAll("[data-controller-panel]").forEach((panel) => {
    panel.dataset.controller = layout.type;
  });
}

function updateStickMonitor(left = { x: 0, y: 0 }, right = { x: 0, y: 0 }) {
  const leftDot = document.getElementById("leftStickDot");
  const rightDot = document.getElementById("rightStickDot");
  if (leftDot) leftDot.style.transform = `translate(calc(-50% + ${left.x * 17}px), calc(-50% + ${left.y * 17}px))`;
  if (rightDot) rightDot.style.transform = `translate(calc(-50% + ${right.x * 17}px), calc(-50% + ${right.y * 17}px))`;
}

function togglePause() {
  if (!matchState?.running) return;
  if (matchState.paused) resumeGame();
  else pauseGame();
}


/* ---- Tastiera su schermo ---------------------------------------------------
   Serve perche' col solo controller non si poteva scrivere: il modulo di feedback
   e il codice di sblocco erano decorativi per chi gioca col pad. Non si puo'
   contare sulla tastiera di Steam — in Big Picture e su Deck compare in base al
   wrapper e alla configurazione di Steam Input, e sul sito non compare affatto.

   I tasti sono veri `<button>` dentro un overlay che diventa il contesto di fuoco:
   la navigazione geometrica dei menu li raggiunge senza una riga di codice nuova. */

const OSK_ROWS = [
  "1234567890",
  "qwertyuiop",
  "asdfghjkl",
  "zxcvbnm",
  // Accentate italiane e i simboli che servono a un indirizzo email.
  "àèéìòù@._-+",
];

const oskEl = document.getElementById("osk");
const oskGrid = document.getElementById("oskGrid");
let oskTarget = null;
let oskShift = false;

function oskOpen() {
  return Boolean(oskEl && !oskEl.hidden);
}

function oskRefresh() {
  const preview = document.getElementById("oskPreview");
  if (preview) preview.textContent = oskTarget?.value ?? "";
  oskGrid?.querySelectorAll("[data-char]").forEach((key) => {
    const ch = key.dataset.char;
    key.textContent = oskShift ? ch.toUpperCase() : ch;
  });
  oskGrid?.querySelector('[data-osk="shift"]')?.classList.toggle("is-active", oskShift);
}

/** Scrive nel campo e avvisa chi ascolta: il contatore di caratteri sta in ascolto. */
function oskInsert(text) {
  if (!oskTarget) return;
  const max = Number(oskTarget.maxLength) > 0 ? Number(oskTarget.maxLength) : Infinity;
  if (oskTarget.value.length + text.length > max) return;
  oskTarget.value += text;
  oskTarget.dispatchEvent(new Event("input", { bubbles: true }));
  oskRefresh();
}

function oskDelete() {
  if (!oskTarget) return;
  oskTarget.value = oskTarget.value.slice(0, -1);
  oskTarget.dispatchEvent(new Event("input", { bubbles: true }));
  oskRefresh();
}

function buildOsk() {
  if (!oskGrid || oskGrid.childElementCount) return;
  OSK_ROWS.forEach((row) => {
    const riga = document.createElement("div");
    riga.className = "osk__row";
    [...row].forEach((ch) => {
      const key = document.createElement("button");
      key.type = "button";
      key.className = "osk__key";
      key.dataset.char = ch;
      key.textContent = ch;
      key.addEventListener("click", () => oskInsert(oskShift ? ch.toUpperCase() : ch));
      riga.appendChild(key);
    });
    oskGrid.appendChild(riga);
  });
  const azioni = document.createElement("div");
  azioni.className = "osk__row osk__row--actions";
  const comandi = [
    ["shift", "oskShift", () => { oskShift = !oskShift; oskRefresh(); }],
    ["space", "oskSpace", () => oskInsert(" ")],
    ["backspace", "oskBackspace", () => oskDelete()],
    ["done", "oskDone", () => closeOsk()],
  ];
  comandi.forEach(([nome, chiave, azione]) => {
    const key = document.createElement("button");
    key.type = "button";
    key.className = `osk__key osk__key--${nome}`;
    key.dataset.osk = nome;
    key.dataset.i18n = chiave;
    key.textContent = t(chiave);
    key.addEventListener("click", azione);
    azioni.appendChild(key);
  });
  oskGrid.appendChild(azioni);
}

function openOsk(field) {
  if (!oskEl || !field) return;
  buildOsk();
  oskTarget = field;
  oskShift = false;
  const etichetta = document.getElementById("oskLabel");
  if (etichetta) {
    // L'etichetta del campo, se c'e': senza, non si sa cosa si sta scrivendo.
    const label = field.labels?.[0]?.textContent
      ?? field.closest(".setup-group")?.querySelector(".setup-group__label")?.textContent
      ?? "";
    etichetta.textContent = `${label} · ${t("oskHint")}`.trim();
  }
  oskEl.hidden = false;
  oskRefresh();
  // Il fuoco passa alla tastiera: `menuContext` la mette davanti a tutto, quindi
  // la navigazione geometrica lavora sui tasti e non piu' sulla schermata sotto.
  setMenuFocus(null);
  ensureMenuFocus();
}

function closeOsk() {
  if (!oskEl || oskEl.hidden) return;
  oskEl.hidden = true;
  const tornaA = oskTarget;
  oskTarget = null;
  setMenuFocus(null);
  ensureMenuFocus();
  // Si torna sul campo appena chiuso, non all'inizio della schermata.
  if (tornaA && collectMenuTargets().includes(tornaA)) setMenuFocus(tornaA);
}

/** Un campo di testo: col pad si scrive con la tastiera su schermo. */
function isTextField(el) {
  if (el instanceof HTMLTextAreaElement) return true;
  if (!(el instanceof HTMLInputElement)) return false;
  return ["text", "search", "email", "url", "tel", "password", ""].includes(el.type);
}

function menuContext() {
  // La tastiera su schermo viene prima di tutto: mentre e' aperta il pad deve
  // muoversi fra i tasti, non fra i pulsanti della schermata sotto.
  if (oskOpen()) return oskEl;
  if (matchState?.running && !matchState?.paused) return null;
  return pauseOverlay.hidden ? document.querySelector(".screen--active") : pauseOverlay;
}

function collectMenuTargets() {
  const root = menuContext();
  if (!root) return [];
  // `textarea` e `summary` mancavano: il campo del messaggio nel modulo di
  // feedback non riceveva mai il fuoco, e il riquadro "cosa viene allegato" non si
  // apriva col pad. `select` non e' usato oggi, ma costa niente prevederlo.
  return [...root.querySelectorAll(
    "button, input, textarea, select, summary, .mode-card, .athlete-card, .arena-card",
  )].filter((el) => {
    if (el.disabled) return false;
    if (el.closest("[hidden]")) return false;
    if (el.classList.contains("mode-card--locked")) return false;
    // Una card che contiene i propri pulsanti e' un contenitore, non un
    // bersaglio. Le caselle del pannello squadra hanno dentro "Atleta" e
    // "Completo", quindi la card faceva da terzo bersaglio in mezzo ai due: per
    // arrivare a "Completo" servivano due spinte della levetta, e quella di
    // mezzo riselezionava la casella intera. Nel selettore e nel guardaroba la
    // card *e'* il bottone, quindi li' resta un bersaglio come prima.
    if (el.tagName !== "BUTTON" && el.querySelector("button")) return false;
    return el.offsetParent !== null;
  });
}

function setMenuFocus(el) {
  if (menuFocusEl === el) return;
  if (menuFocusEl) menuFocusEl.classList.remove("menu-focus");
  menuFocusEl = el;
  if (el) {
    el.classList.add("menu-focus");
    el.scrollIntoView({ block: "nearest", inline: "nearest" });
  }
}

function ensureMenuFocus() {
  const targets = collectMenuTargets();
  if (!targets.length) {
    setMenuFocus(null);
    return;
  }
  if (!menuFocusEl || !targets.includes(menuFocusEl)) setMenuFocus(targets[0]);
}

/**
 * Il contenitore che scorre davvero: puo' essere un riquadro interno — il contesto
 * tecnico del feedback ha il proprio — oppure la pagina.
 */
function scrollContainer() {
  let el = menuFocusEl;
  while (el && el !== document.body) {
    const stile = getComputedStyle(el);
    if (/(auto|scroll)/.test(stile.overflowY) && el.scrollHeight > el.clientHeight + 2) return el;
    el = el.parentElement;
  }
  return null;
}

/**
 * Scorre la vista.
 *
 * Serve perche' lo scorrimento era solo un effetto collaterale di `scrollIntoView`
 * quando il fuoco si spostava: nelle schermate di sola lettura — obiettivi, albo
 * d'oro, profilo — l'unico bersaglio e' il pulsante Indietro, quindi col pad non
 * si poteva vedere il resto della pagina.
 */
function scrollMenu(delta) {
  const el = scrollContainer();
  if (el) el.scrollTop += delta;
  else window.scrollBy(0, delta);
}

/** Il prossimo bersaglio in quella direzione, senza spostare il fuoco. */
function findMenuTarget(dir) {
  const targets = collectMenuTargets();
  if (!targets.length) return null;
  const cur = menuFocusEl && targets.includes(menuFocusEl) ? menuFocusEl : null;
  if (!cur) return targets[0];
  const curRect = cur.getBoundingClientRect();
  const curCx = curRect.left + curRect.width / 2;
  const curCy = curRect.top + curRect.height / 2;
  let best = null;
  let bestScore = Infinity;
  for (const el of targets) {
    if (el === cur) continue;
    const r = el.getBoundingClientRect();
    const dx = r.left + r.width / 2 - curCx;
    const dy = r.top + r.height / 2 - curCy;
    let ok = false;
    if (dir === "left") ok = dx < -8;
    else if (dir === "right") ok = dx > 8;
    else if (dir === "up") ok = dy < -8;
    else ok = dy > 8;
    if (!ok) continue;
    // Chi si sovrappone sull'asse trasversale sta *davvero* in quella direzione, e
    // vince sulla sola distanza fra i centri.
    //
    // Prima il punteggio confrontava i centri penalizzando lo scostamento per
    // tre: un elemento largo — la textarea del feedback — ha il centro in mezzo
    // alla riga, quindi partendo dalla colonna di sinistra perdeva contro una
    // casella di spunta piccola e piu' allineata che stava molto piu' in basso.
    // Veniva saltata del tutto: era nella lista dei bersagli e restava
    // irraggiungibile.
    const verticale = dir === "up" || dir === "down";
    const sovrapposizione = verticale
      ? Math.min(curRect.right, r.right) - Math.max(curRect.left, r.left)
      : Math.min(curRect.bottom, r.bottom) - Math.max(curRect.top, r.top);
    const lungoAsse = verticale ? Math.abs(dy) : Math.abs(dx);
    const trasversale = verticale ? Math.abs(dx) : Math.abs(dy);
    const score = sovrapposizione > 0 ? lungoAsse : lungoAsse + trasversale * 3 + 600;
    if (score < bestScore) {
      bestScore = score;
      best = el;
    }
  }
  return best;
}

function moveMenuFocus(dir) {
  const targets = collectMenuTargets();
  if (!targets.length) return false;
  const cur = menuFocusEl && targets.includes(menuFocusEl) ? menuFocusEl : null;
  if (!cur) {
    setMenuFocus(targets[0]);
    return true;
  }
  if (cur.matches('input[type="range"]') && (dir === "left" || dir === "right")) {
    const step = Number(cur.step) || 0.01;
    const direction = dir === "left" ? -1 : 1;
    cur.value = String(Math.min(Number(cur.max), Math.max(Number(cur.min), Number(cur.value) + step * direction)));
    cur.dispatchEvent(new Event("input", { bubbles: true }));
    return true;
  }
  const best = findMenuTarget(dir);
  if (best) setMenuFocus(best);
  // Il valore di ritorno dice a chi chiama se il fuoco si e' mosso: quando non si
  // muove, il pad deve scorrere la pagina invece di non fare niente.
  return Boolean(best);
}

function activateMenuFocus() {
  ensureMenuFocus();
  // Con un pad collegato, confermare su un campo di testo apre la tastiera su
  // schermo: cliccarlo darebbe il fuoco a un campo in cui non si puo' digitare.
  if (isTextField(menuFocusEl) && ui.lastGamepadId && !oskOpen()) {
    openOsk(menuFocusEl);
    return;
  }
  menuFocusEl?.click();
}

function menuBack() {
  if (oskOpen()) {
    closeOsk();
    return;
  }
  if (!pauseOverlay.hidden) {
    if (smashTutorialOpen) {
      hideSmashTutorial(true);
      return;
    }
    if (activePauseTab !== "match") {
      setPauseTab("match", true);
      return;
    }
    resumeGame();
    return;
  }
  const active = document.querySelector(".screen--active");
  // Il pulsante di ritorno si dichiara con `data-back`. Prima si prendeva il primo
  // `[data-action^="to-"]` della schermata: nel menu principale la barra in alto
  // viene prima dell'hero, quindi "indietro" apriva il Profilo — andava avanti
  // invece di tornare. La ricaduta sul vecchio criterio copre le schermate che
  // non hanno un ritorno dichiarato.
  const back = active?.querySelector("[data-back]") ?? active?.querySelector('[data-action^="to-"]');
  if (back) back.click();
}

function pollGamepads() {
  const pads = (typeof navigator !== "undefined" && navigator.getGamepads)
    ? navigator.getGamepads()
    : [];
  const connected = [...pads].filter((pad) => pad?.connected);
  const pad = connected[0] ?? null;
  const pad2 = connected[1] ?? null;

  if (pad) {
    gamepad.connected = true;
    gamepad.index = pad.index;
    gamepad.id = pad.id ?? "";
    applyControllerLayout(gamepad.id);
    updateGamepadIndicator(true, gamepad.id);
    const previewDeadzone = ui.gamepadDeadzone ?? 0.15;
    updateStickMonitor(
      radialStick(pad.axes[0] ?? 0, pad.axes[1] ?? 0, previewDeadzone),
      radialStick(pad.axes[2] ?? 0, pad.axes[3] ?? 0, previewDeadzone),
    );

    const b = (i) => pad.buttons[i]?.pressed ?? false;
    const inGame = !!matchState?.running && !matchState?.paused;
    if (inGame) pollGamepadGameplay(gamepad, pad, b);
    else pollGamepadMenu(pad, b);

    if (b(9) && !gamepad.prevButtons[9]) togglePause();
    gamepad.prevButtons[9] = b(9);
  } else if (gamepad.connected) {
    gamepad.connected = false;
    gamepad.index = null;
    releaseGamepadKeys();
    updateStickMonitor();
    setMenuFocus(null);
    updateGamepadIndicator(false);
    applyControllerLayout("");
  }

  if (pad2) {
    gamepad2.connected = true;
    gamepad2.index = pad2.index;
    const inGame = !!matchState?.running && !matchState?.paused;
    const multiplayer = matchState && (matchState.humanMode === "coop" || matchState.humanMode === "pvp");
    if (inGame && multiplayer) {
      const b2 = (i) => pad2.buttons[i]?.pressed ?? false;
      pollGamepadGameplay(gamepad2, pad2, b2, true);
    }
  } else if (gamepad2.connected) {
    gamepad2.connected = false;
    gamepad2.index = null;
    releaseGamepadKeys2();
  }
}

function pollGamepadGameplay(g, pad, b, isSecond = false) {
  const deadzone = ui.gamepadDeadzone ?? 0.15;
  const left = radialStick(pad.axes[0] ?? 0, pad.axes[1] ?? 0, deadzone);
  const directionStick = left;
  g.move = directionStick;
  g.splitStep = pad.buttons[6]?.value ?? (b(6) ? 1 : 0);
  g.sprint = pad.buttons[7]?.value ?? (b(7) ? 1 : 0);
  g.technicalModifier = b(5);

  if (g.awaitingGameplayRelease) {
    g.aim = { x: 0, y: 0 };
    if (!b(0) && !b(1) && !b(2) && !b(3) && !b(4) && !b(5)) {
      g.awaitingGameplayRelease = false;
    }
    return;
  }

  const tacticButtons = [12, 13, 14, 15];
  const tactics = ["attack", "defend", "staggered", "balanced"];
  tacticButtons.forEach((button, index) => {
    if (b(button) && !g.prevButtons[button]) {
      g.tacticQueued = tactics[index];
      if (!isSecond) pulseGamepad(42, 0.2, 0.28);
    }
    g.prevButtons[button] = b(button);
  });

  const right = radialStick(pad.axes[2] ?? 0, pad.axes[3] ?? 0, deadzone);
  const secondPaddle = isSecond && matchState
    ? matchState.humanMode === "coop"
      ? matchState.playerMate
      : matchState.humanMode === "pvp"
        ? matchState[matchState.pvpActiveKey]
        : null
    : null;
  const smashPrimed = isSecond
    ? secondPaddle?.smashPrimed
    : matchState?.humanMode === "coop"
      ? matchState.player?.smashPrimed
      : matchState?.smashPrimed;
  const aJustPressed = b(0) && !g.prevButtons[0];
  if (!b(0)) g.smashTapConsumed = false;
  if (aJustPressed && smashPrimed) {
    g.smashUpgradeQueued = true;
    const tapAim = {
      x: shotAimAxis(directionStick.x),
      y: shotAimAxis(directionStick.y),
    };
    if (isSecond) g.shotAimQueued = tapAim;
    else shotAimQueued = tapAim;
    g.smashTapConsumed = true;
    g.move = { x: 0, y: 0 };
    if (!isSecond) pulseGamepad(95, 0.72, 0.5);
  }
  // Secondo tocco su X: stessa grammatica del doppio tap su A per lo smash.
  const cutVolleyPrimed = isSecond
    ? secondPaddle?.cutVolleyPrimed
    : matchState?.cutVolleyPrimed;
  const xJustPressed = b(2) && !g.prevButtons[2];
  if (!b(2)) g.cutVolleyTapConsumed = false;
  if (xJustPressed && cutVolleyPrimed) {
    g.cutVolleyQueued = true;
    g.cutVolleyTapConsumed = true;
    if (!isSecond) pulseGamepad(80, 0.6, 0.42);
  }
  g.prevButtons[2] = b(2);

  // Secondo tocco su Y: globo.
  const globoPrimed = isSecond ? secondPaddle?.globoPrimed : matchState?.globoPrimed;
  const yJustPressed = b(3) && !g.prevButtons[3];
  if (!b(3)) g.globoTapConsumed = false;
  if (yJustPressed && globoPrimed) {
    g.globoQueued = true;
    g.globoTapConsumed = true;
    if (!isSecond) pulseGamepad(70, 0.5, 0.55);
  }
  g.prevButtons[3] = b(3);

  const shotButton = b(2) && !g.cutVolleyTapConsumed
    ? (g.technicalModifier ? "vibora" : "slice")
    : b(3) && !g.globoTapConsumed
      ? (g.technicalModifier ? "defensive-lob" : "lob")
      : b(0) && !g.smashTapConsumed
        ? (g.technicalModifier ? "chiquita" : "drive")
        : null;

  if (shotButton) {
    if (!g.chargeAction && !isSecond) initAudio();
    if (!g.chargeAction) {
      g.chargeAction = shotButton;
    }
    g.aim = {
      x: shotAimAxis(directionStick.x),
      y: shotAimAxis(directionStick.y),
    };
    g.move = { x: 0, y: 0 };
    g.switchStickLatched = false;
  } else if (g.chargeAction) {
    if (isSecond) {
      g.shotAimQueued = { ...g.aim };
      g.hitQueued = true;
      g.sliceQueued = isSliceAction(g.chargeAction);
      g.shotVariantQueued = g.chargeAction;
    } else {
      shotAimQueued = { ...gamepad.aim };
      hitQueued = true;
      sliceQueued = isSliceAction(gamepad.chargeAction);
      shotVariantQueued = gamepad.chargeAction;
      pulseGamepad(45, 0.28, 0.34);
    }
    g.chargeAction = null;
    g.aim = { x: 0, y: 0 };
  } else {
    g.aim = { x: 0, y: 0 };
    if (right.magnitude >= 0.72 && !g.switchStickLatched) {
      if (isSecond) g.switchDirectionQueued = { x: right.x, y: right.y };
      else switchDirectionQueued = { x: right.x, y: right.y };
      g.switchStickLatched = true;
      if (!isSecond) pulseGamepad(38, 0.18, 0.26);
    } else if (right.magnitude <= 0.3) {
      g.switchStickLatched = false;
    }
  }

  if (b(1) && !g.prevButtons[1]) {
    if (isSecond) g.specialQueued = true;
    else {
      specialQueued = true;
      initAudio();
      pulseGamepad(85, 0.55, 0.38);
    }
  }
  g.prevButtons[1] = b(1);

  if (b(4) && !g.prevButtons[4]) {
    if (isSecond) g.switchQueued = true;
    else switchQueued = true;
    if (!isSecond) pulseGamepad(38, 0.18, 0.26);
  }
  g.prevButtons[4] = b(4);
  g.prevButtons[0] = b(0);
}

function pollGamepadMenu(pad, b) {
  gamepad.aim = { x: 0, y: 0 };
  gamepad.move = { x: 0, y: 0 };
  gamepad.chargeAction = null;
  gamepad.switchStickLatched = false;
  ensureMenuFocus();

  const stickY = gamepadAxis(pad, 1);
  const stickX = gamepadAxis(pad, 0);
  const dpadUp = b(12);
  const dpadDown = b(13);
  const dpadLeft = b(14);
  const dpadRight = b(15);
  const dir = dpadUp || stickY < 0
    ? "up"
    : dpadDown || stickY > 0
      ? "down"
      : dpadLeft || stickX < 0
        ? "left"
        : dpadRight || stickX > 0
          ? "right"
          : null;

  // La levetta destra scorre sempre, come nei giochi: e' il gesto che si prova per
  // leggere il resto di una pagina lunga.
  const scorrimento = gamepadAxis(pad, 3);
  if (scorrimento) scrollMenu(scorrimento * 24);

  const now = performance.now();
  const verticale = dir === "up" || dir === "down";
  // Se in quella direzione non c'e' nessun bersaglio, la levetta sinistra scorre.
  // Prima non faceva niente: negli obiettivi, nell'albo d'oro e nel profilo
  // l'unico bersaglio e' il pulsante Indietro, quindi la pagina era bloccata e il
  // resto del contenuto irraggiungibile col solo pad.
  const nessunBersaglio = verticale && !findMenuTarget(dir);
  if (dir && nessunBersaglio) {
    // Ogni fotogramma, non a scatti: lo scorrimento deve essere continuo.
    scrollMenu((dir === "down" ? 1 : -1) * 15);
    gamepad.menuDir = dir;
  } else if (dir) {
    if (dir !== gamepad.menuDir) {
      gamepad.menuDir = dir;
      gamepad.menuRepeatAt = now + 400;
      moveMenuFocus(dir);
    } else if (now >= gamepad.menuRepeatAt) {
      gamepad.menuRepeatAt = now + 150;
      moveMenuFocus(dir);
    }
  } else {
    gamepad.menuDir = null;
  }

  if (b(0) && !gamepad.prevButtons[0]) {
    initAudio();
    activateMenuFocus();
  }
  gamepad.prevButtons[0] = b(0);

  // Indietro su entrambi: `b(1)` e' B su Xbox e Cerchio su PlayStation — cioe' il
  // tasto che tutti provano per tornare indietro, e che qui non era mappato a
  // niente. `b(2)` (X / Quadrato) resta per chi ci si e' abituato.
  const indietro = b(1) || b(2);
  if (indietro && !gamepad.prevMenuBack) {
    menuBack();
  }
  gamepad.prevMenuBack = indietro;
  gamepad.prevButtons[1] = b(1);
  gamepad.prevButtons[2] = b(2);
}

function gamepadLoop() {
  pollGamepads();
  requestAnimationFrame(gamepadLoop);
}

function getInput() {
  const keyboardX = (keys.has("a") || keys.has("arrowleft") ? -1 : 0)
    + (keys.has("d") || keys.has("arrowright") ? 1 : 0);
  const keyboardY = (keys.has("w") || keys.has("arrowup") ? -1 : 0)
    + (keys.has("s") || keys.has("arrowdown") ? 1 : 0);
  const keyboardLength = Math.max(1, Math.hypot(keyboardX, keyboardY));
  const usingGamepadMove = Math.hypot(gamepad.move.x, gamepad.move.y) > 0.02;
  const keyboardCharging = keys.has(" ") || keys.has("meta");
  const controllerVariant = gamepad.chargeAction ?? shotVariantQueued;
  const controllerAim = gamepad.chargeAction ? gamepad.aim : shotAimQueued;
  const input = {
    left: keyboardX < 0,
    right: keyboardX > 0,
    up: keyboardY < 0,
    down: keyboardY > 0,
    moveX: usingGamepadMove ? gamepad.move.x : keyboardX / keyboardLength,
    moveY: usingGamepadMove ? gamepad.move.y : keyboardY / keyboardLength,
    charging: keyboardCharging || Boolean(gamepad.chargeAction),
    hit: hitQueued,
    slice: sliceQueued || isSliceAction(gamepad.chargeAction),
    shotVariant: controllerVariant,
    special: specialQueued,
    switchPlayer: switchQueued,
    switchDirection: switchDirectionQueued,
    aim: controllerAim?.x ?? 0,
    aimY: controllerAim?.y ?? 0,
    analogAim: Boolean(controllerAim),
    smashUpgrade: gamepad.smashUpgradeQueued,
    cutVolley: gamepad.cutVolleyQueued,
    globo: gamepad.globoQueued,
    splitStep: gamepad.splitStep,
    sprint: gamepad.sprint,
    technicalModifier: gamepad.technicalModifier,
    teamTactic: gamepad.tacticQueued,
  };
  hitQueued = false;
  sliceQueued = false;
  shotVariantQueued = null;
  shotAimQueued = null;
  specialQueued = false;
  switchQueued = false;
  switchDirectionQueued = null;
  gamepad.smashUpgradeQueued = false;
  gamepad.cutVolleyQueued = false;
  gamepad.globoQueued = false;
  gamepad.tacticQueued = null;
  return input;
}

function getInput2() {
  const controllerAim2 = gamepad2.chargeAction ? gamepad2.aim : gamepad2.shotAimQueued;
  const input2 = {
    left: gamepad2.move.x < -0.2,
    right: gamepad2.move.x > 0.2,
    up: gamepad2.move.y < -0.2,
    down: gamepad2.move.y > 0.2,
    moveX: gamepad2.move.x,
    moveY: gamepad2.move.y,
    charging: gamepad2.chargeAction !== null,
    hit: gamepad2.hitQueued,
    slice: gamepad2.sliceQueued,
    shotVariant: gamepad2.shotVariantQueued,
    special: gamepad2.specialQueued,
    switchPlayer: gamepad2.switchQueued,
    switchDirection: gamepad2.switchDirectionQueued,
    aim: controllerAim2?.x ?? 0,
    aimY: controllerAim2?.y ?? 0,
    analogAim: Boolean(controllerAim2?.x || controllerAim2?.y),
    smashUpgrade: gamepad2.smashUpgradeQueued,
    cutVolley: gamepad2.cutVolleyQueued,
    globo: gamepad2.globoQueued,
    splitStep: gamepad2.splitStep,
    sprint: gamepad2.sprint,
    technicalModifier: gamepad2.technicalModifier,
    teamTactic: gamepad2.tacticQueued,
  };
  gamepad2.hitQueued = false;
  gamepad2.sliceQueued = false;
  gamepad2.shotVariantQueued = null;
  gamepad2.shotAimQueued = null;
  gamepad2.specialQueued = false;
  gamepad2.switchQueued = false;
  gamepad2.switchDirectionQueued = null;
  gamepad2.smashUpgradeQueued = false;
  gamepad2.cutVolleyQueued = false;
  gamepad2.globoQueued = false;
  gamepad2.tacticQueued = null;
  return input2;
}

function startMatch() {
  gameLoopGeneration += 1;
  resetTransientInput({ awaitRelease: true, resetButtons: true });
  const athlete = athleteWithOutfit(ui.selectedAthlete ?? ATHLETES[0]);
  // In carriera l'arena arriva dal calendario di stagione, non dal menu: va
  // risolta prima di costruire la partita, perche' il campo entra nella fisica.
  // Anche il torneo ha un calendario: i tre turni si giocavano tutti nel campo
  // scelto una volta sola, perche' `rematch` riparte senza ripassare dalla
  // selezione delle arene.
  const fixture = ui.selectedMode === "career"
    ? currentFixture()
    : ui.selectedMode === "tournament"
      ? currentTournamentFixture()
      : null;
  const arena = fixture?.arena ?? ui.selectedArena ?? ARENAS[0];
  const ai = getAiForMatch(ui.selectedMode, ui.tournamentRound, ui.aiDifficulty);
  const humanMode = ui.selectedMode === "quick" ? (ui.playerMode ?? "solo") : "solo";

  // La formazione va decisa prima di costruire la partita, non dopo: le
  // racchette prendono le statistiche di chi le occupa al momento in cui
  // nascono. Assegnarla solo ai campi usati dal disegno, com'era prima,
  // lasciava un compagno con la faccia di un atleta e i numeri di un altro.
  const lineup = resolveLineup(athlete);
  matchState = createMatchState(
    ui.selectedMode,
    athlete,
    arena,
    ai,
    ui.tournamentRound,
    { humanMode, lineup },
  );
  matchState.playerMateAthlete = lineup.playerMate;
  matchState.opponentAthlete = lineup.opponent;
  matchState.opponentMateAthlete = lineup.opponentMate;
  matchState.pvpAthlete = matchState.opponentAthlete;
  matchState.controlMode = ui.controlMode;
  if (ui.selectedMode === "quick") {
    // Il formato arriva tutto da `MATCH_FORMATS`: prima la scelta era un `if`
    // sui due formati a punti e tutto il resto ricadeva sul set pieno, quindi
    // aggiungerne uno voleva dire toccare questa riga invece che una tabella.
    Object.assign(matchState, MATCH_FORMATS[ui.matchLength] ?? MATCH_FORMATS.points11);
  } else if (ui.selectedMode === "career") {
    matchState.scoring = "points";
    matchState.pointsToWin = CAREER_POINTS_TO_WIN;
    matchState.careerSeason = ui.career.season;
    matchState.careerMatch = ui.career.matchIndex + 1;
    matchState.careerRival = fixture.rival;
    matchState.matchObjective = matchObjective(ui.career.season, ui.career.matchIndex);
    ensureSeasonObjectives();
    ui.careerSeasonWon = false;
  }
  matchState.running = true;
  resetReplayBuffer(matchState);
  replayActive = false;
  replayIndex = 0;
  replayAccum = 0;
  matchState.lastTime = performance.now();
  simAccumulator = 0;
  pauseOverlay.hidden = true;

  showScreen("game");
  updateHud(matchState);
  music.setIntensity(0.12);
  music.start();
  const generation = gameLoopGeneration;
  requestAnimationFrame((now) => gameLoop(now, generation));
}

const FIXED_STEP = 1 / 120;
const MAX_SIM_STEPS = 8;
let simAccumulator = 0;

/** Azzera i comandi che devono valere una volta sola per fotogramma. */
function consumeOneShot(input) {
  if (!input) return input;
  return {
    ...input,
    hit: false,
    special: false,
    switchPlayer: false,
    switchDirection: null,
    smashUpgrade: false,
    cutVolley: false,
    teamTactic: null,
  };
}

function gameLoop(now, generation) {
  if (generation !== gameLoopGeneration || !matchState?.running) return;

  const dt = Math.min((now - matchState.lastTime) / 1000, 0.25);
  matchState.lastTime = now;

  let result = null;
  if (replayActive) {
    stepReplay(dt);
    result = null;
  } else {
    // Passo fisso con accumulatore: prima la fisica dipendeva dal frame rate,
    // quindi a 144 Hz si giocava una partita leggermente diversa che a 60.
    simAccumulator = Math.min(simAccumulator + dt, FIXED_STEP * MAX_SIM_STEPS);
    let input = getInput();
    let input2 = getInput2();
    let steps = 0;
    while (simAccumulator >= FIXED_STEP && steps < MAX_SIM_STEPS) {
      result = updateMatch(matchState, FIXED_STEP, input, input2);
      simAccumulator -= FIXED_STEP;
      steps += 1;
      if (result) break;
      // Gli input a colpo singolo valgono per un passo solo: ripetendoli si
      // accoderebbe lo stesso colpo piu' volte nello stesso fotogramma.
      if (steps === 1) {
        input = consumeOneShot(input);
        input2 = consumeOneShot(input2);
      }
    }
  }
  if (matchState.hapticPulse) {
    const { duration, strong, weak } = matchState.hapticPulse;
    pulseGamepad(duration, strong, weak);
    matchState.hapticPulse = null;
  }
  updateHud(matchState);

  const rallyTension = Math.min(1, matchState.rallyHits / 12);
  const stakes = Math.min(
    0.35,
    (matchState.sets.player + matchState.sets.ai) * 0.15
      + (matchState.games.player + matchState.games.ai) * 0.02,
  );
  music.setIntensity(Math.min(1, 0.12 + rallyTension * 0.55 + stakes));

  let replayApplied = null;
  if (replayActive) replayApplied = applyReplayFrame();

  drawScene(ctx, canvas, matchState, now);

  if (matchState.flash > 0) {
    ctx.fillStyle = `rgba(255, 209, 102, ${matchState.flash * 0.14})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }

  if (replayActive) {
    drawReplayOverlay(now / 1000);
    if (replayApplied) restoreReplayFrame(replayApplied);
  }

  if (result) {
    endMatch(result.winner);
    return;
  }

  requestAnimationFrame((nextNow) => gameLoop(nextNow, generation));
}

const REPLAY_PAD_KEYS = ["player", "playerMate", "opponent", "opponentMate"];
const REPLAY_PAD_FIELDS = ["x", "y", "swing", "swingSide", "motion", "charge", "runPhase", "actionPose", "actionIntent", "moveRatio"];
const REPLAY_BALL_FIELDS = ["x", "y", "z", "vx", "vy", "vz", "spin", "topspin", "backspin", "shotType", "serveInFlight", "serveTouchedNet", "bouncePulse", "landRing", "hitFlash", "hitPulse", "trail"];

function stepReplay(dt) {
  const frames = matchState.replayFrames;
  if (!frames.length) {
    replayActive = false;
    return;
  }
  replayAccum += dt;
  while (replayAccum >= 1 / 60) {
    replayAccum -= 1 / 60;
    if (replayIndex < frames.length - 1) replayIndex += 1;
  }
}

/** Applica lo snapshot al matchState per il frame di replay. Restituisce i valori da ripristinare. */
function applyReplayFrame() {
  const snap = matchState.replayFrames[replayIndex];
  if (!snap) return null;
  const savedPads = [];
  REPLAY_PAD_KEYS.forEach((key, i) => {
    const pad = matchState[key];
    const s = snap.pads[i];
    const saved = {};
    REPLAY_PAD_FIELDS.forEach((f) => {
      saved[f] = pad[f];
      pad[f] = s[f];
    });
    savedPads.push(saved);
  });
  const savedBall = {};
  REPLAY_BALL_FIELDS.forEach((f) => {
    savedBall[f] = matchState.ball[f];
    matchState.ball[f] = snap.ball[f];
  });
  const savedServeSide = matchState.serveSide;
  const savedServeCourt = matchState.serveCourt;
  const savedActiveKey = matchState.activePlayerKey;
  matchState.serveSide = snap.serveSide;
  matchState.serveCourt = snap.serveCourt;
  matchState.activePlayerKey = snap.activePlayerKey;
  return { savedPads, savedBall, savedServeSide, savedServeCourt, savedActiveKey };
}

function restoreReplayFrame(saved) {
  if (!saved) return;
  saved.savedPads.forEach((vals, i) => {
    const pad = matchState[REPLAY_PAD_KEYS[i]];
    REPLAY_PAD_FIELDS.forEach((f) => { pad[f] = vals[f]; });
  });
  REPLAY_BALL_FIELDS.forEach((f) => { matchState.ball[f] = saved.savedBall[f]; });
  matchState.serveSide = saved.savedServeSide;
  matchState.serveCourt = saved.savedServeCourt;
  matchState.activePlayerKey = saved.savedActiveKey;
}

function drawReplayOverlay(time) {
  const frames = matchState.replayFrames;
  const total = frames.length;
  const progress = total ? (replayIndex + 1) / total : 0;
  ctx.fillStyle = "rgba(6, 12, 30, 0.42)";
  ctx.fillRect(0, 0, canvas.width, 40);
  ctx.fillStyle = "#ffcc00";
  ctx.font = "12px 'Lilita One', sans-serif";
  ctx.textAlign = "left";
  ctx.fillText(`▶ ${t("replay")}`, 14, 26);
  ctx.fillStyle = "rgba(255,255,255,0.9)";
  ctx.font = "11px 'Lilita One', sans-serif";
  ctx.textAlign = "right";
  ctx.fillText(`${t("replayExit")}`, canvas.width - 14, 26);
  ctx.fillStyle = "rgba(255,255,255,0.2)";
  ctx.fillRect(0, canvas.height - 8, canvas.width, 8);
  ctx.fillStyle = "#ffcc00";
  ctx.fillRect(0, canvas.height - 8, canvas.width * Math.min(1, Math.max(0, progress)), 8);
  ctx.textAlign = "left";
}

function toggleReplay() {
  if (!matchState?.running) return;
  if (replayActive) {
    replayActive = false;
    matchState.paused = false;
    return;
  }
  if (matchState.replayFrames.length < 2) return;
  replayActive = true;
  replayIndex = 0;
  replayAccum = 0;
  matchState.paused = false;
}

function drawMiniMap(state) {
  const { width, height } = miniMap;
  const padding = 11;
  const courtWidth = width - padding * 2;
  const courtHeight = height - padding * 2;
  const mapPoint = (x, y) => ({
    x: padding + ((x - 80) / 800) * courtWidth,
    y: padding + ((y - 56) / 508) * courtHeight,
  });
  miniCtx.clearRect(0, 0, width, height);
  miniCtx.fillStyle = "#123d68";
  miniCtx.fillRect(padding, padding, courtWidth, courtHeight);
  miniCtx.strokeStyle = "rgba(255,255,255,0.86)";
  miniCtx.lineWidth = 2;
  miniCtx.strokeRect(padding, padding, courtWidth, courtHeight);
  miniCtx.beginPath();
  miniCtx.moveTo(padding, height / 2);
  miniCtx.lineTo(width - padding, height / 2);
  miniCtx.stroke();
  const players = [
    [state.player, "#12dff0"],
    [state.playerMate, "#55f1ff"],
    [state.opponent, "#ff5d7a"],
    [state.opponentMate, "#ffad45"],
  ];
  players.forEach(([paddle, color]) => {
    const p = mapPoint(paddle.x, paddle.y);
    miniCtx.fillStyle = color;
    miniCtx.beginPath();
    miniCtx.arc(p.x, p.y, 4, 0, Math.PI * 2);
    miniCtx.fill();
  });
  const ball = mapPoint(state.ball.x, state.ball.y);
  miniCtx.fillStyle = "#fff36a";
  miniCtx.beginPath();
  miniCtx.arc(ball.x, ball.y, 3.2, 0, Math.PI * 2);
  miniCtx.fill();
}

function endMatch(winner) {
  matchState.running = false;
  music.stop();

  // Con il punteggio a game l'archivio riceve il tabellone vero — "6-4" o
  // "6-4, 3-6, 7-5" — e non il conteggio dei set, che nei formati a un set solo
  // valeva "1-0" per qualunque partita.
  const score = matchState.pointsToWin
    ? `${matchState.points.player}-${matchState.points.ai}`
    : (matchState.setScores ?? []).length
      ? matchState.setScores.map((s) => `${s.player}-${s.ai}`).join(", ")
      : `${matchState.sets.player}-${matchState.sets.ai}`;
  const careerWin = winner === "player" && ui.selectedMode === "career";
  const careerSeasonWon = careerWin && ui.career.seasonWins + 1 >= CAREER_MATCHES
    && ui.career.matchIndex + 1 >= CAREER_MATCHES;
  const tournamentTrophy = winner === "player" && ui.selectedMode === "tournament" && ui.tournamentRound === 2;
  recordMatch({
    ts: Date.now(),
    mode: ui.selectedMode,
    humanMode: matchState.humanMode,
    winner,
    score,
    opponent: matchState.humanMode === "pvp" && matchState.opponentAthlete
      ? t(`athlete_${matchState.opponentAthlete.id}_name`)
      : matchState.ai.id ? t(`ai_${matchState.ai.id}_name`) : matchState.ai.name,
    athlete: t(`athlete_${matchState.athlete.id}_name`),
    arena: t(`arena_${matchState.arena.id}_name`),
    difficulty: ui.aiDifficulty,
    pointsToWin: matchState.pointsToWin ?? null,
    trophy: careerSeasonWon || tournamentTrophy,
    season: ui.selectedMode === "career" ? ui.career.season : undefined,
  });

  // Le sfide dei completi valgono in ogni modalita', non solo in carriera: sono
  // la ragione per provare atleti diversi, e legarle alla sola carriera le
  // avrebbe rese un premio della progressione invece che una sfida.
  ui.outfitsWonNow = awardOutfitChallenges(matchState, winner === "player");

  if (ui.selectedMode === "career") {
    ui.objectiveResult = awardObjectives(matchState);
  } else {
    ui.objectiveResult = null;
  }

  if (ui.selectedMode === "career") {
    // La stagione avanza anche quando perdi. Prima `matchIndex` cresceva solo
    // vincendo: perdere non costava nulla, si rigiocava la stessa partita
    // all'infinito e la carriera non aveva nessuna posta in gioco.
    const vinta = winner === "player";
    if (vinta) {
      ui.career.wins += 1;
      ui.career.seasonWins = (ui.career.seasonWins ?? 0) + 1;
      ui.career.rivalStreak = Math.max(0, ui.career.rivalStreak) + 1;
    } else {
      ui.career.losses += 1;
      ui.career.rivalStreak = Math.min(0, ui.career.rivalStreak) - 1;
    }
    ui.career.matchIndex += 1;

    ui.careerSeasonWon = false;
    ui.careerSeasonOutcome = null;
    if (ui.career.matchIndex >= CAREER_MATCHES) {
      const vinte = ui.career.seasonWins ?? 0;
      // Il trofeo dell'ultima stagione chiude il circuito: e' il finale, e si
      // vede una volta sola. Prima la carriera non aveva un traguardo — dalla
      // quinta stagione era la stessa Leggenda a ripetizione, per sempre.
      const finale = vinte >= CAREER_MATCHES && ui.career.season >= CAREER_FINAL_SEASON;
      if (vinte >= CAREER_MATCHES) {
        // Stagione perfetta: trofeo e promozione.
        ui.career.trophies += 1;
        ui.career.season += 1;
        ui.careerSeasonWon = true;
        ui.careerSeasonOutcome = finale && !ui.career.finaleSeen ? "finale" : "trophy";
        if (finale) ui.career.finaleSeen = true;
      } else if (vinte >= CAREER_PROMOTION_WINS) {
        // Stagione positiva: si avanza, ma senza trofeo.
        ui.career.season += 1;
        ui.careerSeasonOutcome = "promoted";
      } else {
        // Stagione fallita: si resta nella stessa, da rigiocare. Le stelle e gli
        // obiettivi gia' conquistati restano: si perde tempo, non progressi.
        ui.careerSeasonOutcome = "repeat";
      }
      ui.career.bestSeason = Math.max(ui.career.bestSeason ?? 1, ui.career.season);
      ui.career.matchIndex = 0;
      ui.career.seasonWins = 0;
      resetSeasonObjectives();
    }
    saveCareer(ui.career);
    ui.pendingContinue = true;
    savePrefs(collectPrefs());
    updateCareerTag();
    showResult(matchState, winner);
    return;
  }

  if (winner === "player" && ui.selectedMode === "tournament" && ui.tournamentRound < 2) {
    ui.tournamentRound += 1;
    ui.pendingContinue = true;
    savePrefs(collectPrefs());
    showResult(matchState, winner);
    return;
  }

  if (ui.selectedMode === "tournament") {
    ui.tournamentRound = 0;
    ui.pendingContinue = false;
  }

  savePrefs(collectPrefs());
  showResult(matchState, winner);
}

function updateCareerTag() {
  const el = document.getElementById("careerTag");
  if (!el) return;
  el.textContent = t("careerTag", {
    season: ui.career.season,
    match: ui.career.matchIndex,
    total: CAREER_MATCHES,
  });
  // Il turno di calendario: dove si gioca e contro chi. Senza questo la carriera
  // annunciava solo un contatore, e l'arena imposta dal circuito arrivava senza
  // preavviso a partita iniziata.
  const fixtureEl = document.getElementById("careerFixture");
  if (!fixtureEl) return;
  const fixture = currentFixture();
  fixtureEl.textContent = `${t("careerFixture", {
    match: ui.career.matchIndex + 1,
    total: CAREER_MATCHES,
    arena: t(`arena_${fixture.arena.id}_name`),
  })} · ${t("careerRivalLabel", { rival: t(`ai_${fixture.rival.id}_name`) })}`;
}

function rematch() {
  if (ui.pendingContinue) {
    ui.pendingContinue = false;
    startMatch();
    return;
  }

  if (ui.selectedMode === "tournament") {
    ui.tournamentRound = 0;
  }

  startMatch();
}

function pauseGame() {
  if (!matchState?.running) return;
  resetTransientInput();
  matchState.paused = true;
  pauseOverlay.hidden = false;
  resetQuitConfirm();
  setPauseTab("match", true);
}

function resumeGame() {
  if (!matchState) return;
  resetTransientInput({ awaitRelease: true });
  matchState.paused = false;
  matchState.lastTime = performance.now();
  simAccumulator = 0;
  pauseOverlay.hidden = true;
}

function quitMatch() {
  gameLoopGeneration += 1;
  resetTransientInput({ resetButtons: true });
  matchState = null;
  music.stop();
  pauseOverlay.hidden = true;
  resetQuitConfirm();
  showScreen("menu");
}

function resetQuitConfirm() {
  quitConfirmArmed = false;
  const quitBtn = document.querySelector('[data-action="quit-match"]');
  if (quitBtn) {
    quitBtn.textContent = t("quit");
    quitBtn.classList.remove("btn--confirm");
  }
}

function handleQuitMatch() {
  if (!quitConfirmArmed) {
    quitConfirmArmed = true;
    const quitBtn = document.querySelector('[data-action="quit-match"]');
    if (quitBtn) {
      quitBtn.textContent = t("quitConfirm");
      quitBtn.classList.add("btn--confirm");
      pulseGamepad(45, 0.25, 0.25);
    }
    return;
  }
  quitMatch();
}

/**
 * Ricostruisce la griglia delle arene.
 *
 * Va rifatta ogni volta che si entra nella schermata, non solo all'avvio: in
 * carriera segna l'arena della giornata, e la giornata cambia a ogni partita.
 * Costruendola una volta sola si sarebbe vista per sempre la prima.
 */
function refreshArenas() {
  renderArenas(() => {
    savePrefs(collectPrefs());
    startMatch();
  });
}

function syncMatchSetup() {
  const setup = document.getElementById("matchSetup");
  if (!setup) return;
  setup.hidden = ui.selectedMode !== "quick";
  if (ui.selectedMode === "tournament") setup.hidden = true;
  if (playerModeSetup) playerModeSetup.hidden = ui.selectedMode !== "quick";
}

function syncSegmented(container, value) {
  const buttons = [...container.querySelectorAll("button[data-value]")];
  buttons.forEach((button) => {
    const active = button.dataset.value === value;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
}

const drillCanvas = document.getElementById("drillCanvas");
const drillCtx = drillCanvas ? drillCanvas.getContext("2d") : null;

/**
 * L'allenamento usa lo stesso input della partita. Prima ne aveva uno ridotto a
 * destra/sinistra/carica: con tre comandi non si possono nemmeno tentare taglio,
 * pallonetto, smash a due tocchi, split-step o sprint — cioe' proprio le
 * meccaniche che si dovrebbero allenare.
 */
function drillInput() {
  return getInput();
}

function startDrill() {
  if (matchState?.running) quitMatch();
  drillLoopGen += 1;
  const athlete = athleteWithOutfit(ui.selectedAthlete ?? ATHLETES[0]);
  // La formazione la risolve l'interfaccia e arriva da qui: `drill.js` deve
  // restare eseguibile senza DOM, quindi non se la va a prendere da solo.
  const lineup = resolveLineup(athlete);
  drillState = createDrill(
    ui.drillExercise ?? DRILL_EXERCISES[0].id,
    athlete,
    ui.selectedArena ?? ARENAS[0],
    // Difficolta' propria dell'allenamento: prima ereditava in silenzio quella
    // della partita rapida, e non c'era modo di accorgersene ne' di cambiarla.
    getAiForMatch("quick", 0, ui.drillDifficulty ?? ui.aiDifficulty),
    {
      playerMate: lineup.playerMate,
      opponent: lineup.opponent,
      opponentMate: lineup.opponentMate,
    },
  );
  // Il record sopravvive alla sessione, quindi va riportato nello stato: senza
  // questo la casella "Record" ripartirebbe da zero a ogni apertura.
  drillState.best = drillRecord(drillState.exercise.id);
  drillLastTime = performance.now();
  drillAccumulator = 0;
  syncDrillChrome();
  showScreen("drill");
  requestAnimationFrame((now) => drillLoop(now, drillLoopGen));
}

/** Titoli, etichette dell'HUD e selettore, che cambiano con l'esercizio. */
function syncDrillChrome() {
  const id = drillState?.exercise?.id ?? ui.drillExercise ?? DRILL_EXERCISES[0].id;
  const sub = document.getElementById("drillSub");
  if (sub) sub.textContent = t(`drill_${id}_desc`);
  const hint = document.getElementById("drillHint");
  if (hint) hint.textContent = t(`drill_${id}_hint`);
  document.querySelectorAll("#drillSeg button").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.value === id);
  });
  const difficolta = ui.drillDifficulty ?? ui.aiDifficulty;
  document.querySelectorAll("#drillDiffSeg button").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.value === difficolta);
  });
  const labels = drillState ? drillMetrics(drillState) : [];
  labels.forEach((metric, index) => {
    const box = document.getElementById(`drillLabel${index}`);
    if (box) box.textContent = t(metric.key);
  });
}

function stopDrill() {
  drillLoopGen += 1;
  if (drillState) drillState.running = false;
}

function drawDrillOverlay(now) {
  if (!drillCtx || !drillState) return;
  const d = drillState;
  const c = drillCtx;
  const cx = drillCanvas.width / 2;

  if (d.phase === "ready") {
    c.fillStyle = "rgba(6, 12, 30, 0.5)";
    c.fillRect(0, 0, drillCanvas.width, drillCanvas.height);
    c.fillStyle = "#ffcc00";
    c.font = "30px 'Lilita One', sans-serif";
    c.textAlign = "center";
    c.fillText(t("drillReady"), cx, 430);
    // Solo il richiamo breve: il suggerimento dettagliato vive nella riga sotto
    // il campo, dove l'HTML lo manda a capo. Qui, disegnato su una riga sola,
    // attraversava il campo e passava sopra i giocatori.
    c.fillStyle = "rgba(255,255,255,0.85)";
    c.font = "15px 'Lilita One', sans-serif";
    c.fillText(t("drillHint1"), cx, 466);
  }

  // Il misuratore di carica e la finestra di timing non si disegnano piu' qui:
  // li porta `drawScene` con lo stesso HUD della partita, che e' il punto —
  // l'allenamento mostrava un misuratore inventato, con un "perfetto" che nel
  // gioco non esisteva.

  if (d.phase === "result" && d.grade) {
    const colori = { perfect: "#1aff8a", good: "#ffcc00", early: "#ff9f43", late: "#ff6d70" };
    const testi = { perfect: "PERFECT ⭐", good: "GOOD", early: "EARLY", late: "LATE" };
    c.font = "28px 'Lilita One', sans-serif";
    c.textAlign = "center";
    c.fillStyle = colori[d.grade] ?? "#ffffff";
    c.fillText(testi[d.grade] ?? "", cx, 380);
    c.fillStyle = "#ffffff";
    c.font = "18px 'Lilita One', sans-serif";
    c.fillText(`${t("drillPoints")} +${d.points}`, cx, 414);
    // Perche' e' andata cosi'. Prima il riepilogo dava voto e punti e taceva sul
    // motivo: un esercizio che valuta senza diagnosticare insegna a metà.
    if (d.diagnosis) {
      c.fillStyle = "rgba(255,255,255,0.82)";
      c.font = "15px 'Nunito', sans-serif";
      c.fillText(t(d.diagnosis), cx, 444);
    }
  }
}

function drawDrill(now) {
  if (!drillCtx || !drillState) return;
  const d = drillState;
  const c = drillCtx;

  // La stessa scena della partita: i quattro atleti con i loro completi, la zona
  // di colpo, il misuratore di timing. Prima l'allenamento disegnava una sola
  // racchetta senza sprite, e si vedeva un omino generico su un campo vuoto.
  drawScene(c, drillCanvas, d.state, now);

  if (d.target.active) drawDrillTarget(c, d.target, now / 1000);
  if (d.landing) {
    const lp = c.__padelProject(d.landing.x, d.landing.y);
    c.fillStyle = "rgba(255,255,255,0.22)";
    c.beginPath();
    c.ellipse(lp.x, lp.y, 16, 8, 0, 0, Math.PI * 2);
    c.fill();
  }
  drawDrillOverlay(now);
}

/**
 * Il bersaglio. Il colore dice quale colpo chiede: corto vuole un rimbalzo
 * schiacciato (taglio), profondo vuole spinta (piatto). Senza questa distinzione
 * i due bersagli sarebbero indistinguibili e l'esercizio non insegnerebbe nulla.
 */
function drawDrillTarget(c, target, time) {
  const p = c.__padelProject(target.x, target.y);
  const corto = target.kind === "short";
  const tinta = corto ? "26,255,138" : "255,204,0";
  const pulse = 0.72 + Math.sin(time * 3.4) * 0.16;
  const rx = target.r * (p.scale ?? 1);
  const ry = rx * 0.52;
  c.save();
  c.lineWidth = 3;
  c.strokeStyle = `rgba(${tinta},${pulse})`;
  c.fillStyle = `rgba(${tinta},0.13)`;
  c.beginPath();
  c.ellipse(p.x, p.y, rx, ry, 0, 0, Math.PI * 2);
  c.fill();
  c.stroke();
  // Il centro vale il doppio: va visto.
  c.beginPath();
  c.ellipse(p.x, p.y, rx * 0.42, ry * 0.42, 0, 0, Math.PI * 2);
  c.stroke();
  c.fillStyle = `rgba(${tinta},0.95)`;
  c.font = "700 12px Nunito, sans-serif";
  c.textAlign = "center";
  c.fillText(t(corto ? "drillTargetShort" : "drillTargetDeep"), p.x, p.y - ry - 8);
  c.restore();
}

function drawScene(c, cvs, state, now) {
      drawArena(c, cvs, state.arena, now / 1000);
    drawServeBox(c, state, now / 1000);
    drawLandingMarker(c, state.ball, now / 1000);
    drawTeamGeometry(c, state);
    drawHitZone(c, state[state.activePlayerKey], "#fff36a");
    drawPaddle(c, state.opponent, state.opponentAthlete.color, false, state.opponent.swing,
      state.humanMode === "pvp" && state.pvpActiveKey === "opponent" ? state.opponent.charge : 0,
      state.opponentAthlete, athleteSprites.get(athleteSpriteKey(state.opponentAthlete)),
      athleteActionSprites.get(athleteSpriteKey(state.opponentAthlete)),
      athleteRunSprites.get(athleteSpriteKey(state.opponentAthlete)), now / 1000);
    drawPaddle(c, state.opponentMate, state.opponentMateAthlete.color, false, state.opponentMate.swing,
      state.humanMode === "pvp" && state.pvpActiveKey === "opponentMate" ? state.opponentMate.charge : 0,
      state.opponentMateAthlete, athleteSprites.get(athleteSpriteKey(state.opponentMateAthlete)),
      athleteActionSprites.get(athleteSpriteKey(state.opponentMateAthlete)),
      athleteRunSprites.get(athleteSpriteKey(state.opponentMateAthlete)), now / 1000);
    drawPaddle(c, state.playerMate, state.playerMateAthlete.color, true, state.playerMate.swing,
      state.humanMode === "coop" ? state.playerMate.charge
        : state.activePlayerKey === "playerMate" ? state.shotCharge : 0,
      state.playerMateAthlete, athleteBackSprites.get(athleteSpriteKey(state.playerMateAthlete)),
      athleteBackActionSprites.get(athleteSpriteKey(state.playerMateAthlete)),
      athleteBackRunSprites.get(athleteSpriteKey(state.playerMateAthlete)), now / 1000);
    drawPaddle(c, state.player, state.athlete.color, true, state.player.swing,
      state.humanMode === "coop" ? state.player.charge
        : state.activePlayerKey === "player" ? state.shotCharge : 0, state.athlete,
      athleteBackSprites.get(athleteSpriteKey(state.athlete)),
      athleteBackActionSprites.get(athleteSpriteKey(state.athlete)),
      athleteBackRunSprites.get(athleteSpriteKey(state.athlete)), now / 1000);
    const activeSprite = state.activePlayerKey === "player"
      ? athleteBackSprites.get(athleteSpriteKey(state.athlete))
      : athleteBackSprites.get(athleteSpriteKey(state.playerMateAthlete));
    const smashChargeThreshold = Math.max(
      0,
      Math.min(1, (BALANCE.smashMinPower / state.athlete.stats.power - 0.4) / 0.95),
    );
    const activePaddle = state[state.activePlayerKey];
    const ballToPaddleY = activePaddle.y - state.ball.y;
    const smashImpactEta = state.ball.vy > 30
      ? ballToPaddleY / state.ball.vy
      : Number.POSITIVE_INFINITY;
    const smashImpactX = state.ball.x + state.ball.vx * Math.max(0, smashImpactEta);
    const smashImpactZ = Number.isFinite(smashImpactEta) && smashImpactEta >= 0
      ? state.ball.z
        + state.ball.vz * smashImpactEta
        - 0.5 * BALANCE.ballGravity * smashImpactEta * smashImpactEta
      : state.ball.z;
    const smashContactGeometry = smashImpactEta >= -0.04
      && smashImpactEta <= 0.2
      && Math.abs(smashImpactX - activePaddle.x) <= activePaddle.w * 0.9;
    const smashHeightReady = (smashContactGeometry ? smashImpactZ : state.ball.z)
      >= BALANCE.smashMinHeight;
    const smashPrimedActive = Boolean(state.smashPrimed || activePaddle.smashPrimed);
    const smashIntentActive = state.shotIntent === "smash" || smashPrimedActive;
    const smashStatus = !smashIntentActive
      ? ""
      : activePaddle.y > COURT.netY + BALANCE.smashNetWindow
        ? t("smashCueNet")
        : !smashHeightReady
          ? t("smashCueHigh")
          : !smashPrimedActive && state.shotCharge < smashChargeThreshold
            ? t("smashCueCharge")
            : smashContactGeometry
              ? t("smashCueSecondTap")
              : t("smashCuePrimed");
    drawActiveIndicator(
      c,
      state[state.activePlayerKey],
      Boolean(activeSprite?.complete),
      state.shotCharge,
      smashChargeThreshold,
      smashIntentActive,
      state.rallyEnergy.player,
      smashStatus,
    );
    drawTimingHud(c, state, now / 1000);
    drawShotFeedback(c, state);
    drawBall(c, state.ball, state.flash);
    drawFx(c, state);
  // La minimappa disegna sul proprio canvas nell'HUD di partita, che
  // l'allenamento non ha: chiamarla da qui scriverebbe su un elemento fuori
  // schermo per tutta la durata dell'esercizio.
  if (state.mode !== "drill") drawMiniMap(state);
}

/**
 * Il selettore di esercizio. Cambiare esercizio ricostruisce lo stato: sono
 * situazioni di partenza diverse — bersagli con avversari fermi, pallonetti da
 * chiudere, scambio pieno — e riusare lo stato precedente lascerebbe in campo
 * una palla che appartiene a un altro esercizio.
 */

/* ---- Feedback dei giocatori ------------------------------------------------
   Il modulo scrive **sempre** in coda locale prima di provare a spedire: su Steam
   si gioca anche offline, e una POST fallita perderebbe il messaggio senza che
   nessuno se ne accorga. L'invio, quando esiste un endpoint, e' un extra. */

let feedbackTopic = "bug";

function feedbackEl(id) {
  return document.getElementById(id);
}

/** Aggiorna il modulo: argomento scelto, contatore, contesto mostrato. */
function renderFeedback(nascondiManuale = false) {
  if (nascondiManuale) hideManualCopy();
  document.querySelectorAll("#feedbackTopics button").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.value === feedbackTopic);
  });
  const testo = feedbackEl("feedbackMessage");
  const contatore = feedbackEl("feedbackCount");
  if (testo && contatore) contatore.textContent = `${testo.value.length} / ${FEEDBACK.maxMessage}`;
  // Il contesto tecnico si vede prima di allegarlo: allegare dati senza mostrarli
  // non e' accettabile, e su Steam richiederebbe un'informativa a parte.
  const diag = feedbackEl("feedbackDiag");
  if (diag) diag.textContent = JSON.stringify(feedbackDiagnostics(), null, 2);
  const steam = feedbackEl("feedbackSteam");
  if (steam) steam.hidden = !FEEDBACK.steamUrl && !FEEDBACK.discordUrl;
  // Senza endpoint "Invia" sarebbe una bugia gentile: il giocatore cliccherebbe,
  // se ne andrebbe e crederebbe di aver segnalato qualcosa. L'azione principale
  // diventa quindi quella che serve davvero — salvare e copiare in un colpo — e
  // il pulsante di sola copia sparisce, perche' farebbe la stessa cosa.
  const invia = document.querySelector('#feedbackForm button[type="submit"]');
  if (invia) {
    invia.textContent = FEEDBACK.endpoint
      ? t("feedbackSend")
      : FEEDBACK.email ? t("feedbackSendMail") : t("feedbackSaveAndCopy");
  }
  // La copia resta come via alternativa quando esiste un recapito: serve a chi non
  // ha un client di posta configurato, che su un PC da gioco e' un caso normale.
  const copia = feedbackEl("feedbackCopyBtn");
  if (copia) copia.hidden = false;
  const nota = feedbackEl("feedbackNote");
  if (nota) {
    nota.textContent = FEEDBACK.endpoint
      ? ""
      : FEEDBACK.email ? t("feedbackMailNote") : t("feedbackNoServer");
  }
  const stato = feedbackEl("feedbackStatus");
  if (stato) {
    const inCoda = loadFeedbackQueue().filter((e) => !e.sent).length;
    stato.textContent = inCoda ? t("feedbackQueued", { n: inCoda }) : "";
    stato.classList.remove("feedback__status--sent");
  }
}

function feedbackStatus(key, params = {}) {
  const stato = feedbackEl("feedbackStatus");
  if (stato) {
    stato.textContent = t(key, params);
    stato.classList.toggle("feedback__status--sent", key === "feedbackSent");
  }
}

/** Raccoglie il modulo in una voce di coda, o `null` se manca il messaggio. */
function collectFeedback() {
  const testo = feedbackEl("feedbackMessage");
  const messaggio = (testo?.value ?? "").trim();
  if (!messaggio) {
    feedbackStatus("feedbackEmpty");
    testo?.focus();
    return null;
  }
  const entry = queueFeedback({
    topic: feedbackTopic,
    message: messaggio,
    contact: feedbackEl("feedbackContact")?.value ?? "",
    attach: Boolean(feedbackEl("feedbackAttach")?.checked),
  });
  if (testo) testo.value = "";
  const contatto = feedbackEl("feedbackContact");
  if (contatto) contatto.value = "";
  return entry;
}

/**
 * Copia il messaggio negli appunti. Ritorna se ci e' riuscita: senza il permesso
 * il messaggio resta comunque in coda, e si dice dov'e' invece di far finta che
 * sia andata bene.
 */
/**
 * L'ultima rete: mostra il testo e lo seleziona, perche' il giocatore lo copi a
 * mano.
 *
 * Serve perche' su itch.io il gioco gira in un iframe con sandbox, dove la
 * navigazione a `mailto:` viene bloccata **in silenzio** — nessuna eccezione,
 * nessun modo di accorgersene — e l'accesso agli appunti puo' essere negato.
 * Questa via non dipende da niente: ne' dalla rete, ne' da un client di posta, ne'
 * da un permesso. E' l'unica che non puo' fallire.
 */
function showManualCopy(entry) {
  const box = feedbackEl("feedbackManual");
  const area = feedbackEl("feedbackManualText");
  if (!box || !area) return;
  area.value = feedbackAsText(entry);
  box.hidden = false;
  // Gia' selezionato: chi arriva qui deve solo premere Ctrl+C.
  area.focus();
  area.select();
  area.scrollIntoView({ block: "nearest" });
}

function hideManualCopy() {
  const box = feedbackEl("feedbackManual");
  if (box) box.hidden = true;
}

async function copyFeedback(entry) {
  try {
    await navigator.clipboard.writeText(feedbackAsText(entry));
    return true;
  } catch {
    return false;
  }
}

/**
 * Cosa offrire quando la consegna automatica non c'e' stata.
 *
 * Si tenta la posta *e* si mostra comunque il testo da copiare, invece di scegliere
 * fra le due. Il motivo e' che l'esito del `mailto:` non e' osservabile: in un
 * iframe con sandbox la navigazione viene bloccata senza errori, quindi annunciare
 * "aperto il client di posta" sarebbe un'affermazione che non possiamo verificare
 * — e per il giocatore diventerebbe un messaggio dato per spedito e mai arrivato.
 */
async function offriRipiego(entry, motivo) {
  const mailto = feedbackMailto(entry);
  if (mailto) window.location.href = mailto;
  await copyFeedback(entry);
  showManualCopy(entry);
  return mailto ? "feedbackFallback" : (motivo ?? "feedbackManualHint");
}

function bindFeedback() {
  document.querySelectorAll("#feedbackTopics button").forEach((button) => {
    button.addEventListener("click", () => {
      const value = button.dataset.value;
      if (!FEEDBACK_TOPICS.includes(value)) return;
      feedbackTopic = value;
      renderFeedback();
    });
  });

  feedbackEl("feedbackMessage")?.addEventListener("input", () => {
    const testo = feedbackEl("feedbackMessage");
    const contatore = feedbackEl("feedbackCount");
    if (testo && contatore) contatore.textContent = `${testo.value.length} / ${FEEDBACK.maxMessage}`;
  });

  feedbackEl("feedbackForm")?.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    const entry = collectFeedback();
    if (!entry) return;
    // Salvato: da qui in poi nulla puo' andare perduto.
    feedbackStatus("feedbackSaved");
    renderFeedback();
    const esito = await flushFeedback();
    let statusKey;
    if (esito.ok && esito.sent) {
      statusKey = "feedbackSent";
    } else if (esito.reason === "offline" || esito.reason === "rejected") {
      // L'endpoint c'e' ma non ha consegnato: rete assente, funzione non ancora
      // configurata, quota esaurita. Il giocatore non deve restare a mani vuote,
      // quindi si offre la via che funziona sempre. La voce resta in coda e
      // ripartira' al prossimo avvio.
      statusKey = await offriRipiego(entry, esito.reason === "offline" ? "feedbackOffline" : null);
    } else if (esito.reason === "no-endpoint") {
      // Nessun server a cui parlare. Con un recapito configurato si apre il client
      // di posta del giocatore, che e' l'unico modo di far arrivare il messaggio
      // senza infrastruttura; senza recapito si ripiega sugli appunti. In entrambi
      // i casi la voce e' gia' salvata, quindi non si perde comunque.
      statusKey = await offriRipiego(entry, null);
    }
    // `renderFeedback` aggiorna normalmente lo stato con la coda residua.
    // La conferma conclusiva va quindi scritta dopo, altrimenti un invio riuscito
    // verrebbe nascosto subito da una stringa vuota.
    renderFeedback();
    if (statusKey) feedbackStatus(statusKey);
  });

  // `data-action` e' riservato alla tabella di navigazione: usarlo per un'azione
  // di modulo faceva sembrare il pulsante non collegato all'audit che verifica
  // che ogni azione dichiarata abbia una destinazione.
  feedbackEl("feedbackCopyBtn")?.addEventListener("click", async () => {
    const entry = collectFeedback();
    if (!entry) return;
    if (await copyFeedback(entry)) {
      feedbackStatus("feedbackCopied");
    } else {
      // Appunti negati: il testo si mostra, non si perde.
      showManualCopy(entry);
      feedbackStatus("feedbackManualHint");
    }
    renderFeedback();
  });

  feedbackEl("feedbackSteam")?.addEventListener("click", () => {
    const url = FEEDBACK.steamUrl ?? FEEDBACK.discordUrl;
    if (url) window.open(url, "_blank", "noopener");
  });
}

function bindDrillSelector() {
  document.querySelectorAll("#drillSeg button").forEach((button) => {
    button.addEventListener("click", () => {
      const id = button.dataset.value;
      if (!id || id === (drillState?.exercise?.id ?? ui.drillExercise)) return;
      ui.drillExercise = id;
      if (drillState) startDrill();
      else syncDrillChrome();
    });
  });
  // Cambiare difficolta' ricostruisce lo stato: il profilo dell'avversario entra
  // nelle racchette quando nascono, quindi non si puo' sostituire a esercizio in
  // corso — e' lo stesso motivo per cui la formazione si risolve prima del match.
  document.querySelectorAll("#drillDiffSeg button").forEach((button) => {
    button.addEventListener("click", () => {
      const value = button.dataset.value;
      if (!value || value === (ui.drillDifficulty ?? ui.aiDifficulty)) return;
      ui.drillDifficulty = value;
      if (drillState) startDrill();
      else syncDrillChrome();
    });
  });
}

function drillLoop(now, generation) {
  if (generation !== drillLoopGen) return;
  const frame = Math.min((now - drillLastTime) / 1000, 0.25);
  drillLastTime = now;
  // Stesso passo fisso della partita: la fisica e' la stessa, e a passo
  // variabile darebbe risultati diversi dal gioco a parita' di comando.
  drillAccumulator += frame;
  let input = drillInput();
  let steps = 0;
  while (drillAccumulator >= FIXED_STEP && steps < MAX_SIM_STEPS) {
    updateDrill(drillState, FIXED_STEP, input);
    drillAccumulator -= FIXED_STEP;
    steps += 1;
    // I comandi a colpo singolo valgono un passo solo, altrimenti lo stesso
    // colpo si accoda piu' volte nello stesso fotogramma.
    if (steps === 1) input = consumeOneShot(input);
  }
  if (drillState.score > drillState.best) {
    drillState.best = saveDrillRecord(drillState.exercise.id, drillState.score);
  }
  drillMetrics(drillState).forEach((metric, index) => {
    const box = document.getElementById(`drillValue${index}`);
    if (box) box.textContent = metric.value;
  });
  drawDrill(now);
  requestAnimationFrame((nextNow) => drillLoop(nextNow, generation));
}

bindNavigation({
  "to-menu": () => {
    quitMatch();
    stopDrill();
    showScreen("menu");
  },
  "to-characters": () => showScreen("characters"),
  "to-modes": () => {
    syncMatchSetup();
    showScreen("modes");
  },
  "to-help": () => showScreen("help"),
  "to-history": () => {
    showScreen("history");
    renderHistory();
  },
  "to-feedback": () => {
    showScreen("feedback");
    renderFeedback(true);
  },
  "to-challenges": () => {
    showScreen("challenges");
    renderChallenges();
  },
  "to-drill": startDrill,
  "to-profile": () => {
    showScreen("profile");
    renderProfile();
  },
  "to-settings": () => {
    showScreen("settings");
    syncAllSettings();
  },
  // La modalita' viene ora prima degli atleti. Sceglierli prima significava
  // comporre una squadra senza sapere per cosa: in carriera l'avversario e'
  // dettato dal calendario, in torneo dal tabellone.
  selectMode: () => {
    syncMatchSetup();
    showScreen("characters");
  },
  rematch,
  resume: resumeGame,
  pause: pauseGame,
  "quit-match": handleQuitMatch,
  replay: () => {
    if (pauseOverlay) pauseOverlay.hidden = true;
    toggleReplay();
  },
});

const muteBtn = document.getElementById("muteBtn");

function updateMuteButton() {
  muteBtn.textContent = isMuted() ? "🔇" : "🔊";
  muteBtn.title = isMuted() ? t("muteOn") : t("muteOff");
  muteBtn.setAttribute("aria-pressed", String(isMuted()));
}

muteBtn.addEventListener("click", () => {
  initAudio();
  setMuted(!isMuted());
  updateMuteButton();
  savePrefs(collectPrefs());
});

const prefs = loadPrefs();
if (prefs.muted) setMuted(true);
if (prefs.mode) ui.selectedMode = prefs.mode;
// L'arena era l'unica preferenza salvata e mai riletta: atleta e modalita'
// tornavano come li avevi lasciati, il campo no.
if (prefs.arenaId) {
  const salvata = ARENAS.find((a) => a.id === prefs.arenaId);
  if (salvata) ui.selectedArena = salvata;
}
if (prefs.tournamentRound) ui.tournamentRound = prefs.tournamentRound;
if (["assisted", "semi", "manual"].includes(prefs.controlMode)) ui.controlMode = prefs.controlMode;
if (Number.isFinite(prefs.gamepadDeadzone)) ui.gamepadDeadzone = Math.min(0.3, Math.max(0.08, prefs.gamepadDeadzone));
if (typeof prefs.vibration === "boolean") ui.vibration = prefs.vibration;
if (["easy", "medium", "hard", "legend"].includes(prefs.aiDifficulty)) ui.aiDifficulty = prefs.aiDifficulty;
if (MATCH_FORMAT_IDS.includes(prefs.matchLength)) ui.matchLength = prefs.matchLength;
if (Number.isFinite(prefs.volume)) setVolume(Math.min(1, Math.max(0, prefs.volume)));
if (typeof prefs.reduceMotion === "boolean") ui.reduceMotion = prefs.reduceMotion;
if (typeof prefs.colorblind === "boolean") ui.colorblind = prefs.colorblind;
if (typeof prefs.matchPanel === "boolean") ui.matchPanel = prefs.matchPanel;
if (["solo", "coop", "pvp"].includes(prefs.playerMode)) ui.playerMode = prefs.playerMode;
if (prefs.lineup && typeof prefs.lineup === "object") {
  for (const ruolo of ["playerMate", "opponent", "opponentMate"]) {
    const id = prefs.lineup[ruolo];
    // Si accetta solo un identificativo che esiste ancora: `resolveLineup`
    // scarta comunque i bloccati e i fuori demo, ma un salvataggio vecchio puo'
    // contenere un atleta rimosso dal roster.
    if (typeof id === "string" && ATHLETES.some((a) => a.id === id)) ui.lineup[ruolo] = id;
  }
}
if (["it", "en"].includes(prefs.lang)) {
  ui.lang = prefs.lang;
  setLang(prefs.lang);
}
applyAccessibility();
bindDrillSelector();
bindFeedback();
// I messaggi rimasti in coda — scritti offline, o quando la funzione non era
// ancora configurata — ripartono all'avvio. Senza questo la coda sarebbe solo un
// cassetto: si accumulerebbe e non consegnerebbe mai.
flushFeedback().then((esito) => {
  if (esito.sent) console.info(`feedback: ${esito.sent} in coda consegnati`);
});
applyLanguage();
// Allinea documento e selettore alla lingua effettiva: il markup parte in
// inglese, ma una preferenza salvata puo' averla gia' cambiata.
document.documentElement.lang = getLang();
document.getElementById("langToggle")?.replaceChildren(getLang() === "it" ? "EN" : "IT");
applyControllerLayout(gamepad.connected ? gamepad.id : "xbox");
updateMuteButton();

const controlModeButtons = [...document.querySelectorAll("[data-control-mode]")];
const deadzoneInput = document.getElementById("gamepadDeadzone");
const deadzoneValue = document.getElementById("deadzoneValue");
const vibrationInput = document.getElementById("gamepadVibration");
const langToggle = document.getElementById("langToggle");
const settingsLangSeg = document.getElementById("settingsLangSeg");
const optReduceMotion = document.getElementById("optReduceMotion");
const optColorblind = document.getElementById("optColorblind");
const masterVolume = document.getElementById("masterVolume");
const volumeValue = document.getElementById("volumeValue");
const settingsVolume = document.getElementById("settingsVolume");
const settingsVolumeValue = document.getElementById("settingsVolumeValue");
const settingsDeadzone = document.getElementById("settingsDeadzone");
const settingsDeadzoneValue = document.getElementById("settingsDeadzoneValue");
const settingsVibration = document.getElementById("settingsVibration");
const difficultySeg = document.getElementById("difficultySeg");
const lengthSeg = document.getElementById("lengthSeg");
const playerModeSeg = document.getElementById("playerModeSeg");
const playerModeSetup = document.getElementById("playerModeSetup");
const helpInputTabs = [...document.querySelectorAll("[data-help-input]")];
const helpInputPanels = [...document.querySelectorAll("[data-help-panel]")];

function setHelpInputView(view) {
  helpInputTabs.forEach((button) => {
    const active = button.dataset.helpInput === view;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-selected", String(active));
  });
  helpInputPanels.forEach((panel) => {
    const active = panel.dataset.helpPanel === view;
    panel.hidden = !active;
    panel.classList.toggle("is-active", active);
  });
}

pauseTabs.forEach((button) => {
  button.addEventListener("click", () => setPauseTab(button.dataset.pauseTab, gamepad.connected));
});

openSmashTutorialButton?.addEventListener("click", showSmashTutorial);
closeSmashTutorialButton?.addEventListener("click", () => hideSmashTutorial(true));
trySmashTutorialButton?.addEventListener("click", () => {
  hideSmashTutorial(false);
  resumeGame();
});

helpInputTabs.forEach((button) => {
  button.addEventListener("click", () => setHelpInputView(button.dataset.helpInput));
});
setHelpInputView("keyboard");
applyControllerLayout(gamepad.id);

function applyAccessibility() {
  document.body.classList.toggle("reduce-motion", ui.reduceMotion);
  document.body.classList.toggle("mode-colorblind", ui.colorblind);
  setReduceMotion(ui.reduceMotion);
  applyMatchPanel();
}

/** La fascia inferiore e' nascosta di default: il campo prende tutto lo schermo. */
function applyMatchPanel() {
  const screen = document.getElementById("screen-game");
  const button = document.getElementById("panelBtn");
  if (screen) screen.classList.toggle("immersive", !ui.matchPanel);
  if (button) button.setAttribute("aria-pressed", String(ui.matchPanel));
}

// La demo esiste per generare wishlist: un solo invito, un solo bottone.
if (IS_DEMO) {
  const cta = document.getElementById("demoCta");
  const link = document.getElementById("demoWishlist");
  if (cta) cta.hidden = false;
  if (link) link.href = DEMO_CONTENT.wishlistUrl;
}

const panelBtn = document.getElementById("panelBtn");
panelBtn?.addEventListener("click", () => {
  ui.matchPanel = !ui.matchPanel;
  applyMatchPanel();
  savePrefs(collectPrefs());
});

function setLanguage(lang) {
  ui.lang = lang;
  setLang(lang);
  document.documentElement.lang = lang;
  langToggle.textContent = getLang() === "it" ? "EN" : "IT";
  applyLanguage();
  // `syncDrillChrome` possiede i testi dinamici dell'allenamento (descrizione e
  // suggerimento dell'esercizio in corso), che `applyLanguage` non conosce.
  syncDrillChrome();
  updateMuteButton();
  updateGamepadIndicator(gamepad.connected, gamepad.id);
  applyControllerLayout(gamepad.id);
  updateCareerTag();
  renderAthletes(() => {
    savePrefs(collectPrefs());
    refreshArenas();
    showScreen("arena");
  }, ui.selectedAthlete?.id ?? prefs.athleteId);
  refreshArenas();
  syncAllSettings();
  savePrefs(collectPrefs());
}

function syncControllerSettings() {
  controlModeButtons.forEach((button) => {
    const active = button.dataset.controlMode === ui.controlMode;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  deadzoneInput.value = String(ui.gamepadDeadzone);
  deadzoneValue.textContent = `${Math.round(ui.gamepadDeadzone * 100)}%`;
  vibrationInput.checked = ui.vibration;
}

function syncAllSettings() {
  syncControllerSettings();
  settingsDeadzone.value = String(ui.gamepadDeadzone);
  settingsDeadzoneValue.textContent = `${Math.round(ui.gamepadDeadzone * 100)}%`;
  settingsVibration.checked = ui.vibration;
  masterVolume.value = String(getVolume());
  volumeValue.textContent = `${Math.round(getVolume() * 100)}%`;
  settingsVolume.value = String(getVolume());
  settingsVolumeValue.textContent = `${Math.round(getVolume() * 100)}%`;
  syncSegmented(difficultySeg, ui.aiDifficulty);
  syncSegmented(lengthSeg, ui.matchLength);
  syncSegmented(settingsLangSeg, getLang());
  optReduceMotion.checked = ui.reduceMotion;
  optColorblind.checked = ui.colorblind;
  if (playerModeSeg) syncSegmented(playerModeSeg, ui.playerMode);
}

controlModeButtons.forEach((button) => {
  button.addEventListener("click", () => {
    ui.controlMode = button.dataset.controlMode;
    if (matchState) matchState.controlMode = ui.controlMode;
    syncAllSettings();
    savePrefs(collectPrefs());
    pulseGamepad(45, 0.2, 0.3);
  });
});

deadzoneInput.addEventListener("input", () => {
  ui.gamepadDeadzone = Number(deadzoneInput.value);
  syncAllSettings();
  savePrefs(collectPrefs());
});

vibrationInput.addEventListener("change", () => {
  ui.vibration = vibrationInput.checked;
  syncAllSettings();
  savePrefs(collectPrefs());
  pulseGamepad(70, 0.34, 0.34);
});

langToggle.addEventListener("click", () => {
  setLanguage(getLang() === "it" ? "en" : "it");
});

settingsLangSeg.querySelectorAll("button").forEach((button) => {
  button.addEventListener("click", () => setLanguage(button.dataset.value));
});

optReduceMotion.addEventListener("change", () => {
  ui.reduceMotion = optReduceMotion.checked;
  applyAccessibility();
  savePrefs(collectPrefs());
});

optColorblind.addEventListener("change", () => {
  ui.colorblind = optColorblind.checked;
  applyAccessibility();
  savePrefs(collectPrefs());
});

function bindVolume(input, valueEl) {
  input.addEventListener("input", () => {
    setVolume(Number(input.value));
    syncAllSettings();
    savePrefs(collectPrefs());
  });
}

bindVolume(masterVolume, volumeValue);
bindVolume(settingsVolume, settingsVolumeValue);

settingsDeadzone.addEventListener("input", () => {
  ui.gamepadDeadzone = Number(settingsDeadzone.value);
  syncAllSettings();
  savePrefs(collectPrefs());
});

settingsVibration.addEventListener("change", () => {
  ui.vibration = settingsVibration.checked;
  syncAllSettings();
  savePrefs(collectPrefs());
  pulseGamepad(70, 0.34, 0.34);
});

difficultySeg.querySelectorAll("button").forEach((button) => {
  button.addEventListener("click", () => {
    ui.aiDifficulty = button.dataset.value;
    syncAllSettings();
    savePrefs(collectPrefs());
  });
});

lengthSeg.querySelectorAll("button").forEach((button) => {
  button.addEventListener("click", () => {
    ui.matchLength = button.dataset.value;
    syncAllSettings();
    savePrefs(collectPrefs());
  });
});

playerModeSeg?.querySelectorAll("button").forEach((button) => {
  button.addEventListener("click", () => {
    ui.playerMode = button.dataset.value;
    syncAllSettings();
    savePrefs(collectPrefs());
    pulseGamepad(40, 0.16, 0.2);
  });
});

syncAllSettings();
langToggle.textContent = getLang() === "it" ? "EN" : "IT";
updateCareerTag();

renderAthletes(() => {
  savePrefs(collectPrefs());
  refreshArenas();
  showScreen("arena");
}, prefs.athleteId);
refreshArenas();

window.addEventListener("pointerdown", initAudio, { passive: true });

document.addEventListener("pointerover", (event) => {
  if (!gamepad.connected) return;
  const root = menuContext();
  if (!root) return;
  const target = event.target.closest("button, input, .mode-card, .athlete-card, .arena-card");
  if (target && root.contains(target) && !target.disabled && !target.classList.contains("mode-card--locked")) {
    setMenuFocus(target);
  }
});

window.addEventListener("keydown", (event) => {
  // Un campo di testo fa parte del modulo, non della navigazione del menu. Senza
  // questa uscita, lo spazio della textarea attivava il bottone "Indietro" che
  // aveva il fuoco e riportava al menu principale invece di scrivere uno spazio.
  const target = event.target;
  const isTextEntry = target instanceof HTMLInputElement
    || target instanceof HTMLTextAreaElement
    || target instanceof HTMLSelectElement
    || target?.isContentEditable;
  if (isTextEntry) return;
  initAudio();
  const key = event.key.toLowerCase();
  if ([" ", "meta", "alt", "tab", "z", "arrowleft", "arrowright", "arrowup", "arrowdown"].includes(key)) {
    event.preventDefault();
  }
  if (key === "escape" && matchState?.running) {
    event.preventDefault();
    if (replayActive) {
      toggleReplay();
      return;
    }
    if (matchState.paused && smashTutorialOpen) hideSmashTutorial(false);
    else if (matchState.paused && activePauseTab !== "match") setPauseTab("match", false);
    else if (matchState.paused) resumeGame();
    else pauseGame();
    return;
  }
  if (key === "r" && matchState?.running) {
    event.preventDefault();
    if (!matchState.paused || replayActive) {
      hideSmashTutorial(false);
      if (pauseOverlay && !pauseOverlay.hidden && !replayActive) {
        pauseOverlay.hidden = true;
        matchState.paused = false;
      }
      toggleReplay();
      return;
    }
  }
  // L'allenamento e' gioco, non un menu. `menuActive` guardava solo `matchState`,
  // che durante l'allenamento non e' in corso: la condizione era quindi vera per
  // tutto l'esercizio, e il ramo qui sotto intercettava spazio e frecce con un
  // `return` prima di `keys.add(key)`. Lo spazio premeva il bottone col fuoco e
  // le frecce spostavano il fuoco del menu — al campo non arrivava un comando.
  const drillActive = Boolean(drillState?.running);
  if (drillActive && key === "escape") {
    // L'uscita deve fermare anche il ciclo, altrimenti l'esercizio continua a
    // girare invisibile dietro il menu.
    event.preventDefault();
    stopDrill();
    showScreen("menu");
    return;
  }
  const menuActive = (!matchState?.running || matchState?.paused) && !drillActive;
  if (menuActive) {
    if (key === "arrowup" || key === "arrowdown" || key === "arrowleft" || key === "arrowright") {
      event.preventDefault();
      const dir = key.replace("arrow", "");
      // Stessa regola del pad: dove il fuoco non puo' andare, si scorre.
      if (!moveMenuFocus(dir) && (dir === "up" || dir === "down")) {
        scrollMenu((dir === "down" ? 1 : -1) * 90);
      }
      return;
    }
    if (key === "enter" || key === " ") {
      event.preventDefault();
      activateMenuFocus();
      return;
    }
    if (key === "escape") {
      event.preventDefault();
      menuBack();
      return;
    }
  }
  if (key === "alt") specialQueued = true;
  if (key === "tab" || key === "z") switchQueued = true;
  keys.add(key);
});

window.addEventListener("keyup", (event) => {
  const key = event.key.toLowerCase();
  if (key === " ") {
    hitQueued = true;
    sliceQueued = false;
  }
  if (key === "meta") {
    hitQueued = true;
    sliceQueued = true;
  }
  keys.delete(key);
});

document.querySelectorAll("[data-dir]").forEach((button) => {
  const direction = button.dataset.dir;
  const map = { left: "a", right: "d", up: "w", down: "s" };
  button.addEventListener("pointerdown", () => {
    if (direction === "hit") hitQueued = true;
    else if (direction === "special") specialQueued = true;
    else if (direction === "switch") switchQueued = true;
    else keys.add(map[direction]);
  });
  button.addEventListener("pointerup", () => {
    if (map[direction]) keys.delete(map[direction]);
  });
  button.addEventListener("pointerleave", () => {
    if (map[direction]) keys.delete(map[direction]);
  });
});

eventLogToggle.addEventListener("click", () => {
  const expanded = eventLog.hidden;
  eventLog.hidden = !expanded;
  eventLogToggle.setAttribute("aria-expanded", String(expanded));
  eventLogToggle.title = expanded ? "Chiudi cronaca" : "Apri cronaca";
});

window.addEventListener("gamepadconnected", (event) => {
  gamepad.connected = true;
  gamepad.index = event.gamepad.index;
  gamepad.id = event.gamepad.id ?? "";
  applyControllerLayout(gamepad.id);
  updateGamepadIndicator(true, gamepad.id);
});

window.addEventListener("gamepaddisconnected", (event) => {
  if (gamepad.index === event.gamepad.index) {
    gamepad.connected = false;
    gamepad.index = null;
    applyControllerLayout("");
    releaseGamepadKeys();
    updateGamepadIndicator(false);
  }
});

requestAnimationFrame(gamepadLoop);

window.__padelDebug = () => matchState;
