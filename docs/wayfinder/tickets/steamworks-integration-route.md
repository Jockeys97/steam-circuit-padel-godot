# Steamworks integration route

- Status: resolved
- Type: research
- Mode: AFK
- Owner: crew (AFK research session)
- Blocked by: none
- Resolved: 2026-09-16
- Evidence: [Steamworks integration route](../evidence/steamworks-integration-route.md)

## Dependency correction (2026-09-16, mission gate 1)

This ticket was blocked by [Steamworks prerequisites](steamworks-prerequisites.md).
That was wrong for the research part: bridge selection and its compatibility
check need a Steam development/test app, not the live App ID, and the engine
version the check runs against is now pinned by
[Godot headless harness](godot-headless-harness.md). Only the live release proof
waits on Luca's App ID, and that requirement stays in the prerequisites ticket.

## Question

Choose how the Godot build talks to Steam. Compare the available bridges against
the **chosen** Godot version (see [Godot headless harness](godot-headless-harness.md);
4.7.2 is a proposed default, not confirmed available), and check they expose what
the release promises: achievements, cloud saves, and the overlay. Record what each
needs, what breaks headless tests, and how the game degrades when Steam is not
running, since the current build runs standalone.

Bridge research does **not** need the live App ID; a development/test app
suffices. Only live release proof needs the real ID.

## Resolved when

One route is chosen with reasons, a compatibility check against the chosen Godot
version cites the bridge's own release information, and a fallback is stated for
a build with no Steam client present. Feeds [Save and cloud format](save-and-cloud-format.md).

## Decision (2026-09-16)

**Route: GodotSteam — GDExtension plug-in, release 4.22.1 Stable (Steamworks SDK
1.65, 2026-09-04), added as an `addons/godotsteam/` drop-in.** Fallback route if
the prebuilt plug-in does not load in the pinned binary: **GodotSteam 4.22.1
module pre-compiles, which upstream ships as explicit Godot 4.7.2 variants**
(`linux64-g472-...` editor + `godotsteam-g472-...` templates).

Candidates compared, with current releases and declared Godot support:

| Candidate | Current release | Declared Godot support | 4.7.2 status |
|---|---|---|---|
| GodotSteam GDExtension (Community Edition) | 4.22.1 Stable, 2026-09-04, SDK 1.65 | "any Godot version 4.4 and up"; Asset Store "Minimum Godot Version: 4.4.1" | **UNVERIFIED for exact 4.7.2** — inside the declared range, but upstream names no 4.7.2 plug-in build and compiles against godot-cpp 4.4 |
| GodotSteam module / pre-compiled editor + templates (Community Edition) | 4.22.1 Stable, 2026-09-04, SDK 1.65 | built "In Godot 4.7.2 and 4.5.2 variants" | explicitly named 4.7.2 |
| Heathen "Foundation for Steamworks" (third-party GDExtension) | repo published 2026-05-04, no pinnable release; SDK 1.63 | "Godot 4.6 or compatible" | UNVERIFIED, and unverifiable from releases |

Chosen because it keeps the pinned engine build (`4.7.2.stable.official.ed1daf0bf`)
as the thing under test, uses stock Godot export templates (upstream explicitly
forbids GodotSteam templates with the plug-in), covers achievements, Remote
Storage cloud and overlay from the same class surface as the module build, and
has a documented path to a Steam-free build. The module route was not chosen
because it replaces the engine binary and export templates, which would invalidate
the [Godot headless harness](godot-headless-harness.md) provenance. Heathen was
rejected because overlay ergonomics sit in its paid Toolkit, only Linux x86_64
binaries ship prebuilt, and its engine support is stated as "4.6 or compatible"
with no pinnable release.

**Build-time needs (chosen route):** the `godotsteam-4.22.1-gdextension-plugin-4.4.zip`
addon under `addons/godotsteam/`, containing `libgodotsteam.<os>.template_{debug,release}.*`
**plus Valve's `libsteam_api.so` / `steam_api64.dll` / `libsteam_api.dylib`**, shipped
with the export; stock Godot export templates; no custom editor. A Steam-free build
may omit the plug-in binaries entirely if no Steam method is called.

**Headless CI impact:** with no Steam client, `steamInitEx()` returns `status: 2`
("cannot connect to Steam, the client probably isn't running") — tests must treat
status ≠ 0 as a soft failure and continue. A missing `libsteam_api.so` next to the
binary is a hard loader error; a missing plug-in leaves `Engine.has_singleton("Steam")`
false; unregistered GDExtension entries in `.godot/extension_list.cfg` emit harmless
errors CI must not fail on. **The overlay can never be asserted headless** — upstream
states it does not work in the editor (Vulkan limitation) and only works in an export
launched from Steam, so it needs one manual Steam-client run.

**No-Steam fallback (stated, required for v1):** guard everything on
`Engine.has_singleton("Steam")`; if the singleton is absent, or `steamInitEx()`
returns `status > 0`, null the Steam API and route every achievement, cloud and
overlay call through a single `is_steam_enabled()` gate, so headless CI runs,
Steam-less machines and non-Steam builds take the same local-only path. Cloud saves
are therefore layered on top of the local save, never the only copy — input for
[Save and cloud format](save-and-cloud-format.md).

## Open item carried forward (does not reopen this ticket)

Exact-version 4.7.2 compatibility of the prebuilt GDExtension binary is
**unverified**; upstream declares a 4.4+ range and links against godot-cpp 4.4.
Closing probe, to run when the plug-in zip is first fetched (a download, so out of
scope for this AFK research ticket): load the addon in the pinned
`Godot_v4.7.2-stable_linux.x86_64`, and assert `Engine.has_singleton("Steam")` is
true and `steamInitEx()` returns a status code instead of failing to load. If that
fails, switch to the fallback route above (explicit 4.7.2 module builds) and record
it here. Overlay remains a manual Steam-client verification either way.

Out of scope and still blocked for release: the live Steam App ID, achievement API
names and the cloud quota — those live in
[Steamworks prerequisites](steamworks-prerequisites.md).

Housekeeping: this ticket's row in [map.md](../map.md) still reads `open`; the map
is the parent's file and was deliberately not edited by this lane.
