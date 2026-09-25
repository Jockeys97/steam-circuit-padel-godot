extends Node
## soundtrack_manager.gd — Complete OST and Dynamic Music Manager for Steam Circuit Padel Pro.
##
## WHAT IT DOES:
##   Manages playback and smooth crossfades for the 47 orchestral/steampunk OST tracks.
##   Resolves arena and menu contexts to track IDs, streams audio files from
##   `res://assets/audio/music/`, and routes audio directly to the engine's `Music` bus.
##
## SAFE FALLBACK DESIGN:
##   If an audio file (.ogg/.mp3/.wav) is not present on disk, operations return false
##   or remain silent gracefully without failing assertions or throwing runtime errors.
##   This guarantees 100% compatibility with headless tests and the existing procedural
##   sequencer (`music.gd`).

const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_BUS_NAME := "Music"
const MixerContract := preload("res://src/audio/mixer_contract.gd")

## Complete mapping of arenas and UI states to track IDs
const ARENA_TRACK_MAP := {
	# 9 Frozen Roster Arenas
	"officina": "ost_officina",
	"fonderia": "ost_fonderia",
	"cattedrale": "ost_cattedrale",
	"forgia": "ost_forgia",
	"osservatorio": "ost_osservatorio",
	"tempesta": "ost_tempesta",
	"abissale": "ost_abissale",
	"caldera": "ost_caldera",
	"orrery": "ost_orrery",
	# 5 World Circuit Arenas
	"torii": "ost_torii",
	"medina": "ost_medina",
	"carioca": "ost_carioca",
	"aurora": "ost_aurora",
	"egeo": "ost_egeo",
	# 2 New Arenas
	"heritage_hall": "ost_heritage_hall",
	"steam_workshop": "ost_steam_workshop",
}

const CONTEXT_TRACK_MAP := {
	"menu": "ost_menu",
	"roster": "ost_roster",
	"career": "ost_career",
	"training": "ost_training",
	"climax": "ost_climax",
	"victory": "ost_victory",
	# 8 Epic / Anime Steampunk Additions
	"epic_anthem": "ost_epic_anthem",
	"epic_semifinal": "ost_epic_semifinal",
	"epic_grand_final": "ost_epic_grand_final",
	"epic_rival_legend": "ost_epic_rival_legend",
	"epic_awakening": "ost_epic_awakening",
	"epic_sudden_death": "ost_epic_sudden_death",
	"epic_ascension": "ost_epic_ascension",
	"epic_rematch": "ost_epic_rematch",
	# 12 Sawano / Attack on Titan Special Suite (6 Instrumental + 6 Vocal Anthems)
	"titan_breach": "ost_sawano_titan_breach",
	"titan_breach_vocal": "ost_sawano_titan_breach_vocal",
	"counterattack": "ost_sawano_counterattack",
	"k21_vocal": "ost_sawano_k21_vocal",
	"wings_of_freedom": "ost_sawano_wings_of_freedom",
	"wings_of_freedom_vocal": "ost_sawano_wings_of_freedom_vocal",
	"shiganshina_cry": "ost_sawano_shiganshina_cry",
	"shiganshina_cry_vocal": "ost_sawano_shiganshina_cry_vocal",
	"colossal_smash": "ost_sawano_colossal_smash",
	"colossal_smash_vocal": "ost_sawano_colossal_smash_vocal",
	"barricades": "ost_sawano_barricades",
	"barricades_vocal": "ost_sawano_barricades_vocal",
	# 5 Dragon Ball GT / 90s Anime Suite (2 Sung Vocal Anthems + 3 Instrumentals)
	"dbgt_dan_dan_vocal": "ost_dbgt_dan_dan_vocal",
	"dbgt_dont_you_see_vocal": "ost_dbgt_dont_you_see_vocal",
	"dbgt_grand_tour": "ost_dbgt_grand_tour",
	"dbgt_super_saiyan_4": "ost_dbgt_super_saiyan_4",
	"dbgt_sabitsuita_machine_gun": "ost_dbgt_sabitsuita_machine_gun",
	# 15 Automata Suite (Acoustic / Choral / Orchestral)
	"rays_of_rust": "ost_rays_of_rust",
	"weight_of_the_rally": "ost_weight_of_the_rally",
	"beautiful_duel": "ost_beautiful_duel",
	"memories_of_sand": "ost_memories_of_sand",
	"rebirth_of_hope": "ost_rebirth_of_hope",
	"broken_monolith": "ost_broken_monolith",
	"city_of_pearls": "ost_city_of_pearls",
	"tears_of_porcelain": "ost_tears_of_porcelain",
	"hymn_of_the_ancients": "ost_hymn_of_the_ancients",
	"ashes_of_destiny": "ost_ashes_of_destiny",
	"carnival_of_illusions": "ost_carnival_of_illusions",
	"verdant_whispers": "ost_verdant_whispers",
	"abyssal_silence": "ost_abyssal_silence",
	"dance_of_the_blade": "ost_dance_of_the_blade",
	"cradle_of_waves": "ost_cradle_of_waves",
	# 1 Hunter x Hunter Special Vocal Anthem
	"hyori_ittai_vocal": "ost_hyori_ittai_vocal",
	# 15 Legendary Game Menu Themes
	"menu_velvet_lounge": "ost_menu_velvet_lounge",
	"menu_grand_touring": "ost_menu_grand_touring",
	"menu_astral_solitude": "ost_menu_astral_solitude",
	"menu_dearly_reminiscent": "ost_menu_dearly_reminiscent",
	"menu_cyber_terminal": "ost_menu_cyber_terminal",
	"menu_breeze_plaza": "ost_menu_breeze_plaza",
	"menu_sacred_spring": "ost_menu_sacred_spring",
	"menu_ancient_sanctum": "ost_menu_ancient_sanctum",
	"menu_rainy_atrium": "ost_menu_rainy_atrium",
	"menu_chronicle_winds": "ost_menu_chronicle_winds",
	"menu_subaquatic_drift": "ost_menu_subaquatic_drift",
	"menu_northern_aurora": "ost_menu_northern_aurora",
	"menu_champions_pavilion": "ost_menu_champions_pavilion",
	"menu_orbital_vanguard": "ost_menu_orbital_vanguard",
	"menu_third_strike": "ost_menu_third_strike",
	# 19 Canzoni Cantate Speciali (Suno Vocal Anthems)
	"vocal_overdrive_line": "ost_vocal_overdrive_line",
	"vocal_break_point_riot": "ost_vocal_break_point_riot",
	"vocal_reach_for_the_sun": "ost_vocal_reach_for_the_sun",
	"vocal_neon_velocity": "ost_vocal_neon_velocity",
	"vocal_girei": "ost_vocal_girei",
	"vocal_gleiches_blut": "ost_vocal_gleiches_blut",
	"vocal_tie_break_burn": "ost_vocal_tie_break_burn",
	"vocal_maschine_jagd": "ost_vocal_maschine_jagd",
	"vocal_schwarzmarkt": "ost_vocal_schwarzmarkt",
	"vocal_nullpunkt": "ost_vocal_nullpunkt",
	"vocal_zheleznaia_volya": "ost_vocal_zheleznaia_volya",
	"vocal_double_rebond": "ost_vocal_double_rebond",
	"vocal_oltre_il_vetro": "ost_vocal_oltre_il_vetro",
	"vocal_padelista_energy": "ost_vocal_padelista_energy",
	"vocal_balle_de_match": "ost_vocal_balle_de_match",
	"vocal_por_tres": "ost_vocal_por_tres",
	"vocal_bandeja_chic": "ost_vocal_bandeja_chic",
	"vocal_bandeja_chic_catchy": "ost_vocal_bandeja_chic_catchy",
	"vocal_bandeja_chic_rap": "ost_vocal_bandeja_chic_rap",
	# 5 Nuove Tracce Boss & Battle Champions Special (Epico / Anime Special)
	"apex_victory": "ost_apex_victory",
	"clash_of_champions": "ost_clash_of_champions",
	"reflex_strike": "ost_reflex_strike",
	"iron_juggernaut": "ost_iron_juggernaut",
	"thunder_strike": "ost_thunder_strike",
}

## Complete metadata dictionary for all 102 OST tracks (22 Standard + 13 Epic/Anime + 12 Sawano + 5 DBGT + 15 Automata + 1 HxH + 15 Menu Legends + 19 Canzoni Cantate)
const TRACK_METADATA := {
	"ost_menu": {
		"id": "ost_menu",
		"title": "Steam Circuit Overture",
		"scene": "Menu Principale & Titolo",
		"category": "Menu & Sistema",
		"bpm": 118,
		"key": "D minor",
		"style": "Electro-Swing Steampunk con ottoni ed effetti a vapore",
		"prompt": "A high-energy steampunk electro-swing main theme for an arcade sports game. Upright acoustic bass groove, syncopated brass section with muted trumpets and trombones, vintage gramophone crackle, clockwork tick-tock percussion, piston steam release fx on downbeats, driving swing rhythm, Victorian grand adventure melody, polished modern mix."
	},
	"ost_roster": {
		"id": "ost_roster",
		"title": "The Grand Roster & Atelier",
		"scene": "Selezione Atleti & Guardaroba",
		"category": "Menu & Sistema",
		"bpm": 105,
		"key": "A minor",
		"style": "Gypsy Jazz Manouche con chitarra acustica e carillon",
		"prompt": "Mid-tempo gypsy jazz manouche infused with steampunk clockwork textures. Fast acoustic guitar rhythm chords, melancholic yet playful accordion lead, delicate music box arpeggios, gentle upright bass, subtle mechanical gear clicks as percussion, elegant Victorian Parisian workshop atmosphere."
	},
	"ost_career": {
		"id": "ost_career",
		"title": "Circuit Board & Career Roadmap",
		"scene": "Tabellone & Calendario Carriera",
		"category": "Menu & Sistema",
		"bpm": 95,
		"key": "E minor",
		"style": "Neo-Victorian Ambient Synth con violoncello e campane",
		"prompt": "Sophisticated steampunk menu ambiance, brooding solo cello counterpoint over atmospheric analog synth pads, ticking pocket watch pulses, tubular bells, subtle brass chimes, methodical and strategic feeling, high-stakes Victorian tournament preparation."
	},
	"ost_training": {
		"id": "ost_training",
		"title": "The Maestro's Tactical Workshop",
		"scene": "Campo Allenamento / Coach Jev",
		"category": "Menu & Sistema",
		"bpm": 124,
		"key": "C minor",
		"style": "Minimal Steampunk Tech-House con ingranaggi e marimba",
		"prompt": "Focus and training arcade theme, minimal steampunk tech-house, tight clean bassline, rhythmic clicking gear loops, soft marimba ostinato, subtle pressurized steam valve accents, hypnotic arpeggiated analog synth, disciplined athletic atmosphere."
	},
	"ost_officina": {
		"id": "ost_officina",
		"title": "Pistons in the Foundry",
		"scene": "Arena Officina Meccanica",
		"category": "Arena Frozen",
		"bpm": 128,
		"key": "F minor",
		"style": "Industrial Funk con incudini, pressa idraulica e slap bass",
		"prompt": "Industrial funk sports arena track, heavy anvil strikes, rhythmic hydraulic press beats, distorted clavinet riffs, driving syncopated four-on-the-floor kick, steam hiss transitions, aggressive bassline, energetic workshop match ambiance."
	},
	"ost_fonderia": {
		"id": "ost_fonderia",
		"title": "Molten Heart Furnace",
		"scene": "Arena Fonderia a Vapore",
		"category": "Arena Frozen",
		"bpm": 132,
		"key": "D minor",
		"style": "Dark Industrial Rock / Synthwave con tamburi da guerra",
		"prompt": "High-intensity industrial synthwave rock, pounding resonant war drums, chugging mechanical guitar grooves, distorted analog synth leads, roaring blast furnace soundscapes, energetic fast-paced padel rally pacing."
	},
	"ost_cattedrale": {
		"id": "ost_cattedrale",
		"title": "Clockwork Nave",
		"scene": "Arena Cattedrale degli Ingranaggi",
		"category": "Arena Frozen",
		"bpm": 135,
		"key": "G minor",
		"style": "Organo a canne barocco ibridato con breakbeat frenetico",
		"prompt": "Gothic steampunk hybrid, majestic pipe organ motifs layered over fast breakbeat drums, resonant choir vocal pads, cathedral hall reverberation, metallic pendulum swings, dramatic baroque counterpoint with electronic arcade drive."
	},
	"ost_forgia": {
		"id": "ost_forgia",
		"title": "Tesla Coil Arc",
		"scene": "Arena Forgia Elettrica",
		"category": "Arena Frozen",
		"bpm": 130,
		"key": "B minor",
		"style": "Electro-Industrial con arpeggiatori a 16esimi e bassi acid",
		"prompt": "High-voltage electro-industrial soundtrack, buzzing electric arpeggios, snappy punchy snare, buzzing sawtooth basslines, metallic laser zap transients, relentless energetic sports pacing, crackling lightning textures."
	},
	"ost_osservatorio": {
		"id": "ost_osservatorio",
		"title": "Astrolabe Horizon",
		"scene": "Arena Osservatorio Astronomico",
		"category": "Arena Frozen",
		"bpm": 125,
		"key": "A minor",
		"style": "Celestial Synthwave con melodie di flauto d'ottone e pad",
		"prompt": "Victorian celestial synthwave, glittering music box melodies, soaring brass trumpet hooks, lush retro pad swells, clockwork telescope gears revolving, deep round sub-bass, wonderous yet competitive athletic arcade tempo."
	},
	"ost_tempesta": {
		"id": "ost_tempesta",
		"title": "Gale Force Turbine",
		"scene": "Arena Tempesta Eolica",
		"category": "Arena Frozen",
		"bpm": 160,
		"key": "F# minor",
		"style": "Liquid Drum & Bass con fiati a raffica e breakbeat rapido",
		"prompt": "Steampunk liquid drum and bass, rushing aerodynamic synth sweeps, fast rolling acoustic breakbeats, urgent brass stabs, whistling wind pressure bursts, agile and rapid rally tempo, clean modern club mix."
	},
	"ost_abissale": {
		"id": "ost_abissale",
		"title": "Bathysphere Depth",
		"scene": "Arena Profondità Abissali",
		"category": "Arena Frozen",
		"bpm": 120,
		"key": "C# minor",
		"style": "Deep Industrial Dub con sonar d'ottone e sub-bass oceanico",
		"prompt": "Atmospheric deep industrial dub, heavy sub-bass pulses, pinging brass sonar pings, muffled steam vents, subaquatic reverberations, crisp metallic rimshot percussion, dark and mysterious deep-sea arena match."
	},
	"ost_caldera": {
		"id": "ost_caldera",
		"title": "Magma Chamber Deuce",
		"scene": "Arena Caldera Vulcanica",
		"category": "Arena Frozen",
		"bpm": 136,
		"key": "E minor",
		"style": "Tribal Industrial con tamburi taiko e trombe a vapore",
		"prompt": "Tribal industrial battle soundtrack, thunderous taiko and bronze kettle drums, rising sirens, volcanic bubbling low-end drones, intense aggressive brass blasts, high-stakes sports showdown rhythm."
	},
	"ost_orrery": {
		"id": "ost_orrery",
		"title": "Clockwork Planets in Motion",
		"scene": "Arena Grande Planetario",
		"category": "Arena Frozen",
		"bpm": 126,
		"key": "D major",
		"style": "Sinfonia meccanica staccata e carillon monumentali",
		"prompt": "Grand mechanical clockwork symphony, intricate interlocking staccato strings, metallic chime bells, steady punchy electro beat, brass section crescendo, celestial orbit soundscapes, triumphant and precise."
	},
	"ost_torii": {
		"id": "ost_torii",
		"title": "Steam Over Gion",
		"scene": "Arena Mondiale Torii (Kyoto)",
		"category": "Arena Mondiale",
		"bpm": 116,
		"key": "D minor",
		"style": "Shamisen ed Shakuhachi con beat hip-hop e percussioni lignee",
		"prompt": "Japanese steampunk hybrid, energetic shamisen pluck riffs, breathy shakuhachi flute melodies, punchy hip-hop breakbeat with wooden clackers and steam valve percussion, harmonious traditional oriental scales with electronic bass drive."
	},
	"ost_medina": {
		"id": "ost_medina",
		"title": "Mirage of the Brass Minaret",
		"scene": "Arena Mondiale Medina",
		"category": "Arena Mondiale",
		"bpm": 122,
		"key": "D Hijaz",
		"style": "Oud elettrico virtuosistico, darbuka e synthwave calda",
		"prompt": "Middle-Eastern steampunk groove, virtuosic electric oud melodies, driving darbuka and riq polyrhythms, warm brass horns, desert wind whooshes, hypnotic synth bassline, vibrant bustling arcade arena."
	},
	"ost_carioca": {
		"id": "ost_carioca",
		"title": "Carnival Across the Aqueduct",
		"scene": "Arena Mondiale Carioca (Rio)",
		"category": "Arena Mondiale",
		"bpm": 134,
		"key": "G major",
		"style": "Samba Batucada a vapore con fischietti e fiati festosi",
		"prompt": "Steampunk samba batucada, furious surdo and cuica rhythm section fused with clanking metal gears, jubilant brass horn riffs, whistling steam whistles, celebratory sunny arcade padel match energy, exuberant tropical steampunk."
	},
	"ost_aurora": {
		"id": "ost_aurora",
		"title": "Cryo-Steam Horizon",
		"scene": "Arena Mondiale Aurora (Nordica)",
		"category": "Arena Mondiale",
		"bpm": 120,
		"key": "A minor",
		"style": "Tagelharpa nordica, glockenspiel e pad boreali ghiacciati",
		"prompt": "Nordic cryo-steampunk soundtrack, bowed tagelharpa and crystalline glockenspiel, frozen metallic impacts, icy synth pads sweeping like the northern lights, steady resolute kick drum, vast arctic sky sports ambiance."
	},
	"ost_egeo": {
		"id": "ost_egeo",
		"title": "Aegean Bronze Amphitheatre",
		"scene": "Arena Mondiale Egeo (Colosseo)",
		"category": "Arena Mondiale",
		"bpm": 128,
		"key": "E Phrygian",
		"style": "Bouzouki greco, archi eroici e rullante d'incudine a 4/4",
		"prompt": "Mediterranean heroic steampunk theme, lightning-fast bouzouki lead licks, grand cinematic brass chords, rhythmic bronze anvil clangs, driving four-on-the-floor beat, sun-drenched coastal arena glory."
	},
	"ost_heritage_hall": {
		"id": "ost_heritage_hall",
		"title": "Echoes of the Founders",
		"scene": "Nuova Arena Heritage Hall",
		"category": "Arena Speciale",
		"bpm": 115,
		"key": "C minor",
		"style": "Chamber Orchestra nobile con quartetto d'archi e beat 808",
		"prompt": "Chamber steampunk fusion, elegant classical string quartet ostinato, subtle 808-style vintage analog kick and snare, grand piano flourishes, ticking grandfather clock, dignified royal sports hall ambiance."
	},
	"ost_steam_workshop": {
		"id": "ost_steam_workshop",
		"title": "Locomotive Express Rally",
		"scene": "Nuova Arena Steam Workshop",
		"category": "Arena Speciale",
		"bpm": 138,
		"key": "E minor",
		"style": "Train-Chug blues accelerato con chitarra slide e fischi treno",
		"prompt": "Fast locomotive steam-train rhythm, chugging piston drums accelerating like a train on tracks, bluesy slide guitar riffs with brass accompaniment, doppler train whistle fx, intense adrenaline padel match pacing."
	},
	"ost_climax": {
		"id": "ost_climax",
		"title": "Pressure Gauge Critical",
		"scene": "Match Point / Deuce / Climax",
		"category": "Fasi Partita",
		"bpm": 140,
		"key": "D minor",
		"style": "Tensione cinematografica con battito cardiaco e riser",
		"prompt": "Extreme climax sports match point tension, accelerating heartbeat mechanical bass drum, rising steam pressure sirens, stuttering distorted synth arpeggios, urgent staccato strings, peak tournament final suspense."
	},
	"ost_victory": {
		"id": "ost_victory",
		"title": "Brass Laurels & Steam Anthem",
		"scene": "Cerimonia di Vittoria / Risultati",
		"category": "Fasi Partita",
		"bpm": 110,
		"key": "C major",
		"style": "Fanfara trionfale d'ottoni in stile parata e coriandoli",
		"prompt": "Triumphant steampunk victory fanfare, glorious brass section theme, celebratory snare roll cadence, steam cannon bursts, uplifting major chords, regal and heroic arcade trophy presentation."
	},
	# 8 Epic / Anime Steampunk OST Tracks
	"ost_epic_anthem": {
		"id": "ost_epic_anthem",
		"title": "Steam Spiral Overdrive",
		"scene": "Sigla d'Apertura & Eventi Speciali",
		"category": "Epico / Anime Special",
		"bpm": 150,
		"key": "E minor",
		"style": "J-Rock sinfonico a vapore, chitarre epiche, ottoni e arpeggiatori veloci",
		"prompt": "Epic shonen anime sports opening theme, high-energy symphonic J-Rock with blazing melodic electric guitars, soaring cinematic violins, fast driving rock drum beat with double kick bursts, brass section counterpoint, soaring heroic melody, polished modern anime soundtrack mix."
	},
	"ost_epic_semifinal": {
		"id": "ost_epic_semifinal",
		"title": "Gears of Destiny",
		"scene": "Semifinali di Torneo & Sfide Decisive",
		"category": "Epico / Anime Special",
		"bpm": 145,
		"key": "D minor",
		"style": "Violini staccati epici, breakbeat incalzante e drop di percussioni d'acciaio",
		"prompt": "Urgent cinematic anime battle theme, intense staccato string ostinato, pounding hybrid orchestral percussion, heavy metal anvil accents, aggressive synth bassline, fast syncopated breakbeat, soaring brass fanfare climax, high-stakes tournament tension."
	},
	"ost_epic_grand_final": {
		"id": "ost_epic_grand_final",
		"title": "Zenith of the Champions",
		"scene": "Finalissima per il Trofeo & Match Scudetto",
		"category": "Epico / Anime Special",
		"bpm": 148,
		"key": "B minor",
		"style": "Stile Hiroyuki Sawano: drop orchestrali, chitarre distorte e coro a piena potenza",
		"prompt": "Monumental orchestral anime sports climax, Hiroyuki Sawano style, thunderous orchestral drops, chugging distorted power chords, majestic choir pad swells, emotive lead violin solo soaring over energetic four-on-the-floor beat, colossal steam blast transitions."
	},
	"ost_epic_rival_legend": {
		"id": "ost_epic_rival_legend",
		"title": "Aether Clash: The Legendary Duel",
		"scene": "Sfida contro Atleta Tier Leggenda",
		"category": "Epico / Anime Special",
		"bpm": 155,
		"key": "F# minor",
		"style": "Battaglia anime shonen ad alta velocità, slap bass a vapore e assoli melodici",
		"prompt": "Fast anime rival battle theme, virtuoso electric guitar lead duel, furious slap bass groove, rapid clockwork snare rolls, rushing pressurized steam bursts, neoclassical harpsichord runs, triumphant adrenaline duel pacing."
	},
	"ost_epic_awakening": {
		"id": "ost_epic_awakening",
		"title": "Overclock Awakening",
		"scene": "Steam Gauge 100% & Overdrive",
		"category": "Epico / Anime Special",
		"bpm": 165,
		"key": "A minor",
		"style": "Power metal steampunk neoclassico, doppia cassa e arpeggi laser",
		"prompt": "Ultra high-speed power metal anime awakening soundtrack, galloping double-bass drum rhythm, twin lead guitar harmonies, blazing synthesizer arpeggios, emergency steam valve releases, invincible heroic sports turnaround mood."
	},
	"ost_epic_sudden_death": {
		"id": "ost_epic_sudden_death",
		"title": "Zero Hour: The Final Point",
		"scene": "Match Point Decisivo / Deuce a Oltranza",
		"category": "Epico / Anime Special",
		"bpm": 142,
		"key": "D minor",
		"style": "Tensione cinematografica colossale con battito cardiaco e archi drammatici",
		"prompt": "Colossal anime sports final deuce tension, racing heartbeat sub-bass thumps, ticking pocket watch panic, rising orchestral string risers, sharp anvil strikes on the offbeats, heart-stopping dramatic suspense."
	},
	"ost_epic_ascension": {
		"id": "ost_epic_ascension",
		"title": "Wings of Brass & Glory",
		"scene": "Cerimonia Titolo Leggendario & Credits",
		"category": "Epico / Anime Special",
		"bpm": 130,
		"key": "G major",
		"style": "Inno trionfale anime, melodie svettanti di violino e ottoni regali",
		"prompt": "Emotional and triumphant anime victory anthem, grand orchestral brass melody, soaring violin hooks, uplifting major-key harmonies, celebratory timpani rolls, steam fireworks fx, royal golden trophy celebration."
	},
	"ost_epic_rematch": {
		"id": "ost_epic_rematch",
		"title": "Defiance in the Steam",
		"scene": "Rivincita Immediata / 'Never Give Up'",
		"category": "Epico / Anime Special",
		"bpm": 138,
		"key": "C minor",
		"style": "Groove d'acciaio in crescendo con progressione eroica",
		"prompt": "Determined and heroic anime comeback theme, driving industrial steel groove, resolute cello riffs growing into a powerful symphonic rock wall of sound, pulsing clockwork synth, indomitable will to win."
	},
	# 12 Sawano / Attack on Titan Special Tracks (6 Instrumental + 6 Vocal Anthems)
	"ost_sawano_titan_breach": {
		"id": "ost_sawano_titan_breach",
		"title": "ət'æk:0N:WALL (Colossal Breach)",
		"scene": "Boss Match Intro & Invasione Campo",
		"category": "Sawano / Titan Special",
		"bpm": 135,
		"key": "C minor",
		"style": "Orchestrale drammatico con corni in unisono, timpani colossali e power metal drop",
		"prompt": "Epic orchestral symphonic metal in the unmistakable style of Hiroyuki Sawano (Attack on Titan / Vogel im Käfig). Heavy colossal timpani and taiko stomps, unison brass French horns screaming a soaring tragic melody in C minor, sudden dramatic drop into ticking clockwork tension, followed by explosive distorted guitar wall-of-sound with choral accents."
	},
	"ost_sawano_titan_breach_vocal": {
		"id": "ost_sawano_titan_breach_vocal",
		"title": "ət'æk:0N:WALL [VOCAL ANTHEM] (Titan Cry)",
		"scene": "Boss Match Inno Vocale & Invasione Campo",
		"category": "Sawano / Titan Special",
		"bpm": 135,
		"key": "C minor",
		"style": "Inno titanico cantato con rituale in tedesco, cori ad armonie multiple e grida di battaglia",
		"prompt": "Epic orchestral symphonic metal vocal anthem in the style of Hiroyuki Sawano (Attack on Titan / Vogel im Käfig). Dark German spoken intro, soaring English male rock lead, powerful female backing choir in fifths and octaves, heavy djent guitars, thunderous taiko rolls, and emotional Sawano drop climax."
	},
	"ost_sawano_counterattack": {
		"id": "ost_sawano_counterattack",
		"title": "K21:Vanguard (Counter-Rally)",
		"scene": "Rimonta Epica / Break Point Critico",
		"category": "Sawano / Titan Special",
		"bpm": 142,
		"key": "D minor",
		"style": "Hybrid Orchestral Rap-Rock con rullante sincopato e archi taglienti",
		"prompt": "Hiroyuki Sawano hybrid orchestral rap-rock battle theme (inspired by K21 and Before Lights Out). Fast syncopated hip-hop snare beat, screeching overdrive guitars, rapid staccato violin runs, heroic brass answers, intense motivational sports combat drive."
	},
	"ost_sawano_k21_vocal": {
		"id": "ost_sawano_k21_vocal",
		"title": "K21:Vanguard [VOCAL ANTHEM] (Battle Aria)",
		"scene": "Boss Match Climax & Inno Vocale Sawano",
		"category": "Sawano / Titan Special",
		"bpm": 142,
		"key": "D minor",
		"style": "Inno rock/hip-hop cantato con voce solista acapella, cori a 3 parti e riff titanico",
		"prompt": "Hiroyuki Sawano epic vocal battle anthem (inspired by K21 vocal and Before Lights Out). Emotional acapella vocal opening, exploding into heavy distorted guitar power chords, syncopated hip-hop breakbeat, soaring male/female lead vocals belting anthemic melodies, 3-part vocal choir harmonies, high soprano breakdown, and massive symphonic rock climax."
	},
	"ost_sawano_wings_of_freedom": {
		"id": "ost_sawano_wings_of_freedom",
		"title": "FLÜGEL:der:Freiheit (Scouting Overdrive)",
		"scene": "Semifinali Torneo & Battaglia per la Libertà",
		"category": "Sawano / Titan Special",
		"bpm": 154,
		"key": "G minor",
		"style": "Symphonic Power Metal anime con violino solista e coro staccato",
		"prompt": "Hiroyuki Sawano heroic anime anthem (style of The Reluctant Heroes and Bauklötze). Soaring lead violin melody, driving symphonic power metal drum double-kick, energetic German-style choir stabs, brass fanfares, euphoric sense of speed and freedom."
	},
	"ost_sawano_wings_of_freedom_vocal": {
		"id": "ost_sawano_wings_of_freedom_vocal",
		"title": "FLÜGEL:der:Freiheit [VOCAL ANTHEM] (Wings of Freedom)",
		"scene": "Semifinali Torneo & Inno Vocale della Libertà",
		"category": "Sawano / Titan Special",
		"bpm": 154,
		"key": "G minor",
		"style": "Power metal vocale sinfonico con duetto maschile/femminile e cori tedeschi epici",
		"prompt": "Hiroyuki Sawano symphonic power metal battle hymn with soaring lead vocals. Emotional violin ballad intro with female vocals, exploding into high-speed double-kick power metal, dual male/female vocal harmonies, German choral calls, and blazing anime climax."
	},
	"ost_sawano_shiganshina_cry": {
		"id": "ost_sawano_shiganshina_cry",
		"title": "T:T (Shiganshina Requiem)",
		"scene": "Match Point Decisivo / Deuce a Oltranza",
		"category": "Sawano / Titan Special",
		"bpm": 128,
		"key": "E minor",
		"style": "Violoncello solista drammatico, Sawano drop e climax corale maestoso",
		"prompt": "Dramatic emotional anime soundtrack (style of YouSeeBIGGIRL/T:T and Call of Silence). Melancholic solo cello intro over ambient breathy pads, sudden silence heartbeat drop, erupting into a colossal symphonic choir climax with thundering percussion and weeping brass chords."
	},
	"ost_sawano_shiganshina_cry_vocal": {
		"id": "ost_sawano_shiganshina_cry_vocal",
		"title": "T:T [VOCAL ANTHEM] (Shiganshina Requiem Aria)",
		"scene": "Match Point Decisivo & Aria Vocale Drammatica",
		"category": "Sawano / Titan Special",
		"bpm": 128,
		"key": "E minor",
		"style": "Aria vocale lirica eterea con carillon, sussurro nel Sawano drop e boato corale operatico",
		"prompt": "Heart-wrenching Hiroyuki Sawano vocal requiem aria (style of YouSeeBIGGIRL/T:T and Call of Silence). Delicate music box and breathy female solo aria intro, building into a dramatic duet, sudden silence heartbeat drop with a fragile whisper, exploding into a colossal SATB operatic choir wall-of-sound."
	},
	"ost_sawano_colossal_smash": {
		"id": "ost_sawano_colossal_smash",
		"title": "XL-TT (Padel Colossus)",
		"scene": "Steam Gauge 100% / Super Colpo Speciale",
		"category": "Sawano / Titan Special",
		"bpm": 148,
		"key": "F# minor",
		"style": "Passi titanici industriali, sub-bass drop e synth arpeggiato aggressivo",
		"prompt": "Hiroyuki Sawano colossal monster battle music (style of XL-TT and APETITAN). Earth-shaking industrial sub-bass thumps, distorted synth arpeggios pulsing in F# minor, massive orchestral brass stabs, adrenaline-fueled titan confrontation."
	},
	"ost_sawano_colossal_smash_vocal": {
		"id": "ost_sawano_colossal_smash_vocal",
		"title": "XL-TT [VOCAL ANTHEM] (Colossal Smash Roar)",
		"scene": "Steam Gauge 100% & Inno Vocale Cyber-Colosso",
		"category": "Sawano / Titan Special",
		"bpm": 148,
		"key": "F# minor",
		"style": "Cyber-industrial rap-metal cantato con countdown vocale distorto e cori aggressivi",
		"prompt": "High-octane industrial cyberpunk titan vocal battle anthem (style of XL-TT and APETITAN). Distorted warning countdown alert, aggressive rhythmic chants with sub-octave doublings, driving 4-on-the-floor kick, metallic anvil strikes, and colossal shouting brass climax."
	},
	"ost_sawano_barricades": {
		"id": "ost_sawano_barricades",
		"title": "bà:R1CADES (Final Wall)",
		"scene": "Finalissima Scudetto & Inno di Gloria",
		"category": "Sawano / Titan Special",
		"bpm": 160,
		"key": "A minor",
		"style": "Inno J-Rock orchestrale ad alta energia con chitarre gemelle e ottoni trionfali",
		"prompt": "High-octane Hiroyuki Sawano J-Rock orchestral anthem (style of Barricades and ət'æk 0N t'aɪtn). Driving 160 BPM drum beat, soaring twin lead guitars, uplifting choir chants, heroic trumpet hooks, emotional climax for a world championship victory."
	},
	"ost_sawano_barricades_vocal": {
		"id": "ost_sawano_barricades_vocal",
		"title": "bà:R1CADES [VOCAL ANTHEM] (Break the Wall)",
		"scene": "Finalissima Scudetto & Inno Vocale Shonen",
		"category": "Sawano / Titan Special",
		"bpm": 160,
		"key": "A minor",
		"style": "Inno J-Rock anime shonen cantato con battiti di mani, slap bass e ritornello a due voci",
		"prompt": "Joyful and electrifying Hiroyuki Sawano J-Rock anime vocal anthem (style of Barricades and Zero Eclipse). Energetic spoken shout intro with clapping hands, punchy slap bassline, sunny dual male/female vocal chorus singing in thirds, and triumphant stadium victory celebration."
	},
	# 5 Dragon Ball GT / 90s Anime Suite Tracks
	"ost_dbgt_dan_dan_vocal": {
		"id": "ost_dbgt_dan_dan_vocal",
		"title": "DAN DAN Kokoro Hikareteku (Bit by Bit)",
		"scene": "Opening Shonen GT & Inno J-Pop Cantato",
		"category": "Dragon Ball GT / 90s Anime",
		"bpm": 132,
		"key": "C major",
		"style": "Inno J-Pop leggendario interamente cantato, chitarre acustiche a 16esimi, piano Rhodes DX7 e ottoni solari",
		"prompt": "Legendary 90s anime J-Pop opening theme in the unmistakable style of Dan Dan Kokoro Hikareteku (Field of View / ZARD). Melodic Japanese singing vocals, shimmering 16th-note acoustic guitar strumming, bright DX7 electric piano chords, punchy brass hits, upbeat rock drums, joyful nostalgic anime melody."
	},
	"ost_dbgt_dont_you_see_vocal": {
		"id": "ost_dbgt_dont_you_see_vocal",
		"title": "Don't You See! (Memories in the Sky)",
		"scene": "Ending Melodica & Ballata J-Rock",
		"category": "Dragon Ball GT / 90s Anime",
		"bpm": 118,
		"key": "E major",
		"style": "Ballata J-Rock nostalgica cantata con voce femminile, piano Rhodes, basso fretless e chitarre sognanti",
		"prompt": "Emotional 90s anime J-Rock ballad in the style of Don't You See! by ZARD (Dragon Ball GT ending). Expressive melodic female singing vocals, warm Rhodes electric piano, melodic chorused bassline, gentle rock drum groove, soaring electric guitar solo, heartfelt sunset anime nostalgia."
	},
	"ost_dbgt_grand_tour": {
		"id": "ost_dbgt_grand_tour",
		"title": "G.T. Grand Tour Odyssey",
		"scene": "Viaggio Spaziale & Esplorazione Cosmica",
		"category": "Dragon Ball GT / 90s Anime",
		"bpm": 140,
		"key": "D major",
		"style": "Synth-rock d'avventura spaziale con arpeggiatori cosmici, impulsi Dragon Radar e fanfara di chitarre",
		"prompt": "90s cosmic anime synth-rock adventure theme for Dragon Ball GT space exploration. Pumping analog synth arpeggios, electronic Dragon Radar bleep pulses, driving four-on-the-floor beat, soaring heroic lead guitar melody, brass accents, galactic journey."
	},
	"ost_dbgt_super_saiyan_4": {
		"id": "ost_dbgt_super_saiyan_4",
		"title": "Primal Awakening: Super Saiyan 4",
		"scene": "Trasformazione Scimmione Dorato & Risveglio Supremo",
		"category": "Dragon Ball GT / 90s Anime",
		"bpm": 156,
		"key": "D minor",
		"style": "Heavy rock sinfonico tellurico con flauto Shakuhachi, riff pesanti, doppia cassa e ottoni guerrieri",
		"prompt": "Epic primal transformation battle theme for Super Saiyan 4 (Dragon Ball GT). Haunting solo Japanese bamboo flute (Shakuhachi) intro, exploding into thunderous heavy metal guitar riffs in D minor, double-kick rock drums, orchestral brass power stabs, unstoppable primal warrior power."
	},
	"ost_dbgt_sabitsuita_machine_gun": {
		"id": "ost_dbgt_sabitsuita_machine_gun",
		"title": "Rusting Machine Gun (90s Heartbeat)",
		"scene": "Ending Shonen Spensierata & Rivincita",
		"category": "Dragon Ball GT / 90s Anime",
		"bpm": 168,
		"key": "G major",
		"style": "Pop-punk anime anni '90 veloce e spensierato con chitarre in levare, rullante incalzante e melodia allegra",
		"prompt": "High-tempo 90s anime pop-punk ending theme in the style of Sabitsuita Machine Gun (WANDS). Upbeat staccato guitar skank intro, driving skate-punk drum beat at 168 BPM, melodic walking bassline, bright distorted power chords, euphoric shonen anime celebration."
	},
	"ost_rays_of_rust": {
		"id": "ost_rays_of_rust",
		"title": "Rays of Rust",
		"scene": "Rovine Meccaniche & Raggi di Luce",
		"category": "Automata Special",
		"bpm": 108,
		"key": "D minor",
		"style": "Acustico etereo con chitarra a 12 corde, canto Chaos Language, archi intimi e toms tribali",
		"prompt": "Ethereal NieR: Automata inspired acoustic theme. Fingerpicked steel-string acoustic guitar arpeggios, haunting breathy female solo vocals chanting in evocative alien Chaos Language, warm expressive cello melodies, subtle crystalline glockenspiel chimes, deep tribal toms."
	},
	"ost_weight_of_the_rally": {
		"id": "ost_weight_of_the_rally",
		"title": "Weight of the Rally",
		"scene": "Cattedrale Diroccata & Duello Filosofico",
		"category": "Automata Special",
		"bpm": 115,
		"key": "F# minor",
		"style": "Inno corale maestoso ed emotivo con pianoforte a coda, cori polifonici e archi travolgenti",
		"prompt": "Soaring emotional NieR: Automata anthem in the style of Weight of the World. Melancholic yet resolute grand piano chords, lush layered choral vocals chanting in invented language, expressive solo violin and rich string orchestra swells, driving acoustic percussion."
	},
	"ost_beautiful_duel": {
		"id": "ost_beautiful_duel",
		"title": "Beautiful Duel",
		"scene": "Teatro dell'Opera Infranto & Valzer Gotico",
		"category": "Automata Special",
		"bpm": 132,
		"key": "G minor",
		"style": "Valzer tragico teatrale in 3/4 con violino virtuoso solista, arpeggi di chitarra drammatici e voce operistica",
		"prompt": "Tragic, theatrical waltz in 3/4 inspired by NieR: Automata boss themes (A Beautiful Song). Virtuosic dramatic solo violin passionate runs, operatic female vocal flourishes with microtonal melisma, heavy percussive orchestral downbeats, broken harpsichord accents."
	},
	"ost_memories_of_sand": {
		"id": "ost_memories_of_sand",
		"title": "Memories of Sand",
		"scene": "Deserto Infinito & Relitti Sepolti",
		"category": "Automata Special",
		"bpm": 96,
		"key": "E Phrygian",
		"style": "Etnico meditativo con chitarra araba/acustica, percussioni desertiche e canto misterioso",
		"prompt": "Hypnotic, atmospheric desert ambient theme inspired by NieR: Automata Memories of Dust. Intricate acoustic guitar picking in E Phrygian mode, subtle frame drum and tambourine shaker rhythms, resonant cello drone, ethereal female vocal melodies echoing over sun-scorched dunes."
	},
	"ost_rebirth_of_hope": {
		"id": "ost_rebirth_of_hope",
		"title": "Rebirth of Hope",
		"scene": "Alba sulle Nubi & Redenzione",
		"category": "Automata Special",
		"bpm": 120,
		"key": "A minor / C major",
		"style": "Crescendo estatico luminoso con piano brillante, coro celestiale, rintocchi cristallini e archi trionfali",
		"prompt": "Uplifting, spiritual sunrise crescendo inspired by NieR: Automata final epilogue themes. Gentle hopeful piano ostinato modulating from A minor to C major, soaring angelic choral harmony chanting in Chaos Language, crystalline glockenspiel chimes, triumphant cinematic strings."
	},
	"ost_broken_monolith": {
		"id": "ost_broken_monolith",
		"title": "Broken Monolith",
		"scene": "Santuario Sommerso & Rovine Antiche",
		"category": "Automata Special",
		"bpm": 104,
		"key": "C minor",
		"style": "Arpeggi acustici di chitarra classica, pianoforte felpato, violoncello profondo e taiko solenne",
		"prompt": "Contemplative, profound acoustic NieR: Automata piece. Gentle fingerpicked nylon-string classical guitar arpeggios, warm felt grand piano chords, deep steady acoustic cello pedal tones, subtle resonant concert taiko downbeats."
	},
	"ost_city_of_pearls": {
		"id": "ost_city_of_pearls",
		"title": "City of Pearls",
		"scene": "Città di Cristallo & Architettura D'Alabastro",
		"category": "Automata Special",
		"bpm": 126,
		"key": "D minor",
		"style": "Minimalismo virtuosistico al pianoforte a coda, arpa da concerto, violoncello caldo e taiko soffuso",
		"prompt": "Crystalline post-classical minimalist piano arpeggios inspired by Copied City (NieR: Automata). Rapid fluid 16th-note grand piano runs, sustained warm acoustic cello bass, delicate concert harp accents, pristine architectural stillness."
	},
	"ost_tears_of_porcelain": {
		"id": "ost_tears_of_porcelain",
		"title": "Tears of Porcelain",
		"scene": "Palazzo d'Inverno & Marionette Spezzate",
		"category": "Automata Special",
		"bpm": 114,
		"key": "A minor",
		"style": "Valzer acustico in 3/4 con chitarra classica, pianoforte a coda, violoncello pizzicato e celesta morbida",
		"prompt": "Nostalgic, sorrowful acoustic 3/4 waltz of antique marionettes. Gentle nylon-string guitar strums on offbeats, warm felt piano harmonies, acoustic cello, soft wooden celesta melody, intimate moonlit conservatory mood."
	},
	"ost_hymn_of_the_ancients": {
		"id": "ost_hymn_of_the_ancients",
		"title": "Hymn of the Ancients",
		"scene": "Cattedrale Ipogea & Divinità Dimenticate",
		"category": "Automata Special",
		"bpm": 92,
		"key": "E minor",
		"style": "Coro sacro ad armonie aperte, pianoforte risonante, violoncello maestoso e taiko cerimoniale",
		"prompt": "Sacred, profound subterranean sanctuary anthem. Serene open-harmony vocal choir chords with rock-solid steady pitch, dark resonant felt grand piano, deep acoustic cello pedal tones, slow ceremonial taiko drum."
	},
	"ost_ashes_of_destiny": {
		"id": "ost_ashes_of_destiny",
		"title": "Ashes of Destiny",
		"scene": "Dune di Cenere Vulcanica & Spada nel Suolo",
		"category": "Automata Special",
		"bpm": 100,
		"key": "B minor",
		"style": "Marcia acustica solenne con chitarra a 12 corde, pianoforte a coda, arpa da concerto e taiko marciante",
		"prompt": "Solemn, sweeping cinematic acoustic march across volcanic ash plains. Rich acoustic guitar fingerpicking, resonant felt piano chords, warm cello countermelody, concert harp cadences, steady marching taiko heartbeat."
	},
	"ost_carnival_of_illusions": {
		"id": "ost_carnival_of_illusions",
		"title": "Carnival of Illusions",
		"scene": "Parco Meccanico & Giostra Spezzata",
		"category": "Automata Special",
		"bpm": 138,
		"key": "A minor / C major",
		"style": "Marimba in legno, contrabbasso pizzicato, accordi di chitarra in levare e carillon spettrale",
		"prompt": "Playful, nostalgic, and eerie mechanical amusement park in ruins. Staccato wooden rosewood marimba arpeggios, walking upright acoustic double bass, light offbeat acoustic guitar strums, delicate music box accents, no pitch modulation."
	},
	"ost_verdant_whispers": {
		"id": "ost_verdant_whispers",
		"title": "Verdant Whispers",
		"scene": "Regno delle Foreste & Bastioni Sommersi",
		"category": "Automata Special",
		"bpm": 96,
		"key": "D Dorian (6/8)",
		"style": "Ballata pastorale in 6/8 con liuto acustico, flauto dolce ligneo, tamburo bodhran e violoncello",
		"prompt": "Enchanting 6/8 pastoral folk melody for an overgrown forest castle. Delicate lute fingerpicking, pure wooden transverse recorder flute melody, heartbeat bodhran hand-drum pulse, warm sustained acoustic cello."
	},
	"ost_abyssal_silence": {
		"id": "ost_abyssal_silence",
		"title": "Abyssal Silence",
		"scene": "Voragine Ipogea & Monolite Sommergibile",
		"category": "Automata Special",
		"bpm": 72,
		"key": "F minor",
		"style": "Atmosfera ipogea solenne con contrabbasso sub-grave, pianoforte felpato, campana tibetana e blocchi di legno",
		"prompt": "Profound, dark subterranean cavern ambient. Deep bowed double bass sub-octave fundamental at 43.6 Hz, sparse felt grand piano chords with spacious room reverb, sustained acoustic bronze meditation chime, wooden temple blocks."
	},
	"ost_dance_of_the_blade": {
		"id": "ost_dance_of_the_blade",
		"title": "Dance of the Blade",
		"scene": "Piattaforma del Duello & Lame Incrociate",
		"category": "Automata Special",
		"bpm": 144,
		"key": "E Phrygian / E minor",
		"style": "Duello acustico rapido con chitarra flamenca spagnola, ostinato di violoncello e cajon poliritmico",
		"prompt": "High-intensity acoustic duel theme inspired by NieR: Automata boss encounters. Rapid virtuosic Spanish flamenco nylon guitar riffs, driving cello bass ostinato, tight acoustic cajon percussion and concert taiko."
	},
	"ost_cradle_of_waves": {
		"id": "ost_cradle_of_waves",
		"title": "Cradle of Waves",
		"scene": "Rive della Città Allagata & Ninna Nanna Marina",
		"category": "Automata Special",
		"bpm": 84,
		"key": "G major",
		"style": "Ninna nanna marina con cascate d'arpa da concerto, armonici di chitarra, violoncello cantabile e celesta",
		"prompt": "Serene, tranquil flooded city shoreline lullaby. Cascading concert harp pentatonic arpeggios, gentle acoustic guitar natural harmonics, singing warm acoustic cello melody, soft celesta water-drop chimes."
	},
	"ost_hyori_ittai_vocal": {
		"id": "ost_hyori_ittai_vocal",
		"title": "Hyori Ittai [VOCAL ANTHEM] (Two Sides of Fate)",
		"scene": "Eclissi Solare & Duello della Chimera",
		"category": "Anime Vocal Special",
		"bpm": 154,
		"key": "D minor / F major",
		"style": "Inno shonen vocale epico con chitarre acustiche furiose a 12 corde, archi sinfonici, ottoni da battaglia e duo vocale armonizzato",
		"prompt": "Passionate, high-intensity shonen anime ending anthem inspired by Hyori Ittai (Hunter x Hunter Chimera Ant Arc). Furious 12-string acoustic guitar strumming at 154 BPM, dramatic soaring orchestral strings, heavy brass stabs, driving rock drums with taiko, and emotional dual-voice shonen vocal harmony.",
		"preview_offset": 18.7
	},
	"ost_menu_velvet_lounge": {
		"id": "ost_menu_velvet_lounge",
		"title": "Velvet Velvet (Midnight Lounge)",
		"scene": "Menu Principale & Guardaroba Notturno",
		"category": "Menu & Sistema",
		"bpm": 96,
		"key": "E minor / G major",
		"style": "Acid Jazz / Neo-Soul Lounge con piano Fender Rhodes, walking bass e tromba con sordina Harmon",
		"prompt": "Ultra-stylish, laid-back Tokyo rooftop jazz lounge theme inspired by Persona 5. Lush Fender Rhodes MK I electric piano 7th and 9th chords, silky electric walking bass, singing harmon-muted jazz trumpet hooks, mellow hip-hop downtempo beat with wooden rimshots and vintage vinyl tape warmth."
	},
	"ost_menu_grand_touring": {
		"id": "ost_menu_grand_touring",
		"title": "Moon Over the Circuit (Prestige Pavilion)",
		"scene": "Showroom Circuiti & Padiglione Prestige",
		"category": "Menu & Sistema",
		"bpm": 108,
		"key": "D major / B minor",
		"style": "Nu-Jazz Fusion giapponese con Rhodes scintillante, chitarra nylon e basso fretless",
		"prompt": "Sophisticated luxury automotive showroom lounge inspired by Gran Turismo. Sparkling bell-like Rhodes electric piano chords, smooth acoustic nylon jazz guitar arpeggios, fluid melodic fretless bass, bossa-fusion brush snare with ride cymbal and delicate soprano flute phrases."
	},
	"ost_menu_astral_solitude": {
		"id": "ost_menu_astral_solitude",
		"title": "Quiet Horizons (Meditative Solitude)",
		"scene": "Pausa & Menu Meditativo",
		"category": "Menu & Sistema",
		"bpm": 72,
		"key": "C major / A minor",
		"style": "Minimalismo acustico ambient con felt piano intimo, celesta e archi caldi",
		"prompt": "Deeply peaceful, therapeutic ambient acoustic solitude inspired by Minecraft C418. Intimate felt upright piano with soft hammer thuds, warm analog string drone breathing underneath, crystalline celesta bell drops, and spacious meditative room acoustics."
	},
	"ost_menu_dearly_reminiscent": {
		"id": "ost_menu_dearly_reminiscent",
		"title": "Silver Moon Reflections (Fantasy Prelude)",
		"scene": "Schermata Titolo & Preludio Fantastico",
		"category": "Menu & Sistema",
		"bpm": 84,
		"key": "F major / D minor",
		"style": "Preludio sinfonico fantasy con arpa a cascata, risacca oceanica e pianoforte nostalgico",
		"prompt": "Tender, emotional fantasy title screen prelude inspired by Kingdom Hearts Dearly Beloved and Final Fantasy Prelude. Cascading concert harp arpeggios rolling up and down, gentle soothing ocean wave wash, emotional grand piano lullaby melody, and warm French horn swells."
	},
	"ost_menu_cyber_terminal": {
		"id": "ost_menu_cyber_terminal",
		"title": "Neon Grid Terminal (Data Terminal)",
		"scene": "Terminale Dati & Personalizzazione HUD",
		"category": "Menu & Sistema",
		"bpm": 90,
		"key": "D minor",
		"style": "Chill Synthwave / Ambient Sci-Fi HUD con Moog sub-bass e pad Juno-106",
		"prompt": "Futuristic, immersive high-tech data terminal ambiance inspired by Metroid Prime and Cyberpunk 2077. Deep 45Hz analog Moog sub-bass pulse, lush Roland Juno-106 analog string pad sweeps, digital crystalline chime arpeggios, downtempo electronic beat with high-tech HUD tick accents."
	},
	"ost_menu_breeze_plaza": {
		"id": "ost_menu_breeze_plaza",
		"title": "Breeze Plaza (Sunshine Pavilion)",
		"scene": "Padiglione Resort & Menu Soleggiato",
		"category": "Menu & Sistema",
		"bpm": 112,
		"key": "F major",
		"style": "Bossa Nova spensierata con nylon guitar, vibrafono e fischiettio da resort",
		"prompt": "Carefree sunny resort lobby bossa nova inspired by Wii Sports and Mii Channel. Breezy nylon acoustic guitar chords, warm vibraphone leads, cheerful melodic whistling, playful shaker and congas, bouncy electric bass groove."
	},
	"ost_menu_sacred_spring": {
		"id": "ost_menu_sacred_spring",
		"title": "Sacred Spring (Fairy Sanctuary)",
		"scene": "Santuario delle Fate & Sorgente Sacra",
		"category": "Menu & Sistema",
		"bpm": 76,
		"key": "Db major / F minor",
		"style": "Arpeggi d'arpa eterea e flauto di cristallo in armonie fiabesche",
		"prompt": "Mystical crystal spring oasis inspired by Zelda Great Fairy Fountain. Enchanting cascading concert harp arpeggios, gentle silver flute melody, shimmering celestial choir pads, warm ambient resonance."
	},
	"ost_menu_ancient_sanctum": {
		"id": "ost_menu_ancient_sanctum",
		"title": "Sanctum of the Ring (Choral Vault)",
		"scene": "Cattedrale dei Precursori & Cripta Sacra",
		"category": "Menu & Sistema",
		"bpm": 68,
		"key": "E minor",
		"style": "Canto gregoriano solenne con riverbero da cattedrale e violoncello intimo",
		"prompt": "Echoing primordial cathedral expanse inspired by Halo Monk Chant. Resonant male Gregorian choir harmony humming in a massive stone vaulted nave, warm solo cello playing a solemn counterpoint melody."
	},
	"ost_menu_rainy_atrium": {
		"id": "ost_menu_rainy_atrium",
		"title": "Rainy Atrium (Cafe Reverie)",
		"scene": "Caffè della Pioggia & Relax del Club",
		"category": "Menu & Sistema",
		"bpm": 80,
		"key": "Bb major / G minor",
		"style": "Cozy acoustic lo-fi jazz con chitarra acustica, pioggia e rhodes intimo",
		"prompt": "Warm cozy coffee shop rain theme inspired by Animal Crossing and Persona Rain. Gentle falling rain soundscape, sweet acoustic guitar fingerpicking, subtle Fender Rhodes chords, relaxed brushed drums."
	},
	"ost_menu_chronicle_winds": {
		"id": "ost_menu_chronicle_winds",
		"title": "Timeless Winds (Chronicle of the Ages)",
		"scene": "Mappa del Tempo & Memorie del Circuito",
		"category": "Menu & Sistema",
		"bpm": 88,
		"key": "G major / E minor",
		"style": "Folk celtico nostalgico con chitarra acustica a 12 corde e tin whistle",
		"prompt": "Poignant, nostalgic acoustic folk title theme inspired by Chrono Trigger and Chrono Cross. Intricate 12-string acoustic guitar picking, soaring tin whistle and pan flute melody, lush string quartet backing."
	},
	"ost_menu_subaquatic_drift": {
		"id": "ost_menu_subaquatic_drift",
		"title": "Coral Drift (Deep Oceanic Current)",
		"scene": "Acquario del Circuito & Correnti Sottomarine",
		"category": "Menu & Sistema",
		"bpm": 78,
		"key": "Eb major / C minor",
		"style": "Ambient sottomarino onirico con synth pad galleggianti e campane marine",
		"prompt": "Dreamlike, floating deep ocean ambiance inspired by Donkey Kong Country Aquatic Ambience. Ethereal detuned analog synth pads, crystal marine chime arpeggios, gentle bubble FX, serene expansive underwater acoustics."
	},
	"ost_menu_northern_aurora": {
		"id": "ost_menu_northern_aurora",
		"title": "Northern Frost (Halls of Whiterun)",
		"scene": "Taverna del Nord & Fuoco del Focolare",
		"category": "Menu & Sistema",
		"bpm": 70,
		"key": "A minor",
		"style": "Folk nordico intimo con hammered dulcimer, viola da gamba e flauto di legno",
		"prompt": "Cozy Nordic tavern and frozen landscape theme inspired by Skyrim The Streets of Whiterun. Delicate hammered dulcimer melodies, deep expressive viola da gamba lines, warm fireplace crackle, soft timber flute."
	},
	"ost_menu_champions_pavilion": {
		"id": "ost_menu_champions_pavilion",
		"title": "Champions Hall (Tournament Fanfare)",
		"scene": "Hall dei Campioni & Selezione Torneo",
		"category": "Menu & Sistema",
		"bpm": 128,
		"key": "D major",
		"style": "Fanfara orchestrale trionfale con ottoni eroici e percussioni da torneo",
		"prompt": "Epic, heroic tournament main menu fanfare inspired by Super Smash Bros Melee and Brawl. Punchy brass fanfare, driving orchestral snare and timpani cadence, sweeping violins, triumphant competitive spirit."
	},
	"ost_menu_orbital_vanguard": {
		"id": "ost_menu_orbital_vanguard",
		"title": "Orbital Vista (Galaxy Map Lounge)",
		"scene": "Osservatorio Orbitale & Mappa Stellare",
		"category": "Menu & Sistema",
		"bpm": 85,
		"key": "F# minor",
		"style": "Sci-fi cosmico contemplativo con pad Juno-60 e arpeggio analogico spaziale",
		"prompt": "Meditative deep space exploration theme inspired by Mass Effect Galaxy Map Vigil. Warm pulsing analog synthesizer sequencer, expansive Roland Juno lush string pads, glistening crystal arp bells, profound celestial awe."
	},
	"ost_menu_third_strike": {
		"id": "ost_menu_third_strike",
		"title": "Street Select (Underground Cipher)",
		"scene": "Schermata Selezione Personaggio & Club Underground",
		"category": "Menu & Sistema",
		"bpm": 160,
		"key": "F minor",
		"style": "Liquid Drum & Bass con piano jazz sincopato e 808 sub-bass profondo",
		"prompt": "High-fashion urban character selection groove inspired by Street Fighter III 3rd Strike. Crisp rolling liquid drum and bass breakbeats, syncopated jazz piano stabs, deep 808 sub-bass, slick urban arcade attitude."
	},
	"ost_vocal_overdrive_line": {
		"id": "ost_vocal_overdrive_line",
		"title": "Overdrive Line",
		"scene": "Match Arena & Gran Finale",
		"category": "Canzoni Cantate",
		"bpm": 145,
		"key": "G minor / Bb major",
		"style": "Indie Rock / Garage Rock cantato con chitarre sferzanti, basso melodico e batteria energica",
		"prompt": "90s energetic indie rock, driving drums, electric guitar riff, catchy vocal melody, passionate singer. Lyrics: Fast spin on the concrete floor, heat behind the iron door, gears turning and the pulse is high, we watch the spark ignite the midnight sky. Pre-Chorus: No time to hesitate, no time to slow, count down the seconds till we let it go! Chorus: We're burning out on the overdrive line! Catch the rebound, running out of time! Yeah we hit the wall, but we break right through, there's nothing left between me and you!",
		"preview_offset": 26.0
	},
	"ost_vocal_break_point_riot": {
		"id": "ost_vocal_break_point_riot",
		"title": "Break Point Riot",
		"scene": "Match Arena & Climax",
		"category": "Canzoni Cantate",
		"bpm": 165,
		"key": "C minor / Eb major",
		"style": "Pop Punk / Skate Rock energico con power chord sferzanti, basso martellante e voce grintosa",
		"prompt": "Fast 2000s energetic pop punk / skate rock, 165 BPM, driving rhythm section, catchy vocal hooks and gritty vocals, intense padel match climax.",
		"preview_offset": 40.0
	},
	"ost_vocal_reach_for_the_sun": {
		"id": "ost_vocal_reach_for_the_sun",
		"title": "Reach for the Sun",
		"scene": "Match Arena & Gran Finale",
		"category": "Canzoni Cantate",
		"bpm": 160,
		"key": "D minor / F major",
		"style": "Anime Rock / J-Rock trionfale con chitarra solista epica, sezione ritmica galoppante e voce appassionata",
		"prompt": "Triumphant anime opening J-rock, 160 BPM, soaring guitar leads, dramatic chord progressions, passionate emotional vocals, victory anthem.",
		"preview_offset": 40.0
	},
	"ost_vocal_neon_velocity": {
		"id": "ost_vocal_neon_velocity",
		"title": "Neon Velocity",
		"scene": "Match Arena & Cyber Circuit",
		"category": "Canzoni Cantate",
		"bpm": 126,
		"key": "A minor / C major",
		"style": "Synthwave / Cyber Rock cantato con arpeggiatori synth, basso funky trascinante, riff di chitarra al neon e voce melodica",
		"prompt": "Synthwave / Cyber rock vocal track, 126 BPM, funky bassline, neon synth arpeggios, electric guitar fills, smooth confident vocals. Lyrics: Midnight reflections on the court, a game of speed, a brand new sport. You move to the left, I cut to the right, electric silhouettes in violet light. Pre-Chorus: Every heartbeat syncs to the beat, feel the rhythm rising beneath our feet. Chorus: Oh, neon velocity, take the floor! One more touch and we want some more! Spinning around in the golden glow, we set the tempo wherever we go!",
		"preview_offset": 60.0
	},
	"ost_vocal_girei": {
		"id": "ost_vocal_girei",
		"title": "Girei (Almighty Judgment)",
		"scene": "Boss Fight Finale & Cattedrale di Vetro",
		"category": "Canzoni Cantate",
		"bpm": 135,
		"key": "D minor",
		"style": "Gothic Symphonic Metal cantato con coro gregoriano, organo a canne, chitarre metal pesanti e voce operatica",
		"prompt": "Gothic symphonic metal, ominous sacred Gregorian choir chanting, massive church pipe organ, heavy 8-string distorted guitars, thunderous timpani drums, soaring operatic lead vocals, dramatic dark anime boss climax, 135 BPM",
		"preview_offset": 115.5
	},
	"ost_vocal_gleiches_blut": {
		"id": "ost_vocal_gleiches_blut",
		"title": "Gleiches Blut (Same Blood)",
		"scene": "Arena Torneo & Scontro Fraterno",
		"category": "Canzoni Cantate",
		"bpm": 130,
		"key": "D minor",
		"style": "Neue Deutsche Härte / Industrial Metal cantato in tedesco con riff pesanti di chitarra, sintetizzatori marziali e voce profonda",
		"prompt": "Neue Deutsche Härte, Industrial Metal vocal track in German, 130 BPM, chugging low-tuned guitars, martial electronic sequence, deep powerful baritone vocals, dramatic operatic synths",
		"preview_offset": 50.0
	},
	"ost_vocal_tie_break_burn": {
		"id": "ost_vocal_tie_break_burn",
		"title": "Tie-Break Burn",
		"scene": "Match Point ad Alta Tensione & Tie-Break",
		"category": "Canzoni Cantate",
		"bpm": 158,
		"key": "E minor",
		"style": "High-Energy Anime Rock cantato con doppia cassa, chitarre incendiarie, melodie vocali adrenaliniche e basso slap",
		"prompt": "High-energy anime sports vocal rock, 158 BPM, explosive double-kick drums, blazing electric guitars, soaring passionate vocals, intense tie-break match climax tension",
		"preview_offset": 40.0
	},
	"ost_vocal_maschine_jagd": {
		"id": "ost_vocal_maschine_jagd",
		"title": "Maschine Jagd (Machine Hunt)",
		"scene": "Fonderia & Caccia al Mecha",
		"category": "Canzoni Cantate",
		"bpm": 140,
		"key": "C minor",
		"style": "Cyber-Industrial Rock cantato con ritmi a pistone, arpeggi acidi, chitarre taglienti e voce energica",
		"prompt": "Cyberpunk Industrial Rock with driving German vocals, 140 BPM, mechanical piston rhythm, aggressive guitar riffs, pulsing synth bass, relentless pursuit anthem",
		"preview_offset": 35.0
	},
	"ost_vocal_schwarzmarkt": {
		"id": "ost_vocal_schwarzmarkt",
		"title": "Schwarzmarkt (Black Market)",
		"scene": "Distretto d'Ombra & Bazar Steampunk",
		"category": "Canzoni Cantate",
		"bpm": 128,
		"key": "A minor",
		"style": "Dark Electro-Rock cantato con basso synth distorto, fisarmonica darkwave, riff cupi e voce carismatica",
		"prompt": "Dark cabaret electro-rock in German, 128 BPM, distorted synth bass, dark accordion touches, infectious driving groove, charismatic theatrical vocals, shady steampunk underworld",
		"preview_offset": 30.0
	},
	"ost_vocal_nullpunkt": {
		"id": "ost_vocal_nullpunkt",
		"title": "Nullpunkt (Zero Point)",
		"scene": "Caldera & Azzeramento Finale",
		"category": "Canzoni Cantate",
		"bpm": 165,
		"key": "F minor",
		"style": "Symphonic Darksynth Metal cantato con breakbeat, synth laser, percussioni taiko e ritornello epico",
		"prompt": "Fast symphonic darksynth metal vocal anthem, 165 BPM, frantic breakcore drums, laser-sharp arpeggios, epic choir accents, powerful anthemic vocals at the zero point",
		"preview_offset": 20.0
	},
	"ost_vocal_zheleznaia_volya": {
		"id": "ost_vocal_zheleznaia_volya",
		"title": "Железная Воля (Iron Will)",
		"scene": "Arena Invernale & Duello delle Leggende",
		"category": "Canzoni Cantate",
		"bpm": 145,
		"key": "G minor",
		"style": "Epic Slavic Folk Metal cantato in russo con chitarre pesanti, coro marziale, fisarmonica epica e voce titanica",
		"prompt": "Epic Slavic Folk Metal vocal anthem in Russian, 145 BPM, heavy distorted guitar riffs, thunderous marching drums, heroic choir, soaring passionate lead vocals, indomitable spirit of iron will",
		"preview_offset": 50.0
	},
	"ost_vocal_double_rebond": {
		"id": "ost_vocal_double_rebond",
		"title": "Le Double Rebond",
		"scene": "Arena Torneo & Open di Parigi",
		"category": "Canzoni Cantate",
		"bpm": 128,
		"key": "G minor / Bb major",
		"style": "French Electro-Pop / Dance Chanson cantato in francese con beat house alla francese, piano e voce accattivante",
		"prompt": "French Electro-Pop / Dance Chanson, 128 BPM, catchy French vocals, groovy four-on-the-floor beat, funky bass, French touch house synth chords, padel tournament anthem about the double bounce",
		"preview_offset": 45.0
	},
	"ost_vocal_oltre_il_vetro": {
		"id": "ost_vocal_oltre_il_vetro",
		"title": "Oltre il Vetro",
		"scene": "Climax Caldera & Gran Finale",
		"category": "Canzoni Cantate",
		"bpm": 135,
		"key": "E minor / G major",
		"style": "Pop Rock Epico italiano in crescendo con chitarre acustiche ed elettriche, batteria arena e voce appassionata",
		"prompt": "Epic Italian Pop-Rock anthem, 135 BPM, passionate Italian vocals, emotive acoustic guitar building into soaring electric guitars, driving arena drums, inspiring sports lyrics about breaking past the court glass wall",
		"preview_offset": 45.0
	},
	"ost_vocal_padelista_energy": {
		"id": "ost_vocal_padelista_energy",
		"title": "Padelista Energy",
		"scene": "Arena Carioca & Match Festivo",
		"category": "Canzoni Cantate",
		"bpm": 125,
		"key": "A minor / C major",
		"style": "Latin Dance-Pop / Reggaeton elettronico con percussioni tropicali, ottoni sintetici e voce solare",
		"prompt": "High-energy Latin Dance-Pop / Padel anthem, 125 BPM, infectious Latin urban rhythm, syncopated brass stabs, tropical percussion, charismatic energetic vocals, vibrant court celebration",
		"preview_offset": 15.0
	},
	"ost_vocal_balle_de_match": {
		"id": "ost_vocal_balle_de_match",
		"title": "Balle de Match",
		"scene": "Match Point Decisivo & Tie-Break",
		"category": "Canzoni Cantate",
		"bpm": 140,
		"key": "D minor",
		"style": "Dramatic French Alternative Rock cantato con riff taglienti di chitarra, percussioni incalzanti e ritornello mozzafiato",
		"prompt": "Dramatic French Alternative Rock, 140 BPM, tense guitar ostinatos, urgent driving bassline, passionate French vocals building to explosive climax for match point victory",
		"preview_offset": 60.0
	},
	"ost_vocal_por_tres": {
		"id": "ost_vocal_por_tres",
		"title": "POR TRES!",
		"scene": "Arena Iberica & Smash Fuori Gabbia",
		"category": "Canzoni Cantate",
		"bpm": 150,
		"key": "A minor",
		"style": "High-Energy Spanish Latin Rock / Anthem cantato in spagnolo sul colpo smash Por Tres che vola fuori campo",
		"prompt": "High-energy Spanish vocal rock anthem, 150 BPM, blazing guitars, pounding drums, explosive crowd chants, heroic lead vocals singing Por Tres padel smash out of the court",
		"preview_offset": 35.0
	},
	"ost_vocal_bandeja_chic": {
		"id": "ost_vocal_bandeja_chic",
		"title": "Bandeja Chic",
		"scene": "Club Privé Parigi & Eleganza sulla Senna",
		"category": "Canzoni Cantate",
		"bpm": 120,
		"key": "F# minor",
		"style": "French Electro-Chanson / Nu-Disco cantato in francese, groove elegante, piano house e archi glamour",
		"prompt": "French Electro-Chanson, Nu-Disco, 120 BPM, chic seductive French vocals, elegant four-on-the-floor house groove, funky bassline, lush disco strings, Parisian luxury padel club",
		"preview_offset": 25.0
	},
	"ost_vocal_bandeja_chic_catchy": {
		"id": "ost_vocal_bandeja_chic_catchy",
		"title": "Bandeja Chic (Catchy Chorus Remix)",
		"scene": "Dancefloor Notturno & Festa Padel",
		"category": "Canzoni Cantate",
		"bpm": 120,
		"key": "F# minor",
		"style": "Dance-Pop Remix con hook vocale immediato, beat incalzante e ritornello esteso",
		"prompt": "Catchy French dance-pop vocal remix, 120 BPM, irresistible melodic hook, driving dance beat, extended euphoric chorus, energetic electro club vibe",
		"preview_offset": 25.0
	},
	"ost_vocal_bandeja_chic_rap": {
		"id": "ost_vocal_bandeja_chic_rap",
		"title": "Bandeja Chic (French Rap Remix)",
		"scene": "Underground Parigi & Street Padel",
		"category": "Canzoni Cantate",
		"bpm": 125,
		"key": "F# minor",
		"style": "Urban French Rap Remix con flow ritmico incalzante, bassi 808 profondi e percussioni trap-house",
		"prompt": "Urban French Rap vocal remix, 125 BPM, rhythmic French rap flow, deep 808 sub-bass, snappy trap-house percussion, stylish street padel attitude",
		"preview_offset": 30.0
	},
	# 5 Boss & Battle Champions Special Tracks (Epico / Anime Special)
	"ost_apex_victory": {
		"id": "ost_apex_victory",
		"title": "Apex Victory",
		"scene": "Boss Fight & Circuito Cyber",
		"category": "Epico / Anime Special",
		"bpm": 174,
		"key": "F minor",
		"style": "Cyberpunk Darksynth / Breakcore ad alta velocità con synth acidi e percussioni frenetiche",
		"prompt": "High-speed Cyberpunk Darksynth / Breakcore boss theme, 174 BPM, distorted acid synth bass, relentless amen break-inspired percussion, dark cinematic stabs, futuristic neon adrenaline sports battle"
	},
	"ost_clash_of_champions": {
		"id": "ost_clash_of_champions",
		"title": "Clash of Champions",
		"scene": "Gran Finale & Climax Caldera",
		"category": "Epico / Anime Special",
		"bpm": 160,
		"key": "E minor",
		"style": "Symphonic Rock da battaglia epico con ottoni maestosi, archi impetuosi e chitarre trionfali",
		"prompt": "Epic symphonic battle rock, 160 BPM, soaring triumphant brass fanfare, driving distorted power chords, frantic cinematic staccato strings, massive taiko impacts, grand tournament finals climax"
	},
	"ost_reflex_strike": {
		"id": "ost_reflex_strike",
		"title": "Reflex Strike",
		"scene": "Duello Riflessi & Match Point",
		"category": "Epico / Anime Special",
		"bpm": 174,
		"key": "A minor",
		"style": "Fast Action Darksynth con beat incalzante, riff di chitarra elettrica e percussioni taiko",
		"prompt": "Fast-paced adrenaline darksynth action track, 174 BPM, relentless electronic pulse, aggressive electric guitar riffs, heavy taiko drum hits, dramatic tension for critical reflex duel"
	},
	"ost_iron_juggernaut": {
		"id": "ost_iron_juggernaut",
		"title": "Iron Juggernaut",
		"scene": "Boss Meccanico & Fonderia a Vapore",
		"category": "Epico / Anime Special",
		"bpm": 142,
		"key": "D minor",
		"style": "Industrial Steampunk Metal con chitarre a 8 corde, ritmi meccanici e sfiatatoi a vapore",
		"prompt": "Industrial Steampunk Metal boss fight theme, 142 BPM, low-tuned 8-string mechanical guitar chugs, hydraulic piston rhythms, steam release sound effects, unstoppable iron machine march"
	},
	"ost_thunder_strike": {
		"id": "ost_thunder_strike",
		"title": "Thunder Strike",
		"scene": "Arena Torii & Scontro dei Campioni",
		"category": "Epico / Anime Special",
		"bpm": 155,
		"key": "G minor",
		"style": "Anime Battle Rock con shamisen tradizionale, batteria doppia cassa e chitarre sferzanti",
		"prompt": "High-voltage Japanese Anime Battle Rock, 155 BPM, blazing electric guitar lead dueling with aggressive shamisen, galloping double-kick drums, thunderstorm ambience, electrifying tournament clash"
	},
}

const SUPPORTED_EXTENSIONS := [".ogg", ".mp3", ".wav"]

## Dual-player setup for seamless crossfading
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null
var _current_track_id: String = ""
var _tween: Tween = null
var _current_intensity: float = 0.0
## True while playback is held (the streams are frozen, not stopped).
var _paused: bool = false
## Where the active track sits while held; also what `resume()` plays from.
var _paused_position: float = 0.0
## A seek requested while held. Measured on Godot 4.7: a seek on a paused
## `AudioStreamPlayer` does not stick, so it is recorded here and applied on resume.
var _pending_seek: float = -1.0


func _init() -> void:
	name = "SoundtrackManager"


func _ready() -> void:
	_setup_players()


func _setup_players() -> void:
	if _player_a != null and _player_b != null:
		return

	var mixer = MixerContract.new()
	mixer.ensure_bus(MUSIC_BUS_NAME)

	_player_a = AudioStreamPlayer.new()
	_player_a.name = "MusicPlayerA"
	_player_a.bus = MUSIC_BUS_NAME
	add_child(_player_a)

	_player_b = AudioStreamPlayer.new()
	_player_b.name = "MusicPlayerB"
	_player_b.bus = MUSIC_BUS_NAME
	add_child(_player_b)


## Returns all 82 registered OST track IDs.
static func all_track_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in CONTEXT_TRACK_MAP:
		out.append(CONTEXT_TRACK_MAP[k])
	for k in ARENA_TRACK_MAP:
		var tid: String = ARENA_TRACK_MAP[k]
		if not out.has(tid):
			out.append(tid)
	return out


## Returns the metadata dictionary for a track ID, or an empty Dictionary if unknown.
static func track_info(track_id: String) -> Dictionary:
	return TRACK_METADATA.get(track_id, {})


## Returns the starting playback offset (in seconds) for Emporio audio sample preview.
## Vocal tracks jump straight to their sung hook/chorus, while standard tracks default to 0.0s.
static func preview_offset(track_id: String) -> float:
	var info := track_info(track_id)
	return float(info.get("preview_offset", 0.0))


## Resolves an arena ID to its designated OST track ID.
static func track_id_for_arena(arena_id: String) -> String:
	return String(ARENA_TRACK_MAP.get(arena_id, "ost_officina"))


## Resolves a system context (e.g. "menu", "career", "climax") to its track ID.
static func track_id_for_context(ctx_name: String) -> String:
	return String(CONTEXT_TRACK_MAP.get(ctx_name, "ost_menu"))


## Returns candidate file paths on disk for a given track ID in order of preference.
static func candidate_paths(track_id: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for ext in SUPPORTED_EXTENSIONS:
		paths.append(MUSIC_DIR + track_id + ext)
	return paths


## Checks if an audio file exists on disk for the given track ID.
static func has_track(track_id: String) -> bool:
	for path in candidate_paths(track_id):
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return true
	return false


## Checks if a track exists for a specific arena.
static func has_track_for_arena(arena_id: String) -> bool:
	var tid := track_id_for_arena(arena_id)
	return has_track(tid)


## Loads the AudioStream for the given track ID if available, or returns null.
static func load_stream(track_id: String) -> AudioStream:
	for path in candidate_paths(track_id):
		var global_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(global_p):
			if path.ends_with(".ogg"):
				var ogg = AudioStreamOggVorbis.load_from_file(global_p)
				if ogg != null:
					ogg.loop = true
					return ogg
			elif path.ends_with(".mp3"):
				var mp3 = AudioStreamMP3.new()
				mp3.data = FileAccess.get_file_as_bytes(global_p)
				mp3.loop = true
				return mp3
			elif path.ends_with(".wav"):
				var wav = AudioStreamWAV.new()
				wav.data = FileAccess.get_file_as_bytes(global_p)
				return wav
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				return res
	return null


## Gets the currently active track ID.
func get_current_track_id() -> String:
	return _current_track_id


func current_track_id() -> String:
	return _current_track_id


## ---------------------------------------------------------------------------
## Playback readout (additive).
##
## The Jukebox player card shows real elapsed/duration/progress, so it needs to
## read the state `play_track()` and `stop()` already own. These five readers are
## views over that same dual-player state — no playback path changes here, and a
## caller that never asks for a readout behaves exactly as before.
## ---------------------------------------------------------------------------

## The player currently carrying the music, or null before `_setup_players()`.
func active_player() -> AudioStreamPlayer:
	return _active_player


## True while the active player is really emitting audio (during the crossfade
## out of `stop()` this stays true until the fade completes, which is honest).
func is_playing() -> bool:
	return _active_player != null and _active_player.playing


## True while a track is loaded — playing or held. False at idle and after `stop()`,
## which is the state a transport button should key its enabled-ness off.
func is_active() -> bool:
	if _active_player == null or _current_track_id == "":
		return false
	# A stream that has run to its end is neither playing nor held, so it is not active:
	# the transport must not offer a seek into something that is no longer running.
	return _paused or _active_player.playing


## True while playback is held by `pause()`. A held stream is not playing, so this is
## a third state, not a synonym for either.
func is_paused() -> bool:
	return _paused


## Elapsed seconds of the active stream; 0.0 while stopped or absent. While held this
## is the frozen (or most recently requested) position, so a paused readout is honest.
func playback_position() -> float:
	if _paused:
		return maxf(_paused_position, 0.0)
	if _active_player == null or not _active_player.playing:
		return 0.0
	return maxf(_active_player.get_playback_position(), 0.0)


## Duration in seconds of the active stream; 0.0 when there is no stream or the
## stream reports no length. A 0.0 here means "unknown", never "finished".
func playback_duration() -> float:
	if _active_player == null or _active_player.stream == null:
		return 0.0
	return maxf(_active_player.stream.get_length(), 0.0)


## Fraction of the active stream already played, clamped to [0, 1]. Returns 0.0
## when stopped, idle or when the duration is unknown, so a caller can drive a bar
## straight from this without inventing a value. A held stream still reports its
## frozen fraction.
func playback_progress() -> float:
	var duration := playback_duration()
	if duration <= 0.0 or not is_active():
		return 0.0
	return clampf(playback_position() / duration, 0.0, 1.0)


## Holds playback where it is. Both players are frozen, not just the active one, and a
## crossfade in flight is held too — otherwise the fade's own volume tween would keep
## walking volumes while the mix was supposedly stopped. Returns false when there is
## nothing playing to hold.
func pause() -> bool:
	if _paused:
		return true
	if _active_player == null or not _active_player.playing:
		return false
	# Read the position BEFORE freezing, so resume returns to where the listener was
	# rather than to wherever the in-flight mix buffer happened to be.
	_paused_position = maxf(_active_player.get_playback_position(), 0.0)
	_pending_seek = -1.0
	if _tween != null and _tween.is_valid():
		_tween.pause()
	_freeze_players(true)
	_paused = true
	return true


## Releases a held stream from the same position. A seek requested while held is applied
## here, once the audio thread can take it.
func resume() -> bool:
	if not _paused:
		return false
	_freeze_players(false)
	if _active_player != null:
		var target := _pending_seek if _pending_seek >= 0.0 else _paused_position
		_active_player.seek(_position_within(target, playback_duration()))
	if _tween != null and _tween.is_valid():
		_tween.play()
	_paused = false
	_pending_seek = -1.0
	return true


## Moves the ACTIVE stream to `seconds` (clamped into the stream). This is the same
## stream the readout reports, so it is independent of which row the list has selected.
## While held the request is recorded and the held readout reports it immediately; a
## paused stream cannot take the engine seek, so it is applied on resume.
func seek(seconds: float) -> bool:
	if _active_player == null or _active_player.stream == null or _current_track_id == "":
		return false
	var target := _position_within(seconds, playback_duration())
	if target < 0.0:
		return false
	if _paused:
		_paused_position = target
		_pending_seek = target
		return true
	if not _active_player.playing:
		return false
	_active_player.seek(target)
	return true


## Clamp into [0, duration]; -1.0 when the duration is unknown, which every caller
## above reads as "do not move".
func _position_within(seconds: float, duration: float) -> float:
	if duration <= 0.0:
		return -1.0
	return clampf(seconds, 0.0, duration)


## Freezes or releases BOTH players. `stream_paused` is set unconditionally (a stopped
## player keeps the flag harmlessly) and cleared the same way, which is what stops a
## held flag from leaking into the next track.
func _freeze_players(hold: bool) -> void:
	for player in [_player_a, _player_b]:
		if player != null:
			player.stream_paused = hold


## Plays an OST track with an optional crossfade duration in seconds.
func play_track(track_id: String, fade_duration: float = 1.0) -> bool:
	_setup_players()

	if _current_track_id == track_id and _active_player != null:
		# The same track asked for again: a held one is released from where it was, and
		# a playing one is left alone — the behaviour this call already had.
		if _paused:
			return resume()
		if _active_player.playing:
			return true

	# Validate the request BEFORE touching transport state. A missing or unreadable track
	# must leave a held track held, frozen, and exactly where it was — clearing the hold
	# first would silently release audio to play a track that never starts.
	var stream := load_stream(track_id)
	if stream == null:
		# Fallback: track file not found on disk
		return false

	# A new track always starts playing: no hold flag and no deferred seek may survive
	# into it, or a fresh track would open silent or jump to the previous position.
	_freeze_players(false)
	_paused = false
	_paused_position = 0.0
	_pending_seek = -1.0

	var incoming_player := _player_b if _active_player == _player_a else _player_a
	var outgoing_player := _active_player

	incoming_player.stream = stream
	incoming_player.volume_db = -80.0
	incoming_player.play()

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	if outgoing_player != null and outgoing_player.playing:
		_tween.tween_property(outgoing_player, "volume_db", -80.0, fade_duration)
		_tween.chain().tween_callback(Callable(outgoing_player, "stop"))

	_tween.tween_property(incoming_player, "volume_db", 0.0, fade_duration)

	_active_player = incoming_player
	_current_track_id = track_id
	return true


## Plays the track assigned to the given arena.
func play_for_arena(arena_id: String, fade_duration: float = 1.0) -> bool:
	var tid := track_id_for_arena(arena_id)
	return play_track(tid, fade_duration)


## Plays a UI/system context theme ("menu", "roster", "career", "climax", "victory").
func play_context(ctx_name: String, fade_duration: float = 1.0) -> bool:
	var tid := track_id_for_context(ctx_name)
	return play_track(tid, fade_duration)


## Fades out and stops current music playback.
func stop(fade_duration: float = 0.5) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if _paused:
		# A held stop is IMMEDIATE. Releasing the freeze and then fading would let the
		# stream play for the length of the fade — a short resumption of audio on a
		# control that is supposed to silence it. Both players are stopped outright.
		_hard_stop_players()
		_paused = false
		_paused_position = 0.0
		_pending_seek = -1.0
		_current_track_id = ""
		return

	_paused = false
	_paused_position = 0.0
	_pending_seek = -1.0
	_freeze_players(false)

	if _active_player != null and _active_player.playing:
		_tween = create_tween()
		_tween.tween_property(_active_player, "volume_db", -80.0, fade_duration)
		_tween.tween_callback(Callable(_active_player, "stop"))

	_current_track_id = ""


## Silences both players outright: stop first, then release the freeze, so no mix can
## pick the stream up again between the two calls.
func _hard_stop_players() -> void:
	for player in [_player_a, _player_b]:
		if player == null:
			continue
		player.stop()
		player.stream_paused = false


func _exit_tree() -> void:
	# A scene may disappear while a crossfade is pending. Release both stream
	# references explicitly, including a paused/outgoing decoder.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_hard_stop_players()
	for player in [_player_a, _player_b]:
		if is_instance_valid(player):
			player.stream = null
	_active_player = null


## Updates match intensity (0.0 to 1.0) for dynamic audio adjustments.
func set_intensity(intensity: float) -> void:
	_current_intensity = clampf(intensity, 0.0, 1.0)
	# Volume modulation or bus effects can be hooked here based on match tension
