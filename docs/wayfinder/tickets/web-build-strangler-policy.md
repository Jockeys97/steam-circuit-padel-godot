# Web build strangler policy

- Status: open
- Type: grilling
- Mode: HITL
- Owner: unassigned
- Blocked by: none

## Question

Does the current web build keep receiving fixes while the port runs, in parallel
with a frozen baseline, or is it frozen at commit 2979588 for the duration? This
decides whether every parity test targets a moving or a fixed reference. If fixes
continue, name the rule for when the baseline is re-frozen and parity re-measured.

## Why it matters

Parity is meaningless against a moving target. This is also the cheapest question
to answer and one of the two that unblock the parity gate.

## Resolved when

A stated policy, and if fixes continue, a named re-freeze rule.
