# Steam Circuit Padel Pro — Music Assets & OST Directory

This directory (`res://assets/audio/music/`) hosts the recorded or AI-generated soundtrack files (OSTs) for Steam Circuit Padel Pro.

## Supported Audio Formats
Godot 4 natively supports streaming:
- **`.ogg`** (Ogg Vorbis) — **Recommended** for loops, efficient memory streaming, and seamless looping.
- **`.mp3`** — Supported for background streams.
- **`.wav`** — Supported for short stingers (e.g. victory fanfare).

## File Naming Convention
The `SoundtrackManager` (`res://src/audio/soundtrack_manager.gd`) looks for files following these IDs:

| Track ID | Expected Filename(s) | Usage / Scene |
|---|---|---|
| `ost_menu` | `ost_menu.ogg` / `.mp3` | Main Menu / Title Screen |
| `ost_roster` | `ost_roster.ogg` / `.mp3` | Athlete Roster & Wardrobe |
| `ost_career` | `ost_career.ogg` / `.mp3` | Career Calendar & Tournament Bracket |
| `ost_training` | `ost_training.ogg` / `.mp3` | Practice Court / Coach Jev Lab |
| `ost_officina` | `ost_officina.ogg` / `.mp3` | Arena: Officina Meccanica |
| `ost_fonderia` | `ost_fonderia.ogg` / `.mp3` | Arena: Fonderia a Vapore |
| `ost_cattedrale` | `ost_cattedrale.ogg` / `.mp3` | Arena: Cattedrale degli Ingranaggi |
| `ost_forgia` | `ost_forgia.ogg` / `.mp3` | Arena: Forgia Elettrica |
| `ost_osservatorio` | `ost_osservatorio.ogg` / `.mp3` | Arena: Osservatorio |
| `ost_tempesta` | `ost_tempesta.ogg` / `.mp3` | Arena: Tempesta Eolica |
| `ost_abissale` | `ost_abissale.ogg` / `.mp3` | Arena: Profondità Abissali |
| `ost_caldera` | `ost_caldera.ogg` / `.mp3` | Arena: Caldera Vulcanica |
| `ost_orrery` | `ost_orrery.ogg` / `.mp3` | Arena: Grande Planetario |
| `ost_torii` | `ost_torii.ogg` / `.mp3` | World Arena: Torii (Kyoto) |
| `ost_medina` | `ost_medina.ogg` / `.mp3` | World Arena: Medina |
| `ost_carioca` | `ost_carioca.ogg` / `.mp3` | World Arena: Carioca (Rio) |
| `ost_aurora` | `ost_aurora.ogg` / `.mp3` | World Arena: Aurora (Nordic) |
| `ost_egeo` | `ost_egeo.ogg` / `.mp3` | World Arena: Egeo |
| `ost_heritage_hall` | `ost_heritage_hall.ogg` / `.mp3` | Arena: Heritage Hall |
| `ost_steam_workshop` | `ost_steam_workshop.ogg` / `.mp3` | Arena: Steam Workshop |
| `ost_climax` | `ost_climax.ogg` / `.mp3` | Match Point / Deuce / Climax |
| `ost_victory` | `ost_victory.ogg` / `.mp3` | Post-Match Victory Ceremony |
| `ost_epic_anthem` | `ost_epic_anthem.ogg` / `.mp3` | Epic Shonen Opening & Grand Event |
| `ost_epic_semifinal` | `ost_epic_semifinal.ogg` / `.mp3` | Tournament Semifinals |
| `ost_epic_grand_final` | `ost_epic_grand_final.ogg` / `.mp3` | Championship Grand Final Match |
| `ost_epic_rival_legend` | `ost_epic_rival_legend.ogg` / `.mp3` | Legend Tier Boss AI Opponents |
| `ost_epic_awakening` | `ost_epic_awakening.ogg` / `.mp3` | 100% Steam Gauge Super Rally |
| `ost_epic_sudden_death` | `ost_epic_sudden_death.ogg` / `.mp3` | Sudden Death & Golden Point |
| `ost_epic_ascension` | `ost_epic_ascension.ogg` / `.mp3` | Hall of Fame & Trophy Ascension |
| `ost_epic_rematch` | `ost_epic_rematch.ogg` / `.mp3` | Immediate Rematch & Defiance |
| `ost_sawano_titan_breach` | `ost_sawano_titan_breach.ogg` / `.mp3` | Boss Match Intro & Colossal Breach |
| `ost_sawano_counterattack` | `ost_sawano_counterattack.ogg` / `.mp3` | Counter-Rally & High Stakes Turnaround |
| `ost_sawano_wings_of_freedom` | `ost_sawano_wings_of_freedom.ogg` / `.mp3` | Scouting Overdrive & Championship Semifinals |
| `ost_sawano_shiganshina_cry` | `ost_sawano_shiganshina_cry.ogg` / `.mp3` | Shiganshina Requiem & Sudden Death Deuce |
| `ost_sawano_colossal_smash` | `ost_sawano_colossal_smash.ogg` / `.mp3` | Padel Colossus & Berserk Super Smash |
| `ost_sawano_barricades` | `ost_sawano_barricades.ogg` / `.mp3` | Final Wall & Grand Championship Anthem |

## Graceful Fallback
If an OST file is not yet placed in this directory, `SoundtrackManager` gracefully falls back to silence or the deterministic procedural synthesizer (`music.gd`), ensuring test suites and match controllers continue without interruption.
