

## R38 — somebody joining hands the reader a free solve

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.**

0. **Checked first, no defect: the other reset paths ARE complete.** Walked
   `Lifecycle.restart`, `Connected.clear`, `Station.clear`,
   `Operator.forgetObservations` and `Pursuit.sendHome` against their own field
   lists — every per-round field is handled, and `Operator.lastDecayAt` is
   deliberately not (the Lexicon cools in real time, across rounds, by design).
   So generalising R37's completeness guard would have been a no-op fix, and
   AGENT_LOOP says not to ship one. **Recorded so it is not re-swept.**
1. *(picked)* **`PlayerAdded` re-deals the whole board, and a player who has
   already READ a line can then submit it themselves.** `submit` refuses only
   the CURRENT holder. Probed three times against the real board:
   - two players, `board` held by one of them, holder refused: `ok=false`
   - the holder reads the number out — the whole point of the game
   - a third player joins; `board:deal` reassigns every unsolved line
   - the ORIGINAL holder, who knows the answer, submits it:
     **`ok=true, solved=true`** (twice in three runs; the third kept the same
     holder by chance, since `deal` starts at a random index)
   The invariant this game is built on — *the player who can SEE an answer may
   never be the player who ENTERS it* — is defeated by an ordinary join. It
   needs no exploit knowledge: the reader still has the number on their screen a
   moment earlier, and the keypad simply accepts it.
   **This is fixable without touching the owner's filed question.** Whether a
   join should re-deal at all is theirs to answer; that having read an answer
   must disqualify you from entering it is true under every policy.
2. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** `Objective.seenBy` records everyone a line has been DEALT
to this round, and `submit` refuses anyone in it. Being dealt a line is what puts
its answer on your screen, so that is where the mark is made — in `deal` and in
`redealOrphans` both.

The invariant is now written as what it actually is. It was implemented as *"is
not the current holder"*, which is a different and weaker claim than *"has not
seen the answer"*, and the gap between them is exactly one join.

The refusal is a plain refusal: no miss is recorded against a disqualified
player, because they are refused for who they are rather than for what they
typed.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 99, pursuit 90,
  round 49, config 55, wiring 210, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 59, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **R37's completeness guard picked up the new field on its own.** `seenBy` was
  added this round and the derived sweep immediately required `reset` to clear
  it — `reset clears 'seenBy'` appeared without being written. A guard earning
  its keep one round after it was built.
- **Proved it fails, in both directions.**
  Plant A, refusing only the current holder as before: five failures by name
  including `the player who read it cannot enter it` and `the first reader is
  still disqualified` — 94/99.
  Plant B, overwriting the reader set instead of accumulating it:
  `every reader is remembered, not just the last (1)` — 97/99. That second one
  matters, because "remember the last person who saw it" is the obvious
  implementation and is wrong the moment a board is re-dealt twice.
  Restored, sha256 byte-identical.
- **The keep side is asserted**: a player who never saw the answer can still
  patch it, and the line does solve. Without that, "refuse everybody" would pass
  every other check in this block.
- **And it is per ROUND**: after `reset` re-rolls the answer, last round's
  readers are strangers to it again.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**What this round did NOT decide.** Whether a mid-round join should re-deal the
board at all is one of the owner's four filed questions and stays filed. This
fix holds under every answer to it: having read an answer disqualifies you from
entering it whether the board reshuffles on join, on leave, or never.

**Commit** `%%HASH%%`.

**Next round.** The same question — is the rule written as what it MEANS, or as
the nearest thing that was easy to check? — is worth asking of the other gates.
`Station.accepts` answers "did you most recently walk up to this station", and
the rule it stands for is "are you standing at it"; those come apart as soon as
a player walks away without touching anything else.
