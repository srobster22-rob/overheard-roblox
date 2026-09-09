

## R50 — one room hears it for six seconds, the other for one and a half

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Extended R49's method to the thing the soak never
modelled: WALKING. Every distance in this building is a timing, and nothing had
checked that they add up.

Measured at Roblox's default `WalkSpeed` of 16, which the game still never sets:

| | distance | time |
|---|---|---|
| player -> breaker station | 42 studs via the door | 2.6s |
| player -> board station | 66 studs via the door | 4.1s |
| Operator -> archive | 40 studs from its post | 4.0s, **last 2.4s silent** |
| Operator -> board | 80 studs from its post | 8.4s, last 2.4s silent |

1. *(picked)* **The two rooms get wildly different warnings.** The audible part
   of an approach is **6.0 seconds** for the board and **1.6 seconds** for the
   archive — because R27 put the post at `-Separation / 6`, which is forty studs
   from one room and eighty from the other. I chose that number to sit "well
   inside the band and away from the player spawn" and never checked it for
   symmetry.
   **R27's guard cannot see this.** It asserts every approach STARTS audible,
   which 1.6 seconds satisfies. It never asked for how long — and "you hear it
   crossing the building" is the promise GAME.md makes.
   Same shape as R27's own defect, one step less extreme: there the board got
   zero warning, here the archive gets a second and a half.
2. **Players win both races comfortably** — 2.6s against 4.0s, 4.1s against
   8.4s — so a group that moves the moment a giveaway slips out always beats the
   Operator to the station. Whether that is too easy is balance and is the
   owner's; it is not a defect and is **recorded, not filed**.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, R46's learning gap — **all still filed.**

**Stage 2 — built.** The post moves to the corridor MIDPOINT, pushed to the
edge of the corridor floor so the spawn pad stays clear:
`{ x = 0, z = -(corridorWidth / 2 - 1) }`. That is the only equidistant point on
the corridor, and both rooms now hear **3.8 seconds** of approach instead of 6.0
and 1.6.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 122, pursuit 90,
  round 56, config 57, wiring 234, connected 32, ordering 4, heat 20,
  layout 73, lifecycle 75, hud 16, readout 29, soak 12, plus the operator
  assertions. `suite passed`.
- **The new guard asks the question R27's could not.** R27 checks that an
  approach starts audible; this measures HOW LONG each room is warned for,
  requires the least-warned room to clear a reactable floor, and requires no
  room to hear much more than another — because a tell that means six seconds in
  one half of the building and one and a half in the other is not one rule.
- **Proved it fails, twice, and the second plant is the one that matters.**
  A, R27's post restored: four failures including `no room hears much more than
  another (1.6s vs 6.0s)` and `the post is equidistant from both rooms (80.0 vs
  40.0)`. B, `SilenceRadius` widened to 58 with the NEW post in place — still
  perfectly equidistant, so every symmetry check passes — fails
  `the least-warned room still gets a usable warning (0.2s >= 2s)`. Symmetry
  alone would have been a guard that a silent monster satisfies. Restored,
  sha256 byte-identical.
- **Recorded, not filed**: players win both races to a station comfortably —
  2.6s against 4.0s, 4.1s against 8.4s — so a group that moves the moment a
  giveaway slips out always beats the Operator there. Whether that is too easy
  is balance and is the owner's.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether 3.8 seconds of hum FEELS
like enough warning is exactly the claim this cannot make.

**Commit** `%%HASH%%`.

**The pattern in R27 and R50 together.** R27 fixed "the board hears nothing" and
wrote a guard for "every approach starts audible". That guard is true of a
1.6-second warning, so the next defect of the same kind lived comfortably
underneath it for twenty-three rounds. A guard written as a BOOLEAN — does it
happen — cannot see a defect of DEGREE. Where the promise is about an amount,
the guard has to measure the amount.

**Next round.** By that reading, the other boolean guards in this suite are
worth re-examining for the degree question hiding under them: `isAudible` is a
yes/no over a distance, `Heat.isUnderstood` is a yes/no over a heat, and
`anyFinishable` is a yes/no over a whole board. Each was written to catch a
defect of kind, and each may be sitting on one of degree.
