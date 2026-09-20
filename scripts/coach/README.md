# `scripts/coach/` — the Jev coach's local bridge

The Godot game never talks to TypeSafe. The result screen's coach block posts one bounded
body to a bridge **you start yourself on this machine**, and the bridge — which owns the
API key in its own environment — makes the one upstream call:

```
Godot  ──POST http://127.0.0.1:8787/coach/jev──▶  jev_bridge.mjs  ──▶  https://api.typesafe.ai/v1/systemone
       (version, measured counters, candidates)     (owns the key)        (model jev-latest, one Choice)
```

Both sides read `godot/src/coach/coach_contract.json` for the counter allowlist, the
category ids, the criteria text, the model and the endpoint, so there is no second copy of
the question to drift.

## Start it

```bash
export TYPESAFE_API_KEY="$(cat ~/.hermes/secrets/typesafe.apikey)"
node scripts/coach/jev_bridge.mjs                 # 127.0.0.1:8787
COACH_PORT=9000 node scripts/coach/jev_bridge.mjs # another port (the game reads COACH_PORT too)
```

Without the key the bridge refuses to start (exit 2) and names the variable. It never
prints, logs or writes the value. It binds `127.0.0.1` only.

## Test it (no key, no charge)

```bash
node scripts/coach/jev_bridge_test.mjs
node scripts/coach/jev_bridge_integration_test.mjs   # real Godot client -> real bridge -> fake upstream
```

Every upstream in that run is a loopback server the test starts itself; nothing reaches
TypeSafe, and no key is needed. It covers the wire's bounds, the browser-Origin and Host
refusals, the fixed endpoint, the refused redirect, the single bounded timeout with no
retry, malformed and oversized upstream answers, the bounded client body, and that no log
line carries a secret or a payload.

The integration test is the one seam the unit tests cannot cover: it runs the engine's own
`HTTPRequest` through the real `CoachClient` against the real `createBridge` (with a fake
upstream), in three scenarios — fail/retry/advice, the whole visible path including the
route into the drill screen, and a bridge whose upstream is unreachable. It needs the Godot
binary (`$GODOT` or `/Applications/Godot.app/Contents/MacOS/Godot`) and still no key.

## The boundary, in short

- loopback bind; `POST` on `/coach/jev` only; JSON only; body under
  `wire.maxRequestBytes` (413 over it)
- any `Origin` / `Sec-Fetch-*` header is 403 (a page cannot call it), and `Host` must be
  loopback on the bridge's own port; no CORS header is ever sent
- every counter is validated against the allowlist: an unexpected field, a missing
  counter, a negative, a fraction, a non-finite or over-bound value is 400 and nothing
  leaves the machine
- upstream: fixed https endpoint, `redirect: "manual"` (a 3xx is a refusal), no automatic
  retry, one bounded timeout, a bounded response size, and a 200 whose answer fails its own
  contract is refused
- the client gets `{status, type, choice, confidence, probabilities}` or a status code —
  never upstream text, never a token
- one log line per request, and it carries the CANONICAL route and a known verb only: a
  query string, another route's path and an unexpected verb are marked (`(other-route)`,
  `(other-method)`), never quoted. No payloads, no secrets

## This is a development integration

It is not a deployed service and it is not authenticated: anything running as you on this
machine can call it, and it exists so the coach can be built and tested locally. A public
distribution needs an authenticated backend (per-account keys, rate limiting, abuse
controls) — the game's side of the contract (a bounded snapshot in, a bounded Choice out)
is what such a backend would keep.
