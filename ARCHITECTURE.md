# ARCHITECTURE Ã¢â‚¬â€ OVERHEARD

The map of the code. Use it to find the module that owns a concern before you
open anything. Any commit that adds, moves or splits a module updates this
file in the same commit (`tests/wiring.luau` fails if a module in `src/` is
missing from the map). Sizes are lines, as of R152.

Luau on Roblox, synced with Rojo (`default.project.json`):
`src/server` Ã¢â€ â€™ ServerScriptService.Server, `src/client` Ã¢â€ â€™
StarterPlayerScripts.Client, `src/shared` Ã¢â€ â€™ ReplicatedStorage.Shared.
Everything except the two entry scripts is a pure module that the headless
harness can load; the entry scripts only run inside Roblox.

## Module map

### Entry scripts (Roblox only)
| Path | Owns | Size |
|---|---|---|
| src/server/init.server.luau | the Roblox glue: the world, the remotes, Exchange's host, the guarded connections and the loop | 119 |
| src/client/init.client.luau | the client's three panels, the keypad and the remote listeners | 529 |

### Server systems (`src/server/systems`)
| Module | Owns | Size |
|---|---|---|
| Exchange | the server's game flow: chat, restores, capture, the Supervisor, the way out, a round's start and end; built from a host so tests can run it | 696 |
| Operator | the listener: hears chat, learns coinages, number words and a group's alphabet, credits restores | 708 |
| Heuristic | what one line conveys: plain words, learned coinages, live codes | 344 |
| Objectives | the board: lines, holders, who has seen a code, submissions, the stranded-line rule | 463 |
| Round | stations, secret concepts and their plain words, the Operator's lines, dealing, the wall | 361 |
| Pursuit | where the Operator walks, queues and waits; when it is audible | 346 |
| Connected | being caught: who is on the line, taking everyone in a room | 162 |
| Lifecycle | whether a round is playing, its outcome, the loss rule, the intermission | 118 |
| Escape | the way out: the ring, the door, the lobby and its outcome | 165 |
| Supervisor | the silence clock and putting a silent line through | 199 |
| Station | which station each player stands at, on the server | 128 |
| ChatFeed | what players type, heard on the server through `Player.Chatted` | 80 |
| Censor | filtering each phrase before other players may read it | 91 |
| Presence | the Operator's body and hum in the world (renders Pursuit) | 91 |
| World | the code-built blockout of the exchange | 271 |

### Shared (`src/shared`, loaded by both sides)
| Module | Owns | Size |
|---|---|---|
| Config | every tuning value | 201 |
| Types | the shared type vocabulary | 74 |
| Remotes | the RemoteEvent names and the folder that holds them | 77 |
| Lexicon | tokenising, stemming and word tests for the listener | 652 |
| Numerals | number words, sums and letters a group uses for digits | 490 |
| Layout | the exchange's dimensions, rooms and routes | 463 |
| Readout | what the Your Line and Lexicon panels say | 232 |
| Hud | where the HUD panels go at every screen size | 190 |
| Heat | what a coinage's heat means on the panel | 45 |
| Silence | what a player's silence means, band by band | 115 |
| Hum | what the Operator sounds like in each state | 71 |
| Keypad | who may write on the keypad, and a valid submission | 89 |
| Guard | runs every handler, loop and callback under xpcall and keeps each failure (tag, message, traceback) | 62 |
| LexiconSave | the Lexicon's save format (no DataStore call yet) | 159 |

### Tests (`tests`) and tools (`tools`)
- Each suite is `tests/<name>.luau`, run by `lune run tests/<name>`. Most are
  named for the module they cover (`objectives`, `pursuit`, `counting` for
  Numerals and the Operator's counting, `exchange` for the server's flow on a
  fake host). `wiring` (1,549) checks the client, the entry script's glue and
  cross-module rules; `soak` runs long seeded sessions.
- Helpers: `harness.luau` (a fake Roblox runtime: `Harness.build()`, then
  `rt.require(rt.shared.X)` / `rt.require(rt.systems.X)`; it adopts every
  module in src/shared and src/server/systems from the folders, and the
  Studio test under `rt.dev`), `kit.luau` (the shared `check` and `finish`),
  `luaucode.luau` (strips comments and strings from source), `sources.luau`
  (the server's code as the source-reading checks see it: the entry script
  and Exchange).
- `tests/studio/TestOperator.luau`: an end-to-end acquisition test that needs
  a Roblox runtime. It is not in the shipped place: `dev.project.json` adds it
  under ServerScriptService.Dev for Studio; `tests/operator` runs it headlessly.
- `tools/check.luau` the check command; `tools/build.luau` the shipped build,
  which fails if it holds dev-only test code; `tools/suites.luau` which files are
  suites; `tools/sim.luau` the server's flow run headlessly on a stepped
  clock; `tools/playtest.luau` the three bot personas; `tools/play.luau` a
  session player for unscripted testers (its language is at the top of the
  file); `tools/market.luau` MARKET.md's totals; `tools/inventory.luau`
  CONTENT.md; `tools/guards.luau` the lint that every connection and task
  in src goes through `Guard.wrap`.

## One round, on the server (systems/Exchange)
1. **Deal.** `Round.dealSecrets` picks the secret concepts; `Objectives.deal`
   hands each station's line to a holder, who is the only one who sees its
   code (`viewFor`, sent on the `Objectives` remote).
2. **Talk.** `ChatFeed` hears a line Ã¢â€ â€™ `hearChat` Ã¢â€ â€™ `Operator:hear` Ã¢â€ â€™
   `Heuristic.conveyed` (plain words, the group's learned words, a live code
   said aloud, a learned number word or alphabet). An understanding fires
   `operator.onUnderstood` Ã¢â€ â€™ `Pursuit` walks to that room, or queues it. A
   code heard fires `onCodeHeard` Ã¢â€ â€™ `Objectives.reroll` (spent, new code).
3. **The beat** (`beat`, run by init.server's loop every
   `Config.TickSeconds`, while Presence steps `Pursuit` each frame);
   on arrival `Connected.takeInRoom` puts everyone in the room on the line;
   `Supervisor` puts a silent line through; `Lifecycle.nobodyCanWin` ends a
   round nobody can win; `Escape` steps the way out; panels are pushed.
4. **Restore.** The `Submit` remote Ã¢â€ â€™ `Station` (is the player at that
   station) Ã¢â€ â€™ `Keypad.validSubmission` Ã¢â€ â€™ `Objectives.submit` Ã¢â€ â€™ `onSolved` Ã¢â€ â€™
   `Operator:credit` and `creditCode` (what was said before the restore is
   learned) Ã¢â€ â€™ the last line opens the way out (`Escape`).
5. **End and restart.** `Lifecycle` records "won" or "lost"; after the
   intermission `beginRound` resets the board, clears the line and the
   stations, cools the Operator (`coolRound`), resets the Escape and the
   Supervisor, deals again and sends the Operator home.

init.server builds the world and hands `Exchange.build` its host: Players,
TextService, the remotes it fires, the built world and task.spawn/defer. It
connects what the build returns (hearChat, readerPrompt, openStation, submit,
playerAdded, playerRemoving, beat) under Guard. `tools/sim.luau` runs the same
modules in the same order with scripted or session-driven players, so a
headless trace follows the live game.

## Content registries (content is data)
| Kind | Lives in |
|---|---|
| stations (id, concept, prompt, action text, label) | `Round.STATIONS` |
| secret concepts and their plain words | `Round.dealSecrets` pool, `Round.secretsPerRound` |
| the Operator's lines | `Round.LINES` |
| rooms, sizes, routes | `Layout` |
| tuning values | `Config` |
| panel strings and styles | `Readout`, `Heat`, `Silence` |
| number words and letter names | `Numerals` |
| remote names | `Remotes` (`REMOTE_NAMES`) |
| side-restricted engine APIs | `PLATFORM.md` (read by `tests/wiring.luau`) |

## Side-restricted engine APIs
`PLATFORM.md` holds the table and its sources; `tests/wiring.luau` fails if a
client-only API is used in `src/server`, a server-only one in `src/client`,
or either in `src/shared`. Server only: `Chatted`, `FilterStringAsync`,
`GetNonChatStringForBroadcastAsync`, `OnServerEvent`, `FireClient`,
`FireAllClients`, `ShouldDeliverCallback`. Client only: `LocalPlayer`,
`FireServer`, `OnClientEvent`, `OnIncomingMessage`, `MessageReceived`,
`SendingMessage`. Add a row there before using a new one.

## The check command
`test.cmd` (= `lune run tools/check`) runs every SHIP gate in turn: each
suite in `tests/`, a 2-round bot run (`gate`: fails if the bots win none),
the smoke session, the market check, `selene src`, the guards lint,
`stylua --check`, and the shipped build (`tools/build`, to %TEMP%), which
fails if it holds anything only the dev project adds. It prints one line per passing gate and the whole output
of a failing one, then a summary: each failing gate, its first failure and
its `file:line`. `test.cmd heuristic` runs only the gates whose names contain
`heuristic`; `test.cmd verbose` prints every gate's output.

## How to find an error
- Start from the summary line: `heat: FAIL  <check name>  (tests/heat.luau:101)`
  is the failing check's own line; a crash reads
  `<message>  (tests/heat.luau:27)`.
- Re-run one gate: `test.cmd <name>` or `lune run tests/<name>`.
- A server-side bug: `tests/exchange.luau` runs the server's flow on a fake
  host (players you place, remotes that record what was sent, a clock you
  step), so a handler's behaviour can be reproduced without Studio.
- Reproduce a round: write a session file (`seed <n>`, then chat and moves;
  see the top of `tools/play.luau`) and `lune run tools/play <file>`; it is
  deterministic, so append and re-run. Bot runs: `lune run tools/playtest
  <firsttimer|returning|quiet> <rounds> <seed>`.
- In Studio, the server prints `[operator]`, `[objective]` and round lines to
  the output window. Every handler, loop and callback runs under `Guard`, so
  an error warns `[<tag>] <message>` with its traceback there (the tag names
  the handler, e.g. `server.submit`, `client.heard`, `Presence.heartbeat`)
  and is kept in `Guard.failures()`.
- Headless, the sim guards the same callbacks and each beat; `tools/play`
  and `tools/playtest` print `GUARD: [<tag>] <message>` and exit 1 if
  anything was caught, so the check's bot and smoke gates fail on it.

## Known traps
- Chat is heard on the server only through `Player.Chatted`;
  `TextChatService.OnIncomingMessage` is client-only (it silenced the live
  game for 138 rounds while every test passed).
- The harness is a test double: it supports exactly the require shapes the
  code uses (`script.Parent.X`, and `Shared.X` or `Server.systems.X` through
  `game:GetService`).
- `LOOP_LOG.md` is append-only (`tests/log.luau` guards it).
- The heuristic suite's 30 ms timing budget fails under a loaded machine, on
  HEAD too: run it alone before calling it a regression.
- Every tools/play and tools/playtest run is on a STEPPED clock: it proves
  rules and pacing, never feel, art or frame rate.
- A second judge (the soak's) must ask its own question, not copy the
  module's, or it cannot see the module's bug.

## Organization debt (ORGANIZE phase, R152 on)
- About 110 lines of `tests/wiring.luau` still read source text: the client
  (37 checks; it cannot run headlessly), module-order checks on Supervisor,
  Connected, Station, Lifecycle and Presence, the soak-mirrors-server check,
  and four facts about the entry script's glue. The server's flow checks run
  as behaviour in `tests/exchange.luau`.
- Tests do not all mirror modules: `wiring.luau` (2,017 lines) covers many.
- `Exchange.build` is a 635-line factory of closures (its largest inner
  function, `submit`, is 70 lines). Methods on a flow object would bring
  it under the 150-line limit.
- About 270 comment lines in src, and 370 in tests, narrate round history
  (R-numbers, playtests) rather than say why.
