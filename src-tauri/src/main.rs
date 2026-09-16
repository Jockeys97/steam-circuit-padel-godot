// Contenitore desktop di Steam Circuit Padel Pro.
//
// Non fa niente di suo, ed e' voluto: apre una finestra sulla stessa pagina che
// gira nel browser. Il gioco non ha dipendenze a runtime e non parla con la
// rete, quindi il contenitore non deve fare da ponte verso nulla — deve solo
// esistere, perche' Steam distribuisce eseguibili e non indirizzi.
//
// L'unica cosa che aggiunge e' `window.__PADEL_BUILD`, che `js/build.js` legge
// per sapere se sta girando il gioco completo o la demo. Su Steam sono due app
// separate, ciascuna col suo appid, e questa e' l'unica riga che le distingue a
// parita' di codice.
//
// La finestra si costruisce qui e non in `tauri.conf.json` per una ragione
// precisa: `initialization_script` gira *prima* degli script della pagina, e
// `build.js` legge `__PADEL_BUILD` mentre viene valutato. Iniettandolo dopo il
// caricamento — con un `eval` nel setup — la demo si sarebbe avviata come gioco
// completo per la prima frazione di secondo, cioe' abbastanza da leggere il
// valore sbagliato.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{WebviewUrl, WebviewWindowBuilder};

/// Quale delle due build e' questa. La demo si compila con
/// `cargo build --features demo`, ed e' l'unica differenza fra i due binari.
const BUILD: &str = if cfg!(feature = "demo") { "demo" } else { "full" };

fn main() {
    // Dichiarato all'avvio: e' l'unico modo per sapere da fuori quale dei due
    // pacchetti si sta eseguendo, e serve tanto alla verifica della build quanto
    // a un giocatore che segnala un problema senza sapere cosa ha installato.
    eprintln!("Steam Circuit Padel Pro — build: {BUILD}");

    tauri::Builder::default()
        .setup(|app| {
            WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                .title("Steam Circuit Padel Pro")
                // Il campo e' disegnato su un canvas 960x620 e la pagina si
                // adatta: qui conta solo partire su una finestra sensata.
                .inner_size(1280.0, 800.0)
                .min_inner_size(960.0, 600.0)
                .resizable(true)
                .fullscreen(false)
                .initialization_script(&format!("window.__PADEL_BUILD = {BUILD:?};"))
                .build()?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("errore nell'avvio della finestra di gioco");
}
