

## R52 — the corridor lets you walk where the door will not let you through

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R51 ended by treating the log's "could not verify"
notes as a backlog. R22 left one: *"whether the doorway is wide enough to run
through under pressure."* That is a FEEL question with a measurable half, which
is what R51 proved worth looking for.

Measured. The doorway is 12 studs clear, R28 derived the corridor from it so its
walls sit at the same +/-6, and a Roblox character is about 4 studs across:

| player centred at | spans | through the door |
|---|---|---|
| z = 0 | -2 .. 2 | yes |
| z = 4 | 2 .. 6 | yes (exactly) |
| **z = 5** | **3 .. 7** | **no** |
| **z = 5.9** | **3.9 .. 7.9** | **no** |

1. *(picked)* **The corridor walks you into the door frame.** Anyone past
   `z = 4` clips it, and the corridor's own walls let a player walk to `z = 6`.
   So a third of the corridor's width leads to a doorway you cannot fit through
   — and a player hugging a wall is exactly what a player fleeing does.
   This is R28's fix meeting R52's requirement head-on: R28 made the corridor
   AT LEAST as wide as the door so no part of the approach is unfloored, and
   clearance wants the reverse. Both are right; they are about different things.
   The floor must cover the doorway, and the WALLS must keep players inside the
   span the door can pass. R28 built one part from the other and used it for
   both.
2. R21's "does being caught in a corner read as unfair" and R36's "does
   deferring a call read as patience" — **still filed**, no measurable half
   found yet.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, R46's learning gap, `anyFinishable`'s margin — **all still
   filed.**


**Stage 2 — the fix.** Two numbers where R28 kept one.

- `Config.PlayerWidth = 4` — how wide a character is, as a dial, because every
  number that has to clear a body should be derived from one place.
- `Layout.corridorClear() = Layout.Door - Config.PlayerWidth` = **8**. This is
  the width a player can WALK. `corridorWidth()` (the FLOOR) stays at 12 and
  keeps R28's rule intact: the floor is still at least as wide as the doorway,
  so no part of the approach is unfloored. `corridorWalls()` now uses
  `corridorClear()`, so the walls sit at +/-4 and every position between them
  spans at most 2..6 — inside the frame, with the wall itself the exact
  touching case.

**The cascade, caught mid-round.** Insetting the walls left `operatorPost()` at
`z = -5`, derived from the FLOOR's half-width — one stud OUTSIDE the new walls.
Every path from the post to a room would then have crossed the wall line, which
is the filed geometry-blind-movement defect made reachable by this round's own
fix. The post is now `-(corridorClear() / 2 - 1)` = **z = -3**, still equidistant
(60.07 to each room, both rooms still hear 3.8s of approach).

**Stage 3 — proof.** 20 new checks in `tests/layout.luau`, swept rather than
asserted at one point: 81 positions across the walkable width, none clipping;
the wall itself (`4 + 2 <= 6`); a control a stud further out that DOES clip, so
the sweep is not passing because it cannot fail; the built wall rects read back
and compared to the number; the post inside the walls; and a straight walk from
the post to each room checked step by step for straying past them.

Planted both halves and confirmed each failed by name:

| plant | what failed |
|---|---|
| `corridorClear()` returns `Layout.Door` again (R28's single number) | `nowhere you can stand clips the frame (28 of 81)`, `pressed against the wall you still fit (6 + 2 <= 6)`, +3 more — 86/91 |
| post derived from `corridorWidth()` instead (the z = -5 cascade) | `the post is inside the walls (5 <= 4)`, and the walk to each room `(12 outside)` — 88/91 |

Restored from a byte-copy backup, sha256 `7d538c3f...fe2b6f37` both before and
after each plant.

**Stage 4 — ship.** `stylua` clean, `selene src` 0 errors / 0 warnings,
`rojo build` clean, full suite **green**: lexicon 22, heuristic 40, operator ok,
objectives 122, pursuit 90, round 56, config 58, wiring 241, connected 32,
ordering 4, heat 20, layout **91**, lifecycle 75, hud 16, readout 29, soak 12,
hum 21.

*Not claimed:* whether 8 studs FEELS wide enough to run down under pressure.
The clearance half is now proved; the feel half needs Studio, which is
device-blocked. It stays filed.
