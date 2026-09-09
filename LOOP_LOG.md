

## R35 — the Your Line panel separates every note from its line

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R34 gave the client's GEOMETRY real coverage; its
BEHAVIOUR — what a panel says for a given payload — is still only checked by
grepping for a handler's name. Went looking for a defect there rather than
refactoring for its own sake.

1. *(picked)* **`renderObjectives` orders its rows with `i` and `i + 100`, so
   with two held lines every note detaches from the line it describes.**
   Computed from the live values:

   ```
      1  PROMPT  board
      2  PROMPT  breaker
    101  note    only you can see this   (belongs to board)
    102  note    only you can see this   (belongs to breaker)
    900  restored 0/2
   ```

   Both prompts, then both notes. "only you can see this" is a claim ABOUT a
   specific line — the line nobody else can act on — and it ends up under a
   different one.
   **Reachable in ordinary multiplayer**, not just solo: two players hold one
   objective each, one leaves, `redealOrphans` hands the orphan to the survivor,
   and now one player holds both. With a single held line the defect is
   invisible, which is why it has survived — every screenshot anyone has ever
   taken of this panel had one line on it.
2. **`string.format(entry.prompt, entry.answer)` runs a SERVER string through a
   client formatter.** A prompt containing a stray `%` throws and takes the
   whole panel render down. Real, but the prompts are authored in
   `Round.STATIONS` and none contains one. **Filed** rather than built — it is a
   robustness fix with no reachable trigger today, and this round already has a
   reachable one.
3. Geometry-blind movement, no player light, the stemming pair — **still filed.**

**Stage 2 — built.** New `src/shared/Readout.luau` returns the panel's rows
ALREADY ORDERED, each tagged with a kind, and the client renders them in the
order it gets. The note is inserted immediately after the line it belongs to,
which is the whole reason the list is built in one place instead of being
reassembled from two number series at render time.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 74,
  round 49, config 55, wiring 209, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 46, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **The property is asserted, not just the example.** Beyond checking the exact
  sequence for two lines, the test sweeps the rows and requires that no `note`
  is ever preceded by anything but a `line` — so a future reordering cannot pass
  by landing correctly on this one payload.
- **Tested against the REAL `Objectives.viewFor` payload**, not a hand-made
  table, so a change to what the server sends cannot leave this file checking a
  shape the game no longer produces. That is also what makes the two-held-lines
  case honest: `board:deal({ 1 })` with one player reproduces exactly the state
  `redealOrphans` creates when someone leaves.
- **Proved it fails, on both sides.** In the module: notes collected and
  appended after all lines, the way the client used to order them — five
  failures by name including `every note sits directly under its own line` and
  `no note is orphaned from its line (1 orphaned)`, 15/20. In the client: the
  render re-inventing `+ 100` — `the panel does not invent an order of its own`,
  208/209. Both restored, both sha256 byte-identical.
- Also asserted the quieter rules the extraction had to preserve: a SOLVED line
  you hold is not listed and does not suppress the empty message, the count
  covers every objective rather than only yours, and a player who holds nothing
  gets no answers in their rows at all.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: this proves the row ORDER, and
nothing about spacing, wrapping or whether the note is legible at 10px.

**Commit** `%%HASH%%`.

**Why this one survived 35 rounds.** With a single held line the ordering reads
correctly, and every manual look at this panel has had one line on it. It only
misbehaves when a player holds two — which needs either a solo server or
somebody leaving mid-round. That is the shape worth remembering: a defect that
is invisible at the size everyone tests at.

**Next round.** `onPhase` is the other client handler that computes text from
server state and is still only checked by grepping for its name. Same treatment
would suit it, but only if there is something actually wrong — this round's rule
was to find the defect first and let the extraction follow it, and that is the
order to keep.
