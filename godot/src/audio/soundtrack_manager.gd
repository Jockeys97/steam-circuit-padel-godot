extends Node
## soundtrack_manager.gd — Complete OST and Dynamic Music Manager for Steam Circuit Padel Pro.
##
## WHAT IT DOES:
##   Manages playback and smooth crossfades for the 22 orchestral/steampunk OST tracks.
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
}

## Complete metadata dictionary for all 30 OST tracks (22 Standard + 8 Epic/Anime)
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
}

const SUPPORTED_EXTENSIONS := [".ogg", ".mp3", ".wav"]

## Dual-player setup for seamless crossfading
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null
var _current_track_id: String = ""
var _tween: Tween = null
var _current_intensity: float = 0.0


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


## Returns all 22 registered OST track IDs.
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
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				return res
		if FileAccess.file_exists(path):
			if path.ends_with(".ogg"):
				var ogg = AudioStreamOggVorbis.load_from_file(path)
				if ogg != null:
					ogg.loop = true
					return ogg
			elif path.ends_with(".mp3"):
				var mp3 = AudioStreamMP3.new()
				mp3.data = FileAccess.get_file_as_bytes(path)
				mp3.loop = true
				return mp3
			elif path.ends_with(".wav"):
				var wav = AudioStreamWAV.new()
				wav.data = FileAccess.get_file_as_bytes(path)
				return wav
	return null


## Gets the currently active track ID.
func get_current_track_id() -> String:
	return _current_track_id


## Plays an OST track with an optional crossfade duration in seconds.
func play_track(track_id: String, fade_duration: float = 1.0) -> bool:
	_setup_players()

	if _current_track_id == track_id and _active_player != null and _active_player.playing:
		return true

	var stream := load_stream(track_id)
	if stream == null:
		# Fallback: track file not found on disk
		return false

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

	if _active_player != null and _active_player.playing:
		_tween = create_tween()
		_tween.tween_property(_active_player, "volume_db", -80.0, fade_duration)
		_tween.tween_callback(Callable(_active_player, "stop"))

	_current_track_id = ""


## Updates match intensity (0.0 to 1.0) for dynamic audio adjustments.
func set_intensity(intensity: float) -> void:
	_current_intensity = clampf(intensity, 0.0, 1.0)
	# Volume modulation or bus effects can be hooked here based on match tension
