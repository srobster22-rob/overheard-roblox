

## R49 — a soak, and proving it would have caught the last three rounds

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R46, R47 and R48 each came from simulating ONE session
by hand and throwing the script away. AGENT_LOOP lists "a NEW instrument on
ground the suite cannot see" first among idea sources, and three rounds running
have proved that ground is where this project's real defects live. So this round
builds the instrument instead of another one-off.

Ran a soak of a server's whole life — 1500 seconds, rounds cycling, players
joining and leaving, chatter, giveaways, captures and patching, driven the way
`init.server` drives them:

```
simulated 1500s of server life
  rounds completed: 22   won 23  lost 0
  players at end: 6
  largest lexicon seen: 10
  most players connected at once: 3
  ticks where a live round was unfinishable: 0
```

**No new deadlock.** R48's fix holds across 22 rounds with churn and captures.

**Two false findings I nearly reported, both mine.**
1. The first retune produced numbers IDENTICAL to the first run — 149 rounds,
   150 wins. That is impossible: I had cut the solve cadence from every 40 ticks
   to every 260, which allows 23 opportunities in 6000 ticks, not 150. The patch
   had silently not applied, because I wrote `str.replace` with no assert. Added
   asserts, re-ran, got 22 rounds.
2. With the patch applied, `largest lexicon seen: 0` — which I nearly wrote up as
   R46's finding confirmed at soak scale. It was my harness: the sim called
   `board:submit` directly and so never ran `board.onSolved`, which is where the
   server calls `operator:credit`. Wired it faithfully and the lexicon peaks at
   10. **A simulation is only evidence about the game to the extent it is wired
   like the game.**

1. *(picked)* **Ship the soak as a permanent test, and prove it earns its place
   by planting the three defects R46-R48 fixed.** A new instrument that cannot
   catch the defects it was inspired by is decoration — R43's lesson, applied
   before shipping rather than after.

**Stage 2 — built.** `tests/soak.luau`: three scenarios driving the whole server
loop the way `init.server` does — a quiet server, one player with a bad
connection rejoining every 25 ticks, and the Operator taking everyone but one.
It asserts what R46-R48 established, on every tick.

**And it immediately found a real defect — in R48's own fix.** The harsh
scenario failed against shipped code: **134 ticks** — about half a minute — of a
stranded round still running. R48 put the losing rule inside the capture path,
so once the Operator walked away nothing looked again until it came back. I had
written that limitation into R48's log entry and left it; the instrument
measured what it cost.

Losing now lives in `endTheRoundIfNobodyCanWin`, asked by the capture path AND
the tick. The soak drops from 134 stranded ticks to one per lost round, which is
the granularity of asking on a tick rather than slack in the rule — so the
assertion is written as `unfinishableTicks <= lost`, not a number somebody
picked.

The `line:count() > 0` clause is what keeps a solo server from losing instantly
and looping forever: a board nobody can finish with NOBODY connected is the
dealing problem — the owner's filed solo question — not a round play stranded.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 122, pursuit 90,
  round 56, config 57, wiring 234, connected 32, ordering 4, heat 20,
  layout 65, lifecycle 75, hud 16, readout 29, **soak 12**, plus the operator
  assertions. `suite passed`.
- **The soak had to earn its place, and the first version did not.** Planting
  R48's defect PASSED, because the soak detected "unfinishable" by calling
  `Objectives.anyFinishable` — breaking it blinded the game's rule and the
  measurement at the same time. The soak now computes that answer with its own
  implementation. A second opinion has to be a second implementation.
- **Then it still passed**, because a gentle soak never strands anything: with
  half the group caught the team wins every round. Added the harsh scenario, and
  only then did the instrument have teeth.
- **Proved it catches all three.** R47's defect (deal burning a fresh reader):
  `rejoining never strands the board (32 times)`, `the seen set stays bounded
  (6)`, 18 unfinishable ticks. R48's limitation restored: `a stranded round ends
  within a tick (115 ticks over 5 lost rounds)`. R46 is recorded rather than
  asserted, because it is a filed gap and not a fixed one. All restored, sha256
  byte-identical.
- **Five wiring checks went red when the rule moved**, which is correct — they
  described its old address. Rewritten against `endTheRoundIfNobodyCanWin`.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**Three false findings this round, all mine, all caught before shipping.** A
retune that silently did not apply (no assert on `str.replace`); a Lexicon
reading of zero that was the harness not calling `onSolved`; and a soak that
passed against the defect it was built for. The instrument is only worth what
its own validation is worth — and the seventh heredoc backslash collapse this
session says the same thing about my patching method: write the block to a file
and splice it, every time, not just when I remember.

**Next round.** The soak is the ground the last four rounds have lived on, and
it now covers the three defects it was inspired by. Worth extending it rather
than starting elsewhere: it does not yet model players WALKING, so nothing has
ever tested whether a group can physically reach both stations between the
Operator's linger cycles.
