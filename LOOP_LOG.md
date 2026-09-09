

## R40 — one sentence can hide a second giveaway

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Put R39's standing question to the remaining gates:
name the rule in words, then read what the code tests.

1. *(picked)* **"Plain speech is always punished" is implemented as "report the
   single best concept".** `Heuristic.understand` returns ONE `Understanding`,
   so an utterance carrying plain giveaways for two concepts gives away one and
   the other is never registered. Probed against the real secret pool:
   - `"the jack is right by the fuse"` -> **`jack_number`, conf 1.00, and
     nothing else**; `onUnderstood` fired **once**
   - both words are live plain terms: saying only "jack" gives away
     `jack_number`, saying only "fuse" gives away `breaker`
   So the combination hides one of them. A group that has worked out the trick
   can bury every dangerous word inside a sentence that gives away something
   they have already lost — and `Config.luau` states the rule this breaks in its
   own comment: *"Low enough that plain speech is ALWAYS punished."* Same shape
   as R38 and R39: the rule is about EVERY concept conveyed and the code tests
   the best-scoring one.
2. **The Config comment claiming a half-learned coinage is "a gamble" is
   false** — comprehension is a hard threshold, so heat 0.6 is understood every
   time and 0.59 never. Checked whether to make it probabilistic and decided
   NOT to: R20 committed the panel to determinism (`no gradient above the
   threshold: there is no "partly"`), and the Lexicon now TELLS players
   "understood" as a fact. Making comprehension random would make that panel
   lie. **Filed as a comment to correct, not a behaviour to change** — and it is
   the owner's call if they want the gamble instead.
3. **The jam gives two free guesses after each lockout**
   (`misses % GuessesBeforeLockout == 0` fires only on exact multiples). Traced
   the cost of guessing a 2-digit answer anyway: 15 jams totalling **40 minutes**
   before exhausting the space. Deterrent holds. **No defect, recorded.**
4. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** `Heuristic` splits into three: `conveyed` returns EVERY
concept an utterance carries, strongest first; `novelTerms` returns the
candidate coinages; `understand` is a thin wrapper returning the strongest,
which is what every existing caller and all 29 existing checks ask for.
`Operator.hear` iterates `conveyed`, so the first giveaway moves the Operator
and the rest queue behind it under R36's commitment rule.

Ties are broken by concept name so the reading ORDER is stable — otherwise which
room the Operator sets off for would depend on how `dealSecrets` happened to
shuffle the pool that round.

**Novel terms are gathered once per utterance, outside the loop.** A sentence
conveying two concepts still offered its unfamiliar words once; recording them
per-concept would credit them twice and inflate the heat of every coinage minted
from it.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 49, config 56, wiring 214, connected 32, ordering 4, heat 20,
  layout 59, lifecycle 59, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **The test carries controls.** Each word ALONE is asserted to be understood
  before the combined sentence is examined — without them, "both giveaways are
  reported" would pass just as well against a matcher that understood neither.
- **The concepts come from the real pool** (`Round.dealSecrets`), so a change to
  `SECRET_POOL` cannot leave this checking words the game no longer listens for.
- **Proved it fails, three ways.**
  A, the Operator acting on the strongest reading only: `the Operator is told
  about both (1)` — 39/40.
  B, novel terms recorded once per concept: two failures including
  `novel terms are recorded once per utterance, not once per concept` — 38/40.
  C, the tie-break removed: `the reading order does not depend on the pool's
  order` — 39/40.
  Both files restored, both sha256 byte-identical.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether hearing two announcements
from one sentence reads as attentive or as chatter is not claimed.

**Commit** `%%HASH%%`.

**Recorded, not built.** Two things this round checked and deliberately left:
- `Config`'s claim that a half-learned coinage is "a gamble" is FALSE —
  comprehension is a hard threshold. Left as a comment to correct rather than a
  behaviour to change, because R20 committed the Lexicon panel to determinism
  and made it tell players "understood" as a fact. Making comprehension random
  would make that panel lie, and choosing between them is the owner's.
- The jam's two-free-guesses-per-lockout is deliberate escalation, and guessing
  a 2-digit answer still costs about **40 minutes** of accumulated jams. The
  deterrent holds.

**Next round.** Three rounds have now come from one question — name the rule in
words, then read what the code tests. The gates are largely swept; the same
question aimed at the DATA rather than the gates is the obvious next move,
starting with `Round.dealSecrets`, whose job is "the Operator listens for
everything a station needs" and which nothing has re-derived since R12.
