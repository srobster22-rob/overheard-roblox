

## R21 — the Operator's reach contradicts its own stated intent

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** New ground: the layout arithmetic, which no test has
ever touched because `World` and `Presence` need Roblox instances. The LAYOUT
itself is arithmetic and can be swept once the constants are extracted — the
same move that made `Heat` testable in R20.

1. *(picked)* **`OperatorReach` fails the invariant written three lines above
   it.** `Config.luau` says, in its own comment: *"it stops at the room centre,
   and being anywhere in that room should not be survivable."* The number is
   **22**. The room is **48x48**, so its half-width is 24 and its corners are
   **33.94** studs from the centre. Computed:
   - mid-edge (24.0) covered: **False**
   - corner (33.94) covered: **False**
   - the reach circle covers **66.0%** of the room floor, leaving **34.0% a
     safe zone** — and that 34% is the entire perimeter and all four corners,
     which is exactly where a frightened player stands.
   So the Operator arrives in the room it understood, and anyone pressed
   against a wall is untouched. The fiction says it takes everyone in the room;
   the code lets you beat it by backing into a corner. Player-facing,
   arithmetic, and admits a CLASS fix: derive the reach from the room instead of
   restating a magic number that can drift from it again.

2. **The two stations really are out of earshot.** Checked while probing:
   `SEPARATION = 120` with stations at each room's centre-ish, so the read and
   patch points are 120 studs apart. That invariant holds — but it holds by
   coincidence of two unrelated literals, and nothing asserts it. **Folded into
   this round's test rather than filed**, since the same extraction makes it
   free to check.

3. `Station.openedBy`, `Connected.clear`, `Connected.count` — still no callers,
   still deliberately left. **Not re-swept.**

4. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** New `src/shared/Layout.luau` holds the exchange's
dimensions and the facts that follow from them: `Room`, `Separation`, `Floor`,
plus `halfRoom()`, `cornerDistance()`, `reach()` and `inRoom()`. Pure
arithmetic, no Roblox APIs, so it can be swept — the same extraction that made
`Heat` testable in R20, applied to the numbers that were locked inside
`World.luau` because that file needs Roblox instances to load.

`Config.OperatorReach` is now `Layout.reach()` — DERIVED, so the promise in the
comment cannot drift from the number again. `World.luau` reads its three
constants from the same module instead of keeping private copies.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 36,
  round 48, config 47, wiring 145, connected 21, ordering 4, heat 20,
  layout 12, plus the operator assertions. `suite passed`.
- **The load-bearing check is a floor sweep through the REAL capture rule**, not
  the arithmetic: 625 points on a 2-stud grid, each fed to
  `Connected.reached` with the live `Config.OperatorReach`. Asserting the
  formula alone would pass while `reached` applied it differently.
- **Proved it fails.** Backup after the fix (sha256 `d10131e4...20a`), the
  hand-typed `22` planted, suite re-run: three failures by name —
  `reach covers the nearest wall`, `reach covers the furthest corner`, and
  `nobody standing in the room survives (248 escaped, worst at 33.9)`. That
  **248 of 625** is the defect measured: 39.7% of the floor was a safe pocket,
  all of it the perimeter. Restored, sha256 byte-identical.
- **Checked the keep side.** A reach that swallowed the building would destroy
  the mechanic, so the test also asserts a player in the OTHER room is not
  taken, and neither is one at that room's near edge — not just its centre.
- **A defect in my own test, fixed before shipping.** Two checks
  (`the rooms are separated...` / `their floors do not overlap`) asserted the
  identical condition. Replaced the duplicate with the gap between near edges,
  which is the walk a player actually makes (72 studs of corridor).
- **Verified it reached the PRODUCT**: `cornerDistance` appears in the
  Rojo-built place file.

**This is a balance change, and it is being flagged as one.** Reach moves
22 -> 33.94, so the Operator now takes the whole room instead of two thirds of
it. That follows the intent already written in `Config.luau` by R16 rather than
a new opinion of mine — but if the owner wants corners survivable, the fix is to
change the promise in the comment and the two `reach covers...` checks, not to
retype the number.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, full suite green
with output pasted above. Studio DEVICE-BLOCKED: whether being caught in a
corner FEELS unfair is exactly the claim this round does not make.

**Commit** `%%HASH%%`.

**Next round.** `Presence` is still the only system with no coverage at all, and
its one real rule — the hum's volume follows `Pursuit:isAudible()` — is now the
last untested link in the sound design the whole game rests on.
