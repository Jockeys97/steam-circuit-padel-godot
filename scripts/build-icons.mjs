import { execFileSync } from "node:child_process";
import { rm, readdir } from "node:fs/promises";
import sharp from "sharp";

/**
 * Rigenera le icone del pacchetto desktop dalla key art del gioco.
 *
 * `tauri icon` produce una sessantina di file — mipmap Android, loghi Windows
 * Store, favicon — che per una pubblicazione su Steam non servono e pesano 7,5 MB
 * nel repository. Qui si tiene solo cio' che `tauri.conf.json` referenzia
 * davvero, e la sorgente quadrata non si conserva affatto: si ricava dalla key
 * art, che nel repository c'e' gia'.
 */

const SORGENTE = "assets/ui/steam-circuit-key-art.webp";
const TEMPORANEA = "src-tauri/icon-source.png";
const TENUTE = ["32x32.png", "128x128.png", "128x128@2x.png", "icon.icns", "icon.ico", "icon.png"];

const meta = await sharp(SORGENTE).metadata();
const lato = Math.min(meta.width, meta.height);
await sharp(SORGENTE)
  .extract({ left: Math.round((meta.width - lato) / 2), top: 0, width: lato, height: lato })
  .resize(1024, 1024)
  .png()
  .toFile(TEMPORANEA);

execFileSync("npx", ["tauri", "icon", TEMPORANEA], { stdio: "inherit" });
await rm(TEMPORANEA, { force: true });

let tolti = 0;
for (const voce of await readdir("src-tauri/icons", { withFileTypes: true })) {
  if (voce.isDirectory() || !TENUTE.includes(voce.name)) {
    await rm(`src-tauri/icons/${voce.name}`, { recursive: true, force: true });
    tolti += 1;
  }
}
console.log(JSON.stringify({ tenute: TENUTE.length, rimosse: tolti }, null, 2));
