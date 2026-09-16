# Evidence: Steamworks integration route

Ticket: [Steamworks integration route](../tickets/steamworks-integration-route.md)
Date: 2026-09-16 · Author: crew (AFK research)
Target: **Godot 4.7.2.stable.official.ed1daf0bf**, pinned at
`/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (version string read from the
binary by the [Godot headless harness](../tickets/godot-headless-harness.md) ticket).

Scope note: this ticket picks the *bridge*. The live Steam App ID, achievement API
names and cloud quota stay in [Steamworks prerequisites](../tickets/steamworks-prerequisites.md).
A development/test app (or Valve's app ID 480, Spacewar) is enough for everything below.

---

## 1. Candidates compared

Three real, currently-maintained options. All three expose the three things v1
promises — achievements, Steam Cloud (Remote Storage), and the overlay:

| # | Candidate | Kind | Current release | Declared Godot support |
|---|---|---|---|---|
| A | **GodotSteam — GDExtension plug-in** (Community Edition) | GDExtension addon (`.gdextension` + prebuilt `.so`/`.dll`/`.dylib`) | **4.22.1 Stable**, 2026-09-04 (Steamworks SDK 1.65) | "Works on any Godot version 4.4 and up" (release note); Asset Store field "Minimum Godot Version: 4.4.1" |
| B | **GodotSteam — module / pre-compiled editor + templates** (Community Edition) | custom engine build (editor binaries + export templates) | **4.22.1 Stable**, 2026-09-04 (Steamworks SDK 1.65) | explicitly built "In Godot 4.7.2 and 4.5.2 variants" |
| C | **Heathen Engineering — Foundation for Steamworks** | third-party GDExtension (C++ core, C# facade) | repo created 2026-05-04; README badge "Steamworks SDK 1.63"; no tagged release list read | README "Requirements: **Godot 4.6** or compatible"; badge "Godot 4.6 +" |

A and B are the same upstream project (GodotSteam, by Gramps) in two delivery forms;
C is an independent binding. A/B are the sane comparison because they are the two
build-time shapes this project could actually adopt; C is included because it is the
only other maintained GDExtension-class binding found and it fails two v1 needs (see §4).

### Evidence for each claim

- **A, release + Godot range.** Codeberg release `Godot 4.4+ - Steamworks 1.65 - GodotSteam GDExtension 4.22.1 Stable`, dated 2026-09-04, states "Works on any Godot version 4.4 and up. Just drop the contents of this zip into the base of your project and that's it! Available for Windows, Linux, Android ARM64, and OSX." Download: `godotsteam-4.22.1-gdextension-plugin-4.4.zip`. Source: https://codeberg.org/godotsteam/godotsteam/releases
- **A, minimum engine version, second source.** Godot Asset Store listing "GodotSteam for GDExtension" (last updated 2026-08-05) carries "Minimum Godot Version: 4.4.1" and the known issue "GDExtension for 4.4 is not compatible with 4.3.x or lower". Source: https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/
- **B, explicit 4.7.2.** Same release page, entry `Godot 4.x - Steamworks 1.65 - GodotSteam 4.22.1 Stable`, dated 2026-09-04: "For a full list of changes, please check the change-log here. **In Godot 4.7.2 and 4.5.2 variants.**" Artefacts are named for the engine: `linux64-g472-s165-gs4221-editor.tar.xz`, `win64-g472-s165-gs4221-editor.tar.xz`, `godotsteam-g472-s165-gs4221-templates.tar.xz`. Source: https://codeberg.org/godotsteam/godotsteam/releases
- **B, what ships in the zip.** Same release note: "Zips include the relevant Steam API .dll/.so/.dylib files." (So even the module route still ships Valve's redistributable.) Source: https://codeberg.org/godotsteam/godotsteam/releases
- **A/B share one release train.** GDExtension changelog: "As of version 4.22, however, all changes refer to the godot4 branch as they have been merged." and 4.22 "Changed: merged GDExtension branch into Godot 4". Source: https://godotsteam.com/changelog/gdextension/
- **A, ABI baseline is 4.4.** GodotSteam's own build guide: "git clone https://github.com/godotengine/godot-cpp.git **-b 4.4** godot-cpp … **We currently use 4.4 to compile the official GDExtensions.**" This is the concrete reason the "4.4 and up" claim is a declaration, not a per-version certification against 4.7.2. Source: https://godotsteam.com/howto/gdextension/
- **C, requirements.** README "Requirements: **Godot 4.6** or compatible; a registered Steamworks developer account; **Steamworks SDK 1.63** — download from the Steamworks partner portal and place in `addons/FoundationSteamworks/include/sdk/`; a C++ build environment (GCC/Clang + CMake) only if building from source", plus "Pre-built binaries for Linux x86_64 are included. **Windows and macOS builds require compiling from source.**" Source: https://github.com/heathen-engineering/Godot-Foundation-for-Steamworks
- **C, overlay is split into the paid tier.** Same README: Foundation owns "User, Achievements, Stats, Leaderboards, App/Utilities … fully", while "Everything else (Lobby/Matchmaking, Friends beyond the basics, Inventory, UGC/Workshop, Input, **Overlay**, Parties, RemoteStorage, RemotePlay, Screenshots, Voice, Timeline, Clans) — Foundation owns the **data types and native SDK plumbing only** … The *convenience* operational surface … is Toolkit's to add", Toolkit being a commercial extension behind GitHub Sponsorship. Source: https://github.com/heathen-engineering/Godot-Foundation-for-Steamworks
- **All Steam bindings expose the three v1 features.** GodotSteam Remote Storage class: "Provides functions for reading, writing, and accessing files which can be stored remotely in the Steam Cloud." (https://godotsteam.com/classes/remote_storage/). Achievements: the common-issues page documents set/get achievement behaviour and that "GodotSteam should do this by default when you initialize Steamworks" (https://godotsteam.com/issues/common_issues/). Overlay: same page's "Steam Overlay" section, plus Valve's own statement "Your game does not need to do anything special for the overlay to work, it automatically hooks into any game launched from Steam … While in development and running your game in a debugger, the overlay is loaded when you call SteamAPI_Init." (https://partner.steamgames.com/doc/features/overlay)

---

## 2. Compatibility against Godot 4.7.2 — read this honestly

**Verdict: NOT verified for 4.7.2 by an exact-version statement for the chosen
GDExtension route. Declared by range only. This is the single open risk.**

- Candidate **A (GDExtension)** declares **"any Godot version 4.4 and up"**
  (release note) / "Minimum Godot Version: 4.4.1" (Asset Store). 4.7.2 sits inside
  that declared range, and 4.7.x is a minor release of the same 4.x ABI family, but
  **no upstream document names 4.7.2 for the GDExtension build.** The plug-in is
  compiled against godot-cpp `4.4`, not `4.7`. → **UNVERIFIED for exact 4.7.2.**
- Candidate **B (module)** is the only artefact upstream names 4.7.2 for, explicitly,
  with a 4.7.2-specific editor and template set. That is a much stronger compatibility
  statement — but it buys it by replacing the engine binary (§3).
- Candidate **C** declares Godot 4.6+, worded as "or compatible", and has no released
  version I could pin. → **UNVERIFIED, and unverifiable from releases alone.**
- The corroborating signal for A: the same 4.22.1 code base, merged into one branch,
  is what B compiles for 4.7.2. That makes "the source supports 4.7.2" well supported;
  it does **not** prove that the prebuilt 4.4-ABI `.so` loads in a 4.7.2 editor.

**Cheap empirical check that closes this gap** (not performed here: it needs a binary
download, which this ticket forbids): unzip `godotsteam-4.22.1-gdextension-plugin-4.4.zip`
into a scratch project, run the pinned binary headless, and assert
`Engine.has_singleton("Steam")` is `true` and `steamInitEx()` returns a status code
rather than erroring on load. That single probe converts "declared" into "verified"
for this exact engine. Record the result on this ticket when it runs.

---

## 3. What each route needs at build time

### A — GodotSteam GDExtension (chosen route)

- **Addon only, no engine swap.** Drop `godotsteam-4.22.1-gdextension-plugin-4.4.zip`
  into the project root → `addons/godotsteam/`. The pinned stock
  `Godot_v4.7.2-stable_linux.x86_64` stays the engine. Source: https://codeberg.org/godotsteam/godotsteam/releases
- **Native libraries.** `addons/godotsteam/<platform>/libgodotsteam.<os>.template_{debug,release}.x86_64.so|.dll|.dylib` **plus** Valve's `libsteam_api.so` / `steam_api64.dll` / `libsteam_api.dylib`. GodotSteam's own folder layout: `addons/godotsteam/linux64/{libgodotsteam.linuxbsd.template_*.x86_64.so, libsteam_api.so}`. Source: https://godotsteam.com/howto/gdextension/
- **Export templates: stock Godot templates, explicitly not GodotSteam's.** "When using the GDNative or GDExtension version of GodotSteam, you will need to use the regular Godot templates … do not use the GodotSteam templates. That will cause a lot of issues." Source: https://godotsteam.com/tutorials/exporting_shipping/. Same statement on the Asset Store page.
- **Ship the bridge libs.** "take note of any additional files Godot exports for you like the godotsteam.dll / libgodotsteam.so / libgodotsteam.dylib because these must also be shipped with your game." Source: https://godotsteam.com/tutorials/exporting_shipping/
- **Headless/standalone variant is possible.** "as long as you don't call any methods on the Steam class provided by this plugin, you can actually simply not export those binaries" — i.e. a Steam-free build can omit the plug-in libs entirely. Source: https://godotsteam.com/tutorials/exporting_shipping/
- **App ID at dev time:** Project Settings → Steam → Initialization, or `steamInitEx(480)`, or `SteamAppId`/`SteamGameId` env vars, or `steam_appid.txt` (not shipped). Source: https://godotsteam.com/tutorials/initializing/
- **Do not mix with the module build:** "Do not use the GDExtension version of GodotSteam with any of the module versions … They are not compatible with each other." Source: https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/
- **Double-precision engine:** "if you are using Godot Engine that has double-precision enabled, using the GDNative or GDExtension plug-ins may crash the editor as they are not compiled with double-precision." Irrelevant while the pinned build is single-precision, but it would break a future double-precision switch. Source: https://godotsteam.com/issues/common_issues/

### B — GodotSteam module / pre-compiled

- **Replace the engine.** Two editor binaries (debug/release as needed) *and* the
  matching export templates must be installed from the `-g472-` artefacts; the project
  must then be run and exported with that editor. Source: https://codeberg.org/godotsteam/godotsteam/releases
- **Export templates are mandatory and version-locked.** "If you use a non-GodotSteam
  template or leave these fields blank, you will end up with an executable that crashes":
  `Parse Error: The identifier "Steam" isn't declared in the current scope.` Source: https://godotsteam.com/tutorials/exporting_shipping/
- **Valve libs cannot be dropped.** "While this may work with the plug-ins, you will
  still have to ship the Steam API shared libraries (steam_api64.dll, libsteam_api.so,
  libsteam.dylib) if using the pre-compiled editor / templates **since Steam is always
  present**." Source: https://godotsteam.com/tutorials/exporting_shipping/
- **Cost to this repo:** the pinned binary `4.7.2.stable.official.ed1daf0bf` is the
  provenance for the [Godot headless harness](../tickets/godot-headless-harness.md)
  evidence (`PASS 8/8`). The module route swaps the engine out from under that proof.

---

## 4. What breaks headless CI

Common to both routes unless guarded:

1. **No Steam client on the runner → init fails by design, not by crash.**
   `steamInitEx()` returns `status: 2` = "We cannot connect to Steam, the client
   probably isn't running" (1 = other failure, 3 = client out of date, 0 = success).
   CI must treat status ≠ 0 as a soft failure and continue. Source: https://godotsteam.com/tutorials/initializing/
   Related runtime error if the client is up but the account has no licence:
   `ConnectToGlobalUser failed`. Source: https://godotsteam.com/issues/common_issues/
2. **Missing `libsteam_api.so` next to the binary** → hard loader failure:
   `error while loading shared libraries: libsteam_api.so: cannot open shared object
   file: No such file or directory`. Source: https://godotsteam.com/issues/linux_issues/
3. **Missing plug-in / wrong templates** → `Parse Error: The identifier "Steam"
   isn't declared in the current scope` (module route), or a GDExtension that silently
   fails to register, leaving `Engine.has_singleton("Steam") == false`. Source: https://godotsteam.com/tutorials/exporting_shipping/
4. **Overlay cannot be tested headless at all.** "Overlay will not work in the editor
   but will work in export projects when uploaded to Steam. This seems to a limitation
   with Vulkan currently." Plus the documented Forward+/Vulkan flicker from 4.x. So the
   overlay needs one manual Steam-client run, not a CI assertion. Sources:
   https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/ ,
   https://godotsteam.com/issues/common_issues/
5. **GDExtension leftovers.** Unregistering the plug-in "need[s] to also alter the
   extension_list.cfg file located in your .godot folder … the game will produce some
   errors in your log files when run. They are harmless, however, just a little
   annoying." CI logs must not fail on those lines. Source: https://godotsteam.com/tutorials/remove_steam/
6. **Double-precision** engine → GDExtension editor crash (§3A).
7. **Module route only:** the CI engine binary is no longer the pinned one, so every
   existing harness log stops describing the binary under test.

---

## 5. Decision

**Chosen route: A — GodotSteam GDExtension plug-in, release 4.22.1 (Steamworks SDK 1.65),
with B (GodotSteam 4.22.1 module pre-compiles for Godot 4.7.2) as the documented
fallback if the prebuilt plug-in fails to load in the pinned 4.7.2 binary.**

Reasons, in order of weight:

1. **It preserves the pinned toolchain.** The engine stays
   `4.7.2.stable.official.ed1daf0bf`; the module route replaces it and invalidates the
   harness provenance. One less thing that can differ between CI and release.
2. **It is the upstream-supported shape for shipping on stock Godot.** GodotSteam
   explicitly instructs GDExtension users to use normal Godot templates — the exact
   templates this project already has.
3. **The Steam-free standalone build is an explicit, documented path** (§3A, omit the
   plug-in binaries and guard calls), which is precisely the v1 requirement that the
   game still runs standalone. The module route always drags Valve's libs along.
4. **All three v1 features are covered** by the same class surface the module route
   uses (achievements/stats, Remote Storage for cloud, overlay).
5. **Failure mode is narrow and detectable.** If the 4.4-ABI `.so` does not register on
   4.7.2, the symptom is `Engine.has_singleton("Steam") == false` at startup — caught by
   the one probe in §2, with route B (explicit 4.7.2 builds) as the fallback.
6. **C was rejected**: overlay ergonomics live in the paid Toolkit, Windows/macOS
   binaries must be self-compiled, it targets SDK 1.63 vs 1.65, and it declares only
   "Godot 4.6 or compatible" with no pinnable release.

### No-Steam fallback (v1 requirement: standalone still runs)

Adopt GodotSteam's documented singleton-check pattern:

```
if Engine.has_singleton("Steam"):
    steam_api = Engine.get_singleton("Steam")
    var init := steam_api.steamInitEx()
    if init['status'] > 0:      # 2 = client not running, 3 = outdated, 1 = other
        steam_api = null        # Steamworks disabled for this run
else:
    steam_api = null            # plug-in absent or stripped from the build
```

with a single `is_steam_enabled()` gate in front of every achievement, cloud and
overlay call, so a headless CI run, a Steam-less laptop run and an itch-style build all
take the same non-Steam path instead of crashing. Source for the pattern (upstream
tutorial, including the `Engine.has_singleton` check and the `status > 0` disable):
https://godotsteam.com/tutorials/remove_steam/

Consequence for the cloud-save requirement: cloud save must be layered *on top of* the
local save, never the only copy — which is the input to
[Save and cloud format](../tickets/save-and-cloud-format.md).

---

## 6. Source list (URL → exact claim it supports)

| # | URL | Claim it supports |
|---|---|---|
| 1 | https://codeberg.org/godotsteam/godotsteam/releases | GodotSteam 4.22.1 Stable (module) is dated 2026-09-04 and ships "In Godot 4.7.2 and 4.5.2 variants" with `*-g472-*` editor and template artefacts; GodotSteam GDExtension 4.22.1 Stable (same date) "Works on any Godot version 4.4 and up" and is a drop-in zip; both are Steamworks SDK 1.65; zips include the Steam API `.dll/.so/.dylib`. (Primary release source; the GitHub repo is archived and redirects here.) |
| 2 | https://github.com/GodotSteam/GodotSteam | The GodotSteam GitHub repository is **ARCHIVED** — "This repository has been moved to Codeberg". Confirms Codeberg is the canonical release host. |
| 3 | https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/ | GDExtension listing: "Minimum Godot Version: 4.4.1"; "GDExtension for 4.4 is not compatible with 4.3.x or lower"; "Overlay will not work in the editor but will work in export projects when uploaded to Steam … limitation with Vulkan"; "use the normal Godot Engine templates instead of our GodotSteam templates"; "Do not use the GDExtension version … with any of the module versions". |
| 4 | https://godotsteam.com/changelog/gdextension/ | "As of version 4.22 … all changes refer to the godot4 branch as they have been merged" — the GDExtension and module share one release train after 4.22. |
| 5 | https://godotsteam.com/howto/gdextension/ | Official GDExtensions are compiled against **godot-cpp `-b 4.4`** ("We currently use 4.4 to compile the official GDExtensions") → the ABI baseline is 4.4, so "4.4 and up" is a declaration; also documents the required `addons/godotsteam/<platform>/` layout with `libgodotsteam.*` + `libsteam_api.so`, and that a Steamworks SDK download requires a partner account. |
| 6 | https://godotsteam.com/tutorials/initializing/ | App-ID methods (Project Settings / `steamInitEx(480)` / `SteamAppId` env / `steam_appid.txt`); `steamInitEx()` status codes 0 success, 1 other failure, **2 = client probably not running**, 3 = client out of date. |
| 7 | https://godotsteam.com/tutorials/exporting_shipping/ | Module route **requires** GodotSteam templates, else `Parse Error: The identifier "Steam" isn't declared in the current scope`; GDExtension route must use **stock** templates; bridge libs must be shipped; module route must always ship Valve's `steam_api*`/`libsteam_api.so`; a plug-in build can omit those binaries if no Steam methods are called. |
| 8 | https://godotsteam.com/tutorials/remove_steam/ | The documented no-Steam pattern: `Engine.has_singleton("Steam")` guard, `steamInitEx` status check that nulls the API and disables Steamworks, and an `is_steam_enabled()` gate before achievement calls; GDExtension caveat about clearing `extension_list.cfg`. |
| 9 | https://godotsteam.com/issues/linux_issues/ | `error while loading shared libraries: libsteam_api.so: cannot open shared object file` means the Valve lib was not placed next to the executable. |
| 10 | https://godotsteam.com/issues/common_issues/ | Achievements need published backend entries and retrieved user stats; `ConnectToGlobalUser failed` = Steam not started or no licence; Forward+/Vulkan overlay flicker in the editor since Godot 4 alpha; double-precision + GDExtension editor crash; module/plug-in mixing symptoms. |
| 11 | https://godotsteam.com/classes/remote_storage/ | `RemoteStorage` is the Steam Cloud surface (fileRead/Write/Async, fileDelete/Forget, `beginFileWriteBatch`/`endFileWriteBatch`) — the cloud-save API the save ticket will build on. |
| 12 | https://partner.steamgames.com/doc/features/overlay | Valve: the overlay hooks in automatically for games launched from Steam and is loaded when the game calls `SteamAPI_Init` during debug runs. |
| 13 | https://github.com/heathen-engineering/Godot-Foundation-for-Steamworks | Candidate C: "Requirements … Godot 4.6 or compatible … Steamworks SDK 1.63 … C++ build environment only if building from source"; "Pre-built binaries for Linux x86_64 are included. Windows and macOS builds require compiling from source"; overlay and RemoteStorage convenience surfaces sit in the commercial Toolkit. |

---

## 7. Honest gaps (not verified here)

1. **Exact-version 4.7.2 compatibility of the chosen GDExtension binary is UNVERIFIED.**
   Upstream declares a 4.4+ range and compiles against godot-cpp 4.4; nothing names
   4.7.2 for the plug-in. The probe in §2 (load the plug-in under the pinned binary and
   assert `Engine.has_singleton("Steam")`) is the required closing step.
2. No download was performed in this ticket (explicitly out of scope), so the plug-in
   has **not** been loaded in this repo and no in-engine Steam evidence exists here.
3. Overlay behaviour cannot be verified without a Steam client and an app ID, and
   upstream states it never works in the editor — it needs one manual run through Steam.
4. Steam Cloud quota, achievement API names and the live App ID remain in
   [Steamworks prerequisites](../tickets/steamworks-prerequisites.md) (out of scope here).
5. Candidate C has no readable release/tag list, so its current version number could not
   be pinned; the comparison uses its README requirements only.
