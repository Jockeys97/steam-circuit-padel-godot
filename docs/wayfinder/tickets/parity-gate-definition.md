# Parity gate definition

- Status: open
- Type: grilling
- Mode: HITL
- Owner: unassigned
- Blocked by: [Godot headless harness](godot-headless-harness.md), [Web build strangler policy](web-build-strangler-policy.md)

## Question

Decide what "at parity" means for quick match. Which ported audits must be
green, at what tolerance for anything numeric that cannot match exactly, and
what only a human can sign off: framing, ball readability, shot feedback timing,
and whether the AI feels like the same four opponents.

The baseline is **not green**: `npm run audit` scores **25/27** on this host, red
on `outfit-assets` (assertion error, cause not yet diagnosed) and
`unlockable-animation` (cannot import `sharp`). The gate must say how the port
treats those two, and must not treat either red as a dependency problem without
evidence. Log: [baseline audit](../evidence/baseline-audit.log).

## Why it matters

Without a written gate, parity becomes an argument. This is also what stops an
agent from declaring victory on a green suite alone.

## Resolved when

A named list of gates with the exact command that proves each one, a stated
tolerance where exactness is impossible, the treatment of the two red audits,
and an explicit list of what only play can approve. See
[Parity harness](../parity-harness.md) for the audit inventory this selects from.
