# PLAYBOOK — OVERHEARD (RETRO edits only; max 40 lines)

## KEEP
- Simulate a whole session, not a rule: R46, R47, R48 and PT1's "red but never hunted" were each invisible to rule-level tests (R46-R48, R132).
- Probe candidate wording/values through the real `Heuristic.conveyed` before choosing (R126-R130).
- Plant the bug, see the test fail BY NAME, restore by sha256; take the backup after the fix (R85, R127).
- Measure options on one shared seeded instrument and have a second pass try to break the pick: it caught wrong conclusions in 4 of 5 families (R131).
- Read the bot trace for when the MONSTER acts, not when a number crosses a line: PT1 turned R131's "4 rounds" into "9" in one run, fixed in R134 (R132-R134).
- Ship every EXPAND with a trace excerpt of it happening: PT3's blind players met both R137-R138 additions unprompted (the latch every round, the way out in the critic's best shot) (TRY R136-R140, kept at R141).
- Let players who never saw the rules produce the evidence: blind chat tripped the Operator 30 times in 160 lines where 45 hand-picked lines tripped it 0 (R139), and two blind unscripted playtesters found in one session the digits bypass that 139 rounds of bots never could (R140).

## STOP
- Rounds that only reword, re-verify or wait for the owner (R124-R129: six rounds, no new player situation).
- Trusting a metric named after the goal: "rounds until red" measured the panel, not the Operator acting (R131 vs PT1).
- Leaving scratch probes in tests/: wiring fails on any unlisted file (R130).

## TRY
- (from R141) Every building round ends with one blind `tools/play` session by a subagent that has not seen the change, quoted in the log. Judge at the next PLAYTEST: it passes if that playtest reports fewer confusing items than PT3's eight.
