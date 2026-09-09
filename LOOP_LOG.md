

## R47 — five joins and the round can never be finished

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Took R46's method — simulate a session rather than
read a rule — and aimed it at R38's own fix.

`deal` marks everyone it hands a line to as having SEEN it, and `PlayerAdded`
re-deals the whole board. Simulated:

- **joins alone are safe**: each join adds an unseen player as fast as `seenBy`
  grows. Four, eight, twenty joins — every line still solvable.
- **churn with fresh faces is safe** for the same reason.
- **repeated deals over the SAME roster are not.** Four players, one of them
  rejoining — every join fires `PlayerAdded`, every `PlayerAdded` re-deals:

  | deal | seenBy sizes | lines nobody can patch |
  |---|---|---|
  | 1 | board=1 breaker=1 | 0 |
  | 3 | board=2 breaker=2 | 0 |
  | 4 | board=3 breaker=3 | 0 |
  | **5** | **board=4 breaker=4** | **2** |

1. *(picked)* **After five deals every player has seen every line, and the round
   is stuck for good.** Four players are in the server, nobody can patch
   anything, so `allSolved` never becomes true — so the round never ends, so
   `reset` never runs, so `seenBy` is never cleared. The only escapes are
   everyone being caught or the server emptying.
   Five joins in a round is ordinary Roblox: one player with a bad connection
   produces it alone.
   **This is R38's defect.** That round closed a real hole — a join used to hand
   the reader a free solve — and opened this one by letting the seen-set grow
   without bound.
2. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, and R46's learning gap — **all still filed.**

**Stage 2 — built.** `deal` now PREFERS a reader who has already seen the line.
Showing a line again to somebody who has already read it costs nothing, and it
stops the seen set growing every time anybody joins. `seenBy` settles at one
entry per line instead of climbing to the size of the server.

**It does not touch the owner's filed question.** Whether a join should re-deal
at all stays open: the board still reshuffles exactly as before, it simply stops
burning a fresh reader each time.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 112, pursuit 90,
  round 56, config 57, wiring 223, connected 32, ordering 4, heat 20,
  layout 65, lifecycle 75, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **Thirty re-deals** over four players now leave every line patchable, with
  `seenBy` still at one — asserted, not sampled.
- **R38's rule is re-asserted in the same block**, because the obvious way to
  fix a deadlock is to weaken the thing causing it: the reader of a line STILL
  cannot patch it, and somebody who never saw it still can. Without those two
  checks, "let everybody patch everything" would pass every other check here.
- **A growing server is checked too** — joins add unseen players, and the new
  preference must not start handing lines to them instead.
- **Proved it fails, and the second plant is the useful one.** A, the preference
  removed (R38's behaviour): `thirty re-deals leave every line patchable (2
  stuck)` and both `burned exactly one reader (4)`. B, the preference INVERTED
  to prefer an unseen reader — which is the tempting reading of "spread the
  lines around" — fails identically. That is the version somebody would write
  next, and it deadlocks just as fast.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**Two rounds, one method.** R46 and R47 both came from simulating a session
rather than reading a rule, and both found things that forty-five rounds of
careful file-reading had missed. R46's was structural arithmetic between correct
systems; R47's was a defect in a fix I had shipped nine rounds earlier and
verified thoroughly — every check R38 wrote still passes, because they all
examined ONE deal. The defect only exists in the fifth.

**Next round.** The same question has one more obvious target: the jam. R37
established it is per (line, actor) and escalates, and R45 measured the
arithmetic — but nothing has asked what a jam does over a round with several
players guessing, or whether a group can lock ITSELF out of a station the way
they can now no longer lock themselves out of a line.
