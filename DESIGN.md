# Design — open questions

Filled in with the user, not guessed. **Answered, below, from `GAME.md` —
which is the design bible and outranks this file. This questionnaire predates
`GAME.md`; keeping it blank next to a filled-in bible would tell a reader that
none of this had been decided, when 71 rounds of build say otherwise.**

## The one loop
What does a single round look like, start to finish, in three sentences?

Four players spawn in a dark exchange building and are dealt two secret
lines between them. They talk to solve the objectives without saying the
literal secret near the Operator, which hunts by meaning and takes anyone
whose room it reaches; a round ends when the board is fully patched (won) or
everyone is on the line / nobody left can finish it (lost), then an
intermission and the next round begins. See `GAME.md`, "Round flow" and
`LOOP_LOG.md` R29/R48/R49 for exactly how won/lost is decided.

## Shape (pick one, cut the rest)
- Co-op PvE survive/escape (Doors, Specter) — everyone vs the game.
- Asymmetric PvP (Forsaken, Flee the Facility) — one killer, many survivors.
- Extraction — go in, grab, get out, lose it if you die.
- Liminal/exploration (3008, Apeirophobia) — dread from space, not a monster.

**Picked: co-op PvE.** Everyone is on the same side against the Operator;
there is no player-controlled killer. `GAME.md`'s core mechanic section is the
full rationale.

## Answers so far
- Players per server: **four.** ("Four players, roughly ten minutes, one
  exchange building" — `GAME.md`.)
- Round length: **roughly ten minutes**, per the same line; the server clock
  dials (`Config.TickSeconds`, `IntermissionSeconds`, etc.) are in
  `src/shared/Config.luau`.
- What is the monster, and what is its ONE learnable rule: **the Operator.**
  It hunts by *meaning*, not by volume or literal phrasing — say a fact any
  way you like and it walks toward it. What defeats it is shared context it
  was never present for: history between players it cannot infer from the
  words alone. `GAME.md`'s epigraph states the inversion directly: "Every
  horror game teaches the player the monster's rule. This one teaches the
  monster the player's."
- What does the player have to push back the dark: **an invented private
  language** — coinages the group mints together, tracked as the Lexicon —
  plus each other: proximity chat and asymmetric information (who is holding
  which secret) do the real work, not an item or a gadget.
- Why does a player come back tomorrow: **the Lexicon persists the group's
  vocabulary and it escalates** — a coinage that works safely for a while
  becomes understood by the Operator the more it is used, so the group's own
  history becomes both its encryption key and, eventually, a liability it has
  to keep replacing. (`GAME.md`'s "The escalation" section; the persistence
  half — carrying the Lexicon across sessions via DataStore — is still
  unbuilt, tracked as backlog item R6 in `LOOP_LOG.md`'s EXPANSION AXIS.)
