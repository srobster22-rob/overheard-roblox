

## R33 — the round ends and the client never finds out

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Applying R32's own lesson: when a phase check goes in,
ENUMERATE every behaviour that phase is supposed to suppress rather than the one
that motivated it. R29 gated capture, R32 gated listening. Enumerated the rest:

1. *(picked)* **The phase never reaches the client, and `Submit` is not gated on
   it either.** Two findings, one cause:
   - `grep -cE "phase|isPlaying|intermission|outcome" src/client/init.client.luau`
     returns **0**. The client has no idea a round can end. So the win or loss
     is a single sentence that fades after 2.5s, the keypad stays open and
     usable-looking through the intermission, "restored 1/1" sits there and then
     silently flips to "restored 0/1" when the next round starts, with nothing
     saying why.
   - the `Submit` handler checks `isConnected`, `desk:accepts` and the jam, but
     **never `round:isPlaying()`** — the same omission R32 found in the chat
     handler, in the one place left that takes player input.
   The keypad case is the sharp one: a player types the number they were told
   into a keypad the game still draws, and the answer vanishes into a round that
   is over. There is no message, because `board:submit` refuses it for a reason
   that is nobody's doing.
2. Geometry-blind movement — **filed, derivation attached (R32).**
3. No player light, the stemming pair — **still filed**, both owner-shaped.

**Stage 2 — built.** A `Phase` remote carrying `{playing, outcome, number}`,
pushed on both endings, on `beginRound`, and on join. `Submit` is gated on
`round:isPlaying()` and says so on the keypad's private channel. The client
gains a PERSISTENT between-rounds panel — "ROUND RESTORED" in brass or "ROUND
LOST" in red, what happened, and which round is next — and closes the keypad,
because a keypad you can still type into is a keypad that lies about being
usable. Persistent on purpose: an outcome you can miss by looking away is not an
outcome.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 74,
  round 49, config 55, wiring 195, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 46, plus the operator assertions. `suite passed`.
- **Proved it fails.** Three regressions planted at once — Submit ungated, the
  win not pushing the phase, and the client never subscribing. Two failed by
  name immediately. **The third did not**, and that was the useful part: my
  check looked for the handler's NAME in the client and passed against a client
  that declared `onPhase` and never connected it — the same weakness R20 found
  in its own ramp check. Tightened to assert the subscription itself, re-planted,
  and it now fails by name. Both files restored, both sha256 byte-identical.
- **Three guard defects found and fixed inside this round**, all in tests:
  1. The remote-name pattern demanded `local REMOTE_NAMES = {` on ONE LINE.
     stylua wraps that declaration once the list is long enough, so adding an
     eighth remote broke the whole block. It failed LOUDLY rather than passing
     falsely, which is the right failure mode, but a guard that breaks on
     reformatting is one somebody loosens later. **And the same brittle pattern
     existed in BOTH `tests/wiring.luau` and `tests/config.luau` — I fixed one
     and shipped the other broken; the suite caught it at the ship gate.** That
     is the "one instance swept, the class left" shape AGENT_LOOP warns about,
     committed by me, in the same round I was applying its lesson.
  2. My new checks referenced `solvedBlock` and `beginBody`, both declared
     FURTHER DOWN the test file — the use-before-declaration trap
     `tests/ordering.luau` guards for in `src/`, reproduced inside `tests/`
     where nothing guards it. Moved them below their inputs.
  3. `Remotes.get("Phase")` was checked against STRIPPED client source. The
     lexer removes string bodies, so it reads `Remotes.get()` and can never
     match. **Fifth occurrence of that trap** (R18, R20, R24, R29, now R33).

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. The panel's text is in the built place — code shipped;
whether it reads clearly, or covers something, is Studio-blocked.

**Commit** `%%HASH%%`.

**Next round.** The phase enumeration is now complete: capture (R29), listening
(R32), input and display (R33). The client still has no test file of its own —
every client assertion in this project lives in `tests/wiring.luau` and is a
source grep. That is the largest untested surface left, and the three guard
defects above all came from testing the client by grepping it.
