

## R41 — the board's own prompt gives away a different room

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Turned R38-R40's question on the DATA rather than the
gates: `plain` stands for "every ordinary way a player names this thing", and
the prompts stand for "what the holder has to get across". Swept both against
the real pool.

0. **Three clean sweeps, recorded so they are not re-run.**
   - every plain term FIRES and is heard as its own concept: **0 dead or
     misheard** across the whole pool
   - no two concepts claim the same word or the same stem: **0 clashes**
   - no plain term is a stopword: **0**
1. *(picked)* **A station's prompt conveys a concept that is not its own.**
   The prompts are free text in `Round.STATIONS` and nothing has ever checked
   them against the words the Operator listens for. Read verbatim:
   - `board`: *"Line is out. Patch it to jack 47."* -> heard as **`exit`**,
     confidence 1.00. "out" is a plain term for `exit`, whose payload is the
     ARCHIVE — so a player reading their own board instruction aloud sends the
     Operator to the other room entirely.
   - `breaker`: *"Breaker 47 tripped. Someone has to throw it."* -> heard as
     `breaker`, its own concept.
   The second is coherent: say "breaker", it comes to the breaker, and learning
   not to read your line verbatim is the game. The FIRST is not learnable at
   all — the punishment names a room the prompt was never about, and the player
   has no way to connect cause to effect. It also weaponises them against a
   teammate working in that other room without either of them knowing why.
   Fixing the incoherent case does not require deciding whether prompts SHOULD
   contain their own giveaway; that stays as it is.
2. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, and the false "gamble" comment — **all still filed.**

**Stage 2 — built.** `"Line is out."` becomes `"Line is dead."` — one word,
because the defect was one word. The rule now lives beside the prompt as a
comment AND as a guard: `tests/round.luau` reads every station's prompt,
substitutes the number, runs it through the same `Heuristic.conveyed` the
Operator uses, and requires that nothing but the station's own concept comes
back.

Left alone deliberately: the `breaker` prompt still contains its own giveaway.
Learning not to read your line verbatim is the game; being punished for a
concept you never mentioned is not, and only the second is a defect.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 56, config 56, wiring 214, connected 32, ordering 4, heat 20,
  layout 59, lifecycle 59, hud 16, readout 20, plus the operator assertions.
  `suite passed`.
- **The guard carries a control**: `"the line is out"` on its own must still be
  heard as `exit`. Without it, the whole sweep would pass against a reader that
  had stopped understanding anything.
- **It substitutes the number**, and asserts it did — a prompt whose giveaway sat
  in the substituted text rather than the template would otherwise slip past.
  Plant B proves that: adding "by the door" to the reworded prompt fails the same
  check, so the guard is reading the SPOKEN sentence, not the template.
- **Proved it fails.** Plant A restored the original wording:
  `'board' gives away nothing but its own concept (exit)` — 55/56. Restored,
  sha256 byte-identical.
- **Three clean sweeps recorded as non-defects** so a later round does not redo
  them: every plain term fires and is heard as its own concept (0 dead), no two
  concepts claim the same word or stem (0 clashes), no plain term is a stopword.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**What the data question is worth.** Four rounds now from "name the rule, then
read what the code tests" — three on gates (R38-R40) and this one on the data
they act over. The data version has a different smell: nothing was WRONG in the
pool itself, and the defect lived in the seam between two hand-written things
that had never been compared. The prompts were written to be read by a player;
the plain lists were written to be heard by a monster; nobody had ever run one
through the other.

**Next round.** The same seam exists once more: `Round.LINES` — the Operator's
own sentences — are broadcast to every client, and nothing has ever checked
THEM against the plain lists. If the Operator's own voice contains a giveaway
it is not a player defect, but it is the same unchecked coupling, and it is
cheap to sweep with the guard this round just built.
