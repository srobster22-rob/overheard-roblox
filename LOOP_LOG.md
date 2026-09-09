

## R29 — the game can be played exactly once

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.**

1. *(picked)* **Neither ending leads anywhere, and winning does not even stop
   the monster.** Traced: `allSolved()` fires `LINES.completed` and returns —
   that is the entire win path. `allTaken()` fires `LINES.lost` and calls
   `pursuit:stop()`. `grep` for any reset/restart in the server returns NOTHING.
   So:
   - after a WIN the Operator is still hunting, still arriving, still taking
     people. You finish the board and then get caught.
   - after either ending the objectives stay solved, the connected stay
     connected, and the server is a dead lobby until everyone leaves.
   The game is playable exactly once per server. Everything the last eight
   rounds fixed — the doors, the capture shape, the release, the tell — is
   reachable only in that single round.
2. **The Operator ignores geometry** (filed R28). Re-probed against the new
   corridor walls: post and both room centres all sit on z = 0, so every path
   still runs down the centre line and through the doorways. Still an accident
   rather than a rule, still no crossing today. **Filed a third time** — and
   item 1 does not move it, so it stays honest to defer.
3. **Nobody carries a light.** The rooms have one lamp each (range 34) and the
   corridor has none, with `Lighting.Brightness = 0`. `CLAUDE.md` says darkness
   the player can push back *a little* is the genre; right now there is nothing
   to push back with. Real, but it is an unbuilt FEATURE rather than a defect,
   and it wants a design opinion about what the light is. **Filed.**
4. The stemming pair — **still filed**, still an owner call.

**Stage 2 — built.** New `systems/Lifecycle` — pure and clockless, TOLD the
time so the intermission stays a dial — owning phase, outcome and round number.
`Objectives.reset()` starts the board over with FRESH answers (reusing them
would let a group retype last round's numbers). `Config.IntermissionSeconds = 8`.

The server now:
- routes BOTH endings through `round:finish`, which returns true only on the
  transition. Both are checked on a repeating tick — `allSolved` stays true
  forever once the board is done, `allTaken` while everyone is caught — so
  without that guarantee the ending is announced four times a second.
- **stops the Operator on a win**, which it never did.
- **gates capture on the round still being played**, so the intermission is not
  a hunting ground after the line that said it was over.
- runs `beginRound()` after the intermission: board reset and re-dealt, everyone
  taken off the line, the Operator sent home, clients told.

**The Lexicon deliberately survives the reset.** A group's shared vocabulary
carrying between rounds is the retention mechanic `GAME.md` is built on;
clearing it would make every round a first round with strangers. That is
asserted, not just commented.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 64,
  round 49, config 53, wiring 174, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 28, plus the operator assertions. `suite passed`.
- **Proved it fails, three ways at once**: winning no longer stopping the
  Operator, capture ungated from the round phase, and `finish` made
  non-idempotent. Six failures by name across two files, including
  `winning stops the Operator`, `capture is gated on the round still being
  played`, and `finishing again reports nothing` — 24/28. Both files restored,
  both sha256 byte-identical.
- **The fourth heredoc backslash collapse of this session.** Patching
  `tests/wiring.luau` turned `"
	"` inside a Luau pattern into a real line
  break again (R22, R24, R28, now R29). Fixed with the `string.char(10)` idiom
  the file already uses, and the comment now names the count so the next round
  reaches for it first.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. `IntermissionSeconds` is in the built place — meaning the
CODE shipped; the running round, like every part this project builds, is
Studio-blocked. Whether 8 seconds of intermission is a breath or a lull is not
claimed.

**Commit** `%%HASH%%`.

**Next round.** With a full round now able to start, end and start again, the
oldest unfiled gap is that nothing tells a player what the round's outcome WAS
beyond one sentence that fades in 2.5s — and the intermission has no visible
clock. That is the first thing a second round makes matter.
