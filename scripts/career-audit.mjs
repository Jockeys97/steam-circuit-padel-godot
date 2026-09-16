import assert from "node:assert/strict";

import {
  AI_OPPONENTS,
  ARENAS,
  CAREER_FINAL_SEASON,
  CAREER_MATCHES,
  CAREER_POINTS_TO_WIN,
  CAREER_PROMOTION_WINS,
  CAREER_RAMP,
  OBJECTIVE_DEFS,
  SEASON_METRIC_AGG,
  careerAiProfile,
  careerFixture,
  careerRival,
  emptySeasonProgress,
  matchObjective,
  seasonObjectives,
} from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * Audit della modalita' carriera. Non verifica che il codice girri: verifica che
 * la *progressione* regga — che ogni stella sia raggiungibile, che le stelle si
 * possano prendere una volta sola, che la rampa non cresca senza tetto e che il
 * circuito abbia una fine.
 *
 * I tetti non sono stime. Ogni punto assegnato passa da `scorePoint` con una
 * categoria: POINT_WINNER accredita `winners` a chi vince, POINT_ERROR accredita
 * `errors` a chi perde, e le due sono esclusive. Quindi in un match da N punti
 *
 *     winners[p] + errors[avversario] === pointsWon[p] <= N
 *
 * e su una stagione di M match ogni metrica di somma ha tetto N * M.
 */

const SEASONS = 12;
const POINT_CAP_MATCH = CAREER_POINTS_TO_WIN;
const POINT_CAP_SEASON = CAREER_POINTS_TO_WIN * CAREER_MATCHES;

/** Tetto raggiungibile per metrica in un singolo match. */
const MATCH_CAP = {
  pointsWon: POINT_CAP_MATCH,
  winners: POINT_CAP_MATCH,
  smashWinners: POINT_CAP_MATCH,
  // Gli errori e i doppi falli del giocatore sono limitati dai punti che
  // l'avversario puo' vincere, non dai propri.
  errors: POINT_CAP_MATCH,
  doubleFaults: POINT_CAP_MATCH,
  // Un rally non ha tetto strutturale.
  longestRally: Infinity,
};

/**
 * Il tetto di stagione dipende da come la metrica si accumula, e questo e' il
 * punto in cui l'audit sbagliava: assumendo la somma per tutte, un obiettivo
 * "max 18 errori" tenuto invece al peggior match sembrava tarato (18 < 33) mentre
 * era impossibile da fallire (11 errori massimi in una partita). Il tetto va
 * chiesto alla regola vera.
 */
function seasonCap(metric) {
  const cap = MATCH_CAP[metric];
  if (cap === Infinity) return Infinity;
  return SEASON_METRIC_AGG[metric] === "max" ? cap : cap * CAREER_MATCHES;
}

const report = { seasons: [], ramp: [], farm: null, finale: null };

// ── 1. Ogni obiettivo deve essere raggiungibile ─────────────────────────────
for (let season = 1; season <= SEASONS; season += 1) {
  const objs = seasonObjectives(season);
  const detail = objs.map((o) => {
    const def = OBJECTIVE_DEFS[o.id];
    const cap = seasonCap(def.metric);
    if (def.unit === "max") {
      // Un obiettivo "max" con target al tetto e' soddisfatto sempre: e' una
      // stella regalata, l'altra faccia dell'obiettivo impossibile.
      assert(o.target >= 0, `Stagione ${season}: ${o.id} chiede un massimo negativo`);
      assert(
        o.target < cap,
        `Stagione ${season}: ${o.id} con max ${o.target} e tetto ${cap} non si puo' fallire`,
      );
    } else {
      assert(
        o.target <= cap,
        `Stagione ${season}: obiettivo ${o.id} chiede ${o.target} con un tetto di ${cap}`,
      );
    }
    // Con aggregazione a massimo l'etichetta dipende dal verso dell'obiettivo:
    // per uno da superare quel massimo e' il record della stagione, per uno da
    // non superare e' il match andato peggio.
    const scope = SEASON_METRIC_AGG[def.metric] !== "max"
      ? "totale stagione"
      : def.unit === "max" ? "peggior match" : "record";
    return `${o.id}=${o.target}/${cap === Infinity ? "∞" : cap} (${scope})`;
  });
  report.seasons.push({ season, objectives: detail.join(" ") });

  for (let m = 0; m < CAREER_MATCHES; m += 1) {
    const mo = matchObjective(season, m);
    const def = OBJECTIVE_DEFS[mo.id];
    const cap = MATCH_CAP[def.metric];
    assert(
      def.unit === "max" ? mo.target >= 0 && mo.target < cap : mo.target <= cap,
      `Stagione ${season} match ${m + 1}: bonus ${mo.id} chiede ${mo.target} con tetto ${cap}`,
    );
  }
}

// Ogni obiettivo del pool deve comparire: uno che non esce mai e' codice morto.
const visti = new Set();
for (let season = 1; season <= SEASONS; season += 1) {
  seasonObjectives(season).forEach((o) => visti.add(o.id));
}
Object.keys(OBJECTIVE_DEFS).forEach((id) => {
  assert(visti.has(id), `L'obiettivo ${id} non esce in ${SEASONS} stagioni: e' codice morto`);
});

// Ogni metrica deve avere una regola di aggregazione, e deve averla in UN posto
// solo. Un secondo campo `agg` sugli obiettivi era gia' finito in disaccordo con
// SEASON_METRIC_AGG senza che nulla se ne accorgesse: il gioco leggeva una delle
// due tabelle e l'altra restava li' a sembrare autorevole.
Object.entries(OBJECTIVE_DEFS).forEach(([id, def]) => {
  assert(SEASON_METRIC_AGG[def.metric], `La metrica di ${id} non ha regola di aggregazione`);
  assert(
    def.agg === undefined,
    `${id} dichiara un proprio "agg": l'aggregazione vive solo in SEASON_METRIC_AGG`,
  );
});

// E ogni metrica accumulata deve servire a un obiettivo: una che non viene mai
// letta e' peso morto che si puo' ritarare senza effetti.
const metricheUsate = new Set(Object.values(OBJECTIVE_DEFS).map((d) => d.metric));
Object.keys(SEASON_METRIC_AGG).forEach((metric) => {
  assert(metricheUsate.has(metric), `La metrica ${metric} si accumula ma nessun obiettivo la legge`);
});

// ── 2. Le stelle non si possono farmare ────────────────────────────────────
// Riproduce la macchina a stati: ogni obiettivo centrato, ma solo una vittoria
// su tre, quindi la stagione si ripete per sempre.
function simulateCareer({ winsPerSeason, cycles }) {
  const career = {
    season: 1,
    matchIndex: 0,
    seasonWins: 0,
    stars: 0,
    trophies: 0,
    seasonObjectives: [],
    claimedObjectives: {},
    seasonProgress: emptySeasonProgress(),
  };
  for (let cycle = 0; cycle < cycles; cycle += 1) {
    for (let m = 0; m < CAREER_MATCHES; m += 1) {
      if (!career.seasonObjectives.length) {
        const claimed = new Set(career.claimedObjectives[career.season] ?? []);
        career.seasonObjectives = seasonObjectives(career.season)
          .map((o) => ({ ...o, claimed: claimed.has(o.id) }));
      }
      career.stars += 1; // bonus del match, sempre centrato
      const claimed = new Set(career.claimedObjectives[career.season] ?? []);
      career.seasonObjectives.forEach((o) => {
        if (claimed.has(o.id)) return; // gia' pagato in un tentativo precedente
        claimed.add(o.id);
        career.stars += 1;
      });
      career.claimedObjectives[career.season] = [...claimed];
      career.matchIndex += 1;
      if (m < winsPerSeason) career.seasonWins += 1;
    }
    if (career.seasonWins >= CAREER_MATCHES) {
      career.trophies += 1;
      career.season += 1;
    } else if (career.seasonWins >= CAREER_PROMOTION_WINS) {
      career.season += 1;
    }
    career.matchIndex = 0;
    career.seasonWins = 0;
    career.seasonObjectives = [];
    career.seasonProgress = emptySeasonProgress();
  }
  return career;
}

const CYCLES = 10;
const farmer = simulateCareer({ winsPerSeason: 1, cycles: CYCLES });
const climber = simulateCareer({ winsPerSeason: CAREER_MATCHES, cycles: CYCLES });
report.farm = {
  cicli: CYCLES,
  ripetendo: { stelle: farmer.stars, trofei: farmer.trophies, stagione: farmer.season },
  vincendo: { stelle: climber.stars, trofei: climber.trophies, stagione: climber.season },
};

// Ripetendo la stessa stagione le stelle di stagione si prendono una volta sola:
// resta solo il bonus di match, una stella per partita.
const soloBonus = CYCLES * CAREER_MATCHES;
assert.equal(
  farmer.stars,
  soloBonus + 3,
  `Ripetere la stagione 1 deve dare ${soloBonus} stelle di bonus piu' le 3 di stagione, non ${farmer.stars}`,
);
assert(
  climber.stars > farmer.stars,
  `Avanzare deve rendere piu' che restare fermi: ${climber.stars} contro ${farmer.stars}`,
);

// ── 3. La rampa ha un tetto ────────────────────────────────────────────────
let precedente = null;
for (const season of [1, 2, 3, 4, 5, 8, 12, 20, 40, 120]) {
  const primo = careerAiProfile(season, 0);
  const ultimo = careerAiProfile(season, CAREER_MATCHES - 1);
  report.ramp.push({
    season,
    skill: Number(ultimo.skill.toFixed(3)),
    speed: Math.round(ultimo.speed),
    power: Number(ultimo.power.toFixed(2)),
  });
  assert(ultimo.skill <= CAREER_RAMP.skillCap + 1e-9, `skill oltre il tetto alla stagione ${season}`);
  assert(ultimo.speed <= CAREER_RAMP.speedCap + 1e-9, `speed oltre il tetto alla stagione ${season}`);
  assert(ultimo.power <= CAREER_RAMP.powerCap + 1e-9, `power oltre il tetto alla stagione ${season}`);
  assert(ultimo.skill >= primo.skill, `Dentro la stagione ${season} la skill non deve calare`);
  if (precedente) {
    assert(
      ultimo.skill >= precedente.skill && ultimo.speed >= precedente.speed,
      `La stagione ${season} non deve essere piu' facile della precedente`,
    );
  }
  precedente = ultimo;
}

// La velocita' non deve superare di troppo il gradino piu' duro dichiarato: e' la
// variabile che gli audit dello smash mostrano capace di ribaltare uno scambio.
const speedLeggenda = AI_OPPONENTS[AI_OPPONENTS.length - 1].speed;
assert(
  CAREER_RAMP.speedCap - speedLeggenda <= 60,
  `Il tetto di velocita' (${CAREER_RAMP.speedCap}) si stacca troppo dalla Leggenda (${speedLeggenda})`,
);

// ── 4. Il circuito ha un rivale per gradino e una fine ─────────────────────
const rivali = new Set();
for (let season = 1; season <= SEASONS; season += 1) rivali.add(careerRival(season).id);
assert.equal(
  rivali.size,
  AI_OPPONENTS.length,
  `Ogni avversario deve avere il suo gradino: ${rivali.size} su ${AI_OPPONENTS.length}`,
);
assert(
  CAREER_FINAL_SEASON >= AI_OPPONENTS.length,
  "Il finale non puo' arrivare prima di aver incontrato tutti i rivali",
);
report.finale = { stagioneFinale: CAREER_FINAL_SEASON, rivale: careerRival(CAREER_FINAL_SEASON).id };

// ── 5. Il calendario cambia arena dentro la stagione ───────────────────────
for (let season = 1; season <= SEASONS; season += 1) {
  const arene = new Set();
  for (let m = 0; m < CAREER_MATCHES; m += 1) {
    arene.add(careerFixture(season, m).arena.id);
  }
  assert(
    arene.size === Math.min(CAREER_MATCHES, ARENAS.length),
    `Stagione ${season}: il calendario ripete un'arena (${[...arene].join(", ")})`,
  );
}
// Con una sola arena sbloccata il calendario deve reggere invece di rompersi.
const unaSola = careerFixture(3, 1, [ARENAS[0]]);
assert.equal(unaSola.arena.id, ARENAS[0].id, "Con una sola arena il calendario deve usarla");
assert.deepEqual(careerFixture(3, 1, []).arena, careerFixture(3, 1, ARENAS).arena,
  "Senza arene disponibili si deve ricadere sull'elenco completo");

console.log(JSON.stringify(report, null, 2));
console.log("\ncareer-audit: tutte le asserzioni passate");
