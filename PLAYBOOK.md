# PLAYBOOK — OVERHEARD (RETRO edits only; max 40 lines)

## KEEP
- Simulate a whole session, not a rule: R46, R47, R48 and PT1's "red but never hunted" were each invisible to rule-level tests (R46-R48, R132).
- Probe candidate wording/values through the real `Heuristic.conveyed` before choosing (R126-R130).
- Plant the bug, see the test fail BY NAME, restore by sha256; take the backup after the fix (R85, R127).
- Measure options on one shared seeded instrument and have a second pass try to break the pick: it caught wrong conclusions in 4 of 5 families (R131).

## STOP
- Rounds that only reword, re-verify or wait for the owner (R124-R129: six rounds, no new player situation).
- Trusting a metric named after the goal: "rounds until red" measured the panel, not the Operator acting (R131 vs PT1).
- Leaving scratch probes in tests/: wiring fails on any unlisted file (R130).

## TRY
- (cycle R133-R137) Every EXPAND ships with a `tools/playtest` trace excerpt showing it happen; judge at RETRO by whether PT2 saw the new content without being steered to it.
