

## R22 — the rooms have no doors

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R21 put the layout arithmetic within reach of a test
for the first time. The first question worth asking of it was not about the
Operator at all: **can a player walk to a station?**

1. *(picked)* **Neither room has a doorway. The game cannot be played.**
   `World.room()` builds four walls from one `offsets` table — north, south,
   east, west, each the full `ROOM` span — and nothing ever cuts a gap. The
   corridor is a FLOOR SLAB at y=0 running x=-60..+60; the walls stand from
   y=0 to y=14 across it. Computed:
   - Switchboard at (60, -18): the straight walk from the corridor crosses the
     inner wall plane `x=36` at `z=-10.8`; that wall spans `z=-24..+24`.
     **BLOCKED.**
   - Directory at (-60, -18): crosses `x=-36` at `z=-10.8`. **BLOCKED.**
   Both work rooms are sealed boxes. Every system shipped in twenty-one rounds
   — the objectives that force a transfer, the Operator that hunts by meaning,
   being connected, the loss — sits behind a wall with no door in it. This is
   the most player-facing defect the project has had, and it survived because
   `World.luau` needs Roblox instances to load, so no test could see the
   geometry until last round.
2. **`built.spawn` is computed and never used.** Same file, same blind spot:
   `World.build()` returns a spawn point in the corridor and `init.server` never
   reads it, so players land wherever Roblox decides. Related, cheap, and it
   matters much more once doors exist. **Folded into this round.**
3. `Pursuit`'s `speed = 9`, `silenceRadius = 26`, `arriveRadius = 4` are
   hard-coded outside the `Config` dial system that `tests/config.luau`
   governs, and they now have an unasserted relationship with
   `Layout.reach()` (33.94). Real, and the next good round.
   **Filed, not built.**
4. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** `Shared.Layout` now owns the WALLS, as rectangles:
`walls(centre, openOn)` builds the corridor-facing side as two segments with a
12-stud doorway between them, `allWalls()` assembles the building, `crosses()`
is a segment/segment test, and `walkIsClear` / `routeToStation` /
`routeIsClear` answer the question a player cares about. `World.room()` now
builds its geometry FROM that list, so the walls a player meets are the same
rectangles the test sweeps.

Also wired `built.spawn`, computed since R2 and read by nobody: a `SpawnLocation`
now puts players in the corridor between the two rooms instead of wherever
Roblox decided.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 36,
  round 48, config 47, wiring 145, connected 21, ordering 4, heat 20,
  layout 27, plus the operator assertions. `suite passed`.
- **Proved it fails.** Backup after the fix (sha256 `1d342a3c...d38`), the
  doorway branch removed so `walls` builds four full spans again, suite re-run:
  **seven failures by name**, including `you can walk from the corridor to the
  board station` and `the doorway faces the corridor` — 20/27. Restored,
  sha256 byte-identical.
- **My first version of this test was wrong, and the wrongness mattered.** It
  demanded a clear STRAIGHT line from the corridor to each station. That fails
  even with the door open: the station sits 18 studs off the room's centre line,
  so the direct walk clips the wall at z=-10.8, outside a 12-stud gap. Taken at
  face value it would have argued for widening every door to 22 studs — fixing
  the test's model of walking rather than the building. Replaced with a ROUTE:
  spawn -> doorway -> station, each leg checked, which is how a player actually
  moves. The reasoning is in `Layout.routeToStation` where the next person will
  hit it.
- **Checked the keep side**, or "cut a doorway" could have been satisfied by
  deleting the walls: entering through the far corner is still blocked, and so
  is the back wall the door is NOT in.
- **Verified it reached the PRODUCT**: the built place file contains the
  Layout-driven walls and the `SpawnLocation`.

**A process failure worth recording.** My first edit to `Layout.luau` used a
python `str.replace` on `"return Layout"`, which is a PREFIX of
`return Layout.Room / 2` and `return Layout.reach()`. It injected the new block
inside two existing functions and mangled the file — and `selene` still reported
**0 errors, 0 warnings**, because the result was syntactically valid Luau.
Rebuilt the file by hand rather than reaching for `git checkout`, which the
standing rules forbid. Lesson for later rounds: anchor a replace on a full line
including its newline, never on a fragment that can be a prefix.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, full suite green
with output pasted above. Studio DEVICE-BLOCKED: that the doorway is wide enough
to run through under pressure, and that the spawn faces the right way, are
claims this round does NOT make.

**Commit** `%%HASH%%`.

**Next round.** `Pursuit`'s `speed = 9`, `silenceRadius = 26` and
`arriveRadius = 4` are still hard-coded outside the `Config` dial system, and
they now carry an unasserted relationship with `Layout.reach()` (33.94) and the
room's own size — how long the silent approach lasts, and whether there is time
to reach a door, are decided by three numbers no test connects.
