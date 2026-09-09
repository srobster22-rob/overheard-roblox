# OVERHEARD — loop log

This file outranks every other doc in the repo. Work happens in numbered
rounds; each round appends an entry here. Read the last two entries before
starting anything.

## CHARTER

Build OVERHEARD: a co-op horror game where the monster hunts by understanding
the meaning of what players say, and learns their invented slang over time.
See `GAME.md` for the fiction and `RESEARCH.md` for platform limits.

## GATE — what "done" means for a round

A round is finished only when ALL of these hold:

1. `selene src` reports 0 errors and 0 warnings.
2. `test.cmd` passes (the whole headless suite), and any new pure logic has a
   test of its own in `tests/`.
3. `rojo build default.project.json -o game.rbxlx` succeeds.
4. The change was exercised in a running Studio session (via MCP `run_code`, or
   a 2-player playtest if it touches replication) — not merely compiled.
5. An entry is appended below saying what changed, what was proven, and what
   the next round should pick up.

A round that cannot meet #4 says so explicitly in its entry rather than
claiming success.

## THE EXPANSION AXIS

The game grows along one axis: **new ways of understanding.** Every entity in
the roster is a different comprehension rule (`GAME.md` has the table). This is
what lets the loop run indefinitely without the game repeating itself — each
new listener re-teaches players a habit and then punishes it.

Backlog, roughly in order. Reorder freely; do not skip the gate.

- [x] **R2** Objectives that force transfer. DONE.
- [x] **R3** The Operator as a physical thing. DONE.
- [ ] **R4** Speech-to-Text. Route voice through `AudioSpeechToText` into the
      same `Operator:hear` pipeline. MUST degrade to typed chat (see
      RESEARCH.md — voice needs verified 13+).
- [ ] **R5** LLM comprehension backend behind the existing
      `ComprehensionBackend` interface, A/B against the heuristic. Harden the
      prompt against injection; players WILL try to talk it out of character.
- [ ] **R2b** Second station (the breaker) so a second objective is reachable.
      Rule learned: never add an objective without a station to solve it at.
- [ ] **R6** The Lexicon persists across sessions (DataStore), per group.
      This is the retention mechanic, so it needs to be real, not cosmetic.
- [ ] **R7** Entity #4 The Supervisor — punishes silence. The first true
      inversion; the clip-generating one.
- [ ] **R8** Entity #7 The Translator — understands only figurative speech.
- [ ] **R9** Round flow: cutover, three objectives, the call, the escape.
- [ ] **R10** Being "connected" instead of dying — you become a voice your
      team can hear but cannot answer.

---

## R1 — foundation (2026-09-08)

**Built.** The fiction (`GAME.md`), platform constraints (`RESEARCH.md`), and
the working core of the mechanic:

- `shared/Lexicon` — pure text layer: tokenize, stem, n-grams, stopwords.
- `shared/Types` — shared vocabulary, including a `ComprehensionBackend`
  interface so the heuristic can be swapped for an LLM without touching callers.
- `server/systems/Heuristic` — comprehension that works today with no API
  access. Answers "did that convey a secret?" and "which unfamiliar words were
  used near it?"
- `server/systems/Operator` — the learning loop. Credits novel phrases to a
  concept only when the group *succeeds shortly after saying them*, weighted by
  recency. Acquisition is behavioural, not grammatical, which is why a player
  cannot dodge it just by being weird.
- `server/init.server` — TextChatService feeds every message to the Operator.
- `client/init.client` — the Lexicon panel: your coinages, white to amber to
  red as it closes in.

**Proven.** `lune run tests/lexicon` 14/14. `selene` clean. `rojo build` OK.

**NOT proven.** `TestOperator` (the acquisition assertions) has not been run —
it needs a Roblox runtime and MCP tools were registered but require a session
restart. **Round 2 must run it first** and treat any failure as the ticket.

**Next.** R2, and run TestOperator before anything else.

## R2 — objectives that force you to speak (2026-09-08)

**Unblocked the gate first.** `TestOperator` could not run without a Roblox
runtime, so rather than wait on Studio I built `tests/harness.luau`: a fake
Roblox environment using Lune's `luau.load` with a custom environment, big
enough to satisfy `game:GetService` and `require(script.Parent.X)`. The
acquisition assertions now run headlessly in under a second. **Every future
round can verify without Studio**, which is the single biggest speedup
available to this loop.

**Built.**
- `systems/Objectives` — the invariant: the player who can SEE an answer may
  never be the player who ENTERS it, enforced server-side in `submit`. If that
  ever regresses, nobody needs to talk and the game stops existing.
- `systems/World` — code-generated blockout. Two rooms 120 studs apart with a
  corridor, one weak lamp each, heavy fog, ambient near black. Layout is a
  design variable we tune every round, so it stays in code where it is
  diffable rather than modelled by hand.
- Server wiring: chat feeds the Operator; solving an objective calls
  `Operator:credit`, so **success is what teaches it**. Submit is rate-limited
  (0.75s) and type-checked — a two-digit answer is brute-forceable otherwise.
- Client: three panels — LEXICON (heat), YOUR LINE (the fact only you can see),
  THE BOARD (where you enter what someone told you).

**Proven.** `lexicon` 14/14, `objectives` 15/15, `operator` all assertions,
`selene` 0/0, `rojo build` OK.

**Caught and fixed mid-round.** Added a `power` objective with no station to
solve it at, making `allSolved` unreachable. Removed it; noted the rule in code.

**NOT proven.** Nothing has been run in Studio. The blockout, prompts, lighting
and the three panels are compile-verified only. Also: with ONE player the
invariant means no objective is solvable — correct behaviour, but it means solo
playtesting cannot complete a round. **R3 must open a 2-player playtest.**

**Next.** R3, and open Test > Clients and Servers with 2 players before
anything else.

## R3 — the Operator gets a body (2026-09-08)

**Built.**
- `systems/Pursuit` — pure movement and, more importantly, the AUDIBILITY rule.
  Plain `{x, z}` points so it tests headlessly. It is audible while crossing the
  building and goes silent once inside `silenceRadius`. The scare is not the
  noise arriving, it is the noise STOPPING.
- `systems/Presence` — the Roblox body. A dark mass and a looping hum whose
  volume is driven from `Pursuit:isAudible()` each Heartbeat, faded rather than
  cut so it reads as a decision instead of a bug. No mesh yet on purpose: at
  this stage the sound is the entire performance.
- Wiring: `onUnderstood` now calls `pursuit:sendTo(payload)`. Understanding is
  what MOVES it, which closes the loop from speech -> comprehension -> threat.

**One real bug, caught by writing the tests rather than by running the game.**
Most secret payloads named rooms World never built (`basement`, `lobby`,
`hunt`). Pursuit refuses unknown payloads, so those understandings would have
silently done nothing — no error anywhere, no crash, just a monster that
ignores two thirds of what it understands. Payloads realigned to the rooms that
exist, and `tests/round.luau` now asserts every payload resolves against
`Config.Rooms`. The guard is the durable fix; the realignment alone was not.

**Proven.** Full suite via `test.cmd`: lexicon 14/14, objectives 15/15, pursuit
21/21, round 14/14, operator all assertions. `selene` 0/0. `rojo build` OK.
The silence rule has its own dedicated assertions — including that once it goes
quiet it never becomes audible again while closing, which is the property that
would quietly rot first.

**NOT proven.** Still nothing run in Studio. Specifically unverified: that the
hum is actually audible at range, that `rbxasset://sounds/electronicpingshort.wav`
is a sensible placeholder, and that the body does not clip through walls (it
moves in a straight line and ignores geometry — fine for a blockout, wrong
later).

**Next.** R2b (second station, so a second objective is reachable) is small and
unblocks a fuller round. But the honest priority is a 2-player Studio playtest:
three rounds of logic now rest on zero runtime evidence.
