import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { lazySpriteMap } from "../js/sprite-loader.js";

const requested = [];
class FakeImage {
  constructor() {
    this.complete = false;
    this.naturalWidth = 0;
    this.listeners = {};
  }
  addEventListener(type, listener) { this.listeners[type] = listener; }
  set src(path) {
    requested.push(path);
    queueMicrotask(() => {
      this.complete = true;
      this.naturalWidth = 256;
      this.listeners.load?.();
    });
  }
  async decode() {}
}

const appearances = new Map([
  ["maestro:base", { sprite: "maestro.webp" }],
  ["pantera:base", { sprite: "pantera.webp" }],
]);
const sprites = lazySpriteMap(appearances, "sprite", { ImageCtor: FakeImage });

assert.equal(requested.length, 0, "La cache non deve scaricare sprite alla creazione");
const first = sprites.get("maestro:base");
assert.equal(requested.length, 1, "La prima richiesta deve avviare un solo download");
assert.equal(sprites.get("maestro:base"), first, "Lo stesso sprite deve essere riusato dalla cache");
assert.equal(requested.length, 1, "La cache non deve duplicare il download");
assert.equal(await sprites.ready("maestro:base"), true, "ready() deve attendere load e decode");

const main = await readFile(new URL("../js/main.js", import.meta.url), "utf8");
assert.ok(main.includes("await preloadMatchSprites(athlete, lineup)"),
  "Partita e allenamento devono attendere gli sprite della formazione");
assert.equal(main.match(/await preloadMatchSprites\(athlete, lineup\)/g)?.length, 2,
  "Sia partita sia allenamento devono attraversare il gate degli sprite");
assert.ok(!main.includes("demoFilter(ATHLETES, DEMO_CONTENT.athletes).forEach"),
  "Il roster completo non deve piu' essere precaricato all'apertura");

console.log(JSON.stringify({ lazyRequests: requested.length, waitsForLineup: true }, null, 2));
