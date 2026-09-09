

## R31 — what else survives a round boundary

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R29 made a second round exist and R30 found that three
separate things had only ever been correct once. This round is the deliberate
sweep that pattern asks for: `beginRound()` resets `board`, `line` and
`pursuit`, and nothing else. Everything else declared at the top of the server
survives the boundary untouched.

1. *(picked)* **Two pieces of per-round state cross the boundary, and both
   change what the game does.** Probed live:
   - **The station gate is bypassed.** `desk` records which keypad each player
     walked up to and is never cleared. Round 1: player opens the breaker ->
     `accepts breaker = true`. Round 2, standing in the corridor ->
     **`accepts breaker = true`**. R12 added that gate precisely so the server
     owns where you are; it now leaks one free station per player per round.
   - **The Lexicon learns across rounds.** `Operator.observations` holds novel
     terms waiting to be credited, and `CreditWindow` is 20s against an 8s
     intermission. A phrase said at t=100, just before the round ended, was
     credited by a success at t=112 in the NEXT round: **6 coinages minted
     across the boundary**. The acquisition rule is "the group said it and then
     succeeded"; this quietly makes it "said last round, succeeded this one",
     which is a different and untrue claim about what the Operator learned.
   The instances are small. The CLASS is the round: per-round state that nobody
   reset, in a codebase that had exactly one round until two rounds ago.
2. `lastSubmit` also survives. **Deliberately left**: it is a rate limiter, and
   carrying a timestamp across an 8-second intermission can only make the first
   submit of a round wait a fraction of a second. Recorded so it is not swept
   again.
3. Geometry-blind movement, no player light, the stemming pair — **all still
   filed.**

**Stage 2 — built.** `Station.clear()` and `Operator.forgetObservations()`,
both called from `beginRound`. The Lexicon is explicitly NOT touched: burned
terms carrying between rounds is the retention mechanic, and only the pending
observations are dropped.

**The class fix is the guard, not the two methods.** `tests/wiring.luau` now
DERIVES the per-round holders from the server source —
`local <name> = <Module>.new(` — and requires each to be reset inside
`beginRound`. The next holder added to that file has to be handled or the suite
fails. A hand-kept list would have passed while the new one leaked, which is
exactly how these two got in.

One exemption, named with its reason in the test: `round` is the lifecycle
itself, restarted by the TICK before `beginRound` runs.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 74,
  round 49, config 53, wiring 183, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 37, plus the operator assertions. `suite passed`.
- **The derived guard found a false positive on its first run** and that
  improved it: it swept in `spawnPad`, which is `Instance.new` — a world object
  with nothing to reset. The derivation now excludes `Instance`, with the reason
  written next to it, rather than exempting the name.
- **A silent no-op I nearly shipped.** My first `Station.clear` wrote
  `self.openBy = {}`. The real field is `at`. Assigning a brand-new field is
  legal Luau, so `selene` passed, the suite passed, and the method would have
  cleared nothing at all. Caught by reading the source instead of trusting my
  memory of the field name — and the plant below now catches it mechanically.
- **Proved they fail.** Backups after the fix, then BOTH the resets removed from
  `beginRound` AND `Station.clear` reverted to the wrong field name. Three
  failures by name: `a new round resets 'operator'`, `a new round resets
  'desk'`, and `a new round forgets where everyone was standing` — the last one
  being the no-op version, which nothing else in the toolchain can see. Both
  files restored, both sha256 byte-identical.
- **Asserted what must NOT reset**, in the same block: forgetting observations
  leaves the Lexicon exactly as large as it was.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. `forgetObservations` is in the built place — code shipped;
runtime Studio-blocked.

**Commit** `%%HASH%%`.

**Next round.** The boundary sweep is done and its guard is derived, so that
class is closed. The filed list is unchanged: geometry-blind movement (fifth
time), no player light, and the stemming pair. The light is the one a player
would notice first — the corridor has no lamp at all and `Lighting.Brightness`
is 0 — but it wants a design opinion about what the light IS, so it stays filed
until the owner says.
