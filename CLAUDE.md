# OVERHEARD — co-op horror, Roblox

**Read `LOOP_LOG.md` first — it outranks every other doc here.**
It is APPEND-ONLY. Never rewrite it in place: for thirty-three rounds the last
step of each round wrote a `%%HASH%%` placeholder into the entry and then
substituted the real commit hash into it, and the substitution wrote an empty
file -- 2,509 lines and the CHARTER, GATE and EXPANSION AXIS went with the first
one. Write the hash into the entry BEFORE committing, or leave it out.
`tests/log.luau` fails the ship gate if a round has no entry, if an entry names
no commit, or if a placeholder survives.
`GAME.md` is the design bible, `RESEARCH.md` the platform limits.

Luau on Roblox, synced to Studio with Rojo. Filesystem is the source of truth;
Studio is the viewer and playtester. Never ask the user to paste code back.

## Layout
- `src/server/` -> ServerScriptService.Server (authoritative)
- `src/client/` -> StarterPlayerScripts.Client (view + input only)
- `src/shared/` -> ReplicatedStorage.Shared (pure modules, no side effects on require)

## Hard rules
- `--!strict` at the top of every file.
- The server owns all state that matters. The client never decides whether it
  was caught, how much stamina it has, or what a door does. Exploiters own the
  client entirely; assume every RemoteEvent argument is hostile and validate it
  server-side.
- Remotes: one `RemoteEvent` per verb, named for the verb. Rate-limit every
  remote the client can fire. Never trust a position sent by a client.
- Use `task.spawn`/`task.delay`, never `spawn`/`delay`/`wait`.
- Disconnect every connection you make; store them per-player and clean up on
  `PlayerRemoving` or you leak memory across rounds.
- Tabs for indent, `PascalCase` modules, `camelCase` locals.

## Horror-specific
- Fear comes from audio and pacing, not polygons. Silence before the hit is the
  scare; the sound is just the punctuation.
- Lighting is a mechanic. Darkness the player can push back a little, never
  fully, is the whole genre.
- Multiplayer is the amplifier: players scaring each other beats any monster.
  Proximity voice/chat and asymmetric information do more work than AI does.
- The monster must be legible. Players need to learn a rule, or the scare reads
  as unfair and they leave.

## Testing
`lune run tests/lexicon` for pure logic — keep the text layer free of Roblox
APIs so it stays headlessly testable. `tests/studio/TestOperator` needs a runtime: serve `dev.project.json` and run it
from Studio or MCP.

Studio's playtest with 2 players (Test > Clients and Servers) is the minimum
bar for anything touching replication. A thing that works in solo playtest and
breaks with 2 players is the default outcome, not the exception.
