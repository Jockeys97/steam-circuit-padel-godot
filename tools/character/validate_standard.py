#!/usr/bin/env python3
"""Gate dello standard personaggi 3D — docs/art/character-standard.md.

Legge il registro `docs/art/roster-3d.json`, apre ogni GLB dichiarato e verifica
scheletro, clip, geometria, materiali e nomi dei file. Non serve Godot: il GLB si
parsa direttamente, riusando `read_glb` di `glb_tri_count.py`.

Severita' per stato (registro, campo `stato`):
    approvato  -> ogni scostamento e' FAIL
    in-prova   -> scheletro/clip/nomi sono FAIL, la geometria e' solo un avviso
    generato   -> scheletro/clip sono FAIL, geometria e collocazione sono avvisi
    legacy     -> nessun FAIL, solo avvisi (eccezioni dichiarate nello standard)
    assente    -> nessun controllo

Stampa una riga per controllo, nel formato degli altri gate del repo:
    ok <nome>
    FAIL <nome>: expected <x>, got <y>
    warn <nome>: <dettaglio>
e chiude con esattamente una riga  PASS <n>/<n>  oppure  FAIL <n>/<n>,
uscendo 0 su PASS e 1 su FAIL, cosi' un runner non ha bisogno di parser.

Uso:
    python3 tools/character/validate_standard.py
    python3 tools/character/validate_standard.py --inject-failure   # prova il segnale rosso
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
REGISTRO = os.path.join(REPO, "docs", "art", "roster-3d.json")

sys.path.insert(0, HERE)
from glb_tri_count import read_glb  # noqa: E402  (stesso cartella, nessuna dipendenza esterna)

# Quanto e' severo ogni stato: (scheletro+clip+nomi, geometria)
SEVERITA = {
    "approvato": ("fail", "fail"),
    "in-prova": ("fail", "warn"),
    "generato": ("fail", "warn"),
    "legacy": ("warn", "warn"),
}


class Gate:
    def __init__(self) -> None:
        self.controlli = 0
        self.falliti = 0
        self.avvisi = 0

    def check(self, ok: bool, nome: str, atteso, ottenuto, severita: str = "fail") -> bool:
        if ok:
            self.controlli += 1
            print("ok %s" % nome)
            return True
        if severita == "warn":
            self.avvisi += 1
            print("warn %s: atteso %s, trovato %s" % (nome, atteso, ottenuto))
            return False
        self.controlli += 1
        self.falliti += 1
        print("FAIL %s: expected %s, got %s" % (nome, atteso, ottenuto), file=sys.stderr)
        return False

    def fine(self) -> int:
        if self.avvisi:
            print("# %d avvisi (scostamenti tollerati dallo stato nel registro)" % self.avvisi)
        if self.falliti == 0:
            print("PASS %d/%d" % (self.controlli, self.controlli))
            return 0
        print("FAIL %d/%d" % (self.controlli - self.falliti, self.controlli))
        return 1


def elenco(nomi: list, quanti: int = 4) -> str:
    """Le liste di ossa sono lunghe 28: si mostrano i primi nomi e il resto si conta."""
    if not nomi:
        return "-"
    if len(nomi) <= quanti:
        return ", ".join(nomi)
    return "%s (+%d)" % (", ".join(nomi[:quanti]), len(nomi) - quanti)


def clip_del_glb(g: dict) -> dict:
    """nome clip -> durata in secondi."""
    acc = g.get("accessors", [])
    fuori = {}
    for a in g.get("animations", []):
        durata = 0.0
        for s in a.get("samplers", []):
            massimo = acc[s["input"]].get("max")
            if massimo:
                durata = max(durata, float(massimo[0]))
        fuori[a.get("name", "?")] = round(durata, 3)
    return fuori


def triangoli(g: dict) -> int:
    acc = g.get("accessors", [])
    totale = 0
    for mesh in g.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if prim.get("mode", 4) != 4:
                continue
            idx = prim.get("indices")
            if idx is not None:
                totale += acc[idx].get("count", 0) // 3
            else:
                totale += acc[prim["attributes"]["POSITION"]].get("count", 0) // 3
    return totale


def ossa(g: dict) -> list:
    nodi = g.get("nodes", [])
    fuori = []
    for skin in g.get("skins", []):
        fuori.extend(nodi[i].get("name", "?") for i in skin.get("joints", []))
    return fuori


def valida_atleta(gate: Gate, reg: dict, atleta: dict, inject: bool) -> int | None:
    ident = atleta["id"]
    stato = atleta.get("stato", "assente")
    percorso = atleta.get("glb")
    if stato == "assente" or not percorso:
        print("# %s: %s, nessun controllo" % (ident, stato))
        return None

    sev_rig, sev_geo = SEVERITA.get(stato, ("fail", "fail"))
    assoluto = os.path.join(REPO, percorso)
    if not gate.check(os.path.exists(assoluto), "%s: il GLB del registro esiste" % ident,
                      percorso, "mancante", sev_rig):
        return None

    g, _dimensione, _bin, _versione = read_glb(assoluto)

    # --- nome del file = id del roster (standard §1)
    base = os.path.basename(percorso)
    gate.check(base.startswith(ident), "%s: il file porta l'id del roster" % ident,
               "%s*.glb" % ident, base, sev_rig)
    if stato in ("approvato", "in-prova"):
        gate.check(percorso == "godot/assets/athletes/%s.glb" % ident,
                   "%s: l'asset di gioco sta al posto suo" % ident,
                   "godot/assets/athletes/%s.glb" % ident, percorso, sev_rig)

    # --- scheletro (standard §2)
    attese = list(reg["scheletro"]["ossa"])
    trovate = ossa(g)
    if inject and ident == "colosso":
        trovate = trovate[:-1]  # prova del segnale rosso
    gate.check(len(trovate) == len(attese), "%s: numero di ossa" % ident,
               len(attese), len(trovate), sev_rig)
    mancanti = [b for b in attese if b not in trovate]
    extra = [b for b in trovate if b not in attese]
    gate.check(not mancanti and not extra, "%s: scheletro mixamorig-28" % ident,
               "nessuno scarto",
               "mancanti=%s extra=%s" % (elenco(mancanti), elenco(extra)), sev_rig)
    if trovate:
        gate.check(trovate[0] == reg["scheletro"]["radice"], "%s: radice dello scheletro" % ident,
                   reg["scheletro"]["radice"], trovate[0], sev_rig)

    # --- clip (standard §3)
    presenti = clip_del_glb(g)
    for alias, nome_glb in reg["clip"].items():
        gate.check(nome_glb in presenti, "%s: clip %s (%s)" % (ident, alias, nome_glb),
                   nome_glb, ", ".join(presenti) or "nessuna", sev_rig)

    # --- geometria (standard §4)
    tri = triangoli(g)
    minimo, massimo = reg["geometria"]["triangoli_min"], reg["geometria"]["triangoli_max"]
    gate.check(minimo <= tri <= massimo, "%s: triangoli in banda" % ident,
               "%d-%d" % (minimo, massimo), tri, sev_geo)

    # --- materiali (standard §5)
    gate.check(len(g.get("materials", [])) <= reg["materiali"]["materiali_max"],
               "%s: un solo materiale" % ident,
               "<=%d" % reg["materiali"]["materiali_max"], len(g.get("materials", [])), sev_rig)
    gate.check(len(g.get("images", [])) <= reg["materiali"]["immagini_max"],
               "%s: al massimo %d mappe" % (ident, reg["materiali"]["immagini_max"]),
               "<=%d" % reg["materiali"]["immagini_max"], len(g.get("images", [])), sev_geo)

    return tri if stato == "approvato" else None


def main() -> int:
    inject = "--inject-failure" in sys.argv
    reg = json.load(open(REGISTRO, encoding="utf-8"))
    gate = Gate()

    # --- il registro copre il roster vero, senza inventare atleti (standard §1)
    catalogo = json.load(open(os.path.join(
        REPO, "godot", "assets", "athletes", "reference_catalogue.json"), encoding="utf-8"))
    id_catalogo = sorted(a["id"] for a in catalogo["athletes"])
    id_registro = sorted(a["id"] for a in reg["atleti"])
    gate.check(id_catalogo == id_registro, "il registro copre esattamente il roster",
               id_catalogo, id_registro)

    approvati = {}
    for atleta in reg["atleti"]:
        tri = valida_atleta(gate, reg, atleta, inject)
        if tri is not None:
            approvati[atleta["id"]] = tri

    # --- divario fra approvati (standard §4)
    if len(approvati) >= 2:
        alto, basso = max(approvati.values()), min(approvati.values())
        limite = reg["geometria"]["divario_massimo_fra_approvati"]
        gate.check(alto <= basso * limite, "divario di triangoli fra atleti approvati",
                   "<=%.1fx" % limite, "%.1fx (%d..%d)" % (alto / basso, basso, alto))
    else:
        print("# divario: serve piu' di un atleta approvato, oggi %d" % len(approvati))

    return gate.fine()


if __name__ == "__main__":
    sys.exit(main())
