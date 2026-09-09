

## R32 — the Operator hunts during the intermission

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Audited R29's blind spot again, since R30 and R31 both
came from it and this is the third.

1. *(picked)* **R29 gated CAPTURE on the round being live, and nothing else.**
   The chat feed and the hunt are both ungated: `TextChatService` still calls
   `operator:hear`, and `onUnderstood` still broadcasts and calls
   `pursuit:sendTo`. Probed with the real Operator, Pursuit and Lifecycle wired
   the way the server wires them:
   - the round ends -> `over=true, playing=false`
   - during the intermission someone says "patch the jack"
   - **the Operator announces to everyone (1 broadcast), starts hunting
     (`state=approaching, target=board`), and is AUDIBLE**
   - eight seconds later it is `closing` — and then `beginRound` teleports it
     home mid-walk
   It can take nobody the whole time, because R29 gated that. So players hear
   the approach, and the hum, in a round that is already over, and nothing
   happens. That is worse than no tell at all: the entire game rests on the hum
   meaning something, and this trains players that sometimes it does not. It
   also spends the Operator's own voice on a round nobody is playing.
2. **Geometry-blind movement.** Re-opened rather than filed a sixth time, per
   AGENT_LOOP's note that logged verdicts have been wrong about half the time —
   R30 proved that on my own R26 note. Re-derived: the post and both room
   centres all sit on z = 0, and the doorway spans z = -6..+6, so every path
   still passes through a door. The corridor walls added in R28 are at
   z = +/-6 running parallel to every path. **Genuinely unreachable, verified
   from the current numbers rather than from the old note.** It is an accident
   held by three unrelated constants, so it wants a guard — but a guard alone
   changes nothing observable, and AGENT_LOOP says not to ship a no-op.
   **Filed once more, with the derivation attached so the next round does not
   redo it.**
3. No player light, and the stemming pair — **still filed**, both owner-shaped.

**Stage 2 — built.** One gate, in the chat handler: the Operator only listens
while a round is being played. Gating the FEED rather than the movement means
`onUnderstood` never fires during an intermission, so nothing is broadcast,
nothing is chased, and lobby chatter never reaches the observation buffer
either — three consequences from one check, which is why it goes there rather
than at `pursuit:sendTo`.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 74,
  round 49, config 53, wiring 186, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 46, plus the operator assertions. `suite passed`.
- **The modelled test carries its own CONTROL.** Three checks assert that while
  the round IS live the same wiring hunts, announces and is audible. Without
  them the four "a finished round does not..." checks would pass just as well
  against an Operator that never worked at all.
- **Proved it fails, in both places.** The server gate removed:
  `the Operator only listens while a round is live` — 185/186. The gate deleted
  from the modelled rule in `tests/lifecycle.luau`: four failures including
  `a finished round does not start a hunt` and `...and stays silent` — 42/46.
  Both restored; the server file sha256 byte-identical, the test file from its
  own backup.
- **The plain term comes from the real pool**, not a literal, so a change to
  `SECRET_POOL` cannot leave this test exercising a word the game no longer
  listens for.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED as always.

**Commit** `%%HASH%%`.

**This is the third defect in a row from the same source.** R29 introduced the
round boundary; R30, R31 and R32 have each found something that was only ever
correct when there was exactly one round — the Operator's position, two pieces
of per-round state, and now the listening itself. The pattern worth naming: a
gate added for one consequence (R29 gated capture) tends to be assumed to cover
the others. Next time a phase check goes in, the round should enumerate every
behaviour that phase is supposed to suppress rather than the one that motivated
it.

**Next round.** The filed list is unchanged, and geometry-blind movement now
carries its derivation so it need not be re-derived. The most valuable unfiled
ground left is the client: it has no test of any kind, and the round-outcome UI
gap noted in R29 is still open — the win or loss is one sentence that fades in
2.5 seconds, and the intermission has no clock.
