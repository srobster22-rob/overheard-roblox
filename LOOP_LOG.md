

## R44 — the keypad can open where it will not accept an answer

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Pointed R41-R43's "written separately, never compared"
question at `Config`'s dials and the comments describing them.

1. *(picked)* **`StationReach` describes a relationship with a number in another
   file that nothing enforces.** Its comment says it is *"slightly wider than the
   prompt's own activation distance"* — and that distance is
   `prompt.MaxActivationDistance = 10`, a bare literal in `World.luau` derived
   from nothing. Today `10 < 14` holds by coincidence of two hand-typed numbers.
   If the prompt distance were ever raised past the reach — to 20, say — then:
   - a player standing 15 to 20 studs away CAN trigger the keypad
   - every answer they type is refused, because submit requires 14 or less
   - the rejection reads *"you are not at that station"* while they stand exactly
     where the game just let them open it
   Nothing in the suite would notice. This is the R21 shape exactly: a promise
   in a comment about a number that lives somewhere else, with no derivation
   between them — and R21 is what taught this project that the fix is to derive
   the number, not to retype it.
2. **The false "gamble" comment** on `ActThreshold` (filed in R40): it claims a
   half-learned coinage is "a gamble rather than a certainty", and comprehension
   is a hard threshold. Same family — a comment disagreeing with its own dial —
   and cheap to correct alongside. **Fixed with this round**, and the behaviour
   is deliberately NOT changed: R20 committed the Lexicon panel to determinism
   and the choice of making comprehension random is the owner's.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** `Config.PromptReach = 10` is now a dial beside
`StationReach`, and `World` sets `MaxActivationDistance` from it instead of
carrying a literal. The relationship the comment described is now something the
code holds rather than something a sentence claims.

The `ActThreshold` comment loses its false clause and says what is true instead:
comprehension is a hard threshold, there is no gamble anywhere, and it is left
deterministic ON PURPOSE because R20 built the Lexicon panel on that and made
the row say "understood" as a fact. Whether the game wants the gamble is the
owner's call, not a comment's.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 56, config 57, wiring 223, connected 32, ordering 4, heat 20,
  layout 65, lifecycle 59, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **The guard asserts the PROPERTY, not the two numbers**: it sweeps every
  distance the prompt allows and requires submit to accept all of them. The
  ordering check alone would pass while the two were compared in the wrong unit.
- **Proved it fails, three ways.** A, prompt reaching further than submit
  accepts: three failures including `every distance the prompt allows is a
  distance submit accepts (12 refused)`. B, World back to a literal:
  `World sets the prompt distance from the dial` — the derivation itself is
  guarded, not just the values. C, the two set equal: `there is room for a stud
  of drift (0)`, which is the case the comment's promise is actually about.
  All restored, both files sha256 byte-identical.
- **A misplaced test caught by its own crash.** I first put this block in
  `tests/config.luau` and it died on `attempt to index nil with 'PromptReach'` —
  that file has no Config MODULE at all, by design: it works entirely by reading
  source text. Moved to `tests/layout.luau`, which already has both dials and
  the geometry. Worth remembering that the two config-shaped test files answer
  different questions.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether a four-stud drift band feels
right is a playtest number.

**Commit** `%%HASH%%`.

**The seam, one file further in.** R41-R43 closed it for TEXT: the game's words
versus the monster's vocabulary. This is the same seam between a COMMENT and a
number in another file — and the fix was the same shape as R21's, which is now
the third time this project has found a promise written in prose about a value
nothing derives.

**Next round.** Two dial comments still make checkable claims nothing checks:
`HeatPerCredit`'s "roughly four uses burns a term" (the recency weighting means
it is actually five) and `LockoutSeconds`' description of the escalation. Both
are small, both are measurable against the real modules, and a wrong number in a
comment is what sends the next reader down a wrong path.
