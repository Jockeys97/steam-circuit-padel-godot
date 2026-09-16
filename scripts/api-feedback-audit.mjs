import assert from "node:assert/strict";

import { handleFeedback } from "../api/feedback.js";

/**
 * Audit della funzione serverless che riceve il feedback.
 *
 * Un endpoint pubblico si prova prima di pubblicarlo, non dopo: dopo, sbagliare
 * significa raccogliere spam, perdere messaggi o — il caso peggiore — rispondere
 * 200 senza consegnare, che fa svuotare la coda del gioco e cancella per sempre
 * cio' che il giocatore aveva scritto.
 *
 * Qui l'handler viene chiamato con `req`/`res` finti e un `fetch` finto, quindi
 * si verificano le guardie e i percorsi di consegna senza toccare la rete e senza
 * bisogno di alcuna chiave.
 */

/** `res` finto: registra codice e corpo invece di scriverli su un socket. */
function makeRes() {
  const res = {
    statusCode: null,
    body: null,
    headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
    end() { return this; },
  };
  return res;
}

const makeReq = (over = {}) => ({
  method: "POST",
  headers: { "x-forwarded-for": `10.0.0.${Math.floor(Math.random() * 200) + 1}` },
  socket: { remoteAddress: "10.0.0.1" },
  body: { entries: [{ id: "fb-1", ts: "2026-01-01T00:00:00Z", topic: "bug", message: "la palla passa il vetro" }] },
  ...over,
});

/** Ambiente pulito fra le prove: le variabili sono lo stato di questa funzione. */
function resetEnv() {
  for (const k of ["RESEND_API_KEY", "FEEDBACK_TO", "FEEDBACK_FROM",
    "FEEDBACK_WEBHOOK_URL", "FEEDBACK_ALLOWED_ORIGINS"]) delete process.env[k];
}

const report = {};

// ── 1. Senza configurazione non deve MAI rispondere 200 ────────────────────
{
  resetEnv();
  const res = makeRes();
  await handleFeedback(makeReq(), res, async () => ({ ok: true }));
  assert.equal(
    res.statusCode,
    503,
    "Senza trasporto configurato deve rifiutare: un 200 senza consegna farebbe "
    + "svuotare la coda del gioco e il messaggio sparirebbe",
  );
  assert.equal(res.body.error, "not-configured");
  report.senzaConfigurazione = res.statusCode;
}

// ── 2. Solo POST ───────────────────────────────────────────────────────────
for (const method of ["GET", "PUT", "DELETE"]) {
  const res = makeRes();
  await handleFeedback(makeReq({ method }), res, async () => ({ ok: true }));
  assert.equal(res.statusCode, 405, `${method} non deve essere accettato`);
}
{
  // Il preflight serve al gioco impacchettato, che invia da un'altra origine.
  const res = makeRes();
  await handleFeedback(makeReq({ method: "OPTIONS" }), res, async () => ({ ok: true }));
  assert.equal(res.statusCode, 204, "Il preflight deve passare");
  assert(res.headers["Access-Control-Allow-Methods"], "Il preflight deve dichiarare i metodi");
}

// ── 3. Corpo non valido o vuoto ────────────────────────────────────────────
{
  const casi = [
    [{ body: "non-json" }, 400, "invalid-json"],
    [{ body: { entries: [] } }, 400, "no-entries"],
    [{ body: { entries: [{ message: "   " }] } }, 400, "no-entries"],
    [{ body: "x".repeat(70 * 1024) }, 413, "payload-too-large"],
  ];
  for (const [over, atteso, errore] of casi) {
    resetEnv();
    process.env.FEEDBACK_WEBHOOK_URL = "https://esempio.invalido/hook";
    const res = makeRes();
    await handleFeedback(makeReq(over), res, async () => ({ ok: true }));
    assert.equal(res.statusCode, atteso, `Atteso ${atteso} per ${errore}, ricevuto ${res.statusCode}`);
    assert.equal(res.body.error, errore);
  }
}

// ── 4. Consegna per email: la chiave non deve uscire dalla funzione ────────
{
  resetEnv();
  process.env.RESEND_API_KEY = "chiave-segretissima";
  process.env.FEEDBACK_TO = "destinatario@esempio.it";
  const richieste = [];
  const res = makeRes();
  await handleFeedback(makeReq(), res, async (url, opzioni) => {
    richieste.push({ url, opzioni });
    return { ok: true, status: 200 };
  });
  assert.equal(res.statusCode, 200, "Con la posta configurata deve consegnare");
  assert.equal(res.body.received, 1, "Deve dichiarare quante voci ha ricevuto");
  assert.equal(richieste.length, 1, "Una sola chiamata al fornitore");
  assert(richieste[0].url.includes("resend.com"), "Deve parlare col servizio di posta");
  assert(
    richieste[0].opzioni.headers.Authorization.includes("chiave-segretissima"),
    "La chiave va nell'header verso il fornitore",
  );
  // E non deve tornare al chiamante in nessuna forma.
  const risposta = JSON.stringify({ body: res.body, headers: res.headers });
  assert(
    !risposta.includes("chiave-segretissima"),
    "La chiave non deve comparire nella risposta al client",
  );
  report.email = res.statusCode;
}

// ── 5. Il contatto del giocatore diventa un reply-to ──────────────────────
{
  resetEnv();
  process.env.RESEND_API_KEY = "k";
  process.env.FEEDBACK_TO = "a@b.it";
  let inviato = null;
  const res = makeRes();
  await handleFeedback(makeReq({
    body: { entries: [{ topic: "idea", message: "aggiungete il doppio misto", contact: "tizio@esempio.it" }] },
  }), res, async (url, opzioni) => { inviato = JSON.parse(opzioni.body); return { ok: true }; });
  assert.equal(res.statusCode, 200);
  assert.equal(inviato.reply_to, "tizio@esempio.it", "Con un contatto valido rispondere deve essere un clic");
}

// ── 6. Il webhook e' l'alternativa quando la posta non c'e' ───────────────
{
  resetEnv();
  process.env.FEEDBACK_WEBHOOK_URL = "https://discord.example/webhook";
  let corpo = null;
  const res = makeRes();
  await handleFeedback(makeReq(), res, async (url, opzioni) => { corpo = JSON.parse(opzioni.body); return { ok: true }; });
  assert.equal(res.statusCode, 200, "Il webhook deve bastare da solo");
  assert(corpo.content.includes("la palla passa il vetro"), "Il messaggio deve arrivare nel webhook");
  assert(corpo.content.length <= 1900, "Il corpo va troncato al limite di Discord");
}

// ── 7. Un fallimento del fornitore non deve diventare un successo ─────────
{
  resetEnv();
  process.env.FEEDBACK_WEBHOOK_URL = "https://esempio.invalido/hook";
  for (const [finto, atteso] of [
    [async () => ({ ok: false, status: 500 }), 502],
    [async () => { throw new Error("rete"); }, 502],
  ]) {
    const res = makeRes();
    await handleFeedback(makeReq(), res, finto);
    assert.equal(res.statusCode, atteso, "Un fallimento di consegna deve restare un fallimento");
  }
}

// ── 8. Il freno per indirizzo morde ──────────────────────────────────────
{
  resetEnv();
  process.env.FEEDBACK_WEBHOOK_URL = "https://esempio.invalido/hook";
  const ip = "203.0.113.7";
  const esiti = [];
  for (let i = 0; i < 8; i += 1) {
    const res = makeRes();
    await handleFeedback(
      makeReq({ headers: { "x-forwarded-for": ip } }),
      res,
      async () => ({ ok: true }),
    );
    esiti.push(res.statusCode);
  }
  assert(esiti.includes(429), `Il freno non ha morso in 8 richieste: ${esiti.join(",")}`);
  assert.equal(esiti[0], 200, "La prima richiesta deve passare");
  report.freno = esiti.join(",");
}

// ── 9. I tetti sulle voci e sui messaggi ─────────────────────────────────
{
  resetEnv();
  process.env.FEEDBACK_WEBHOOK_URL = "https://esempio.invalido/hook";
  let corpo = null;
  const molte = Array.from({ length: 60 }, (_, i) => ({ topic: "other", message: `msg ${i}` }));
  const res = makeRes();
  await handleFeedback(
    makeReq({ headers: { "x-forwarded-for": "198.51.100.9" }, body: { entries: molte } }),
    res,
    async (url, opzioni) => { corpo = JSON.parse(opzioni.body); return { ok: true }; },
  );
  assert.equal(res.statusCode, 200);
  assert(!corpo.content.includes("msg 59"), "Le voci oltre il tetto non devono passare");
}

// ── 10. L'allowlist di origini, quando c'e', vale ────────────────────────
{
  resetEnv();
  process.env.FEEDBACK_WEBHOOK_URL = "https://esempio.invalido/hook";
  process.env.FEEDBACK_ALLOWED_ORIGINS = "https://gioco.esempio.it";
  const negato = makeRes();
  await handleFeedback(
    makeReq({ headers: { "x-forwarded-for": "198.51.100.20", origin: "https://cattivo.esempio" } }),
    negato,
    async () => ({ ok: true }),
  );
  assert.equal(negato.statusCode, 403, "Un'origine fuori lista va rifiutata");

  // Senza header `Origin` — il caso del gioco impacchettato per Steam — si passa,
  // altrimenti la lista taglierebbe fuori proprio i giocatori Steam.
  const senzaOrigine = makeRes();
  await handleFeedback(
    makeReq({ headers: { "x-forwarded-for": "198.51.100.21" } }),
    senzaOrigine,
    async () => ({ ok: true }),
  );
  assert.equal(senzaOrigine.statusCode, 200, "Una richiesta senza origine non va bloccata");
}

resetEnv();
console.log(JSON.stringify(report, null, 2));
console.log("\napi-feedback-audit: le guardie tengono e la chiave non esce dalla funzione");
