

## R28 — the corridor is a bridge with no edges

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Audited R27's blind spot: it moved the Operator's post
into the corridor, which made me look at the corridor for the first time.

1. *(picked)* **The corridor floor is narrower than the doorways it serves, and
   has no edges at all.** Measured:
   - doorway clear width **12** studs (z from -6 to +6)
   - corridor floor width **8** studs (z from -4 to +4)
   - so **2 studs of each doorway's approach has no floor under it**
   - and between the rooms (x from -36 to +36) the corridor is the ONLY floor,
     with nothing at its edges, for **72 studs**
   A player at z = +/-4.5 anywhere along that span falls out of the world. This
   is worst exactly when it matters most: R23 made escaping mean RUNNING OUT of
   the room, R26 made the Operator's departure something you flee from, and the
   route between the two rooms is a dark unlit strip four studs either side of
   centre. Players fleeing will overshoot it.
2. **The Operator walks in straight lines and ignores geometry.** Checked: from
   the new post at (-20, 0) both room centres lie on z = 0, so its path passes
   through the doorway gap by coincidence rather than by design. No defect
   today, but nothing asserts it. **Filed** — and worth building the moment
   anything moves off the centre line.
3. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** `Layout.corridorWidth()` is DERIVED from `Layout.Door` — a
corridor narrower than the door it serves is a hole by construction — and
`Layout.corridorWalls()` returns the two edge rectangles, stopping at
`corridorHalfLength()` so the doorways stay open. `allWalls()` includes them, so
every existing walk test now accounts for them. `World` builds the floor at the
derived width and the edges from the same rectangles the tests sweep.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 64,
  round 49, config 52, wiring 166, connected 32, ordering 4, heat 20,
  layout 47, plus the operator assertions. `suite passed`.
- **Proved it fails, in both directions**, because this fix had two opposite
  ways to be wrong:
  1. Narrow corridor planted (back to 8): `the corridor is at least as wide as
     the door it serves (8 >= 12)` and `no part of a doorway approach is
     unfloored (14 gaps)` — 45/47.
  2. Corridor walls extended to the full separation: **`the corridor walls do
     not seal the board doorway`**, the same for archive, and `the doorway leg
     to board is clear` — 40/47. This is the one that mattered: edges that ran
     the whole span would have undone R22 and sealed the rooms again, and the
     obvious implementation does exactly that.
  Restored, sha256 byte-identical.
- Also asserted the Operator's post still stands on floor that exists, since
  R27 put it in the corridor and this round changed the corridor's shape.

**A correction to how I have been claiming PRODUCT verification.** I grepped the
built place for `CorridorWall` and got one hit, then nearly wrote "the corridor
edges are real parts in the built place". They are not. Rojo packages SCRIPTS;
`World` creates parts at runtime, so the single hit is the source string
`CorridorWall{i}`, not two instantiated walls. What the build proves is that the
code which creates them shipped — the parts themselves only exist in a running
Studio, which is device-blocked. Earlier rounds' "it is in the built place file"
claims were about source text too and are true as stated, but this is the
sharper way to say it and later rounds should use it.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether a 12-stud corridor feels
tight or generous, and whether 14-stud walls read as a corridor or a trench, are
not claimed.

**Commit** `%%HASH%%`.

**Next round.** The filed item from this round's shortlist is now the strongest:
the Operator moves in straight lines and ignores geometry. It only passes
through doorways because every centre happens to sit on z = 0 — an accident, not
a rule, and the first thing that moves off that line will send it through a wall
in full view.
