

## R36 — you can neutralise the Operator by saying MORE

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Kept R35's rule — find the defect first, let any
extraction follow it — and hunted for the same SHAPE that made R35's defect
invisible: correct with one, wrong with two.

1. *(picked)* **Two giveaways, alternated, livelock the Operator forever.**
   `sendTo` retargets unconditionally, so saying the other room's plain word
   flips its destination mid-approach. Measured against the real `Pursuit`:

   | what players do | result |
   |---|---|
   | say one giveaway, then go quiet | arrives in 5.5s, `arrived`, 0.0 studs from the room |
   | alternate both, once a second, 60s | **never arrives**, 40.0 studs from either room |
   | alternate both, once a second, **300s** | **never arrives**, 40.0 studs from either room |

   It oscillates around the midpoint, audible the entire time, and can capture
   nobody because capture requires `arrived`. So the counterplay to a monster
   that hunts what you say is **to say more of it** — which inverts the whole
   design. Speaking plainly is supposed to be the danger; here a second plain
   word cancels the first. It needs no coordination and no exploit knowledge:
   two players panicking and both blurting giveaways produce it by accident.
   This is the R35 shape exactly — with ONE concept in play the retarget rule is
   perfectly correct, and every probe until now has used one.
2. `onPhase` extraction — **not built.** Nothing is wrong with it, and R35's
   rule says the extraction follows a defect rather than leading it.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** The Operator FINISHES THE CALL IT STARTED. A different
room heard while it is `approaching` or `closing` is QUEUED on `pending`, not
switched to; `takePending()` takes it up only once it is idle again, so the
sequence is: finish the call, hold the room, walk home, answer the next one.
That is also exactly the fiction — it is a switchboard operator, and "that line
is busy" is already one of its lines.

Being called back out of a RETREAT still works: a retreat is not a call in
progress, and R26's rule survives untouched. `stop()` and `sendHome()` both
clear the queue, or a new round would begin by chasing something said in the
last one.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 90,
  round 49, config 55, wiring 210, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 46, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **All 74 pre-existing pursuit assertions still hold**, including R11's
  "re-sent while already on the way", R26's "hearing something again pulls it
  back", and R30's arrival snap. That mattered more than the new checks: this
  change touches the function every one of those depends on.
- **Proved it fails.** Commitment removed: **8 failures by name**, headed by
  `alternating both giveaways no longer stops it arriving` and
  `(guard) and it really did arrive somewhere` — the exact livelock, caught by
  the exact assertion. The tick's `takePending` removed as well:
  `the tick takes up a queued room`. Both restored, both sha256 byte-identical.
- **The queue's own failure modes are asserted**: re-saying the room it is
  already going to queues nothing, a queued room is not taken while it stands in
  a room, and both resets clear it.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether deferring a call by a whole
walk home feels like patience or like the monster ignoring you is exactly the
claim this cannot make, and is worth watching first whenever a human can.

**Commit** `%%HASH%%`.

**The shape, twice in a row.** R35 and R36 were both "correct with one, wrong
with two" — one held line, one secret concept. Every probe this project has
written until now used one of each, because one is what you reach for when
writing an example. Worth carrying forward as a deliberate question rather than
a coincidence: for any rule, what happens when there are TWO?

**Next round.** The same question has one more obvious target: two players. Most
of the server's per-player state has only ever been exercised with a single
`userId` in the tests — `Station`, the submit jam, `redealOrphans` — and R35
already found that two of something is where this codebase breaks.
