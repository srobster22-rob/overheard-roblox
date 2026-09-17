# DECISIONS — design calls the loop made itself. Owner: write `VETO` on a line to overrule.

| id | round | choice | alternative | why | revert |
|---|---|---|---|---|---|
| D1 | R131 | Delete per-second decay outright when adding `CoolPerRound` (owner picked per-round cooling; the deletion was mine) | keep `Operator.decay` and both dials unused | two clocks cool twice; an uncalled method is a trap (R12, R77) | revert commit 2158fd0 |
| D2 | R132 | tests/log accepts one commit per round from R131 (git must hold an `R<n>:` commit) | keep separate hash-stamp commits | AGENT_LOOP v2 section 5 | restore the stamp rule in tests/log.luau |
