/**
 * Quale build sta girando: gioco completo o demo.
 *
 * Il repository resta uno solo. La distinzione arriva dal contesto, con questa
 * priorita':
 *
 *   1. `window.__PADEL_BUILD` — impostato dal contenitore desktop. Su Steam la
 *      demo e' obbligatoriamente un'applicazione separata, quindi i due
 *      pacchetti sono gia' distinti e non stiamo aggiungendo complessita'.
 *   2. `?build=demo` nell'URL — serve a provare la demo senza pubblicare nulla.
 *   3. Il dominio — `demo.` o un host che contiene `-demo` e' la demo.
 *   4. In mancanza di tutto: gioco completo.
 *
 * Il default e' il prodotto e non la demo: se il rilevamento fallisse, il caso
 * peggiore e' che qualcuno veda il gioco intero, non che un cliente pagante si
 * ritrovi una versione mutilata.
 */

function resolveBuild() {
  if (typeof globalThis !== "undefined" && typeof globalThis.__PADEL_BUILD === "string") {
    return globalThis.__PADEL_BUILD === "demo";
  }
  if (typeof location === "undefined") return false;
  try {
    const forced = new URLSearchParams(location.search).get("build");
    if (forced === "demo") return true;
    if (forced === "full") return false;
  } catch {
    // location.search non disponibile: si prosegue col dominio
  }
  const host = location.hostname ?? "";
  return host.startsWith("demo.") || host.includes("-demo");
}

export const IS_DEMO = resolveBuild();

/**
 * Cosa contiene la demo. Il principio: si taglia la progressione, non il gioco.
 * I due atleti sono gli estremi opposti — controllo contro potenza — cosi' chi
 * prova capisce subito che gli atleti giocano davvero diversi. Il repertorio di
 * colpi resta intero: e' il motivo per cui il gioco e' interessante.
 */
export const DEMO_CONTENT = {
  athletes: ["maestro", "steamer"],
  arenas: ["clockwork"],
  modes: ["quick"],
  difficulty: "medium",
  // Le sfide dei completi valgono in partita rapida, quindi funzionano anche
  // qui: otto completi da vincere per i due atleti concessi. Non era stato
  // progettato — e' una conseguenza dell'aver legato i completi a una prova sul
  // campo invece che alla progressione — ma e' cio' che da' alla demo qualcosa
  // da inseguire, quindi va dichiarato invece di restare un incidente.
  outfitChallenges: true,
  wishlistUrl: "https://store.steampowered.com/",
};

/** Filtra una lista di atleti o arene lasciando solo cio' che la demo espone. */
export function demoFilter(items, allowed) {
  if (!IS_DEMO) return items;
  return items.filter((item) => allowed.includes(item.id));
}

/**
 * Se un contenuto esiste ma la demo non lo concede.
 *
 * Serve a mostrarlo bloccato invece di farlo sparire, che e' la regola gia'
 * scritta per le modalita' — "vedere cosa manca vende piu' che nasconderlo" — e
 * che atleti e arene non seguivano. Il risultato era una demo che si
 * contraddiceva: la schermata Obiettivi elencava nove arene e sei atleti, la
 * partita ne schierava in campo di non giocabili, e la griglia di selezione ne
 * mostrava una e due.
 */
export function demoLocked(item, allowed) {
  return IS_DEMO && !allowed.includes(item?.id);
}
