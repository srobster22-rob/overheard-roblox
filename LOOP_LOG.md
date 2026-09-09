

## R39 — a primed keypad can be used from anywhere in the building

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Carried R38's question forward: is the rule written as
what it MEANS, or as the nearest thing that was easy to check?

1. *(picked)* **`submit` checks what you last walked up to, never where you
   are.** `Station.accepts` is `self.at[userId] == stationId` — a memory of the
   last prompt you TRIGGERED. `MaxActivationDistance = 10` gates the trigger and
   nothing gates the submit. Measured against the real layout:
   - Switchboard at `(60, -18)`, Breaker at `(-42, 0)`, Directory at `(-60, -18)`
   - **104 studs** from the Switchboard to the Breaker room
   - trigger the Switchboard, walk those 104 studs, and the keypad still takes
     your answer
   The consequence is not a minor exploit, it is the premise: the actor primes
   the Switchboard, walks to the room where the holder is reading, stands beside
   them, hears the number and patches it from there. `Layout.luau`'s own comment
   says *"The read point and the patch point must never be reachable in one
   glance: distance IS the mechanic."* Nothing enforces that at the moment it
   matters, so the whole group can stand in one room and play the game by
   talking normally — which also removes any reason for the Operator to hear
   them across a building.
   Same shape as R38 exactly: the rule stands for "are you at that station" and
   is written as "did you most recently trigger it", and the two come apart the
   moment a player walks away.
2. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** `Layout.within(centre, point, radius)` is the pure rule;
`Config.StationReach = 14` is the dial (slightly wider than the prompt's own
activation distance of 10, so a player standing where they triggered it is never
refused by a stud of drift); `World.build` now returns `stationAt`, the position
of each station; and `submit` reads the player's real position through
`livePositions()` — the same server-owned reading capture already uses — and
refuses anyone who is not there.

`desk:accepts` is KEPT. It answers a different and still useful question: which
keypad this player has open, which is what stops a rejection for one station
painting the other's keypad (R10, R12). The position check is the authority;
the memory is the routing.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 99, pursuit 90,
  round 49, config 56, wiring 214, connected 32, ordering 4, heat 20,
  layout 59, lifecycle 59, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **The rule is swept, not sampled**: 36 points on a ring just inside the reach
  must all be accepted and 36 just outside must all be refused, with the
  boundary itself pinned (exactly at the reach counts, a step beyond does not).
- **The situation is asserted, not just the arithmetic**: you cannot patch the
  Switchboard from the other act-station, from beside the player reading at the
  Directory, or from the corridor.
- **The keep side has its own check**, and it is the one that stops this fix
  becoming meaningless: reach must NOT cover the room it stands in, or "be at
  the station" quietly becomes "be somewhere in the building".
- **Proved it fails, in both directions.** Plant A removed the gate: four
  failures by name including `submit reads where the player actually is` —
  210/214. Plant B widened `StationReach` to 200 with the gate in place: five
  failures including `you cannot patch the Switchboard from the other
  act-station` and `reach does not cover the whole room it stands in` — 54/59.
  Both restored, both sha256 byte-identical.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether 14 studs feels like "at the
board" or like an invisible fence is not claimed, and is the sort of number a
playtest moves.

**Commit** `%%HASH%%`.

**Two rounds, one shape.** R38 and R39 were the same defect twice: a rule
implemented as the nearest thing that was easy to check. "May not enter an
answer they have SEEN" was written as "is not the current holder"; "must be
standing at the station" was written as "most recently triggered its prompt".
Both held until a second event — a join, a walk — separated the proxy from the
thing it stood for. Worth carrying as a standing question: for each gate, name
the rule in words, then read what the code actually tests.

**Next round.** The remaining gates worth putting that question to are the jam
(`misses % GuessesBeforeLockout == 0` stands for "has guessed too much") and
`Heuristic`'s confidence threshold (a number stands for "the Operator
understood"). The first is arithmetic and checkable; the second is the one the
whole game rests on.
