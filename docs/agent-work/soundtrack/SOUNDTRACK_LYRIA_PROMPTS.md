# Steam Circuit Padel Pro — Full OST Specification & Lyria Prompt Catalog

This document provides the complete artistic direction, technical parameters, and tailored prompts for generating the **22 Original Soundtrack (OST)** tracks for *Steam Circuit Padel Pro* using **Lyria** (Google DeepMind's music generation model), **MusicFX**, or compatible text-to-music models (Suno, Udio).

---

## 1. Global Sonic Identity

- **Aesthetic**: Steampunk retro-futurism meeting high-velocity arcade sports.
- **Core Elements**:
  - **Mechanical Transients**: Clockwork ticks, brass bell chimes, steam valve releases, hydraulic thuds, and piston rhythms.
  - **Orchestral Brass & Strings**: Victorian fanfare trumpets, trombones, staccato cello/violin ostinatos, gothic pipe organ.
  - **Modern Dance & Sports Drive**: Tight electro-swing, funk breaks, four-on-the-floor kicks, aggressive analog synth basslines, and synthwave arpeggios.
- **Mastering Guideline**: Punchy low-end, warm mid-range to prevent clashing with ball impacts (`bounce.wav`, `hit.wav`, `wall.wav`), and airy highs.

---

## 2. Track Catalog & Lyria Prompts

### Category A: System & Menu Themes

#### OST 01: "Steam Circuit Overture" (Main Menu Theme)
- **ID**: `ost_menu`
- **File**: `res://assets/audio/music/ost_menu.ogg`
- **Screen**: Main Menu & Title (`godot/src/ui/screens/MenuScreen.gd`)
- **Key**: D minor | **BPM**: 118 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *A high-energy steampunk electro-swing main theme for an arcade sports game. Upright acoustic bass groove, syncopated brass section with muted trumpets and trombones, vintage gramophone crackle, clockwork tick-tock percussion, piston steam release fx on downbeats, driving swing rhythm, Victorian grand adventure melody, polished modern mix.*

#### OST 02: "The Grand Roster & Atelier" (Character & Outfit Selection)
- **ID**: `ost_roster`
- **File**: `res://assets/audio/music/ost_roster.ogg`
- **Screen**: Roster selection & Mythic wardrobe atelier (`godot/src/character/outfit_catalogue.gd`)
- **Key**: A minor | **BPM**: 105 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Mid-tempo gypsy jazz manouche infused with steampunk clockwork textures. Fast acoustic guitar rhythm chords, melancholic yet playful accordion lead, delicate music box arpeggios, gentle upright bass, subtle mechanical gear clicks as percussion, elegant Victorian Parisian workshop atmosphere.*

#### OST 03: "Circuit Board & Career Roadmap" (Tournament & Career Hub)
- **ID**: `ost_career`
- **File**: `res://assets/audio/music/ost_career.ogg`
- **Screen**: Career Calendar, Tournament Brackets & World Map (`godot/src/ui/screens/ArenaScreen.gd`)
- **Key**: E minor | **BPM**: 95 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Sophisticated steampunk menu ambiance, brooding solo cello counterpoint over atmospheric analog synth pads, ticking pocket watch pulses, tubular bells, subtle brass chimes, methodical and strategic feeling, high-stakes Victorian tournament preparation.*

#### OST 04: "The Maestro's Tactical Workshop" (Training / Practice Court)
- **ID**: `ost_training`
- **File**: `res://assets/audio/music/ost_training.ogg`
- **Screen**: Practice Court & Coach Jev Tactical Lab
- **Key**: C minor | **BPM**: 124 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Focus and training arcade theme, minimal steampunk tech-house, tight clean bassline, rhythmic clicking gear loops, soft marimba ostinato, subtle pressurized steam valve accents, hypnotic arpeggiated analog synth, disciplined athletic atmosphere.*

---

### Category B: Frozen Roster Arenas (The 9 Core Arenas)

#### OST 05: "Pistons in the Foundry" (Arena: `officina`)
- **ID**: `ost_officina`
- **File**: `res://assets/audio/music/ost_officina.ogg`
- **Arena**: Officina Meccanica
- **Key**: F minor | **BPM**: 128 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Industrial funk sports arena track, heavy anvil strikes, rhythmic hydraulic press beats, distorted clavinet riffs, driving syncopated four-on-the-floor kick, steam hiss transitions, aggressive bassline, energetic workshop match ambiance.*

#### OST 06: "Molten Heart Furnace" (Arena: `fonderia`)
- **ID**: `ost_fonderia`
- **File**: `res://assets/audio/music/ost_fonderia.ogg`
- **Arena**: Fonderia a Vapore
- **Key**: D minor | **BPM**: 132 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *High-intensity industrial synthwave rock, pounding resonant war drums, chugging mechanical guitar grooves, distorted analog synth leads, roaring blast furnace soundscapes, energetic fast-paced padel rally pacing.*

#### OST 07: "Clockwork Nave" (Arena: `cattedrale`)
- **ID**: `ost_cattedrale`
- **File**: `res://assets/audio/music/ost_cattedrale.ogg`
- **Arena**: Cattedrale degli Ingranaggi
- **Key**: G minor | **BPM**: 135 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Gothic steampunk hybrid, majestic pipe organ motifs layered over fast breakbeat drums, resonant choir vocal pads, cathedral hall reverberation, metallic pendulum swings, dramatic baroque counterpoint with electronic arcade drive.*

#### OST 08: "Tesla Coil Arc" (Arena: `forgia`)
- **ID**: `ost_forgia`
- **File**: `res://assets/audio/music/ost_forgia.ogg`
- **Arena**: Forgia Elettrica
- **Key**: B minor | **BPM**: 130 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *High-voltage electro-industrial soundtrack, buzzing electric arpeggios, snappy punchy snare, buzzing sawtooth basslines, metallic laser zap transients, relentless energetic sports pacing, crackling lightning textures.*

#### OST 09: "Astrolabe Horizon" (Arena: `osservatorio`)
- **ID**: `ost_osservatorio`
- **File**: `res://assets/audio/music/ost_osservatorio.ogg`
- **Arena**: Osservatorio Astronomico
- **Key**: A minor | **BPM**: 125 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Victorian celestial synthwave, glittering music box melodies, soaring brass trumpet hooks, lush retro pad swells, clockwork telescope gears revolving, deep round sub-bass, wonderous yet competitive athletic arcade tempo.*

#### OST 10: "Gale Force Turbine" (Arena: `tempesta`)
- **ID**: `ost_tempesta`
- **File**: `res://assets/audio/music/ost_tempesta.ogg`
- **Arena**: Tempesta Eolica
- **Key**: F# minor | **BPM**: 160 (half-time 80 feel) | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Steampunk liquid drum and bass, rushing aerodynamic synth sweeps, fast rolling acoustic breakbeats, urgent brass stabs, whistling wind pressure bursts, agile and rapid rally tempo, clean modern club mix.*

#### OST 11: "Bathysphere Depth" (Arena: `abissale`)
- **ID**: `ost_abissale`
- **File**: `res://assets/audio/music/ost_abissale.ogg`
- **Arena**: Profondità Abissali
- **Key**: C# minor | **BPM**: 120 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Atmospheric deep industrial dub, heavy sub-bass pulses, pinging brass sonar pings, muffled steam vents, subaquatic reverberations, crisp metallic rimshot percussion, dark and mysterious deep-sea arena match.*

#### OST 12: "Magma Chamber Deuce" (Arena: `caldera`)
- **ID**: `ost_caldera`
- **File**: `res://assets/audio/music/ost_caldera.ogg`
- **Arena**: Caldera Vulcanica
- **Key**: E minor | **BPM**: 136 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Tribal industrial battle soundtrack, thunderous taiko and bronze kettle drums, rising sirens, volcanic bubbling low-end drones, intense aggressive brass blasts, high-stakes sports showdown rhythm.*

#### OST 13: "Clockwork Planets in Motion" (Arena: `orrery`)
- **ID**: `ost_orrery`
- **File**: `res://assets/audio/music/ost_orrery.ogg`
- **Arena**: Grande Planetario
- **Key**: D major / B minor | **BPM**: 126 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Grand mechanical clockwork symphony, intricate interlocking staccato strings, metallic chime bells, steady punchy electro beat, brass section crescendo, celestial orbit soundscapes, triumphant and precise.*

---

### Category C: World Circuit Arenas (The 5 Global Arenas)

#### OST 14: "Steam Over Gion" (Arena: `torii`)
- **ID**: `ost_torii`
- **File**: `res://assets/audio/music/ost_torii.ogg`
- **Arena**: Torii (Kyoto Imperial Steam Garden)
- **Key**: D Hirajoshi / D minor | **BPM**: 116 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Japanese steampunk hybrid, energetic shamisen pluck riffs, breathy shakuhachi flute melodies, punchy hip-hop breakbeat with wooden clackers and steam valve percussion, harmonious traditional oriental scales with electronic bass drive.*

#### OST 15: "Mirage of the Brass Minaret" (Arena: `medina`)
- **ID**: `ost_medina`
- **File**: `res://assets/audio/music/ost_medina.ogg`
- **Arena**: Medina Mirage Clocktower
- **Key**: D Hijaz | **BPM**: 122 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Middle-Eastern steampunk groove, virtuosic electric oud melodies, driving darbuka and riq polyrhythms, warm brass horns, desert wind whooshes, hypnotic synth bassline, vibrant bustling arcade arena.*

#### OST 16: "Carnival Across the Aqueduct" (Arena: `carioca`)
- **ID**: `ost_carioca`
- **File**: `res://assets/audio/music/ost_carioca.ogg`
- **Arena**: Carioca Aerial Viaduct
- **Key**: G major | **BPM**: 134 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Steampunk samba batucada, furious surdo and cuica rhythm section fused with clanking metal gears, jubilant brass horn riffs, whistling steam whistles, celebratory sunny arcade padel match energy, exuberant tropical steampunk.*

#### OST 17: "Cryo-Steam Horizon" (Arena: `aurora`)
- **ID**: `ost_aurora`
- **File**: `res://assets/audio/music/ost_aurora.ogg`
- **Arena**: Aurora Cryo-Steam Observatory
- **Key**: A minor | **BPM**: 120 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Nordic cryo-steampunk soundtrack, bowed tagelharpa and crystalline glockenspiel, frozen metallic impacts, icy synth pads sweeping like the northern lights, steady resolute kick drum, vast arctic sky sports ambiance.*

#### OST 18: "Aegean Bronze Amphitheatre" (Arena: `egeo`)
- **ID**: `ost_egeo`
- **File**: `res://assets/audio/music/ost_egeo.ogg`
- **Arena**: Aegean Colosseum
- **Key**: E Phrygian Dominant | **BPM**: 128 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Mediterranean heroic steampunk theme, lightning-fast bouzouki lead licks, grand cinematic brass chords, rhythmic bronze anvil clangs, driving four-on-the-floor beat, sun-drenched coastal arena glory.*

---

### Category D: Special Arenas & Match Climax

#### OST 19: "Echoes of the Founders" (Arena: `heritage_hall`)
- **ID**: `ost_heritage_hall`
- **File**: `res://assets/audio/music/ost_heritage_hall.ogg`
- **Arena**: Heritage Hall
- **Key**: C minor | **BPM**: 115 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Chamber steampunk fusion, elegant classical string quartet ostinato, subtle 808-style vintage analog kick and snare, grand piano flourishes, ticking grandfather clock, dignified royal sports hall ambiance.*

#### OST 20: "Locomotive Express Rally" (Arena: `steam_workshop` / Passing Train)
- **ID**: `ost_steam_workshop`
- **File**: `res://assets/audio/music/ost_steam_workshop.ogg`
- **Arena**: Steam Workshop with Passing Train
- **Key**: E minor | **BPM**: 138 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Fast locomotive steam-train rhythm, chugging piston drums accelerating like a train on tracks, bluesy slide guitar riffs with brass accompaniment, doppler train whistle fx, intense adrenaline padel match pacing.*

#### OST 21: "Pressure Gauge Critical" (Match Point / Deuce Climax)
- **ID**: `ost_climax`
- **File**: `res://assets/audio/music/ost_climax.ogg`
- **Match State**: Match Point, Set Point, Deuce, or Tie-Break
- **Key**: D minor | **BPM**: 140 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Extreme climax sports match point tension, accelerating heartbeat mechanical bass drum, rising steam pressure sirens, stuttering distorted synth arpeggios, urgent staccato strings, peak tournament final suspense.*

#### OST 22: "Brass Laurels & Steam Anthem" (Victory Ceremony)
- **ID**: `ost_victory`
- **File**: `res://assets/audio/music/ost_victory.ogg`
- **Match State**: Post-match Victory & Award Screen
- **Key**: C major | **BPM**: 110 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Triumphant steampunk victory fanfare, glorious brass section theme, celebratory snare roll cadence, steam cannon bursts, uplifting major chords, regal and heroic arcade trophy presentation.*

---

### 6. Epic / Anime Steampunk Expansion Set (OST 23 – 30)

#### OST 23: "Steam Spiral Overdrive" (Opening Theme & Circuit Anthem)
- **ID**: `ost_epic_anthem`
- **File**: `res://assets/audio/music/ost_epic_anthem.ogg`
- **Context**: Opening Cinematic, Special Events & Championship Intro
- **Key**: E minor | **BPM**: 150 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Epic shonen anime sports opening theme, high-energy symphonic J-Rock with blazing melodic electric guitars, soaring cinematic violins, fast driving rock drum beat with double kick bursts, brass section counterpoint, soaring heroic melody, polished modern anime soundtrack mix.*

#### OST 24: "Gears of Destiny" (Tournament Semifinals)
- **ID**: `ost_epic_semifinal`
- **File**: `res://assets/audio/music/ost_epic_semifinal.ogg`
- **Context**: Tournament Semifinal Showdowns (`TournamentScreen`)
- **Key**: D minor | **BPM**: 145 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Urgent cinematic anime battle theme, intense staccato string ostinato, pounding hybrid orchestral percussion, heavy metal anvil accents, aggressive synth bassline, fast syncopated breakbeat, soaring brass fanfare climax, high-stakes tournament tension.*

#### OST 25: "Zenith of the Champions" (Tournament Grand Final)
- **ID**: `ost_epic_grand_final`
- **File**: `res://assets/audio/music/ost_epic_grand_final.ogg`
- **Context**: Grand Final Trophy Match & Championship Point
- **Key**: B minor | **BPM**: 148 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Monumental orchestral anime sports climax, Hiroyuki Sawano style, thunderous orchestral drops, chugging distorted power chords, majestic choir pad swells, emotive lead violin solo soaring over energetic four-on-the-floor beat, colossal steam blast transitions.*

#### OST 26: "Aether Clash: The Legendary Duel" (Legend Tier Rival Boss)
- **ID**: `ost_epic_rival_legend`
- **File**: `res://assets/audio/music/ost_epic_rival_legend.ogg`
- **Context**: Matches against Legendary Tier AI Opponents
- **Key**: F# minor | **BPM**: 155 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Fast anime rival battle theme, virtuoso electric guitar lead duel, furious slap bass groove, rapid clockwork snare rolls, rushing pressurized steam bursts, neoclassical harpsichord runs, triumphant adrenaline duel pacing.*

#### OST 27: "Overclock Awakening" (Steam Gauge 100% Super State)
- **ID**: `ost_epic_awakening`
- **File**: `res://assets/audio/music/ost_epic_awakening.ogg`
- **Context**: Triggered at 100% Steam Pressure / Max Rally Overdrive
- **Key**: A minor | **BPM**: 165 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Ultra high-speed power metal anime awakening soundtrack, galloping double-bass drum rhythm, twin lead guitar harmonies, blazing synthesizer arpeggios, emergency steam valve releases, invincible heroic sports turnaround mood.*

#### OST 28: "Zero Hour: The Final Point" (Decisive Sudden Death Deuce)
- **ID**: `ost_epic_sudden_death`
- **File**: `res://assets/audio/music/ost_epic_sudden_death.ogg`
- **Context**: Sudden Death, Golden Point, Endless Deuce
- **Key**: D minor | **BPM**: 142 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Colossal anime sports final deuce tension, racing heartbeat sub-bass thumps, ticking pocket watch panic, rising orchestral string risers, sharp anvil strikes on the offbeats, heart-stopping dramatic suspense.*

#### OST 29: "Wings of Brass & Glory" (Legendary Championship Ascension)
- **ID**: `ost_epic_ascension`
- **File**: `res://assets/audio/music/ost_epic_ascension.ogg`
- **Context**: Legendary Trophy Presentation & Hall of Fame Induction
- **Key**: G major | **BPM**: 130 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Emotional and triumphant anime victory anthem, grand orchestral brass melody, soaring violin hooks, uplifting major-key harmonies, celebratory timpani rolls, steam fireworks fx, royal golden trophy celebration.*

#### OST 30: "Defiance in the Steam" (Epic Rematch & Comeback)
- **ID**: `ost_epic_rematch`
- **File**: `res://assets/audio/music/ost_epic_rematch.ogg`
- **Context**: Immediate Rematch after Defeat / Comeback Set
- **Key**: C minor | **BPM**: 138 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Determined and heroic anime comeback theme, driving industrial steel groove, resolute cello riffs growing into a powerful symphonic rock wall of sound, pulsing clockwork synth, indomitable will to win.*

---

### Category G: Sawano / Attack on Titan Special Suite (6 Tracks)

#### OST 31: "ət'æk:0N:WALL" (Colossal Breach & Boss Match Intro)
- **ID**: `ost_sawano_titan_breach`
- **File**: `res://assets/audio/music/ost_sawano_titan_breach.ogg`
- **Context**: Boss Match Intro & Invasione Campo (`titan_breach`)
- **Key**: C minor | **BPM**: 135 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Epic orchestral symphonic metal in the unmistakable style of Hiroyuki Sawano (Attack on Titan / Vogel im Käfig). Heavy colossal timpani and taiko stomps, unison brass French horns screaming a soaring tragic melody in C minor, sudden dramatic drop into ticking clockwork tension, followed by explosive distorted guitar wall-of-sound with choral accents.*

#### OST 32: "K21:Vanguard" (Counter-Rally & High Stakes Turnaround)
- **ID**: `ost_sawano_counterattack`
- **File**: `res://assets/audio/music/ost_sawano_counterattack.ogg`
- **Context**: Rimonta Epica / Break Point Critico (`counterattack`)
- **Key**: D minor | **BPM**: 142 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Hiroyuki Sawano hybrid orchestral rap-rock battle theme (inspired by K21 and Before Lights Out). Fast syncopated hip-hop snare beat, screeching overdrive guitars, rapid staccato violin runs, heroic brass answers, intense motivational sports combat drive.*

#### OST 33: "FLÜGEL:der:Freiheit" (Scouting Overdrive & Championship Semifinals)
- **ID**: `ost_sawano_wings_of_freedom`
- **File**: `res://assets/audio/music/ost_sawano_wings_of_freedom.ogg`
- **Context**: Semifinali Torneo & Battaglia per la Libertà (`wings_of_freedom`)
- **Key**: G minor | **BPM**: 154 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Hiroyuki Sawano heroic anime anthem (style of The Reluctant Heroes and Bauklötze). Soaring lead violin melody, driving symphonic power metal drum double-kick, energetic German-style choir stabs, brass fanfares, euphoric sense of speed and freedom.*

#### OST 34: "T:T" (Shiganshina Requiem & Sudden Death Deuce)
- **ID**: `ost_sawano_shiganshina_cry`
- **File**: `res://assets/audio/music/ost_sawano_shiganshina_cry.ogg`
- **Context**: Match Point Decisivo / Deuce a Oltranza (`shiganshina_cry`)
- **Key**: E minor | **BPM**: 128 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Dramatic emotional anime soundtrack (style of YouSeeBIGGIRL/T:T and Call of Silence). Melancholic solo cello intro over ambient breathy pads, sudden silence heartbeat drop, erupting into a colossal symphonic choir climax with thundering percussion and weeping brass chords.*

#### OST 35: "XL-TT" (Padel Colossus & Berserk Super Smash)
- **ID**: `ost_sawano_colossal_smash`
- **File**: `res://assets/audio/music/ost_sawano_colossal_smash.ogg`
- **Context**: Steam Gauge 100% / Super Colpo Speciale (`colossal_smash`)
- **Key**: F# minor | **BPM**: 148 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *Hiroyuki Sawano colossal monster battle music (style of XL-TT and APETITAN). Earth-shaking industrial sub-bass thumps, distorted synth arpeggios pulsing in F# minor, massive orchestral brass stabs, adrenaline-fueled titan confrontation.*

#### OST 36: "bà:R1CADES" (Final Wall & Grand Championship Anthem)
- **ID**: `ost_sawano_barricades`
- **File**: `res://assets/audio/music/ost_sawano_barricades.ogg`
- **Context**: Finalissima Scudetto & Inno di Gloria (`barricades`)
- **Key**: A minor | **BPM**: 160 | **Time Signature**: 4/4
- **Prompt for Lyria**:
  > *High-octane Hiroyuki Sawano J-Rock orchestral anthem (style of Barricades and ət'æk 0N t'aɪtn). Driving 160 BPM drum beat, soaring twin lead guitars, uplifting choir chants, heroic trumpet hooks, emotional climax for a world championship victory.*

