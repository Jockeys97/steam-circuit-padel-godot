#!/usr/bin/env python3
"""
Genera gli atleti 3D di Steam Circuit Padel Pro con l'API Meshy.

Ricetta allineata all'avatar di riferimento (LO STEAMER, "Titan Dash"): modello
umano intero in A-pose, senza racchetta, texturizzato, poi riggato. Il testo del
prompt deriva dal campo `visual` di ogni atleta in `js/data.js` — la stessa
autorita' visiva che il BRIEF di Art/Maestro indica negli sprite.

Lo standard che il modello deve rispettare (scheletro, clip, nomi, triangoli) e'
`docs/art/character-standard.md`; il registro degli atleti e' `docs/art/roster-3d.json`
e si verifica con `python3 tools/character/validate_standard.py`.

Uso:
    python3 tools/meshy/generate_athlete.py balance
    python3 tools/meshy/generate_athlete.py preview pantera
    python3 tools/meshy/generate_athlete.py refine  pantera
    python3 tools/meshy/generate_athlete.py rig     pantera
    python3 tools/meshy/generate_athlete.py status  pantera

Ogni passo salva l'id del task in `state.json`, quindi si puo' riprendere da
dove si era rimasti senza rigenerare (e senza ripagare) i passi gia' fatti.
I crediti consumati dichiarati dall'API vengono registrati in `spese.json`.
"""

# `python3` su macOS e' ancora 3.9: senza questo import le annotazioni tipo
# `dict | None` esplodono al momento della definizione, non della chiamata.
from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

API = "https://api.meshy.ai"
HERE = pathlib.Path(__file__).resolve().parent
STATE_FILE = HERE / "state.json"
SPESE_FILE = HERE / "spese.json"
OUT_DIR = HERE / "output"
KEY_FILE = pathlib.Path.home() / ".hermes" / "secrets" / "meshy.apikey"

# ---------------------------------------------------------------------------
# Gli atleti. `prompt` e' testo-to-3D: Meshy vuole una descrizione fisica, non
# un brief di design. Massimo 600 caratteri (l'API rifiuta oltre).
#
# Regole imparate dal riferimento di Steamer:
#   - la racchetta NON si chiede: nel modello di Steamer non c'e', e nel gioco
#     deve stare separata dalla mano e agganciata al rig destro (BRIEF);
#   - si dichiara "A-pose" nel prompt E nel parametro `pose_mode`;
#   - si descrivono i colori dei capi, non lo stile grafico: l'illustrazione
#     2D e' cel-shaded, la mesh non deve esserlo.
# ---------------------------------------------------------------------------
ATHLETES = {
    "pantera": {
        "nome": "LA PANTERA",
        "ruolo": "Velocita'",
        "height_m": 1.72,
        # Obiettivo del remesh: il BRIEF chiede 15-30k triangoli per atleta e il
        # riferimento di Steamer ne ha 31.155.
        "triangoli": 30000,
        "prompt": (
            "Full body female padel athlete, athletic slim build, tanned skin, "
            "long dark brown hair in a high ponytail, wide pink sport headband. "
            "She wears a sleeveless coral pink athletic tank top with black side "
            "panels and black trim on the neckline and armholes, a black skort "
            "with a vertical pink stripe on each side, black knee-high socks with "
            "a pink stripe at the top, coral court shoes with black accents and "
            "white soles, a pink wristband on the left wrist and a black one on "
            "the right. Relaxed A-pose, arms slightly away from the body, empty "
            "hands, no racket, game-ready character."
        ),
    },
}


def api_key() -> str:
    if not KEY_FILE.exists():
        sys.exit(f"chiave assente: {KEY_FILE}")
    return KEY_FILE.read_text().strip()


def call(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        dettaglio = e.read().decode(errors="replace")
        sys.exit(f"HTTP {e.code} su {method} {path}: {dettaglio}")


def balance() -> int:
    return call("GET", "/openapi/v1/balance")["balance"]


def load_state() -> dict:
    return json.loads(STATE_FILE.read_text()) if STATE_FILE.exists() else {}


def save_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")


def log_spesa(atleta: str, passo: str, crediti: int, task_id: str) -> None:
    voci = json.loads(SPESE_FILE.read_text()) if SPESE_FILE.exists() else []
    voci.append(
        {
            "quando": time.strftime("%Y-%m-%d %H:%M:%S"),
            "atleta": atleta,
            "passo": passo,
            "crediti": crediti,
            "task": task_id,
        }
    )
    SPESE_FILE.write_text(json.dumps(voci, indent=2, ensure_ascii=False) + "\n")


def poll(atleta: str, passo: str, path: str, task_id: str, timeout_s: int = 1800) -> dict:
    """Attende la fine di un task e restituisce l'oggetto completo."""
    inizio = time.time()
    ultimo = None
    while time.time() - inizio < timeout_s:
        task = call("GET", f"{path}/{task_id}")
        stato = task.get("status")
        avanzamento = task.get("progress", 0)
        if (stato, avanzamento) != ultimo:
            print(f"  {passo}: {stato} {avanzamento}%", flush=True)
            ultimo = (stato, avanzamento)
        if stato == "SUCCEEDED":
            crediti = task.get("consumed_credits", 0)
            print(f"  {passo}: SUCCEEDED, {crediti} crediti, {int(time.time() - inizio)}s")
            log_spesa(atleta, passo, crediti, task_id)
            return task
        if stato in ("FAILED", "CANCELED"):
            sys.exit(f"  {passo}: {stato} — {json.dumps(task.get('task_error', {}))}")
        time.sleep(10) if passo != "preview" else time.sleep(5)
    sys.exit(f"  {passo}: tempo scaduto dopo {timeout_s}s (task {task_id} ancora {ultimo})")


def scarica(url: str, dest: pathlib.Path) -> pathlib.Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as r, dest.open("wb") as f:
        while pezzo := r.read(1 << 20):
            f.write(pezzo)
    mb = dest.stat().st_size / 1e6
    print(f"  scaricato {dest} ({mb:.1f} MB)")
    return dest


def url_da(task: dict, *chiavi: str) -> str | None:
    """Cerca ricorsivamente la prima chiave utile dentro `result`."""
    def cerca(obj):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if k in chiavi and isinstance(v, str) and v.startswith("http"):
                    return v
                trovato = cerca(v)
                if trovato:
                    return trovato
        return None

    return cerca(task.get("result") or {})


# ---------------------------------------------------------------------------
# Passi
# ---------------------------------------------------------------------------
def passo_preview(atleta: str) -> None:
    spec = ATHLETES[atleta]
    prompt = spec["prompt"]
    if len(prompt) > 600:
        sys.exit(f"prompt di {len(prompt)} caratteri: il limite dell'API e' 600")
    print(f"preview di {spec['nome']} (prompt {len(prompt)} caratteri)")
    print(f"  crediti prima: {balance()}")
    creato = call(
        "POST",
        "/openapi/v2/text-to-3d",
        {
            "mode": "preview",
            "prompt": prompt,
            "model_type": "standard",
            "ai_model": "latest",
            "pose_mode": "a-pose",
            # Qualita' massima: il remesh e' sconsigliato dalla documentazione
            # quando conta la resa. Il conteggio lo misuriamo dopo, sul GLB.
            "should_remesh": False,
            "enable_pbr": True,
            "target_formats": ["glb"],
        },
    )
    task_id = creato["result"]
    stato = load_state()
    stato.setdefault(atleta, {})["preview"] = task_id
    save_state(stato)

    task = poll(atleta, "preview", "/openapi/v2/text-to-3d", task_id)
    url = url_da(task, "glb")
    if not url:
        sys.exit(f"nessun GLB nel risultato: {json.dumps(task.get('result'))[:400]}")
    scarica(url, OUT_DIR / atleta / f"{atleta}-preview.glb")
    print(f"  crediti dopo: {balance()}")


def passo_refine(atleta: str) -> None:
    stato = load_state().get(atleta, {})
    if "preview" not in stato:
        sys.exit("manca il preview: lancia prima `preview`")
    print(f"refine di {ATHLETES[atleta]['nome']} dal preview {stato['preview']}")
    print(f"  crediti prima: {balance()}")
    creato = call(
        "POST",
        "/openapi/v2/text-to-3d",
        {
            "mode": "refine",
            "preview_task_id": stato["preview"],
            "enable_pbr": True,
            "target_formats": ["glb"],
        },
    )
    task_id = creato["result"]
    stato["refine"] = task_id
    save_state({**load_state(), atleta: stato})

    task = poll(atleta, "refine", "/openapi/v2/text-to-3d", task_id)
    url = url_da(task, "glb")
    if not url:
        sys.exit(f"nessun GLB nel risultato: {json.dumps(task.get('result'))[:400]}")
    scarica(url, OUT_DIR / atleta / f"{atleta}-testurizzato.glb")
    print(f"  crediti dopo: {balance()}")


def passo_rig(atleta: str) -> None:
    spec = ATHLETES[atleta]
    stato = load_state().get(atleta, {})
    # Si rigga la mesh definitiva: se c'e' stato un remesh, e' quella.
    partenza = next((k for k in ("remesh", "refine", "source") if stato.get(k)), None)
    if not partenza:
        sys.exit("manca una mesh da riggare: lancia prima `preview`/`refine`, `adopt` o `remesh`")
    print(f"rigging di {spec['nome']} da {partenza} {stato[partenza]}")
    print(f"  crediti prima: {balance()}")
    creato = call(
        "POST",
        "/openapi/v1/rigging",
        {"input_task_id": stato[partenza], "height_meters": spec["height_m"]},
    )
    task_id = creato["result"]
    stato["rig"] = task_id
    save_state({**load_state(), atleta: stato})

    task = poll(atleta, "rig", "/openapi/v1/rigging", task_id)
    result = task.get("result") or {}
    base = OUT_DIR / atleta
    for chiave, nome in (
        ("rigged_character_glb_url", f"{atleta}-riggato.glb"),
        ("rigged_character_fbx_url", f"{atleta}-riggato.fbx"),
    ):
        if result.get(chiave):
            scarica(result[chiave], base / nome)
    for chiave, url in (result.get("basic_animations") or {}).items():
        if chiave.endswith("_glb_url") and url:
            scarica(url, base / f"{atleta}-{chiave[:-8]}.glb")
    print(f"  crediti dopo: {balance()}")


def passo_status(atleta: str) -> None:
    stato = load_state().get(atleta)
    if not stato:
        print(f"{atleta}: nessun task registrato")
        return
    print(f"{atleta}:")
    for passo, task_id in stato.items():
        percorso = PERCORSI[passo]
        task = call("GET", f"{percorso}/{task_id}")
        print(f"  {passo:8s} {task.get('status'):10s} {task.get('progress', 0):3d}%  "
              f"crediti={task.get('consumed_credits')}  {task_id}")
    print(f"crediti disponibili: {balance()}")


# Un task generato altrove (per esempio a mano nell'app Meshy) si puo' adottare
# e portare avanti da qui: serve a non rigenerare — e non ripagare — quello che
# esiste gia'.
PERCORSI = {
    "source": "/openapi/v1/image-to-3d",
    "preview": "/openapi/v2/text-to-3d",
    "refine": "/openapi/v2/text-to-3d",
    "remesh": "/openapi/v1/remesh",
    "rig": "/openapi/v1/rigging",
}


def passo_remesh(atleta: str) -> None:
    """
    Riduce il conteggio dei triangoli PRIMA del rig: i pesi vanno calcolati sulla
    mesh definitiva, non su una che verra' decimata dopo.

    Il generatore di partenza puo' essere un image-to-3D, un text-to-3D o una
    retexture (la documentazione esclude il remesh di un remesh).
    """
    spec = ATHLETES[atleta]
    stato = load_state().get(atleta, {})
    partenza = next((k for k in ("refine", "source") if stato.get(k)), None)
    if not partenza:
        sys.exit("serve un task di generazione riuscito: lancia prima `preview`/`refine` o `adopt`")
    obiettivo = spec["triangoli"]
    print(f"remesh di {spec['nome']} da {partenza} {stato[partenza]} verso {obiettivo:,} triangoli")
    print(f"  crediti prima: {balance()}")
    creato = call(
        "POST",
        PERCORSI["remesh"],
        {
            "input_task_id": stato[partenza],
            "topology": "triangle",
            "target_polycount": obiettivo,
            "target_formats": ["glb"],
        },
    )
    task_id = creato["result"]
    stato["remesh"] = task_id
    save_state({**load_state(), atleta: stato})

    task = poll(atleta, "remesh", PERCORSI["remesh"], task_id)
    url = url_da(task, "glb") or (task.get("model_urls") or {}).get("glb")
    if not url:
        sys.exit(f"nessun GLB nel risultato: {json.dumps(task.get('result'))[:400]}")
    scarica(url, OUT_DIR / atleta / f"{atleta}-{obiettivo // 1000}k.glb")
    print(f"  crediti dopo: {balance()}")


def passo_adopt(atleta: str, task_id: str) -> None:
    stato = load_state()
    stato.setdefault(atleta, {})["source"] = task_id
    save_state(stato)
    task = call("GET", f"{PERCORSI['source']}/{task_id}")
    print(f"{atleta}: adottato task {task_id} ({task.get('status')} {task.get('progress')}%, "
          f"{task.get('consumed_credits')} crediti gia' spesi)")


def passo_fetch(atleta: str) -> None:
    """Attende la fine del task registrato e ne scarica i GLB."""
    stato = load_state().get(atleta, {})
    chiave = next((k for k in ("rig", "remesh", "refine", "source") if stato.get(k)), None)
    if not chiave:
        sys.exit("nessun task registrato: usa prima `adopt`, `preview`, `refine` o `rig`")
    print(f"fetch di {atleta} dal task {chiave} {stato[chiave]}")
    task = poll(atleta, chiave, PERCORSI[chiave], stato[chiave])
    result = task.get("result") or {}
    base = OUT_DIR / atleta
    scaricati = []

    model_urls = task.get("model_urls") or result.get("model_urls") or {}
    for formato, url in model_urls.items():
        if formato in ("glb", "fbx") and url:
            scaricati.append(scarica(url, base / f"{atleta}-{chiave}.{formato}"))
    for chiave_url, url in result.items():
        if isinstance(url, str) and url.startswith("http") and chiave_url.endswith(("_glb_url", "_fbx_url")):
            estensione = "glb" if chiave_url.endswith("_glb_url") else "fbx"
            nome = chiave_url.removesuffix(f"_{estensione}_url").replace("rigged_character", "riggato")
            scaricati.append(scarica(url, base / f"{atleta}-{nome}.{estensione}"))
    if not scaricati:
        sys.exit(f"nessun file scaricabile: {json.dumps(task)[:600]}")


def main() -> None:
    p = argparse.ArgumentParser(description="Genera un atleta 3D con l'API Meshy")
    p.add_argument("comando",
                   choices=["balance", "preview", "refine", "remesh", "rig", "status", "prompt",
                            "adopt", "fetch"])
    p.add_argument("atleta", nargs="?", choices=sorted(ATHLETES))
    p.add_argument("task_id", nargs="?", help="solo per `adopt`: id di un task gia' creato su Meshy")
    a = p.parse_args()

    if a.comando == "balance":
        print(f"crediti: {balance()}")
        if SPESE_FILE.exists():
            voci = json.loads(SPESE_FILE.read_text())
            totale = sum(v["crediti"] for v in voci)
            print(f"spesi da questo strumento: {totale} in {len(voci)} task")
        return
    if not a.atleta:
        sys.exit(f"serve un atleta: {', '.join(sorted(ATHLETES))}")
    if a.comando == "prompt":
        print(ATHLETES[a.atleta]["prompt"])
        print(f"\n{len(ATHLETES[a.atleta]['prompt'])} caratteri")
        return
    if a.comando == "adopt":
        if not a.task_id:
            sys.exit("serve l'id del task da adottare")
        passo_adopt(a.atleta, a.task_id)
        return
    if a.comando == "fetch":
        passo_fetch(a.atleta)
        return

    {
        "preview": passo_preview,
        "refine": passo_refine,
        "remesh": passo_remesh,
        "rig": passo_rig,
        "status": passo_status,
    }[a.comando](a.atleta)


if __name__ == "__main__":
    main()
