# Demo gate rule

- Status: open
- Type: grilling
- Mode: HITL
- Owner: unassigned
- Blocked by: none

## Question

**How should the demo gate work in the Godot build?** The web build filters
content through `IS_DEMO`, `demoFilter` and `demoLocked` in `js/build.js:35-75`,
producing a two-athlete, one-arena, quick-match-only demo from the same
codebase. Decide the strategy: which content the demo exposes, what stays
locked, whether the mechanism is export presets or something else, and how the
filter is tested (modelled on the existing demo audit). The route is a decision;
building the presets is implementation.

## Why it matters

The demo is the first thing a store visitor plays, and it must not leak unlocked
content. Deciding the rule now keeps the export work from making the decision by
default.

## Resolved when

The demo content set and lock rules are decided, the mechanism is named, and the
test approach is stated. No export needs to exist to close this.
