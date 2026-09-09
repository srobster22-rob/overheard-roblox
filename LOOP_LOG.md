

## R26 — the Operator now leaves audibly instead of switching off

**Stage 0.** `OWNER.md` `## Next` still empty. Its `## Never` block has gained
the destructive-command rules; noted and already being followed (this round
restores from its own byte copies, never from git). Owner questions untouched.

**Stage 1 — shortlist.**

1. *(picked)* **The departure has no tell.** R25 released the room by calling
   `pursuit:stop()`, which sets the state to `idle` WHERE IT STANDS. Both
   `arrived` and `idle` are inaudible and the body does not move, so the room
   goes from lethal to safe with nothing whatsoever to signal it. `CLAUDE.md`
   states the rule this breaks: *"The monster must be legible. Players need to
   learn a rule, or the scare reads as unfair and they leave."* Right now the
   only way to discover the room is safe is to walk in and not die — which is
   indistinguishable from walking in and dying, until it happens. This closes
   the loop R24 and R25 opened together and it is the difference between a rule
   players can learn and one that merely happens to them.
2. **The capture box is centred on `pursuit.position`, not the room.** Probed:
   `Pursuit.step` SNAPS the position onto the target on arrival, so the two
   coincide and there is no offset — but `sendTo` does not snap, so a tracker
   that were already inside `arriveRadius` of a room would go `arrived` with an
   offset centre. Traced the reachable states: it can only be at a centre with
   distance exactly 0, so the offset case is unreachable today.
   **No defect. Recorded so a later round does not re-probe it** — and worth
   re-checking if anything ever teleports the Operator.
3. `speed`/`silenceRadius`/`arriveRadius` as governed dials — **still filed.**
4. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** `Pursuit` gains a fifth state, `leaving`. It is AUDIBLE
(`isAudible` is now approaching OR leaving — you hear it come and you hear it
go, and the silence in between is the tell) and it never captures, because
capture is gated on `arrived`. Reaching home ends as `idle`, explicitly NOT
`arrived`, so the place it retreats to cannot start taking people. While
leaving, `classify()` is skipped — that function describes hunting, not
retreating, and letting it relabel the walk out would have made the Operator go
quiet halfway home.

The server calls `withdrawTo(built.operatorStart)` instead of `stop()`, and
announces it with a line of its own.

**`Round.LINES.givingUp = "I'll try that number again later."`** — a FIFTH
distinct sentence. My first draft reused `busy`, which is the keypad's private
rejection; that would have repeated exactly the collision R10 and R13 each had
to unpick, two unrelated events rendering as one line. Caught while wiring it,
before any test ran. The wiring test now sweeps `givingUp` against all eight
other lines rather than the three the previous check compared.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 64,
  round 49, config 49, wiring 166, connected 32, ordering 4, heat 20,
  layout 28, plus the operator assertions. `suite passed`.
- **Audible for the WHOLE walk, not just the first frame.** Asserted by sweeping
  every step of the retreat with a guard that the walk took more than one step —
  a one-frame `leaving` would otherwise pass a naive check.
- **The dangerous mistake is asserted directly**: withdrawing onto a room's
  centre still ends `idle`, never `arrived`. Without that, a retreat that
  happened to end inside a room would have started capturing at the place it
  fled to — the R24 defect, reintroduced from the other end.
- **And it can be called back**: hearing something again mid-retreat pulls it
  out of `leaving` and back into hunting, with the room name set.
- **Proved they fail.** Backups after the fix (sha256 `...`), then both halves
  planted — the server reverted to `pursuit:stop()` and `isAudible` narrowed
  back to approaching only. Four failures by name including `YOU HEAR IT GO` and
  `it is audible for the whole walk out` — 62/64, plus two wiring failures. Both
  files restored, both sha256 byte-identical.
- **Verified it reached the PRODUCT**: `withdrawTo` and the literal
  "try that number again later" are both in the built place file.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether the hum reads as RETREATING
rather than approaching — same sound, opposite meaning — is exactly the claim
this round cannot make, and is the first thing to listen for whenever a human
can run this.

**Commit** `%%HASH%%`.

**Next round.** With the monster's full cycle now closed (hunt, arrive, hold,
give up, walk out), the oldest filed item is the most valuable: making
`speed`/`silenceRadius`/`arriveRadius` governed dials, which finally lets the
owner answer the escape-window question from R23 by editing one file.
