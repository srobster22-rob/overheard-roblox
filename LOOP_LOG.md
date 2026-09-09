

## R43 — the breaker's keypad tells you about the jack

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R42 ended by admitting that four client literals were
judged "coherent" BY EYE, with nothing enforcing the judgement — the same shape
as the defects R41 and R42 had just fixed. Looked properly.

1. *(picked)* **The keypad hint names `jack_number` at every station, including
   the breaker.** The live text is built as
   `enter the number you were told for the {stationId}`. Probed per station
   against the real pool:
   - at `board` (owns `jack_number`) -> conveys **`jack_number`**
   - at `breaker` (owns `breaker`) -> conveys **`breaker`, `jack_number`**
   The `breaker` half is fine by R41's rule. The `jack_number` half is not: it is
   a concept that keypad is not about, on screen, in front of the player
   actively working the breaker. It comes from the word "number", which is plain
   language, and the interpolated `{stationId}` is the raw internal id — so the
   game was also showing players `board` and `breaker` as the names of things,
   which are the two plain terms themselves.
   A candidate wording that names neither: *"enter what you were told"* ->
   conveys nothing.
2. **The static hint set at construction** — *"enter the jack number you were
   told"* — conveys `jack_number` too. It is overwritten by `onOpenBoard` before
   the panel is ever shown, so no player sees it, but it is a trap left lying in
   the source. **Fixed with the same edit rather than filed.**
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, the false "gamble" comment — **all still filed.**

**Stage 2 — built.** The keypad hint becomes *"enter what you were told"* —
no plain language and no raw station id. The title above already says which
keypad it is, in the station's own verb (PATCH / THROW), which is clearer than
showing players an internal id that happens to be the giveaway word. The dead
construction-time hint and the unreachable `"the board"` title fallback are
reworded with it.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 56, config 56, wiring 223, connected 32, ordering 4, heat 20,
  layout 59, lifecycle 59, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **The guard was wrong three times before it was right, and each time its own
  coverage check caught it — not me.**
  1. First draft collected 3 strings while the client displays 6; the
     `(guard) found text the client displays` count failed rather than letting a
     narrow sweep report "clean".
  2. Widened, it found 5 — `or "The round is over."` sits behind an `or`, not an
     `=`.
  3. **The important one: plant A PASSED.** Restoring the original wording —
     `` `enter the number you were told for the {stationId}` `` — did not fail,
     because the sweep read only double-quoted text and that defect is a
     BACKTICK template. A guard blind to the exact form of the defect it exists
     to catch is worse than no guard, because it reports safety. Extended to
     backtick strings with their `{...}` spans stripped, since those are code
     rather than words; re-planted, and it now fails by name.
  4. Backticks then dragged in `` `jack_number` `` from a COMMENT. Comment lines
     are now skipped — the same false positive R37 hit from the other direction.
- **Proved it fails**, finally on both: plant A (original backtick wording) and
  plant B (a new displayed string carrying "fusebox") each produce
  `no displayed string gives a concept away (1)`. Restored, sha256
  byte-identical.
- **The exemption earns itself**: `"The board was restored."` is shown only
  during an intermission, when R32's gate stops the Operator listening — and the
  test asserts the exempted string BOTH really leaks and really appears in the
  client, so a stale exemption cannot sit there covering nothing.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether "enter what you were told"
is clear enough without naming the station is a legibility question a playtest
answers.

**Commit** `%%HASH%%`.

**Three rounds on one seam, and the last one is the lesson.** R41 fixed the
station prompts, R42 the panel constants, R43 the client's own text. The
finding worth keeping is not any of the rewordings — it is that **my first
version of this guard passed against the exact defect it was written for.** The
plant is what exposed it. Every guard in this project should be assumed blind
until a plant proves otherwise, and the plant has to use the defect's ORIGINAL
FORM rather than a convenient paraphrase of it.

**Next round.** The seam is closed for text. The same "written separately,
never compared" shape most likely remains between `Config`'s dials and the
comments that describe them — R21 found one such disagreement and R40 filed
another (the false "gamble"), which is two instances and no guard.
