# UI port approach

- Status: open
- Type: prototype
- Mode: HITL
- Owner: unassigned
- Blocked by: [Godot headless harness](godot-headless-harness.md)

## Question

Thirteen screens currently live in the DOM (13 `screen-*` ids in `index.html`)
with CSS tuned over months. Rebuild two of them in Godot — the main menu and the
in-match HUD — at the same palette and legibility standard, and stop there for a
verdict. The question is whether a Godot Control tree can carry this interface
without losing what already works: readable type, semantic colour, no overflow.

Features that must be accounted for, not dropped silently: the on-screen keyboard
(`osk` elements, `js/main.js:439-444`) and gamepad navigation. Whether they are
kept, dropped or postponed is decided in
[Product scope and platforms](product-scope-and-platforms.md), not by omission here.

## Why it matters

The current UI is one of the parts Luca has pushed back on before. Rebuilding all
thirteen before asking is the expensive way to find out.

## Resolved when

Luca has seen the two screens running and approved the approach, or rejected it
with reasons. Only then are the other eleven rebuilt.
