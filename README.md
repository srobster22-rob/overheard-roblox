# OVERHEARD — co-op horror on Roblox

> **At a glance** — A multiplayer co-op horror game for Roblox, written in strict Luau
> and synced to Roblox Studio with Rojo. Players pass secret codes to each other over
> chat while an in-game listener, "the Operator", learns their slang and codes and
> uses them against the group. The server is authoritative, remotes are validated and
> rate-limited, and the game logic runs in pure modules with a headless test suite.
> Built by Robert Schwartz.

## Highlights

- **A language-learning antagonist.** The Operator picks up coinages, number words and a group's code scheme from what players type, so players have to keep changing how they talk.
- **Secure multiplayer design.** The server owns all game state. The client only displays it and sends input, and every RemoteEvent argument is treated as hostile.
- **Testable architecture.** Everything except the two Roblox entry scripts is a pure module the headless test harness can load, with about 100 test files.

## Tech

| Layer | Choice |
|---|---|
| Language | Luau (`--!strict`) |
| Tooling | Rojo (filesystem → Studio sync), Rokit, Selene lint |
| Layout | `src/server` (authoritative), `src/client` (view + input), `src/shared` (pure modules) |

See [ARCHITECTURE.md](ARCHITECTURE.md) for the module map and [GAME.md](GAME.md) for the design.

## Run it

```bash
test.cmd        # headless test suite
serve.cmd       # Rojo server; connect from the Rojo plugin in Roblox Studio
```
