/**
 * Ricezione del feedback dei giocatori — funzione serverless su Vercel.
 *
 * Esiste per una ragione sola: dal browser non si spedisce posta, e una
 * credenziale nel codice del client sarebbe pubblica per definizione. Qui la
 * chiave vive come variabile d'ambiente sul server e non raggiunge mai la pagina.
 *
 * Nessuna dipendenza: usa `fetch`, che il runtime Node di Vercel ha di suo. Il
 * gioco resta a zero dipendenze a runtime.
 *
 * ── Configurazione (variabili d'ambiente su Vercel) ────────────────────────
 *   FEEDBACK_TO              destinatario (es. la tua casella)
 *   RESEND_API_KEY           chiave di Resend, se si spedisce per email
 *   FEEDBACK_FROM            mittente verificato (default: onboarding@resend.dev)
 *   FEEDBACK_WEBHOOK_URL     in alternativa: un webhook Discord/Slack
 *   FEEDBACK_ALLOWED_ORIGINS origini ammesse, separate da virgola (facoltativo)
 *
 * Se non e' configurato nulla la funzione **non finge**: risponde 503 e il gioco
 * tiene il messaggio in coda. Un endpoint che risponde 200 senza consegnare e'
 * peggio di uno assente, perche' il giocatore crede di aver parlato e la coda si
 * svuota.
 */

/** Limiti: un endpoint pubblico senza tetti e' un invito. */
const MAX_BODY_BYTES = 64 * 1024;
const MAX_ENTRIES = 20;
const MAX_MESSAGE = 4000;

/**
 * Freno per indirizzo. La memoria di un'istanza serverless non e' condivisa fra
 * le istanze e viene riciclata: questo freno riduce le raffiche di un singolo
 * client, non regge un abuso distribuito. Per quello serve un archivio esterno
 * (Vercel KV) — dichiarato qui perche' credere di essere protetti e' peggio che
 * sapere di non esserlo.
 */
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 5;
const recent = new Map();

function rateLimited(key) {
  const now = Date.now();
  const hits = (recent.get(key) ?? []).filter((t) => now - t < RATE_WINDOW_MS);
  hits.push(now);
  recent.set(key, hits);
  // La mappa non deve crescere per sempre in un'istanza longeva.
  if (recent.size > 500) {
    for (const [k, v] of recent) {
      if (!v.some((t) => now - t < RATE_WINDOW_MS)) recent.delete(k);
    }
  }
  return hits.length > RATE_MAX;
}

function clientKey(req) {
  const forwarded = req.headers["x-forwarded-for"];
  const ip = Array.isArray(forwarded) ? forwarded[0] : (forwarded ?? "").split(",")[0].trim();
  return ip || req.socket?.remoteAddress || "sconosciuto";
}

/**
 * Origini ammesse. Se la variabile non c'e' si accetta tutto, perche' un gioco
 * impacchettato per Steam invia senza header `Origin` e una lista obbligatoria
 * lo taglierebbe fuori senza che nessuno capisca perche'.
 */
function originAllowed(req) {
  const allow = process.env.FEEDBACK_ALLOWED_ORIGINS;
  if (!allow) return true;
  const origin = req.headers.origin;
  if (!origin) return true;
  return allow.split(",").map((o) => o.trim()).includes(origin);
}

/** Ripulisce le voci: si accetta solo cio' che serve, con i tetti dichiarati. */
function sanitize(entries) {
  if (!Array.isArray(entries)) return [];
  return entries.slice(0, MAX_ENTRIES).map((e) => ({
    id: String(e?.id ?? "").slice(0, 40),
    ts: String(e?.ts ?? "").slice(0, 40),
    topic: String(e?.topic ?? "other").slice(0, 24),
    message: String(e?.message ?? "").slice(0, MAX_MESSAGE),
    contact: String(e?.contact ?? "").slice(0, 160),
    // Il contesto arriva come oggetto: si ritrasmette tale e quale, ma con un
    // tetto sulla dimensione perche' e' comunque testo di parte del client.
    diagnostics: e?.diagnostics ? JSON.parse(JSON.stringify(e.diagnostics)) : null,
  })).filter((e) => e.message.trim().length > 0);
}

function formatEntry(entry) {
  const righe = [
    `[${entry.topic}] ${entry.ts}`,
    "",
    entry.message,
  ];
  if (entry.contact) righe.push("", `contatto: ${entry.contact}`);
  if (entry.diagnostics) {
    righe.push("", "--- contesto tecnico ---", JSON.stringify(entry.diagnostics, null, 2));
  }
  return righe.join("\n");
}

async function sendByEmail(entries, fetchImpl) {
  const key = process.env.RESEND_API_KEY;
  const to = process.env.FEEDBACK_TO;
  if (!key || !to) return { attempted: false };
  const primo = entries[0];
  const oggetto = entries.length === 1
    ? `[padel] ${primo.topic} · ${primo.diagnostics?.version ?? "?"} · balance ${primo.diagnostics?.balance ?? "?"}`
    : `[padel] ${entries.length} messaggi`;
  const response = await fetchImpl("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: process.env.FEEDBACK_FROM || "onboarding@resend.dev",
      to: [to],
      subject: oggetto,
      text: entries.map(formatEntry).join("\n\n========================\n\n"),
      // Se il giocatore ha lasciato un contatto, rispondere e' un clic.
      ...(primo.contact?.includes("@") ? { reply_to: primo.contact } : {}),
    }),
  });
  return { attempted: true, ok: Boolean(response?.ok), status: response?.status ?? 0 };
}

async function sendByWebhook(entries, fetchImpl) {
  const url = process.env.FEEDBACK_WEBHOOK_URL;
  if (!url) return { attempted: false };
  const response = await fetchImpl(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    // `content` e' il campo che si aspettano Discord e Slack: un solo formato che
    // funziona su entrambi, senza codice specifico per fornitore.
    body: JSON.stringify({ content: entries.map(formatEntry).join("\n\n---\n\n").slice(0, 1900) }),
  });
  return { attempted: true, ok: Boolean(response?.ok), status: response?.status ?? 0 };
}

/**
 * `fetchImpl` e `env` sono iniettabili perche' altrimenti questo file si potrebbe
 * provare solo dopo il deploy, cioe' quando sbagliare costa. E' lo stesso motivo
 * per cui `flushFeedback` accetta l'endpoint come parametro.
 */
export async function handleFeedback(req, res, fetchImpl = globalThis.fetch) {
  if (req.method === "OPTIONS") {
    res.setHeader("Access-Control-Allow-Origin", req.headers.origin ?? "*");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    return res.status(204).end();
  }
  res.setHeader("Access-Control-Allow-Origin", req.headers.origin ?? "*");

  if (req.method !== "POST") return res.status(405).json({ error: "method-not-allowed" });
  if (!originAllowed(req)) return res.status(403).json({ error: "origin-not-allowed" });
  if (rateLimited(clientKey(req))) return res.status(429).json({ error: "too-many-requests" });

  let body = req.body;
  if (typeof body === "string") {
    if (body.length > MAX_BODY_BYTES) return res.status(413).json({ error: "payload-too-large" });
    try {
      body = JSON.parse(body);
    } catch {
      return res.status(400).json({ error: "invalid-json" });
    }
  }
  const entries = sanitize(body?.entries);
  if (!entries.length) return res.status(400).json({ error: "no-entries" });

  if (!fetchImpl) return res.status(503).json({ error: "no-transport" });

  try {
    // L'email e' il recapito richiesto; il webhook e' l'alternativa quando non si
    // vuole configurare un servizio di posta.
    let esito = await sendByEmail(entries, fetchImpl);
    if (!esito.attempted) esito = await sendByWebhook(entries, fetchImpl);
    if (!esito.attempted) {
      // Niente configurato: non si risponde 200, altrimenti il gioco svuoterebbe
      // la coda e il messaggio sparirebbe senza essere consegnato a nessuno.
      return res.status(503).json({ error: "not-configured" });
    }
    if (!esito.ok) return res.status(502).json({ error: "delivery-failed" });
    return res.status(200).json({ ok: true, received: entries.length });
  } catch {
    // Nessun dettaglio all'esterno: i messaggi d'errore di un fornitore possono
    // contenere frammenti della richiesta, chiave inclusa.
    return res.status(502).json({ error: "delivery-error" });
  }
}

export default function handler(req, res) {
  return handleFeedback(req, res);
}
