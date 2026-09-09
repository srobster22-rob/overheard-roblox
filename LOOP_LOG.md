

## R25 — the Operator never leaves, so one slip locks a station forever

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Deliberately audited R24's own blind spot first,
because the last three rounds each found the previous one's. This one is mine.

1. *(picked)* **Once the Operator arrives it never leaves, and since R24 it
   captures the whole time — so a single plain word permanently locks an
   objective and the round becomes unwinnable.** Traced end to end:
   - `jack_number` -> payload `board`; the **board** station is in the board room
   - `breaker` -> payload `archive`; the **breaker** station is in the archive room
   - the ONLY `pursuit:stop()` in the server is inside the loss branch
     (everyone connected). Nothing else ever returns it to idle.
   So say "jack" plainly once and the Operator walks to the board room and
   stands there for the rest of the round, taking anyone who comes to patch the
   board. `allSolved` can never be reached; the round can only end in a loss.
   Both required stations are lockable this way.
   **R24 created this.** Before it, capture was one frame and the room was safe
   a moment later — the softlock is the price of making the monster work, and it
   has to be paid in the same place.
2. **`speed`/`silenceRadius`/`arriveRadius` as governed dials.** Still filed;
   item 1 changes how long the Operator occupies a room, so re-measuring the
   escape table before that lands would be wasted work.
3. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** `Pursuit` now accumulates `dwell` (real seconds, because
`step` is driven by Heartbeat) while it is `arrived`, resets it the moment it is
anything else, and answers `shouldLeave(after)`. It only REPORTS; the server
acts, so the duration stays a dial and the module stays free of clocks. The
server asks on the same tick as capture and calls `pursuit:stop()`.

`Config.LingerSeconds = 20`. **The number is a balance question filed for the
owner. That there must BE one is not** — without a release, R24's continuous
capture makes a single plain word a permanent softlock.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 50,
  round 48, config 49, wiring 156, connected 32, ordering 4, heat 20,
  layout 28, plus the operator assertions. `suite passed`.
- **Three claims, three places.** `tests/pursuit.luau` covers the RULE, including
  the two ways it could be wrong in the other direction: something still
  travelling must never say it wants to leave, and an idle tracker must not
  either. `tests/connected.luau` covers the CONSEQUENCE — a latecomer is taken
  while it is standing there, and a player who arrives after it has gone works in
  peace. `tests/wiring.luau` covers the SERVER actually asking.
- **Dwell must not survive the trip.** Asserted explicitly: an Operator that has
  dwelt long enough to leave, then sent somewhere new, does not release the
  second room the moment it lands. That was the likeliest way to get this wrong.
- **Proved they fail.** Backups after the fix (sha256 `6c1f9e4b...1e3` and
  `483ce47f...23d`), then BOTH halves planted — the tick's release removed and
  `shouldLeave` neutered to `return false`. Eight failures by name across three
  files: `the tick asks whether it should leave`, `ten seconds in, it has had
  enough`, `the Operator eventually gives up the room`, `a player who comes
  after it has gone is safe`, and four more. Both files restored, both sha256
  byte-identical.
- **Verified it reached the PRODUCT**: `shouldLeave` is in the built place file.

**FILED — the departure has no tell.** When the Operator loses interest it goes
idle where it stands: the hum is already off (both `arrived` and `idle` are
silent), and the body does not move. So the room becomes safe with nothing to
signal it, and players have no way to learn the rule — which `CLAUDE.md` names
as the thing that makes a monster read as unfair. The honest fix is for it to
LEAVE audibly rather than switch off in place, and that is a design round of its
own rather than a line in this one.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether 20 seconds is tense or
tedious is not claimed here.

**Commit** `%%HASH%%`.

**Next round.** The departure tell above is the strongest candidate — it is
player-facing, it closes the loop R24 and R25 opened together, and it is the
difference between a rule players can learn and one that just happens to them.
