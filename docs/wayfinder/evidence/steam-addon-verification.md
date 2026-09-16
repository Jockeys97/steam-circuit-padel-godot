# Evidence: GodotSteam addon verification (API surface, no Steam client)

Lane: crew-steam — de-risk the Steam integration with **no credential of any kind**.
Date: 2026-09-16 · Host: Linux, 3,910 MB RAM, 0 swap, no GPU, no sound device.
Engine under test: **`4.7.2.stable.official.ed1daf0bf`**
(`/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`, version string printed by every run below).
Repo: `/root/projects/steam-circuit-padel-pro`. `js/**` (frozen reference, commit `2979588`) untouched.
Inputs: [route ticket](../tickets/steamworks-integration-route.md),
[route evidence](steamworks-integration-route.md),
[prerequisites ticket](../tickets/steamworks-prerequisites.md),
[seam evidence](saves-steam-seam.md) §5.3 (the seven assumptions).

**Headline:** the route's single open risk — "does the 4.4-ABI GDExtension load in
4.7.2?" — is now **closed empirically: it loads.** The seven assumptions were
checked against the plug-in's *registered* surface inside the pinned engine and
against upstream source at the release commit. **Two were wrong** (`fileRead`'s
arity and its return keys) and are corrected in the seam. No Steam client, App ID
or credential was involved, and no live Steam behaviour is claimed.

---

## 1. What was fetched, and how far its provenance goes

| # | Artefact | Bytes | sha256 |
|---|---|---|---|
| 1 | `godotsteam-4.22.1-gdextension-plugin-4.4.zip` (the release asset) | 27,290,405 | `2b12b3499434c50da16104a0d22b725aee15cc5cd41223c1cea825bae59bfa8f` |
| 2 | `src/register_types.cpp` @ release commit | 5,053 | `5e6fb201b51f9b41c5bd7b5e88203f0e0969f865f6f535e7ab70f153e0152a83` |
| 3 | `src/godotsteam.cpp` @ release commit | 723,975 | `da1a0676f846cbfe3d4da7da8e4ee5852fc9e97a07a430d4d38163eb06b677c2` |
| 4 | `src/godotsteam.h` @ release commit | 83,054 | `647d5350d725f3e5626e748a0c4207d031d877d25e5836bcd6e7b76ffa14603e` |
| 5 | `src/godotsteam_project_settings.cpp` @ release commit | 8,514 | `e73f920a1d13759dd75a0f3b99db056f7f6fa13a56795cfdfa7b5b8393954d31` |
| 6 | `doc_classes/Steam.xml` @ release commit | 732,804 | `fc99bd7f4093f2fec54c361b5b26645614a7b464603f77892d20f8d00001630d` |
| 7 | `addons/godotsteam/godotsteam.gdextension` (extracted) | 1,323 | `f02059cdf3199a97ab2abfb88ba226af500402f7f9053daa09c158d6b47eda77` |
| 8 | `addons/godotsteam/linux64/libgodotsteam.linux.template_release.x86_64.so` | 4,594,136 | `7aaa02843e5bdb8bfec52cf43dab949663ff38255116956db51f438ec6a95cbe` |
| 9 | `addons/godotsteam/linux64/libgodotsteam.linux.template_debug.x86_64.so` | 4,955,864 | `7d2d5e574390d66b4178b830a256031f9948ba37b1f00051ca8d28c359d39760` |
| 10 | `addons/godotsteam/linux64/libsteam_api.so` (Valve's, shipped in the zip) | 385,840 | `659127fd3c36788162149006efb607ae24c08b7264259c7af52c806fa40c2b4f` |

**Provenance established**

- Asset 1 came from the Codeberg release **tag `v4.22.1-gde`**, release id
  `11980384`, asset uploaded `2026-09-04T01:05:22+02:00`, uploader account
  `gramps`, over HTTPS
  (`https://codeberg.org/godotsteam/godotsteam/releases/download/v4.22.1-gde/godotsteam-4.22.1-gdextension-plugin-4.4.zip`).
  Release metadata read from the Codeberg API, not from a rendered page.
- Codeberg is the canonical host: `https://github.com/GodotSteam/GodotSteam` is
  archived and redirects there (the route evidence says the same).
- Tag `v4.22.1-gde` and tag `v4.22.1` point at the **same commit**
  `5853a7741d174cfa37edee1ca44a11581a989d0b` — independent confirmation of the
  route evidence's "one release train after 4.22" claim. Artefacts 2–6 were fetched
  at that commit, so they describe the same code as the binary.
- The loaded binary **self-reports** `get_godotsteam_version() == "4.22.1"` inside
  the pinned engine (§3), which ties the shipped `.so` to the release number.
- The zip's internal layout matches upstream's documented layout exactly
  (`addons/godotsteam/<platform>/libgodotsteam.*` + Valve's `libsteam_api.so`,
  `steam_api64.dll`, `libsteam_api.dylib`), and its `.gdextension` declares
  `entry_symbol = "godotsteam_init"`, `compatibility_minimum = "4.4"` — the same
  symbol `register_types.cpp` exports.

**Could NOT verify, stated plainly**

1. **No upstream-published checksum or signature exists for this asset.** The
   release body carries only prose ("Works on any Godot version 4.4 and up…") and
   no `SHA256SUMS`/signature file is attached to any asset. So the sha256 above is
   *my* record of what I downloaded; it is not a check against a publisher value.
   Verification therefore rests on transport security, a single canonical host and
   the binary's own version string — **not** on a cryptographic signature.
2. No independent mirror was fetched, so a "same bytes from a second source" check
   was not performed.
3. Nothing about Steam's *server side* was or could be verified (App ID, published
   achievement names, cloud quota) — those live in
   [Steamworks prerequisites](../tickets/steamworks-prerequisites.md), still open.

---

## 2. The seven assumptions, verdict by verdict

Sources for a verdict: **[registered]** = `ClassDB.class_get_method_list("Steam")`
inside the pinned engine (raw dump: `tools/steam-verify/probe/api_surface.json`,
798 methods); **[source]** = upstream C++ at commit `5853a774…`; **[docs]** =
upstream class docs; **[probe]** = this lane's engine runs (§3).

| # | Assumption (as written in `saves-steam-seam.md` §5.3) | Verdict | Actual, with source |
|---|---|---|---|
| 1 | Singleton is named `"Steam"`; `Engine.get_singleton("Steam")` / `has_singleton` is the presence test | **VERIFIED** | `register_types.cpp` calls `Engine::get_singleton()->register_singleton("Steam", Steam::get_singleton())` [source]; [probe] `has_singleton("Steam") == true`, `get_class() == "Steam"` |
| 2 | `steamInitEx(app_id = 0)` → `Dictionary` with int `status` (0 ok / 1 other / 2 client not running / 3 out of date) and string `verbal` | **VERIFIED for the shape; CORRECTED for the code this host returns** | [registered] `steamInitEx(app_id: int, embed_callbacks: bool) -> Dictionary`, defaults `0, false`; [source] `init_result["status"]` / `["verbal"]`, `app_id == 0` falls back to the project setting. **Measured here = `status 1`, `verbal = "Failed to load module '/root/.steam/sdk64/steamclient.so'"` — not 2.** Code 2 means "client installed but not running", which is not this host. Only `!= 0` may be asserted. |
| 3 | `setAchievement(name)` + `storeStats()`, both `bool` | **VERIFIED** | [registered] `setAchievement(achievement_name: String) -> bool`, `storeStats() -> bool`, no defaults; [source] both forward straight to the SDK. Added note: upstream documents `storeStats` as rate limited to "minutes, not seconds" [docs]. |
| 4 | `getAchievement(name)` → `Dictionary` with a `ret` field | **VERIFIED, and incomplete** | [registered] `-> Dictionary`; [source] sets **`ret` (bool) *and* `achieved` (bool)**. The assumption named only `ret`; a caller that wants to know whether the user unlocked it needs `achieved`. |
| 5a | `fileWrite(name, PackedByteArray) -> bool` | **VERIFIED** | [registered] `fileWrite(file: String, data: PackedByteArray, size: int = 0) -> bool`; [source] `data_size = data.size(); if (size > 0) data_size = size;` — so the two-argument call writes **all** the bytes. Additional: an **empty** buffer is a documented failure case [docs], so the seam now refuses a zero-byte write itself. |
| 5b | `fileRead(name)` → `Dictionary` with `ret`/`buf`/`size` | **CORRECTED — this call could never have worked** | [registered] `fileRead(file: String, data_to_read: int) -> Dictionary`, **second argument required, no default**; [probe] the one-argument call used by the seam produces `SCRIPT ERROR: Invalid call to function 'fileRead' in base 'Steam'. Expected 2 argument(s).` and yields null. [source] the result carries `ret` (**int, bytes read**) and `buf` (**`PackedByteArray`**) — **there is no `size` key**. Reaching it also needs `getFileSize(file) -> int` first ([registered]; `-1` when Remote Storage is unavailable [source]). |
| 5c | `fileExists(name) -> bool` | **VERIFIED** | [registered] `fileExists(file: String) -> bool`; [source]. |
| 5d | the `buf` type is unverified | **VERIFIED = `PackedByteArray`** | [registered] return type of the dictionary's payload confirmed in [source]: `file_data["buf"] = data;` where `data` is a `PackedByteArray` sized to the request. Note the buffer is sized to `data_to_read`, so it can be **longer** than what was read; `ret` is the authority. |
| 6 | Overlay is `activateGameOverlay("Friends")`, and is not testable headless | **Method: VERIFIED. Return: CORRECTED (void, not bool). Argument: UNVERIFIABLE. "Not headless-testable": stands.** | [registered] `activateGameOverlay(type: String = "") ->` **nil/void**; [source] it forwards to `SteamAPI_ISteamFriends_ActivateGameOverlay` and returns nothing; [probe] reading a value from it raises `SCRIPT ERROR: Trying to get a return value of a method that returns "void"` (the seam calls it as a statement, which is correct). The **dialog string** cannot be settled here: upstream documents lowercase names (`"friends"`, `"achievements"`, …) [docs], this passes Valve's historical `"Friends"`, and **neither shipped library contains the dialog name table** (`strings` finds no `officialgamegroup`/`friends` in `libgodotsteam.*.so` *or* `libsteam_api.so`), so the match happens inside the Steam client. Left as it was, flagged. No Steam client here → no headless assertion is possible. |
| 7 | Cloud file naming `padel-<group>.json` | **UNVERIFIED-BY-DECISION** (it is a policy placeholder, not an API name) — but the real constraints are now known and the placeholder satisfies them | [docs] Steam filenames are **case-insensitive and lowercased automatically**, must be valid cross-platform filenames, and each file is capped at 100 MiB (`MAX_CLOUD_FILE_CHUNK_SIZE`); zero-byte writes fail. The names this code produces — `padel-prefs.json`, `padel-career.json`, `padel-history.json`, `padel-drill.json`, `padel-feedback.json` (from `save_schema.gd::GROUP_FILES`) — are all lowercase, contain no path separators, and are a few hundred bytes. So the scheme is **compatible**, and is still **not decided**: the naming and the quota belong to the open save-format and prerequisites tickets. |

Nothing else in the seam turned out to be an invented name: every identifier the
real bridge calls (`steamInitEx`, `setAchievement`, `storeStats`, `fileWrite`,
`fileRead`, `fileExists`, `getFileSize`, `activateGameOverlay`, `has_singleton`,
`get_singleton`) exists in the registered surface with the arity used after the
corrections.

---

## 3. What the engine does with no Steam client — raw probe results

All engine runs use the shared lock and an inner `timeout`; one engine process at a
time; nothing ran against `godot/` except the four checks in §4.

### 3.1 The plugin loads in 4.7.2 (the route's open risk, closed)

```sh
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --path /root/projects/steam-circuit-padel-pro/tools/steam-verify/probe/ \
  --script res://probe_api.gd
```

**exit 0**, `real 0m15.331s`. Output verbatim (full copy:
`tools/steam-verify/probe/probe_report.txt`):

```
# ==== passive API-surface probe ====
# engine version = 4.7.2-stable (official)
# addon dir present = true
# .godot/extension_list.cfg = true
# Engine.has_singleton("Steam") = true
# ClassDB.class_exists("Steam") = true
# Engine.get_singleton("Steam").get_class() = Steam
# ClassDB reports 798 methods on class Steam
# full surface written to res://api_surface.json (798 methods)
# ---- target methods, as REGISTERED by the loaded binary ----
#   steamInitEx              (app_id:int, embed_callbacks:bool) -> Dictionary | default_args=["0", "false"]
#   steamInit                (app_id:int, embed_callbacks:bool) -> bool | default_args=["0", "false"]
#   get_steam_init_result    () -> Dictionary | default_args=[]
#   get_godotsteam_version   () -> String | default_args=[]
#   setAchievement           (achievement_name:String) -> bool | default_args=[]
#   storeStats               () -> bool | default_args=[]
#   getAchievement           (achievement_name:String) -> Dictionary | default_args=[]
#   clearAchievement         (achievement_name:String) -> bool | default_args=[]
#   fileWrite                (file:String, data:PackedByteArray, size:int) -> bool | default_args=["0"]
#   fileRead                 (file:String, data_to_read:int) -> Dictionary | default_args=[]
#   fileExists               (file:String) -> bool | default_args=[]
#   fileDelete               (file:String) -> bool | default_args=[]
#   filePersisted            (file:String) -> bool | default_args=[]
#   getFileSize              (file:String) -> int | default_args=[]
#   getFileTimestamp         (file:String) -> int | default_args=[]
#   activateGameOverlay      (type:String) -> nil | default_args=[""]
#   run_callbacks            () -> nil | default_args=[]
#   steamShutdown            () -> nil | default_args=[]
# ---- arity check: the seam's 1-argument fileRead(name) ----
SCRIPT ERROR: Invalid call to function 'fileRead' in base 'Steam'. Expected 2 argument(s).
# ---- steamInitEx(0), the seam's call, with no Steam client ----
[S_API] SteamAPI_Init(): SteamAPI_IsSteamRunning() did not locate a running instance of Steam.
dlopen failed trying to load:
/root/.steam/sdk64/steamclient.so
with error:
/root/.steam/sdk64/steamclient.so: cannot open shared object file: No such file or directory
[S_API] SteamAPI_Init(): Failed to load module '/root/.steam/sdk64/steamclient.so'
#   typeof(reply) = 27 (27 = TYPE_DICTIONARY)
#   keys = ["status", "verbal"]
#   reply['status'] type=2 value=1
#   reply['verbal'] type=4 value='Failed to load module '/root/.steam/sdk64/steamclient.so''
#   status == 0 ? false
#   get_steam_init_result() = { "status": 1, "verbal": "Failed to load module '/root/.steam/sdk64/steamclient.so'" }
#   get_godotsteam_version() = 4.22.1
# ==== passive probe done ====
```

Read this honestly: the plug-in **registers** (798 methods) and
`steamInitEx(0)` **returns a real dictionary** — a status code, not a load failure.
That is exactly the closing probe the route ticket asked for. It also shows the
engine, with no client, reports **status 1** and names the missing
`steamclient.so`; it does *not* report 2.

### 3.2 Do the steam methods crash, hang, or no-op with the gate closed?

One call per engine run, `--script res://probe_call.gd -- <method>`, each with a
`timeout 60`; the file `probe_call_<method>.txt` is written **and closed before**
the native call, so a crash or hang would still leave a record. All eight runs:
**exit 0, no crash, no hang** (full logs in `tools/steam-verify/probe/probe_call_*.txt`).

| Method | What the engine returned | What it logged |
|---|---|---|
| `fileExists` | `false` | `ERROR: Remote Storage class not found, Steam may not be initialized: fileExists` |
| `getFileSize` | `-1` | same shape, `getFileSize` |
| `fileWrite` | `false` | same shape, `fileWrite` |
| `fileRead(name, 64)` | `{ "ret": false }` | same shape, `fileRead` |
| `setAchievement` | `false` | `ERROR: User Stats class not found, Steam may not be initialized: setAchievement` |
| `storeStats` | `false` | same shape, `storeStats` |
| `getAchievement` | `{ }` (empty dictionary) | same shape, `getAchievement` |
| `activateGameOverlay` | void; assigning the result is a `SCRIPT ERROR` | `ERROR: Friends class not found, Steam may not be initialized: activateGameOverlay` |

Every method is null-guarded by upstream
(`ERR_FAIL_COND_V_MSG(SteamAPI_SteamRemoteStorage() == nullptr, …)`) — verified by
reading the implementation, then confirmed by running it. So the seam's gate is a
correctness guard, not a crash guard. Two consequences worth carrying forward:

- **Each unguarded call emits an `ERROR:` line in the log.** A CI job that fails on
  `ERROR:` lines would go red if anything called these with the gate closed, even
  though nothing crashed. The gate is also what keeps the logs clean.
- The header's `cloud_read` had **no** chance of working, and the run proves the
  failure mode was silent-from-the-game's-side: nothing crashes, and the game
  would simply never see a cloud copy.

### 3.3 Negative control — a bare copy of the addon does NOT register

Upstream's release note says "just drop the contents of this zip into the base of
your project and that's it". Measured, that is true only via the editor:

```sh
cp -r tools/steam-verify/probe tools/steam-verify/probe2 && rm -rf tools/steam-verify/probe2/.godot
… --path tools/steam-verify/probe2/ --script res://probe_api.gd
```

**exit 0.** Output: `# .godot/extension_list.cfg = false`,
`# Engine.has_singleton("Steam") = false`, `# ClassDB.class_exists("Steam") = false`,
`# RESULT: the plugin did NOT register; nothing further can be probed.` The addon
directory was present and the `.gdextension` file was in it. Registering needs
`godot/.godot/extension_list.cfg` to list
`res://addons/godotsteam/godotsteam.gdextension` — a **generated** file, produced
by opening the project in the editor. (The probe2 copy was deleted afterwards; the
two commands above reproduce it.)

---

## 4. What changed in the seam, and the tests after the change

Two files, both inside this lane's boundary. The mock path, the factory's default
return value and `live_steam_proven()` are untouched.

| File | Bytes | sha256 (after) | Change |
|---|---|---|---|
| `godot/src/steam/godotsteam_backend.gd` | 12,835 | `63d6a2b2dbc792809020da14588e9a945617a12d6524db94c76a5c315364aac9` | `cloud_read()` corrected (asks `getFileSize` first, then `fileRead(name, size)`, reads `ret` as bytes and slices `buf`); `cloud_write()` refuses an empty buffer; every `UNVERIFIED ASSUMED API` comment replaced with the verified arity/return and the residual doubt; header rewritten to state what is proven and what is not |
| `godot/src/steam/steam_backend_factory.gd` | 4,036 | `3476ab40643e7176d086851dbcfa8fbf0476bc271178a36fa8419f99d1b7cdd4` | swap instructions corrected: a bare addon copy does not register; the probe path was wrong (`res://src/steam/probe.gd` → `res://src/steam/probe_steam_addon.gd`); 4.7.2 compatibility restated as verified |

Unchanged, checked by hash: `godot/src/steam/mock_steam_backend.gd`
`5bd2d2413d53e9eac6ff144ccb8b114dc80b13e9058f2f379d4a19313d449bf0` and
`godot/tests/save_steam_test.gd`
`1eb09f97112bd96948184c248760f1c232568cb61d8150057ce44631dd9a158b` (both identical to
the hashes in [seam evidence](saves-steam-seam.md) §3).

### 4.1 The seam's own test — green

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://tests/save_steam_test.gd
```

**exit 0.** `ok ` lines **137**, `FAIL` lines **0**, `SCRIPT ERROR` lines **0**,
final line **`PASS 137/137`** — same counts as before the change. The seam-relevant
lines still hold: `ok with the addon absent the real bridge reports a non-zero
(soft) status`, `ok the factory's default reports the honest no-Steam status`,
`ok the factory never claims live Steam`.

### 4.2 The engine harness — still `PASS 8/8`

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```

**exit 0**, final line **`PASS 8/8`**. `godot/project.godot` untouched:
`run/main_scene="res://tests/SmokeTest.tscn"` (line 10) — unchanged.

### 4.3 The game's own addon probe — unchanged, and still honest

```sh
… --path godot/ --script res://src/steam/probe_steam_addon.gd    # exit 0
```

```
# res://addons/godotsteam/ present = false
# Engine.has_singleton("Steam") = false
# init status = 2
# init message = GodotSteam singleton absent (addon not installed, or stripped from the build)
# is_steam_enabled = false
# is_mock = false (false means this is the real bridge class)
# live_steam_proven = false (always false: the live proof is a manual Steam-client run)
# RESULT: the addon is not installed in this tree; no Steam behaviour is proven.
```

### 4.4 The no-Steam boundary, checked mechanically

```sh
grep -rn 'Steam\.\|steamInit\|GodotSteam' godot/ --include=*.gd | grep -v '^godot/src/steam/'
```

**0 lines.** No Steam-touching identifier exists outside `godot/src/steam/**`.

---

## 5. Where the fetched addon lives, and why the game project is untouched

The addon was fetched, hashed and loaded **only** from the isolated probe project
`tools/steam-verify/probe/**` (its own `project.godot`, its own
`.godot/extension_list.cfg`). **`godot/addons/` does not exist** — the game project
has no addon and no GDExtension entry. Reasons, in order:

1. Registering the plug-in in `godot/` requires writing the **generated**
   `godot/.godot/extension_list.cfg`, which is outside this lane's write boundary.
2. §3.3 shows a bare copy of the addon is inert; so "install it" without that file
   would add 93 MB of binaries to the repo for no behavioural gain.
3. §3.2 shows an unguarded call with the gate closed is noisy (`ERROR:` lines) and
   the gate is what keeps the harness logs clean.
4. The swap is still a human decision that needs the App ID; this lane's job was to
   make the swap *real*, not to take it.

---

## 6. Findings worth carrying forward

1. **The 4.4-ABI GDExtension loads in `4.7.2.stable.official.ed1daf0bf`.** The
   route's "exact-version compatibility UNVERIFIED" risk (`route evidence` §2, §7)
   is resolved positively: 798 methods registered. The documented **fallback** (the
   4.22.1 module build) is therefore not needed on this evidence.
2. **`status 2` was the wrong expectation for a machine with no Steam client.**
   The real code here is 1 with a verbal naming the missing `steamclient.so`. Any
   test or log assertion must accept **any** non-zero status. (The seam already
   gated on `!= 0`; the comment and the evidence file now say so.)
3. **A wrong API name in this seam would have failed silently, not loudly.** The
   `fileRead` bug produced no crash and no non-zero exit — just an empty cloud
   read forever. That is the failure mode this lane existed to catch.
4. **Registering the plug-in does not auto-initialise Steam.** Upstream's
   `steam/initialization/processes/initialize_on_startup` defaults to `false`
   (`godotsteam_project_settings.cpp`), so merely registering it does not call
   `SteamAPI_InitEx` at startup and cannot surprise a headless CI run.
5. **GDScript runtime errors abort only the function they occur in.** The first
   probe attempt hung for 180 s because the bad-arity call aborted `_initialize()`
   before `quit(0)`, leaving an empty `SceneTree` spinning. The fixed probe puts
   each risky step in its own function and force-quits from `_process`. Anyone
   probing this addon again should do the same.
6. `godotsteam_plugin.gd` is an **editor-only updater** (`EditorPlugin`); it is
   irrelevant to a runtime/headless run, so its absence from the exported game
   costs nothing.

---

## 7. NOT DONE — explicitly

1. **No credential was used, requested or needed.** No Steam App ID, no partner
   account, no Steamworks SDK download, no Store/Asset-Store login. Zero paid spend.
2. **No live Steam behaviour is proven.** No Steam client exists on this host; every
   Steam call here failed by design and returned a documented soft value.
3. **No achievement was unlocked, no stats were stored, no file reached Steam
   Cloud.** No cloud round-trip, no second device, no quota check.
4. **The overlay is not proven and cannot be here** — no client, no App ID, no
   export launched from Steam. Its dialog string remains unverified (§2 row 6).
5. **No Windows or macOS packaging.** Only Linux x86_64 was exercised; the
   `win64`/`win32`/`osx`/`androidarm64`/`linuxarm64`/`linux32` binaries in the zip
   were not loaded or tested.
6. **No export was produced.** No export template was used, no `.pck`, no build
   touched (`godot/build/**`, `export_presets.cfg` untouched).
7. **The addon was not vendored into the game project** (§5) and no
   `godot/addons/godotsteam/**` file was created.
8. **No export-preset or `.gdextension` edit** was made; the plug-in was not added
   to `godot/.godot/extension_list.cfg`.
9. **Achievement API names remain undefined** (`SOURCE_TO_API_NAME` is still `{}`)
   — owned by [Steamworks prerequisites](../tickets/steamworks-prerequisites.md).
10. **The cloud naming and quota are still decisions**, not settled facts (§2 row 7).
11. **No commit, push, deploy or publish.** Nothing outside the boundary was
    modified: `js/**`, `godot/project.godot`, `godot/game/**`,
    `godot/src/{sim,locale,audio,modes,input,save}/**`, `scripts/**`,
    `docs/mission/**`, `docs/wayfinder/map.md` and other lanes' tests are untouched.
12. **The route ticket's own text was not edited** (another lane/parent owns it);
    the two corrections it needs — "status 2" and "exact-version 4.7.2 UNVERIFIED" —
    are recorded here instead.

---

## 8. Reproducing this in full

```sh
# 1. fetch + hash (no credential involved)
cd tools/steam-verify
curl -sSL -o dl/godotsteam-4.22.1-gdextension-plugin-4.4.zip \
  https://codeberg.org/godotsteam/godotsteam/releases/download/v4.22.1-gde/godotsteam-4.22.1-gdextension-plugin-4.4.zip
sha256sum dl/*.zip     # expect 2b12b3499434c50da16104a0d22b725aee15cc5cd41223c1cea825bae59bfa8f

# 2. probe project (persisted in this repo; addons/ is the extracted zip)
#    tools/steam-verify/probe/{project.godot,.godot/extension_list.cfg,addons/godotsteam,probe_api.gd,probe_call.gd}

# 3. registered surface + steamInitEx
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --path $PWD/tools/steam-verify/probe/ --script res://probe_api.gd          # exit 0

# 4. one native call per run, gate closed
for M in fileExists getFileSize fileWrite fileRead setAchievement storeStats getAchievement activateGameOverlay; do
  flock -w 900 /tmp/padel-godot.lock timeout 60 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless \
    --path $PWD/tools/steam-verify/probe/ --script res://probe_call.gd -- "$M"
done   # every one: exit 0, no crash, no hang

# 5. the game itself, unchanged: harness + seam test + its own probe
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/          # PASS 8/8
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/save_steam_test.gd                                              # PASS 137/137
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://src/steam/probe_steam_addon.gd                                        # addon absent, status 2
```
