

## R37 — a jam from last round refuses the right answer in this one

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Pointed R36's question — what happens when there are
TWO? — at two players, and at two rounds.

0. **Checked first, no defect: the submit jam is already per (line, actor).**
   One player's wrong guesses do not jam the line for a teammate who knows the
   answer. R9 got that right and R13 tightened the blame. **Recorded so it is not
   re-probed.**
1. *(picked)* **`Objectives.reset` leaves `misses` and `jammedUntil` behind, so
   a jam earned in one round refuses the correct answer in the next.** Probed:
   - round 1, three wrong guesses -> `misses=3, jammed until t=23`
   - `board:reset()` -> **`misses=3, jammedUntil=23`**, both untouched
   - round 2, the SAME player submits the **right** answer ->
     **`ok=false, reason="that line is jammed - wait 19s"`**
   The answers are re-rolled every round, so this punishes a player for guesses
   at a number that no longer exists — and it lands on someone doing the one
   thing the game wants, patching a line they were told.
   **And it exposes a limitation in the guard I shipped in R31.** That guard
   derives the per-round holders from the server source and requires
   `beginRound` to reset each one. `board:reset()` IS called, so it passes —
   while `reset` itself is incomplete. The guard checks that a reset HAPPENS,
   never that it is COMPLETE, and I described it as closing the class. It closed
   one layer of it.
2. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** `Objectives.reset` clears `misses` and `jammedUntil`
alongside the rest. Two lines; the round is the guard.

**The guard is the point.** `tests/lifecycle.luau` now DERIVES the `Objective`
type's fields from the source and requires every non-static one to be named
inside `reset`, with three fields exempt (`id`, `concept`, `prompt`) each
carrying its reason. R31's guard asked whether a reset is CALLED; this one asks
whether it is COMPLETE, which is the layer that let this through.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 90,
  round 49, config 55, wiring 210, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 58, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **The new guard found two defects in ITSELF before it found the real one**,
  and both are the shape this project keeps meeting:
  1. Reading the type block from RAW source picked up a field called `purpose` —
     from the words "on purpose:" inside a comment in that block. A comment that
     can INVENT a required field, which is the mirror of a comment that
     satisfies a check.
  2. Reading it from stripped code then returned NOTHING, because
     `LuauCode.stripNonCode` also removes braces, so a `{`...`}` anchor cannot
     work there. It failed loudly on its own `#fields >= 6` guard rather than
     sweeping an empty list — which is exactly why that guard was written.
     Fixed by slicing to the next `export type` and reading tab-indented
     `name:` at line starts, which also skips the `[number]:` inside a map type.
- **Proved it fails.** The two clearing lines removed: five failures by name,
  from `reset clears 'misses'` through to
  `...so the right answer is accepted again` — 53/58. Restored, sha256
  byte-identical.
- **Recorded a non-defect**: the submit jam is already per (line, actor), so one
  player's guessing cannot lock a teammate out. R9 got that right.

**A sixth backslash collapse, and a change of habit.** Patching this test
through a heredoc turned `
	` into real line breaks and left the file
unparseable. Removed the damage surgically rather than reaching for git
(`## Never` forbids it), then wrote the block to a FILE and spliced that in —
no escapes ever passing through a shell. That is the method from here on; six
occurrences is enough evidence.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**Next round.** The completeness question generalises: `Lifecycle`, `Connected`
and `Station` all have reset paths that nothing checks for completeness the way
`Objectives` now is. Worth pointing the same derived-field guard at each rather
than waiting for the next jam-shaped leak.
