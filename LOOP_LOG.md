

## R23 — the reach is a circle where the promise is a room

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Measured the timing R22 flagged, and found something
worse than the thing I was looking for.

1. *(picked)* **`OperatorReach` catches people who are no longer in the room.**
   This is a consequence of my own R21 fix, and R21's tests could not see it
   because they only ever asked "is everyone in the room taken?" — never "is
   anyone OUTSIDE it taken?" The promise in `Config` is *"being anywhere in that
   room should not be survivable"*. R21 satisfied it with the smallest circle
   containing the square, which is the wrong shape:
   - reach 33.94 from centre, wall at 24 -> the circle spills **9.94 studs past
     every wall**, right round the room
   - it covers **157% of the room's floor area**
   - a player 29 studs from centre is **outside the room, in the corridor, and
     still taken**
   So a player who hears the silence, runs, and gets through the door is caught
   anyway — in R22 I gave the rooms doors, and this makes using one pointless.
   Player-facing, measured, and the fix is to use the shape the promise actually
   names: the room.
2. **The escape window is decided by four numbers nothing connects.** Measured
   at default `WalkSpeed` (16, which the game never sets — it inherits a Roblox
   default nobody chose): the silent approach lasts **2.44s**
   ((26-4)/9), and needing to clear the reach from a standing start costs
   *far corner* 3.98s, *far wall mid* 3.62s, *room centre* 2.12s, *at the door*
   0.62s. So the whole far half of the room has no counterplay at all, however
   fast the player reacts. Item 1 changes these numbers, so re-measure after.
   **The balance question — should the far half be unescapable? — is an OWNER
   call and is filed, not decided.** What this round can honestly do is make the
   window measurable and guarded.
3. `Pursuit`'s `speed`, `silenceRadius`, `arriveRadius` are still magic numbers
   outside the `Config` dial system. **Filed** — real, but governance, and item
   1 is the one a player can feel.
4. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** `Connected.reachedInRoom(centre, positions, half)` takes
everyone inside the room's WALLS. The server calls it with `Layout.halfRoom()`
instead of a radius. The radius form is kept as the honest primitive for
anything genuinely round, but nothing uses it in `src/` now.

`Config.OperatorReach` is **deleted**. The dial guard in `tests/config.luau`
caught it going dead the moment the call site changed — `'OperatorReach' is read
somewhere in src/` failed on the very next run — which is exactly what that
guard is for. A radius nobody enforces is worse than no radius.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 36,
  round 48, config 46, wiring 145, connected 21, ordering 4, heat 20,
  layout 28, plus the operator assertions. `suite passed`.
  (`config` drops 47 -> 46 because a dial was removed, not because a check was.)
- **The new sweep asserts the half R21 never did.** 625 points inside the room
  must all be taken; **1400 points outside it must all be safe.** R21's tests
  only ever asked the first question, which is why a circle passed them.
- **Proved it fails.** Backup after the fix (sha256 `61d678d9...5c0`), the
  circle capture planted, suite re-run: `nobody outside the room is taken
  (264 wrongly taken)` and `getting through the door and out saves you` — 26/28.
  Restored, sha256 byte-identical.
- **Pinned the boundary deliberately**: standing ON the doorway line is still
  inside, stated so a later round does not "fix" it the other way by accident.
- **Verified it reached the PRODUCT**: `reachedInRoom` is in the built place
  file. `OperatorReach` still appears there twice — checked, and both are
  comment prose explaining why it is gone; `grep Config.OperatorReach src/`
  returns no live read.

**FILED FOR THE OWNER — a balance question this round deliberately did not
decide.** With capture fixed, the silent approach lasts **2.44s** and escaping
costs, at Roblox's default `WalkSpeed` of 16:

| from | distance | time | escapes |
|---|---|---|---|
| at the door | 1.0 | 0.06s | yes |
| room centre | 25.0 | 1.56s | yes |
| far wall mid | 49.0 | 3.06s | **no** |
| far corner | 54.7 | 3.42s | **no** |

The fix improved every one of these (the centre was 2.12s under the circle), but
the far half of the room still has no counterplay at any reaction speed. Whether
that is the intended feel is an owner call. Note also that the game **never sets
WalkSpeed** — this entire table rests on an engine default nobody chose.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether 2.44s of silence FEELS like
enough warning is exactly the claim this round does not make.

**Commit** `%%HASH%%`.

**Next round.** `Pursuit`'s `speed`, `silenceRadius`, `arriveRadius` are still
magic numbers outside the dial system, and the table above shows they are the
three that decide whether the game is fair. Making them governed dials does not
decide the balance question, and would let the owner answer it by editing one
file.
