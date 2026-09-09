

## R24 — the Operator is a statue once it arrives

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.**

1. *(picked)* **Capture is a one-frame event; walk in a second late and the
   monster can never touch you.** `takeWhoeverIsHere()` is called from exactly
   one place — inside `pursuit.onStateChanged`, on the transition to `arrived` —
   and `Pursuit.setState` returns early when the state has not changed. So the
   Operator takes whoever is in the room at the single instant it arrives, and
   then stands there permanently harmless.
   Demonstrated headlessly against the real `Pursuit` and `Connected`, wired
   exactly as the server wires them:
   - Operator sent to the board room while the player is in the corridor ->
     `state=arrived, captures=0`
   - the player then walks INTO that room (`inRoom = true`) and stands beside it
     for **60 seconds** -> `captures=0`, `isConnected = false`
   - being told the same room again does not help -> still `captures=0`
   This is the monster not working. Everything the game builds toward — speech,
   comprehension, the hunt, the silence — ends in a thing you can walk past.
   It also makes R23's fix look worse than it is: getting out of the door saves
   you, and so does strolling back in.
2. `Pursuit`'s `speed`/`silenceRadius`/`arriveRadius` as governed dials, and the
   unset `WalkSpeed`. **Still filed** — item 1 changes what those numbers mean,
   so measuring them again first would be wasted work.
3. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** The server's one-second decay loop became the server's
CLOCK, running two jobs at two rates: capture every `Config.TickSeconds`
(0.25s), decay on its own `Config.DecaySeconds` (1s) beat. Occupancy is a
continuous fact, so it has to be asked continuously; decay is time-based, so
ticking it faster would be correct but would replicate the whole lexicon four
times a second, which the original comment explicitly did not want.

Both rates are dials rather than literals, so they are governed by
`tests/config.luau` like every other tuning number.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 36,
  round 48, config 48, wiring 153, connected 28, ordering 4, heat 20,
  layout 28, plus the operator assertions. `suite passed`.
- **Two tests, because there are two claims.** `tests/connected.luau` proves the
  RULE, driving the real `Pursuit` and `Connected` exactly as the server drives
  them: a player in the corridor is not taken, walking in AFTER it arrived is
  fatal, standing there does not re-capture on every tick, and someone who left
  is not taken by a stale position. `tests/wiring.luau` proves the SERVER runs
  that rule — a rule the server does not call is a rule the game does not have.
- **Proved they fail.** Backup after the fix (sha256 `8b4f1fc8...eee`), the
  tick's capture block deleted, suite re-run: four failures by name, including
  `capture is reachable from more than one place (2 occurrences)` and
  `the tick runs capture` — 149/153. Restored, sha256 byte-identical.
- **A defect in my own test, caught by the plant loop.** The wiring check asked
  the STRIPPED server source for the literal `"arrived"`. The lexer removes
  string bodies, so that check could never pass — it failed against correct
  code. Split it: `pursuit.state` is asserted against stripped code because it
  IS code, and the literal against raw source, with its own guard. This is the
  third time this project has hit that trap (R18, R20, now R24); the comment now
  names it at the call site.
- **Verified it reached the PRODUCT**: `TickSeconds` is in the built place file.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether a 0.25s capture beat feels
instant, or whether it should catch on contact instead, is not claimed here.

**Commit** `%%HASH%%`.

**Next round.** With capture continuous, the escape table filed in R23 is worth
re-measuring: leaving the room now matters permanently rather than for one
frame, so `speed`/`silenceRadius`/`arriveRadius` becoming governed dials is the
natural next step — and it still does not decide the owner's balance question.
