# UI recreation execution charter

## Outcome
Implement the existing UI recreation ticket pack in dependency order. Luca's request to implement all tickets approves implementation of the plan. It does not supply the menu and HUD visual verdict, the platform decision, or final acceptance.

## Scope and gates
The README and ticket acceptance criteria are authoritative. Preserve the frozen web reference, simulation, save, locale and modes files. Preserve all pre-existing untracked work. No commits, pushes, deletion, paid service calls or invented assets.

Complete the foundations and menu/HUD prototype first. Present actual captures and a runnable build for the approach verdict before starting tickets gated by that verdict. Keep platform-dependent work and final visual acceptance open until Luca decides.

## Ownership
The parent owns routing, independent verification and reporting. Foundation captain owns baseline, routing, adapters and input contracts, and is the named integration owner. Reference captain owns assets, computed-style extraction and theme. Parent dispatches leaf workers because this runtime does not permit nested delegation. File ownership follows ticket write scopes. Only the foundation captain may run Godot until ownership is explicitly handed over.

## Limits
Additional paid API budget: $0. Native delegated execution uses the configured identity, with no claim of a per-call model override. At most two retries per gate. No silent provider fallback on exhausted capacity.

## Evidence
Each ticket needs actual commands, exit codes, error counts and evidence files. Log historical failures separately from regressions. Child reports are not certification. Parent independently runs confirming checks after integration. UI readability and feel remain Luca's decision.

## Reporting and map
README.md and BOARD.md are the existing map and tracker. LOG.md records dispatches and decisions. Evidence lives in evidence/. Publish a board report at each gate, naming shipped work, verified checks, blockers and budget status.
