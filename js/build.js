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
    return globalThis.__PADEL_BUILD;
  }
  if (typeof location === "undefined") return "full";
  try {
    const forced = new URLSearchParams(location.search).get("build");
    if (forced === "demo" || forced === "beta" || forced === "full") return forced;
  } catch {
    // location.search non disponibile: si prosegue col dominio
  }
  const host = location.hostname ?? "";
  if (host.startsWith("demo.") || host.includes("-demo")) return "demo";
  return "full";
}

/** Quale build sta girando: `full`, `demo` o `beta`. */
export const BUILD = resolveBuild();

/**
 * `IS_DEMO` significa "build limitata", non "build demo": e' il nome storico e lo
 * leggono gia' cinque punti del codice, quindi resta. Vale per demo e beta.
 */
export const IS_DEMO = BUILD !== "full";

/**
 * Cosa contiene la demo. Il principio: si taglia la progressione, non il gioco.
 * I due atleti sono gli estremi opposti — controllo contro potenza — cosi' chi
 * prova capisce subito che gli atleti giocano davvero diversi. Il repertorio di
 * colpi resta intero: e' il motivo per cui il gioco e' interessante.
 */
const BUILD_CONTENT = {
  /**
   * Demo: si taglia la progressione, non il gioco. I due atleti sono gli estremi
   * opposti — controllo contro potenza — cosi' chi prova capisce subito che gli
   * atleti giocano davvero diversi. Il repertorio di colpi resta intero.
   */
  demo: {
    athletes: ["maestro", "steamer"],
    arenas: ["clockwork"],
    modes: ["quick"],
    // Una difficolta' sola: il facile fa sembrare il gioco banale, il difficile
    // respinge chi ha in mano il controller da tre minuti.
    difficulty: "medium",
    outfitChallenges: true,
  },
  /**
   * Beta: come la demo, ma con **tutte le difficolta'** e tre arene.
   *
   * Esiste per una ragione precisa: serve feedback sulla difesa dello smash e
   * sulle scelte dell'IA ai livelli alti, e con la difficolta' bloccata su Medio
   * non arriverebbe una parola su Difficile e Leggenda.
   *
   * Le tre arene coprono l'intervallo del vetro (0.86 / 0.89 / 0.92): l'uscita
   * dello x3 dipende da `wallBounce`, quindi con una sola arena il feedback sullo
   * smash direbbe una cosa sola e la si prenderebbe per generale.
   *
   * Restano fuori Carriera e Torneo — i sistemi che valgono la versione completa.
   */
  beta: {
    athletes: ["maestro", "steamer"],
    arenas: ["clockwork", "officina", "locomotive"],
    modes: ["quick"],
    // `null` = nessun blocco: tutte e quattro le difficolta' sono giocabili.
    difficulty: null,
    outfitChallenges: true,
  },
};

/**
 * Cosa concede la build in corso. Il nome resta `DEMO_CONTENT` perche' lo leggono
 * gia' `demoFilter`, `demoLocked` e `applyDemoLimits`.
 */
export const DEMO_CONTENT = BUILD_CONTENT[BUILD] ?? BUILD_CONTENT.demo;

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
