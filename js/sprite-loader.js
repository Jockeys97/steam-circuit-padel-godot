const readyBySprite = new WeakMap();

/**
 * Crea un'immagine e conserva la promessa che termina soltanto quando il
 * browser l'ha caricata e decodificata. Un errore risolve `false`: il gioco puo'
 * usare consapevolmente il disegno di emergenza senza restare bloccato.
 */
export function loadSprite(path, { ImageCtor = Image, timeoutMs = 15000 } = {}) {
  const sprite = new ImageCtor();
  sprite.decoding = "async";

  const ready = new Promise((resolve) => {
    if (!path) {
      resolve(false);
      return;
    }

    let settled = false;
    const finish = (ok) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(Boolean(ok && sprite.naturalWidth > 0));
    };
    const loaded = async () => {
      try {
        await sprite.decode?.();
      } catch {
        // Alcuni browser possono rifiutare decode() anche dopo `load`: la
        // dimensione naturale resta il controllo autorevole sull'immagine.
      }
      finish(true);
    };

    sprite.addEventListener("load", loaded, { once: true });
    sprite.addEventListener("error", () => finish(false), { once: true });
    const timer = setTimeout(() => finish(false), timeoutMs);
    sprite.src = path;
    if (sprite.complete) queueMicrotask(() => loaded());
  });

  readyBySprite.set(sprite, ready);
  return sprite;
}

export function spriteReady(sprite) {
  return readyBySprite.get(sprite) ?? Promise.resolve(false);
}

/** Una cache per un singolo tipo di posa, caricata solo alla prima richiesta. */
export function lazySpriteMap(appearanceByKey, field, options) {
  const cache = new Map();
  return {
    get(key) {
      let sprite = cache.get(key);
      if (!sprite) {
        sprite = loadSprite(appearanceByKey.get(key)?.[field], options);
        cache.set(key, sprite);
      }
      return sprite;
    },
    ready(key) {
      return spriteReady(this.get(key));
    },
  };
}
