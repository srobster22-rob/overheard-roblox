

## R30 — round two starts with the monster already on top of you

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Audited R29's blind spot. It found two things, and the
second one **overturns a "no defect" I recorded in R26**.

1. *(picked)* **A new round never sends the Operator home, so round two begins
   with it standing inside a room.** `beginRound()` calls `pursuit:stop()`,
   which sets `idle` and leaves the POSITION untouched. Probed:
   - round 1: it hunts the board room and ends at `(56.5, 0)`
   - the round ends; after `stop()` it is still at `(56.5, 0)` — **3.5 studs**
     from that room's centre, where R27's invariant requires **80**
   - round 2, someone says the giveaway: **`state the instant it is sent:
     arrived`**, `audible = false`, arrives in one step, never audible
   So the second and every later round begins with that room's first
   understanding being an instant, silent capture — no approach, no hum, no
   warning, and R24's continuous capture takes everyone standing there. R27
   fixed exactly this for round one and R29 quietly reopened it for every round
   after.
2. **CORRECTION to R26's shortlist item 2.** I recorded "the capture box is
   centred on `pursuit.position` rather than the room's, but `step` snaps the
   position onto the target on arrival, so the offset case is unreachable
   today." **That was wrong.** `step` snaps only on its early-exit branch; the
   path at the bottom calls `setState(classify(distance))`, which can return
   `arrived` at up to `ArriveRadius` away **without snapping**. The probe shows
   it plainly: a normal arrival left the Operator at `(56.5, 0)` for a room
   centred at `(60, 0)`. So R23's room-shaped capture is offset by up to 4 studs
   on every ordinary arrival — the box hangs 4 studs outside one wall and falls
   4 studs short of the opposite one. Same mechanism as item 1, fixed with it.
3. The Operator ignores geometry — **still filed** (fourth time).
4. Nobody carries a light — **still filed**.
5. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** Two changes, one mechanism.

`Pursuit.step` now SNAPS onto the target on the classify path as well as the
early-exit one, so there is a single arrival point and arrival always lands on
the room centre. `Pursuit.sendHome(point)` is a PLACEMENT rather than a walk —
nobody is watching during an intermission, and walking it home would leave the
room lethal until it got there. `beginRound()` calls it with
`built.operatorStart`.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 74,
  round 49, config 53, wiring 177, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 28, plus the operator assertions. `suite passed`.
- **The snap is swept across STEP SIZES, not sampled.** Seven values of `dt`
  from 0.1 to 7, each walked to arrival, asserting the landing is exactly on the
  centre — with a guard that all seven actually arrived. A single `dt` would
  have hidden it: the defect only shows when the final step overshoots into the
  arrive radius rather than landing on the early-exit branch, and that depends
  entirely on step size. Planting it back produces `3 offset` out of 7.
- **Proved both fail.** Backups after the fix (sha256 `...`), then the snap
  disabled and `beginRound` reverted to `pursuit:stop()`: three failures by name
  — `arrival is exactly on the centre at every step size (3 offset)`,
  `a new round sends the Operator home`, and `...to the post World built, not a
  literal`. Both files restored, both sha256 byte-identical.
- The new-round test asserts the CONSEQUENCE too, not just the placement: after
  `sendHome`, being sent to that same room does not arrive instantly and IS
  audible — which is R27's invariant, now held every round rather than only the
  first.

**A logged non-defect that was wrong, and why it matters.** R26 recorded the
offset capture box as "unreachable today" after tracing the states. The trace
was wrong: it followed `step`'s early-exit branch and never considered that the
bottom of the same function reaches `arrived` through `classify` without
snapping. A "no defect, recorded so a later round does not re-probe it" note is
supposed to save work; a wrong one buys silence instead. Four rounds later the
box was still 4 studs off on every arrival, and it only surfaced because R29
made a second round exist and I probed the position directly rather than
re-reading my own note.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. `sendHome` is in the built place, meaning the code shipped;
runtime is Studio-blocked as always.

**Commit** `%%HASH%%`.

**Next round.** The filed items are unchanged (geometry-blind movement, no
player light, the stemming pair). Given this round, the most valuable new work
is probably a sweep of what ELSE `beginRound` fails to reset — `desk` (which
station each player is standing at) and `lastSubmit` both survive a round
boundary untouched, and neither has ever been looked at.
