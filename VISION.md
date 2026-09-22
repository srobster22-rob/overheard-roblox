# VISION — OVERHEARD

**North star:** four friends invent a private language under pressure, and a
polite thing at the switchboard slowly learns it.

## Pillars (from GAME.md and the owner's recorded answers)
1. **Talking is the risk.** Every objective forces a fact across the building;
   the Operator hunts meaning, the Supervisor punishes silence.
2. **Your language decays.** Codewords work, then burn (owner, R46/R131: about
   four rounds), and the group must coin new ones mid-run.
3. **Nothing on screen gives a secret away** (owner, R93/R122/R126-R129), and
   the monster's rule is always learnable (CLAUDE.md: legible or it's unfair).
4. **Being caught keeps you playing**: on the line you are a voice, not a spectator.
5. **Each new entity is a new way of listening** (GAME.md roster of seven).

## The first 10 minutes (as built, from PT1)
Spawn, "Operator. Go ahead, please." Someone reads a number aloud in plain
words, the Operator walks in and takes the room. The group learns to coin a
word. Two stations, ~45 seconds a round, and then the same round again.

## Content axes and targets (counts live in CONTENT.md)
Beside each target: what hitting it would earn on MARKET.md's matrix (R139,
COACH.md C8). Estimates, judged against the comparables' counts, not measured.

**Hitting every target moves content volume from 1 to 2, not further.** The
comparables count rooms by the hundred (Pressure: 115) and entities by the
dozen (DOORS 20+, Phasmophobia 30). Content 3 needs generated content: rooms,
stations and their words as data, laid out by a generator. That is a BIG SWING,
not a target to count toward.

| axis | target | comparable (MARKET.md) | if hit | why |
|---|---|---|---|---|
| stations | 5 | Pressure: puzzle rooms among 115; DOORS: keys, levers, books every floor | content 1→2 with rooms; variety 1→2 if a round deals 3 of the 5 | GAME.md names five objectives; three exist, so every round asks the same three |
| rooms | 5 | DOORS/Pressure: rooms by the hundred | content stays at 2 at most | three rooms give one route and nowhere to hide |
| entities | 4 | DOORS 20+ hostile entities; Phasmophobia 30 ghost types | core loop 2→3 (a second listener changes what is safe to say); content still 2 | one new listener per expansion; #2 Party Line and #6 Echo are next |
| round phases | 4 | DOORS: floors with a finale; The Mimic: chapters with set pieces | core loop +1 only if Cutover becomes a phase with its own decision | Cutover is only a greeting; Work, The Call and Out exist (R138) |
| round outcomes | 3 | DOORS: death, escape, revive | nothing by itself | won / lost today |
| interactables | 8 | DOORS/Pressure: lockers, closets, vents, drawers in most rooms | core loop +1 if hiding is real; content still 2 | the concepts `hiding`/`exit` need objects to hide in and doors to use |
| Operator lines | 16 | Pressure: full voice acting | audio 1→2 only once they are spoken (Text-to-Speech) | one per new event so nothing shares a sentence |
| concepts / plain terms | 8 / 80 | Phasmophobia: ~2 dozen phrases per device | differentiator holds at 3; more words also mean more accidental trips (R139 blind corpus: 18.7%) | each new station brings its own forbidden vocabulary |
| modes / run variants | 3 | DOORS: Daily Runs, Chaos, Rush, Endless | variety 1→3; progression 0→1 | not tracked yet; the first variant adds the axis |

## Headline metrics (every building round logs them before → after)
Measured headlessly while Studio is not connected: `lune run tools/playtest
<persona>` for the three bot personas (7 rounds each, seed 11), and the blind
chat corpus in tests/heuristic.luau. Bots follow a script, so these say whether
the rules hold up, not whether it is fun; the PLAYTEST's unscripted persona
answers that.

| metric | R139 | good looks like | source |
|---|---|---|---|
| rounds won, of 7: first-timers / returning / quiet | 5 / 6 / 6 | a group that learns wins more; nobody wins every round | playtest SUMMARY `won` |
| players taken per round, all personas | 1.7 (36 in 21) | 1 to 2: the Operator bites, the group survives | SUMMARY `captures` |
| Supervisor calls per round, all personas | 1.9 (39 in 21) | falls as a group learns to talk safely | SUMMARY `supervisorCalls` |
| codewords the bots had to replace | 4 | above 0: the Operator really learns their words | SUMMARY `codewordSwaps` |
| natural chat that names a secret | 30 of 160 | at or below the ceiling; every widening chosen | tests/heuristic.luau blind corpus |
| rounds that end, won or lost | 21 of 21 | all of them: none stalls | playtest traces |
