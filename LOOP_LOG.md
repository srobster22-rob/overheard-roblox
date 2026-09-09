

## R46 — the Operator can never learn anything

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Measured something nobody had: how big the Lexicon
gets over a real session, and whether anything in it ever burns.

Simulated a group talking normally — twelve short sentences a minute, an
objective solved every twenty seconds, the server's decay tick running:

| minutes | sentences | lexicon entries | hottest heat |
|---|---|---|---|
| 1 | 12 | 59 | **0.47** |
| 3 | 36 | **0** | 0.00 |
| 5 | 60 | **0** | 0.00 |
| 10 | 120 | **0** | 0.00 |
| 20 | 240 | **0** | 0.00 |

Nothing ever reaches `ActThreshold` (0.6), and by minute three the whole
vocabulary is gone. Then checked the structure behind it:

- `operator:credit` has **exactly one call site**: an objective being solved.
- there are **2 objectives**, so a round supplies **2 credit events**.
- a coinage needs **4 credited uses to burn** at best, **5 to 8** in practice
  (R45 measured the recency weighting).
- heat is fully cold after **100 seconds**, which is shorter than a round.

1. *(the finding)* **No coinage can ever be burned.** The game supplies two
   credits per round against a requirement of four, and whatever heat is gained
   evaporates before the next round can add to it. So the Lexicon panel fills
   with terms that drift up and fall back to nothing, the red state is
   unreachable, and *"your language decaying under you"* — the mechanic on the
   first page of GAME.md, the reason the game is called OVERHEARD — **never
   happens.**
   Everything else works: the Operator hunts plain speech, arrives, takes people,
   gives up, walks out. It is specifically the LEARNING that is unreachable.
2. **The resolution is a design decision and is FILED, not made.** Three dials
   could close the gap — more credit events per round, more heat per credit, or
   slower cooling — and they produce different games. That choice is the
   owner's.
   What this round ships is the measurement and a guard that PINS both sides of
   the gap, so the numbers cannot drift again without something saying so.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair — **all still filed.**

**Stage 2 — built.** No behaviour changed, deliberately. What shipped is the
finding, put where it will be met:

- `tests/lifecycle.luau` pins BOTH sides of the gap — the credit sites counted
  from the server source, the station count, the measured cost of burning, and a
  three-minute simulation of ordinary talk that ends below the threshold.
- `GAME.md` carries the correction directly under the escalation it describes,
  because that page is what a reader trusts first.
- `Config.ActThreshold` says that nothing currently reaches it, and points at
  this entry before anybody retunes the threshold to chase the symptom.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 56, config 57, wiring 223, connected 32, ordering 4, heat 20,
  layout 65, lifecycle 75, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **Proved the pins fail when either side moves.** Plant A added a second
  `operator:credit` call: `(pinned) the Operator is credited from exactly one
  place (2)`. Plant B slowed cooling 20x so talk accumulates: three failures
  including `(pinned) three minutes of ordinary talk leaves nothing understood
  (0.97 < 0.6)`. Both restored, sha256 byte-identical.
  That is the behaviour these checks are FOR: they are not asserting the game is
  correct, they are asserting the numbers are still the ones this entry
  measured, so a change gets a red test pointing here instead of quietly moving
  the goalposts.
- **A misplaced name, caught immediately**: the block used `Round.STATIONS`
  where `tests/lifecycle.luau` binds that module as `RoundModule`. Third round
  running that I reached for the wrong thing in a test file.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**The largest thing found in forty-six rounds, and it is not a bug.** Every
individual system is correct: the Heuristic reads meaning, the Operator credits
behaviourally, the panel renders heat honestly, the decay is exactly what its
comment says. The failure is in the ARITHMETIC BETWEEN them — two credits
supplied against four required, and a cooling rate that outruns a round. No
single file is wrong, which is precisely why forty-five rounds of reading files
did not find it. It took simulating a session.

**Next round.** That suggests the tool rather than the target: this project has
mostly asked "is this rule correct?" and rarely "what happens over ten minutes
of play?" The second question found this in one probe. Other candidates for the
same treatment: how many objectives a group can actually finish before the
Operator's linger cycle blocks a station, and whether the jam escalation is
reachable in a round's length.
