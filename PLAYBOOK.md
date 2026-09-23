# PLAYBOOK — OVERHEARD (RETRO edits only; max 40 lines)

## KEEP
- Simulate a whole session, not a rule: R46, R47, R48 and PT1's "red but never hunted" were each invisible to rule-level tests (R46-R48, R132).
- Probe candidate wording/values through the real `Heuristic.conveyed` before choosing (R126-R130).
- Plant the bug, see the test fail BY NAME, restore by sha256; take the backup after the fix (R85, R127).
- Measure options on one shared seeded instrument and have a second pass try to break the pick: it caught wrong conclusions in 4 of 5 families (R131).
- Read the bot trace for when the MONSTER acts, not when a number crosses a line: PT1 turned R131's "4 rounds" into "9" in one run, fixed in R134 (R132-R134).
- Ship every EXPAND with a trace excerpt of it happening: PT3's blind players met both R137-R138 additions unprompted (the latch every round, the way out in the critic's best shot) (TRY R136-R140, kept at R141).
- Let players who never saw the rules produce the evidence: blind chat tripped the Operator 30 times in 160 lines where 45 hand-picked lines tripped it 0 (R139), and two blind unscripted playtesters found in one session the digits bypass that 139 rounds of bots never could (R140).
- End every building round with one blind `tools/play` session by a subagent that has not seen the change, before the commit. Its own test failed: PT4 still lists 9 confusing items against PT3's 8, because blind players find confusion faster than one round fixes it. It earned its place another way: R144's session found that fix's own gap (the note came too late while the Operator was still walking to the lobby) before the commit, and R143's replay showed which words ever reached understood (TRY R141-R145, kept at R146).

## STOP
- Rounds that only reword, re-verify or wait for the owner (R124-R129: six rounds, no new player situation).
- Trusting a metric named after the goal: "rounds until red" measured the panel, not the Operator acting (R131 vs PT1).
- Leaving scratch probes in tests/: wiring fails on any unlisted file (R130).
- Taking a bot headline as the proof of a change the bots cannot perceive: R144's panel row could not move a bot that never reads the panel. Replay a real session with a `look` at the moment players decide instead (R144).
- Teaching the listener one encoding a round: R147's number words and R148's letters were each beaten inside their own blind session by the next encoding (one-off references, a shifted alphabet, a word between letters), and PT5 found three more (reversed digits, glued letters, one digit per message) (R147-R150).

## TRY
- (from R151) Before the listener learns anything new, run every scheme a group has already won with against it: a scheme corpus of replayable lines (PT4, PT5 and the blind sessions: digits as letters, NATO words, dozens, reversed digits, glued letters, one digit per message, riddles, a word between letters). Report how many it reads beside the blind chat's false trips, and pick the design that reads the most. Judge at the next PLAYTEST: it passes if no unscripted group wins more than half its rounds with the Operator never moving (PT5: 12 of 30, one group 3 of 5).
