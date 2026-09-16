# Save and cloud format

- Status: open
- Type: grilling
- Mode: HITL
- Owner: unassigned
- Blocked by: [Steamworks integration route](steamworks-integration-route.md)

## Question

Define the Godot save **format and policy**: the schema mirroring `padel.prefs`
and `padel.career`, including the merge-against-defaults behaviour implemented
at `js/ui.js:405-442`; the file location under `user://`; the mapping to Steam
Cloud; and whether browser `localStorage` saves need migrating. The migration
question only matters if the web build ever shipped to players, so it is a
conditional decision, stated either way.

## Why it matters

Progress is the thing players lose first when a port goes wrong, and cloud makes
the mapping permanent. The format must be settled before any save code exists.

## Resolved when

A written schema is agreed, the migration decision is stated either way, and a
round-trip test approach for a career payload written by the current game is
named.
