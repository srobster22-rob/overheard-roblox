# OWNER.md — my direction for this project

The agent reads this file at the start of EVERY round (AGENT_LOOP.md, Stage 0).
Write in plain English. One item per line. Top item goes first.

## Open questions — filed by the loop, waiting on you
At most five, each answerable in a word. The gap value is how much the answer
can move on MARKET.md's matrix. Detail is in LOOP_LOG.md at the round named.

1. **Studio (R139): will you connect it? yes / no.** Roblox Studio is blocked
   by one owner action, not by this machine: open the place in Studio, then
   Assistant → "…" → Manage MCP Servers → "Enable Studio as MCP server". It
   gives the loop screenshots and real playtests, which hook (gap 12), art (8)
   and game feel (4) can only rise on. Recommended: yes.
2. **Codes and the chat filter (R139): A) swap the two-digit codes for
   exchange names (KLONDIKE 5, BUTTERFIELD 8) now, B) check the filter on a
   real under-13 account first, C) keep digits.** A 2026 guide says the filter
   hashes numbers for under-13 accounts, and the blind chat writer predicted
   it unprompted. If it is true, younger players cannot pass codes at all.
   Gap: hook 12, accessibility 6. Recommended: A.
3. **Lexicon persistence (R73): A) key it to the private-server id, B) to the
   sorted set of the group's UserIds, C) to Roblox friends.** This decides who
   counts as "the same group" across servers; the save format is ready either
   way. Gap: progression 10. Recommended: A, falling back to B on public
   servers.
4. **The way out (R138, DECISIONS D7): A) keep it: the door opens after a
   10 s ring, and 45 s after that the round ends, won if anyone free got out;
   B) lost unless everyone got out; C) no time limit.** Gap: core loop 9.
   Recommended: A.
5. **Exit words during the ring (R139): A) they keep calling the Operator to
   the lobby, B) exit words stop counting once the call rings.** About 1 in 5
   natural ending lines names the way out ("everyone to the front door").
   Gap: core loop 9. Recommended: A until the next playtest measures it.

Parked, not top five by gap value (ask for any of them back): R5 re-deal on
join, R6 solo play, R9 loud guessing, R21 corner fairness, R36 deferred calls,
R50-51 degree questions, R54 Supervisor pressure, R59/R62 balance numbers,
R63 dropped rooms, R77 unused Layout helpers, R83 reversed words, and R136
publishing (audio is the loop's own work: COACH.md C3).

## Next
<!-- e.g. "the lobby is boring" or "the monster never feels close" -->

## Never
- NEVER run `rm -rf`, `rm -r`, `Remove-Item`, `git clean`, `git checkout`/`restore`
  of files, `git reset --hard`, `git stash`, `git rebase`, `git commit --amend` or
  `git push`. Every one is on the owner's ask-list, so it FREEZES this session on a
  permission prompt nobody is watching -- this has already cost hours more than once.
  Delete a scratch dir with `python -c "import shutil; shutil.rmtree(r'PATH', ignore_errors=True)"`.
  To undo an edit, restore bytes you saved yourself before editing and verify with sha256.
<!-- standing constraints -->

## Done
<!-- the agent moves finished items here with the round number and result -->

- R4: the Operator forgets heat (per second then; once per round since R131).
- R5: a second station, and the stations decide what the Operator listens for.
- R6: the dead-setting test ignores comments; rooms are checked against the built world.
- R8: a line whose holder leaves passes to someone still playing.
- R9: a wrong code jams that line, longer each time, so guessing stops paying.
- R10: the monster's voice and your keypad messages use separate channels.
- R11: the Operator goes quiet once it is close, and announces arriving once.
- R12: the server checks you stand at the keypad you type into.
- R13: "that line is busy" is said only when you did something wrong.
- R14: phrases that cool to zero leave the Lexicon panel.
- R15: phrases match whole words only ("the bluetooth" no longer means "the blue").
- R16-R77: a body, a round lifecycle, the Supervisor, a soak test, mutation sweeps
  and the save format. Detail in LOOP_LOG.md.
- R78-R116: respellings and plurals no longer dodge the Operator, and server logic
  moved into testable modules. Detail in LOOP_LOG.md.
- R85/R86 (stemming): plurals are understood; irregular plurals (leaf/leaves)
  still slip.
- R46 answered "build 5b": heat cools once per round (0.32). Built in R131; a red
  word in use is hunted next time since R134.
- R85 answered, the middle net: 11 more plain words. Built in R130.
- R93 answered: the Operator's lines no longer say "number". Built in R129.
- R122 answered: station labels renamed (Card Index, Exchange Desk, Cutoff).
  Built in R126.
- Correction (R139, COACH.md C9): "0 of 45 everyday lines trip a secret" held for
  lines chosen to avoid its words. Blind chat trips it 30 times in 160.
- R117-R139: see LOOP_LOG.md (the way out, R138; chat heard on the server and the
  Lexicon panel filtered, R139).
