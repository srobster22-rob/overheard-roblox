

## R45 — the Lexicon forgets in 100 seconds, and the design says days

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Measured the two dial comments that still make
checkable claims, against the real modules.

1. **`HeatPerCredit`'s "roughly four uses burns a term" is the BEST case only.**
   Heat is recency-weighted, so how fast a term burns depends on the gap between
   saying it and succeeding:

   | credited after | uses to burn |
   |---|---|
   | 0s | 4 |
   | 1s | 5 |
   | 3s | 5 |
   | 5s | 6 |
   | 10s | 8 |

   "Roughly four" describes only a group that succeeds the instant they speak.
   Small, but it is the number a reader would plan around.
2. *(picked)* **`CoolPerSecond` erases the mechanic the game is named after.**
   Measured: a freshly burned term sits at heat 1.00 and reaches **zero after
   100 seconds — 1.7 minutes.** `GAME.md` says *"Burned terms cool slowly over
   real days."* The rate for one day would be `0.0000116`; the dial is `0.01`,
   about **860x faster**.
   The consequence is not cosmetic. GAME.md's central escalation — *"your
   language decaying under you"*, a coinage that works for four rounds and then
   one night does not — cannot accumulate at all: a term burned at minute one is
   entirely forgotten by minute three, inside the same round. The Operator never
   learns anything that outlives the conversation that taught it.
   **The VALUE is a balance decision and is filed, not made.** What this round
   ships is the measurement, the corrections to two statements that are false as
   written, and a guard that pins the relationships so the next drift is caught
   rather than discovered by reading.
3. **Also true and worth stating plainly**: "over real days" cannot hold under
   ANY rate today, because the cross-session persistence it depends on (DataStore,
   backlog R6) was never built. A server's Lexicon dies with the server.
4. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** Three corrections and a measurement guard. The
`CoolPerSecond` comment turned out to be ACCURATE about the timings — my
Stage 1 framing was wrong on that point and the measurement said so — but it
carried two other defects, and `GAME.md` carried the real disagreement:

- **`HeatPerCredit`'s "roughly four uses"** now states the measured range: 4
  when success is instant, 5 at a one-second gap, 6 at five seconds, 8 at ten.
- **A stale note**: the comment read *"there is no round flow yet — see R9"*.
  R29 built it. A stale note is worse than none, because it sends the next
  reader off to build something that already exists.
- **`GAME.md`'s "cool slowly over real days"** is replaced with what is true: a
  term burned to 1.0 is fully cold in 100 seconds, so nothing accumulates across
  a session and the escalation the document describes cannot build. Cooling over
  days would additionally need the Lexicon to outlive the server — the unbuilt
  DataStore work. **Both are the owner's calls and are filed, not decided.**

**A boundary the prose got wrong, found by measuring.** The comment said a
burned term "falls back under ActThreshold after 40s of disuse". Measured:
`1.0 - 40 * 0.01` lands EXACTLY on 0.6, and `Heat.isUnderstood` is `>=`, so at
forty seconds it is still understood. It goes under a second later. Corrected in
both the comment and the assertion.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 56, config 57, wiring 223, connected 32, ordering 4, heat 20,
  layout 65, lifecycle 69, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **A plant that proved nothing, and why that mattered.** Halving
  `HeatPerCredit` did NOT fail the suite — correctly, because that assertion is
  `instant == math.ceil(1 / Config.HeatPerCredit)`, derived from the dial, so it
  tracks a retune instead of fighting it. But it meant the plant tested nothing.
  Re-planted against the actual claim — the recency weighting — by making
  `credit` ignore how long ago a phrase was said: `a five-second gap costs more
  uses than none (4 > 4)` and `and ten seconds costs more still (4 > 4)`.
  Also planted a 20x cooling rate: `at exactly 40s it is ON the threshold`
  and `a burned term outlives one intermission (1.6 lost)`. All restored,
  sha256 byte-identical.
- **A misplaced test again**, and the same lesson as R44: `tests/operator.luau`
  is a thin runner with no `check` helper and no modules in scope. Moved to
  `tests/lifecycle.luau`, which already had both. Two rounds running, the first
  home I reached for was wrong; the test files answer narrower questions than
  their names suggest.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**What this round is really about.** R21, R41, R44 and now R45 have each found a
promise written in prose about a number nothing derives. The new part here is
that one of the comments was RIGHT and my summary of it was wrong — the
measurement corrected me, not the code. That is the argument for measuring even
the claims that look fine.

**Next round.** The largest remaining prose-versus-code gap is `GAME.md` itself.
It describes four objectives (`The Breakers`, `The Ledger`, `The Route`, `The
Four Doors`) of which two exist, a four-phase round shape that is not
implemented, and a seven-entity roster with one built. None of that is a defect
in the game, but the document is what a new reader trusts first, and it is now
the least accurate file in the repo.
