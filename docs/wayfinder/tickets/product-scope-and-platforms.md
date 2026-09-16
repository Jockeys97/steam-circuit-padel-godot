# Product scope and platforms

- Status: open
- Type: grilling
- Mode: HITL
- Owner: unassigned
- Blocked by: none

## Question

What is the release surface of the desktop build, decided before any port work
commits to it? **No answer is assumed here.** The open choices:

- **Operating systems:** Windows only, Windows + Linux, or all three with macOS?
  This decides export presets, CI runners and storefront path.
- **Performance target:** minimum and target frame rate, and the machine the
  build is judged on. The web build already steps the simulation at a fixed
  120 Hz (see [Simulation port boundary](simulation-port-boundary.md)); this
  target is about rendering, not the tick.
- **Input scope:** keyboard/mouse, gamepad, or both. A Steam release is played on
  a pad, and `gamepad-nav-audit` already assumes one. Touch and the on-screen
  keyboard (OSK) exist in the web build (`js/main.js:439-444`); keep, drop or
  postpone is a decision here, and **nothing is dropped silently**.
- **Save scope:** `user://` only, or Steam Cloud from day one. Cloud is confirmed
  for the first release; the open part is what happens to browser `localStorage`
  saves if the web build ever shipped.

## Why it matters

These answers shape export presets, the input map and the save format before code
exists, and are cheaper to settle now than to retrofit.

## Resolved when

Each of the four is answered explicitly by Luca, including "keep" for anything
retained. Feeds [Athlete roster order](athlete-roster-order.md) and
[Save and cloud format](save-and-cloud-format.md).
