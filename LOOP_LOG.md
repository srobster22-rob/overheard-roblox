

## R20 — the panel lies about when a coinage starts working

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.**

0. **A false lead, recorded so it is not re-probed.** I first read
   `Operator.decay` as unwired — same shape as R18's `allTaken`, and the
   module's own comment says "without it heat is monotonic and every coinage the
   group ever lands on is burned for the lifetime of the server". It was a BAD
   GREP: I searched `cool(` instead of `decay(`. `operator:decay(os.clock())` is
   called every second at `init.server.luau:307`, inside a `task.spawn` loop
   that rebroadcasts only when heat actually moved. **No defect. Cooling is
   wired.** Caught before any code was written, but it would have produced a
   confident round built on nothing.

1. *(picked)* **The Lexicon panel misstates the only moment that matters.**
   Probed against the real `Heuristic` and the real `Config`: the Operator ACTS
   at `heat >= Config.ActThreshold`, measured — 0.55 -> acts=false,
   **0.60 -> acts=true**. The client's `heatColor` hard-codes a breakpoint of
   **0.5**, reaches red only at 1.0, and the client source does not contain the
   string `ActThreshold` at all. So a coinage at 60% is ALREADY giving the group
   away while the panel shades it mid-amber and implies 40% of headroom left.
   Two numbers describing one event, in different files, disagreeing — and the
   panel is the instrument players read to decide what is still safe to say, so
   this is the most player-facing defect available. Class fix: derive it from
   the constant instead of restating it.

2. `Station.openedBy`, `Connected.clear`, `Connected.count` still have no
   callers. Left alone again: small honest accessors, and deleting them is not a
   player-visible improvement. **Recorded so this is not swept a third time.**

3. `Config.RoundLength` — NOT a defect. It sits under `Config.Planned`, and
   `tests/config.luau` already enforces that planned dials are genuinely
   unwired. R18 filed this as an open item; it was already correctly modelled.
   **Closed.**

4. The two stemming defects (`es` over-strip; `stem` not idempotent) remain
   **filed** — both need the same owner decision about which way to be wrong.

**Stage 2 — built.** New `src/shared/Heat.luau` owns what a heat NUMBER means:
`isUnderstood`, `band`, `safeProgress`, all derived from `Config.ActThreshold`.
Extracted as a shared module for the same reason `Shared.Keypad` was — a rule
both sides depend on, made pure so it can be swept in tests instead of inferred
from a screenshot nobody here can take.

The client's `heatColor` now asks the module. The band above the threshold is
deliberately NOT a gradient: above it there is no "partly", the Operator
understands and moves, and a ramp there keeps implying headroom that does not
exist. The row also says `understood` in WORDS beside the percentage — the
crossing is the single fact this panel exists to convey and colour alone cannot
carry it.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 36,
  round 48, config 47, wiring 142, connected 21, ordering 4, heat 20, plus the
  operator assertions. `suite passed`.
- **The load-bearing check is a sweep, not a sample.** 21 heat values from 0.00
  to 1.00, each run through the REAL `Heuristic`, asserting the panel's verdict
  and the server's behaviour agree at every one — with two guards (`the sweep
  saw the server act`, `the sweep saw the server stay silent`) so a sweep that
  never acted could not pass empty.
- **Proved the checks can fail, twice.** Backup after the fix
  (sha256 `ceb82abc...b81`), old hard-coded ramp planted, suite re-run.
- **A defect in my own test, found by that plant and fixed before shipping.**
  The first plant produced only ONE failure: `heatColor asks the module` still
  passed, because it searched the whole client and `Heat.isUnderstood` also
  appears in the row text further down. A check that cannot fail on the thing it
  names is worse than no check. Scoped it to the ramp body, re-planted, and it
  now fails too — 18/20 with the bug in, 20/20 with it out. Restored from the
  backup both times; sha256 byte-identical.
- **Verified it reached the PRODUCT**: `isUnderstood` appears in the Rojo-built
  place file.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, full suite green
with output pasted above. Studio remains DEVICE-BLOCKED: whether the new red
reads as alarming enough, and whether "understood" fits the 260px panel without
clipping, are exactly the claims this round does NOT make.

**Commit** `%%HASH%%`.

**Next round.** Both remaining known correctness holes are the stemming pair,
and both need the same owner call. Absent that, the next honest ground is the
one no test has ever touched: `World` and `Presence` are unguarded because they
need Roblox instances — but the LAYOUT is arithmetic (are the two stations
really out of earshot? is `OperatorReach` sane against a 48-stud room?) and
could be extracted and swept the way `Heat` just was.
