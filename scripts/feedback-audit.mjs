import assert from "node:assert/strict";

/**
 * Audit del feedback dei giocatori.
 *
 * La promessa da difendere e' una sola: **un messaggio scritto non si perde**.
 * Vale offline, vale senza endpoint configurato, vale se gli appunti sono negati
 * e vale se il salvataggio va in errore. Un modulo di feedback che perde in
 * silenzio e' peggio di nessun modulo, perche' il giocatore crede di aver parlato.
 *
 * L'altra promessa e' che nulla venga allegato a sua insaputa: il contesto
 * tecnico e' rifiutabile, e quando lo rifiuta non deve restare traccia.
 */

const V = "?v=20260910-sprite-gate-v41";
const B = new URL("../js/", import.meta.url).href;

/** localStorage finto, con la possibilita' di simularne il guasto. */
function makeStorage({ broken = false } = {}) {
  const store = {};
  return {
    store,
    getItem: (k) => store[k] ?? null,
    setItem: (k, v) => {
      if (broken) throw new Error("quota");
      store[k] = v;
    },
  };
}

function stubDom() {
  const el = () => ({
    textContent: "", innerHTML: "", value: "", placeholder: "", hidden: false,
    dataset: {}, style: {}, checked: false,
    classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
    addEventListener() {}, appendChild() {}, setAttribute() {},
    querySelector: () => null, querySelectorAll: () => [], focus() {},
  });
  globalThis.document = {
    getElementById: el, querySelector: el, querySelectorAll: () => [],
    createElement: el, body: el(), documentElement: el(),
  };
  globalThis.window = { addEventListener() {}, innerWidth: 1280, innerHeight: 720,
    matchMedia: () => ({ matches: false, addEventListener() {} }) };
  if (!("navigator" in globalThis) || !globalThis.navigator) {
    Object.defineProperty(globalThis, "navigator", { value: { language: "it", platform: "test" }, configurable: true });
  }
}

stubDom();
globalThis.localStorage = makeStorage();
const ui = await import(B + "ui.js" + V);
const { FEEDBACK, FEEDBACK_TOPICS, VERSION } = await import(B + "data.js" + V);
const i18n = await import(B + "i18n.js" + V);

const report = {};

// ── 1. La versione dichiara la taratura ────────────────────────────────────
assert(VERSION.build, "La build deve avere un nome");
assert(
  VERSION.balance,
  "Manca il riferimento della taratura: senza, un reclamo di bilanciamento non si "
  + "puo' piu' associare al gioco a cui si riferiva",
);

// ── 2. Un messaggio non si perde: senza endpoint resta in coda ────────────
{
  assert(FEEDBACK.endpoint, "L'endpoint della funzione serverless deve essere configurato");
  const entry = ui.queueFeedback({ topic: "balance", message: "lo smash x2 e' troppo forte" });
  assert(entry.id, "La voce deve avere un identificativo");
  assert.equal(entry.sent, false, "Appena accodata non e' inviata");
  const coda = ui.loadFeedbackQueue();
  assert.equal(coda.length, 1, "Il messaggio deve stare in coda");
  // `null` esplicito: il ramo "nessun endpoint" resta un percorso vivo — vale per
  // chi impacchetta il gioco senza configurare l'URL assoluto — e va provato
  // anche adesso che la funzione esiste.
  const esito = await ui.flushFeedback(async () => ({ ok: true }), null);
  assert.equal(esito.ok, false, "Senza endpoint l'invio non puo' riuscire");
  assert.equal(esito.reason, "no-endpoint", "E deve dirlo, invece di fingere");
  assert.equal(
    ui.loadFeedbackQueue()[0].sent,
    false,
    "Un invio impossibile non deve marcare la voce come inviata",
  );
  report.senzaEndpoint = esito;
}

// ── 3. Offline: la coda resta intatta ─────────────────────────────────────
// Endpoint finto passato di proposito: e' l'unico modo di eseguire davvero questi
// rami finche' quello vero non esiste.
const FINTO = "https://esempio.invalido/feedback";
{
  const esito = await ui.flushFeedback(() => { throw new Error("rete assente"); }, FINTO);
  assert.equal(esito.ok, false, "Con la rete assente l'invio fallisce");
  assert.equal(esito.reason, "offline", "E deve distinguere la rete assente da un endpoint mancante");
  assert(
    ui.loadFeedbackQueue().every((e) => !e.sent),
    "Dopo un fallimento di rete nulla deve risultare inviato",
  );
  report.offline = esito;
}

// ── 4. Un rifiuto del server non consuma la coda ──────────────────────────
{
  const esito = await ui.flushFeedback(async () => ({ ok: false, status: 500 }), FINTO);
  assert.equal(esito.reason, "rejected", "Un rifiuto va distinto da un errore di rete");
  assert(ui.loadFeedbackQueue().every((e) => !e.sent), "Un rifiuto non deve consumare la coda");
}

// ── 4b. E quando l'invio riesce, la coda si svuota una volta sola ─────────
{
  const inviati = [];
  const esito = await ui.flushFeedback(async (url, opzioni) => {
    inviati.push(JSON.parse(opzioni.body).entries.length);
    return { ok: true };
  }, FINTO);
  assert.equal(esito.ok, true, "Con il server che accetta, l'invio deve riuscire");
  assert(esito.sent > 0, "Deve dichiarare quante voci ha spedito");
  assert(
    ui.loadFeedbackQueue().every((e) => e.sent),
    "Dopo un invio riuscito le voci vanno marcate, non cancellate",
  );
  // Secondo giro: niente da rispedire, e nessuna nuova richiesta.
  const secondo = await ui.flushFeedback(async () => { inviati.push("di nuovo"); return { ok: true }; }, FINTO);
  assert.equal(secondo.sent, 0, "Le voci gia' inviate non devono ripartire");
  assert.equal(inviati.length, 1, "Un secondo invio non deve nemmeno toccare la rete");
  report.invioRiuscito = esito;
}

// ── 5. Il contesto tecnico e' rifiutabile e non lascia tracce ─────────────
{
  const conContesto = ui.queueFeedback({ topic: "bug", message: "con contesto", attach: true });
  const senzaContesto = ui.queueFeedback({ topic: "bug", message: "senza contesto", attach: false });
  assert(conContesto.diagnostics, "Con l'allegato attivo il contesto ci deve essere");
  assert.equal(
    senzaContesto.diagnostics,
    null,
    "Rifiutando l'allegato non deve restare nessun dato tecnico",
  );
  // E il testo da incollare non deve reintrodurlo di straforo.
  const testo = ui.feedbackAsText(senzaContesto);
  assert(!testo.includes("contesto tecnico"), "Il testo copiato non deve allegare cio' che e' stato rifiutato");
  assert(testo.includes(VERSION.balance), "La taratura resta: serve per smistare, e non identifica nessuno");
}

// ── 6. Il contesto contiene cio' che rende utilizzabile un reclamo ────────
{
  const d = ui.feedbackDiagnostics();
  for (const campo of ["version", "balance", "lang", "settings", "career", "drillRecords", "recentMatches"]) {
    assert(campo in d, `Il contesto tecnico non porta "${campo}"`);
  }
  // Nessun campo deve contenere qualcosa che il giocatore non ha scritto e che lo
  // identifichi: qui si controlla che non finisca dentro l'intero archivio.
  const serializzato = JSON.stringify(d);
  assert(serializzato.length < 8000, `Contesto troppo grande (${serializzato.length}B): e' un allegato, non un backup`);
  assert(d.recentMatches.length <= 3, "Le partite allegate devono restare poche");
  report.contesto = { campi: Object.keys(d).length, byte: serializzato.length };
}

// ── 7. Il messaggio viene troncato, non rifiutato ─────────────────────────
{
  const lungo = "x".repeat(FEEDBACK.maxMessage + 500);
  const entry = ui.queueFeedback({ topic: "idea", message: lungo });
  assert.equal(entry.message.length, FEEDBACK.maxMessage, "Il messaggio va troncato al limite dichiarato");
}

// ── 8. Un argomento sconosciuto non fa saltare nulla ─────────────────────
{
  const entry = ui.queueFeedback({ topic: "inventato", message: "boh" });
  assert(FEEDBACK_TOPICS.includes(entry.topic), `Argomento fuori elenco salvato come "${entry.topic}"`);
}

// ── 9. La coda non cresce senza limite ───────────────────────────────────
{
  for (let i = 0; i < FEEDBACK.maxQueued + 15; i += 1) {
    ui.queueFeedback({ topic: "other", message: `riempimento ${i}` });
  }
  const coda = ui.loadFeedbackQueue();
  assert(
    coda.length <= FEEDBACK.maxQueued,
    `La coda e' cresciuta a ${coda.length}: e' una casella di posta in uscita, non un archivio`,
  );
  report.tetto = coda.length;
}

// ── 10. Se la persistenza e' negata, il modulo non deve esplodere ────────
{
  globalThis.localStorage = makeStorage({ broken: true });
  const ui2 = await import(B + "ui.js?v=persistenza-negata");
  const entry = ui2.queueFeedback({ topic: "bug", message: "con archivio guasto" });
  assert(entry.message, "Con la scrittura negata la voce va comunque restituita a chi chiama");
  assert.deepEqual(ui2.loadFeedbackQueue(), [], "E la lettura non deve inventare contenuti");
  // Ripristino obbligatorio: lasciare l'archivio guasto avvelenerebbe ogni prova
  // successiva, che fallirebbe per un difetto del banco e non del codice. E'
  // esattamente il caso in cui il primo sospettato deve essere lo strumento.
  globalThis.localStorage = makeStorage();
}

// ── 11. Ogni etichetta esiste in entrambe le lingue ──────────────────────
{
  const chiavi = [
    "feedback", "feedbackTitle", "feedbackSub", "feedbackTopic", "feedbackMessage",
    "feedbackPlaceholder", "feedbackContact", "feedbackContactHint", "feedbackAttach",
    "feedbackWhatIsAttached", "feedbackSend", "feedbackCopy", "feedbackSteam",
    "feedbackEmpty", "feedbackSaved", "feedbackSent", "feedbackOffline",
    "feedbackLocalOnly", "feedbackCopied", "feedbackCopyFailed", "feedbackQueued",
    "feedbackSaveAndCopy", "feedbackNoServer", "feedbackSendMail", "feedbackMailOpened", "feedbackMailNote",
    ...FEEDBACK_TOPICS.map((x) => `fbTopic${x[0].toUpperCase()}${x.slice(1)}`),
  ];
  for (const lang of ["it", "en"]) {
    i18n.setLang(lang);
    const mancanti = chiavi.filter((k) => i18n.t(k) === k);
    assert.deepEqual(mancanti, [], `[${lang}] etichette senza traduzione: ${mancanti.join(", ")}`);
  }
  report.etichette = chiavi.length;
}


// ── 12. Il recapito per posta e' l'unico modo senza server: deve funzionare ──
{
  globalThis.localStorage = makeStorage();
  const entry = ui.queueFeedback({ topic: "bug", message: "la palla attraversa il vetro" });
  const link = ui.feedbackMailto(entry);
  assert(link?.startsWith("mailto:"), "Con un indirizzo configurato deve uscire un mailto");
  assert(link.includes(encodeURIComponent(VERSION.balance)), "L'oggetto deve portare la taratura");
  assert(
    link.includes(encodeURIComponent("la palla attraversa il vetro")),
    "Il corpo deve contenere il messaggio del giocatore",
  );
  // Il corpo va troncato: `mailto:` passa dalla barra degli indirizzi e i client
  // tagliano i testi lunghi. Meglio un troncamento deciso qui che uno silenzioso.
  const lungo = ui.queueFeedback({ topic: "other", message: "y".repeat(FEEDBACK.maxMessage) });
  const corpo = decodeURIComponent(ui.feedbackMailto(lungo).split("&body=")[1]);
  assert(
    corpo.length <= FEEDBACK.maxMailBody,
    `Corpo del mailto oltre il limite: ${corpo.length} > ${FEEDBACK.maxMailBody}`,
  );
  // Senza indirizzo non deve inventare un link rotto.
  assert.equal(ui.feedbackMailto(entry, null), null, "Senza indirizzo non ci deve essere alcun mailto");
  // E il messaggio resta comunque in coda: la posta e' un'aggiunta, non la sola via.
  assert(
    ui.loadFeedbackQueue().some((e) => e.id === entry.id),
    "Aprire la posta non sostituisce il salvataggio locale",
  );
  report.mailto = { schema: link.slice(0, 7), corpoMax: FEEDBACK.maxMailBody };
}

console.log(JSON.stringify(report, null, 2));
console.log("\nfeedback-audit: nessun messaggio si perde e nulla si allega di nascosto");
