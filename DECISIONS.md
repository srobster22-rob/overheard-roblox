# DECISIONS — design calls the loop made itself. Owner: write `VETO` on a line to overrule.

| id | round | choice | alternative | why | revert |
|---|---|---|---|---|---|
| D1 | R131 | Delete per-second decay outright when adding `CoolPerRound` (owner picked per-round cooling; the deletion was mine) | keep `Operator.decay` and both dials unused | two clocks cool twice; an uncalled method is a trap (R12, R77) | revert commit 2158fd0 |
| D2 | R132 | tests/log accepts one commit per round from R131 (git must hold an `R<n>:` commit) | keep separate hash-stamp commits | AGENT_LOOP v2 section 5 | restore the stamp rule in tests/log.luau |
| D3 | R134 | A coinage that is understood and was credited since the last round boundary skips that boundary's cooling (`Operator.coolRound`) | lower ActThreshold, or cool mid-round | PT1/PT2: red on the panel in round 4 but first hunted in round 9; this makes red mean it is coming without touching the owner's 0.32 | call `operator:cool` instead of `coolRound` in beginRound |
