

## R27 — the board room never hears it coming

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Audited R26's blind spot first, as now standard.

1. *(picked)* **From its post, the Operator's approach to the board room is
   silent for the entire trip.** `operatorStart` is the board room's centre plus
   `ROOM/2 - 4` — **20 studs** — and `classify()` calls anything within
   `silenceRadius` (26) `closing`, which is inaudible. Probed against the real
   `Pursuit`:
   - sent to `board`: `state=closing, audible=false` **at the moment it is
     sent**; arrives after 2s having been audible **never**
   - sent to `archive` from the same post: arrives after 14s, audible on the way
   So one of the two rooms — the one holding a required station — has no warning
   at all, while the other has the full one. R26 made this the NORMAL case
   rather than a round-start quirk: the Operator now returns to that post every
   time it loses interest, so every subsequent approach to the board room is
   silent too. "Silence is the tell" is the game's central promise and half the
   building never gets it.
2. The three magic numbers (`speed`, `silenceRadius`, `arriveRadius`) are not
   dials, which is why the invariant above cannot currently be asserted against
   the real `silenceRadius`. **Folded into this round** rather than filed again:
   item 1's test needs them.
3. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** Three things, one defect.

`Config` gains `PursuitSpeed`, `SilenceRadius` and `ArriveRadius`;
`Pursuit.new` reads them instead of carrying literals. This is what makes the
invariant assertable AGAINST THE REAL NUMBER rather than against a 26 copied
into a test — and it also answers the oldest filed item, so the owner can now
tune the escape window from R23 by editing one file.

`Layout.operatorPost()` puts the Operator in the CORRIDOR, at
`-Separation / 6`. The corridor runs the full span at z=0, so any x whose
distance from both room centres exceeds `SilenceRadius` satisfies the
invariant; this sits well inside that band and away from the player spawn at
the midpoint. `World` returns it as `operatorStart`.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 64,
  round 49, config 52, wiring 166, connected 32, ordering 4, heat 20,
  layout 37, plus the operator assertions. `suite passed`.
- **The invariant is swept through the real `Pursuit`, not just measured.** For
  every room: the post must be outside `Config.SilenceRadius`, AND walking the
  real tracker from post to room must be audible at some point, with a guard
  that it actually arrived. Distance alone would pass while `classify` did
  something else.
- **Proved it fails, twice, in two different ways.**
  1. Old post planted (board centre + 20): three failures by name including
     `the post is outside the silence radius of board (20.0 > 26)` and
     `you hear it coming to board` — 34/37.
  2. `SilenceRadius` widened to 120 with the new post in place: four failures,
     including both rooms. **This is the check that matters** — it proves the
     assertion follows the DIAL and would not have passed a test that hardcoded
     26 next to a Config that said something else.
  Both files restored, both sha256 byte-identical.
- **Verified it reached the PRODUCT**: `operatorPost` and `SilenceRadius` are
  both in the built place file.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether an approach from 80 studs
away is a satisfying amount of warning, or simply a long wait, is not claimed.

**Commit** `%%HASH%%`.

**Next round.** The Operator now idles in the corridor, which is where players
spawn and walk — worth checking whether an idle body standing in the only route
between the two rooms reads as a threat, blocks a doorway sightline, or wants a
different resting place. Its `CanCollide` is already false, so this is about
legibility rather than obstruction.
