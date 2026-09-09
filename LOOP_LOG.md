

## R48 — a round that cannot be won does not end

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R47 asked what repeated DEALS do over a session. This
asks what repeated CAPTURES do.

R23 made the Operator take everyone in the room at once, and R16 made being
connected cost you the ability to act for the rest of the round. Simulated four
players with three of them caught in one arrival — one arrival on a huddled
group:

- the lone survivor is **always** the reader of one of the two lines, because
  with two lines and four players somebody holds each
- that line can be patched by nobody: its reader cannot, and the other three
  cannot act at all
- so `allSolved` is unreachable
- and `allTaken` needs the survivor caught too, which they can simply avoid

1. *(picked)* **The round ends neither way and runs forever.** Three runs, three
   different deals, same outcome every time: `lines nobody left can finish: 1`,
   `allSolved reachable: false`. A group loses three players to one bad arrival
   and the fourth is left in a building where nothing can be finished and
   nothing will end. No timer exists to rescue it — `RoundLength` is still a
   planned dial nothing reads.
   The shape is R47's: state that only accumulates. There, the seen-set grew
   without bound; here, the connected-set does, and neither had a path back.
2. **The fix is not to re-deal a connected player's line.** Tried it on paper:
   handing it to the survivor marks them as having seen it too, so they can
   patch neither line and the deadlock is unchanged. With one player able to
   act, the round is structurally unwinnable whatever the dealing does — which
   is the owner's filed solo question, reached by a different road.
   What IS a defect rather than a balance call: **a round that cannot be won
   must still end.** The loss condition asks whether everyone is taken; the
   thing that actually matters is whether anybody can still finish anything.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, R46's learning gap — **all still filed.**

**Stage 2 — built.** `Objectives.anyFinishable(able)` asks the question the
loss condition should always have asked: can anybody still finish anything?
`able` is present-and-not-connected. The capture path now ends the round when
either everyone is taken OR nothing is finishable — both mean the group cannot
win.

A WON board also reports nothing finishable, since there is nothing left, so
that case is excluded LOCALLY (`not board:allSolved()`) rather than relying on
the phase gate three hundred lines away to prevent a false loss.

**Checked deliberately, and NOT done: re-dealing a stranded line.** Handing it
to the survivor marks them as having seen it, so they could patch neither. With
one player able to act the round is unwinnable however the cards fall — that is
the owner's solo question, reached by a different road, and it stays filed.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 122, pursuit 90,
  round 56, config 57, wiring 229, connected 32, ordering 4, heat 20,
  layout 65, lifecycle 75, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **The plant caught my guard being useless, which is the story of this round.**
  Plant A removed `or stranded` from the loss condition and the wiring test
  PASSED — because it looked for `anyFinishable` appearing in the capture body,
  and the computation was still sitting there, unused. Exactly R43's shape: a
  guard satisfied by code that does nothing. Tightened to assert the USE
  (`line:allTaken(present) or stranded`), re-planted, and it now fails by name.
- Plant B made `anyFinishable` ignore whether the player has read the line:
  `nobody able means nothing finishable` — 121/122. Both restored, both sha256
  byte-identical.
- **A known limitation, stated rather than hidden**: the check runs in the
  capture path, so a round stranded some OTHER way (everyone able simply
  leaving) is not detected until the Operator next arrives. Running it on the
  tick instead would end a solo round instantly and loop it forever, which is a
  worse failure and a decision the owner has not made. The deadlock this round
  found is caused BY captures, so checking there is proportionate.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**Three rounds of simulating sessions, three deadlocks.** R46: the Operator can
never learn. R47: five joins and no line can be patched. R48: three captures and
the round never ends. All three were invisible to every rule-level test in the
suite, and all three are the same family — STATE THAT ONLY ACCUMULATES, with no
path back. `seenBy` grew, `held` grew, heat only ever fell. Worth carrying as a
question of its own: for each piece of state, what makes it go DOWN?

**Next round.** By that question the remaining candidates are `misses` (cleared
on success and on reset — has a path back), `observations` (windowed and cleared
— fine), and `Connected.held`, which is cleared only by a new round and is
therefore exactly the accumulator this round tripped over. Whether a connected
player should ever be released mid-round is a design question, but it is the
last unexamined one-way door.
