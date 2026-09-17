# OWNER.md — my direction for this project

The agent reads this file at the start of EVERY round (AGENT_LOOP.md, Stage 0).
Write in plain English. One item per line. Top item goes first.

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

- R4 � the Operator now forgets. Heat bleeds off in real time, so a phrase
  your group retires becomes safe to say again after about 40 seconds. It
  never did this before: once a phrase was burned it stayed burned for the
  life of the server. Also added a test that fails if a tuning dial is not
  actually read by the game (three of them were not).
  *(R131: forgetting is now charged once per round, not per second; see R46
  under Open questions.)*

- R5 - the second station (the breaker) is in, and the round's two lists were
  wired together. Before this, 4 servers in 10 ran the only objective for a
  concept the monster was not listening for: you could shout the jack number
  and nothing happened. Now the stations decide what it listens for.
  ONE THING FOR YOU: when a player joins mid-round, should the lines be
  re-dealt (holders reshuffled) or should whoever knows a number keep it?
  The code currently reshuffles. That is a design call, not a bug.

- R6 - the test that is supposed to catch dead settings could be fooled by a
  comment. One setting (the list of rooms the Operator can be sent to) had been
  dead for two rounds while the suite said it was fine. The test now ignores
  comments, and the room list is checked against the rooms the game actually
  builds - in both directions - so a room named in settings but never built
  can no longer make the Operator silently never show up.
  ONE THING FOR YOU (new, small): with only one player in the server, nobody
  can finish a round - both lines deal to that player, and the rule is that the
  holder may not enter their own answer. Should there be a minimum player
  count, or should a solo player be allowed to solve their own?

- R8 - if the player holding a line disconnected, that line was stranded for
  good. Nobody else had ever been shown the answer, so it could never be
  entered and the round could never be completed by the people still in the
  server - the station just sat there being useless. Now a line whose holder
  has left is passed to somebody still playing. Only stranded lines move;
  everyone else keeps what they were already holding, so this does not answer
  your open question about what should happen when someone JOINS mid-round.
  Nothing to decide here.

- R9 - a player could just guess. The code you enter at a station is two digits,
  and there was no penalty for a wrong one, so anybody standing at a keypad
  could hold Enter and open a line in about half a minute without a word being
  said - which is the one thing this game is not allowed to let you do. Now a
  wrong answer jams that line for the player who gave it, and each jam is
  longer than the last: three typos costs 20 seconds, but guessing your way to
  the answer costs over half an hour. It never punishes the person who was
  actually told the number, and one player guessing cannot lock anyone else out.
  ONE THING FOR YOU: I fixed this with a timer, which is quiet. The other option
  is to make guessing LOUD - a wrong code trips something the Operator hears, so
  the cost of brute-forcing is that it comes looking for you. That is probably
  the better horror game, but it might make the keypad frightening to use even
  when you are doing it honestly. Your call; I did not make it.

- R10 - the keypad had one red line under it, and it was being written by the
  monster. When the Operator understood somebody, or a word of yours burned, or
  it arrived somewhere, the server told EVERY player - and whoever happened to
  be standing at a keypad got that message painted into their error slot, in
  red, where "that line is jammed" goes. So you would be typing the number
  your friend just gave you and the keypad would say jack_number at you. You
  could never see this alone: you cannot be typing at a keypad and be the one
  talking. With two people it happens on a good round, because the whole game
  is one of you talking while the other stands at the keypad. The monster's
  voice and your keypad are now separate channels, and a keypad message is also
  tagged with which station it is about, so the breaker cannot answer for the
  switchboard. Nothing to decide here.

- R11 - the monster was supposed to go quiet when it got close to you. That
  silence is the scare; the hum is just it crossing the building. But every
  time it understood something, the hum switched back on wherever it happened
  to be - and it understands you every time you talk about the thing you have
  to talk about. So on a normal round it was standing right on top of you,
  still humming, and announcing itself over and over. It now works out whether
  it should be making noise from where it actually is, so it goes quiet once
  and stays quiet, and it only announces arriving once. Nothing to decide here.

- R12 - the game never checked that you were actually standing at the keypad you
  were typing into. Your computer told the server which station it was, and the
  server believed it. The two stations sit in different rooms 120 studs apart on
  purpose - that walk is what forces somebody to talk - but nothing stopped a
  player from clearing the breaker without ever leaving the switchboard, so the
  second room and the corridor were free. The server now remembers which station
  you last walked up to and refuses a code for any other one. Walking to the
  breaker gives up the switchboard, so you hold one at a time.
  Also: winning a round used to make the Operator say the exact same sentence it
  says when the monster walks into your room - "Go ahead, caller." Winning now
  has its own line. Nothing to decide here.

- R13 - when two of you enter the same number at the same keypad within a
  moment of each other, the second one was told off for it. The Operator said
  "That line is busy." straight into their ear - the same sentence it uses for a
  jammed line - for typing the number they had been told correctly, at the exact
  moment everyone else heard the round was won. You can only ever see this with
  two people, and it happens on a GOOD round, because two people both knowing
  the number and both reaching for the keypad is what a group that is talking
  properly looks like. The refusal itself was right - the line was already
  fixed - but the blame was not. The game now knows the difference between "you
  did something wrong" and "somebody beat you to it", and the Operator is only
  allowed to say the busy line to the first kind. Nothing to decide here.

- R14 - the Operator forgot words but never let go of them. The Lexicon panel
  is the only place you can see what it has picked up, and it listed every
  phrase the group ever coined for the life of the server - including ones at
  0%, which it does not understand at all and cannot act on, sitting in the
  same list as the words that will get you caught. It also only ever grew: one
  long chat message offers about 79 candidate phrases, and one solve within
  twenty seconds wrote all of them in permanently, so the panel filled with
  junk and every line of chat afterwards was scanned against it. A phrase that
  cools all the way to zero is now dropped, so the list drains on its own and
  only shows words it actually knows something about. Nothing to decide here.


- R15 - the monster could understand a phrase you did not say. Once your group
  burns a two-word phrase, it was matched as raw letters rather than as words,
  so it fired on any longer word that happened to start the same way. Real
  examples, all tested: with "the blue" burned, saying "check the bluetooth"
  moved it; with "big red" burned, "the big redhead" moved it; with "one blue"
  burned, "someone blue" moved it. The game mints exactly those short phrases
  from ordinary sentences - one line of normal chat produced "the blue" and
  "is fine" - so this was reachable by talking normally, and the Lexicon panel
  gave you no way to see why it happened. Phrases now have to be said as whole
  words. The phrase still works everywhere it should: said alone, mid-sentence,
  at either end, and in the plural.
  Also: the part of the code that decides what the monster understood had no
  test of its own until now, which is why this survived fifteen rounds.
  Nothing to decide here.

- R16-R77 (summary) - sixty-two rounds shipped without an entry here; this one
  catches the file up. Rough shape of the work:
  - R16-R29: the Operator got a body that can be taken, be lost to, leave
    audibly, and the game gained a real round boundary (win, lose, restart).
  - R30-R49: per-round state stopped leaking across restarts; the acquisition
    math (how a coinage burns) was measured against real sessions; a
    permanent soak test was built after three straight rounds shipped defects
    a soak would have caught.
  - R50-R58: Entity #4, the Supervisor (punishes silence), designed, measured,
    built, and given its own remote, HUD panel, and a bar that actually moves.
  - R59-R77: the evidence itself came under audit - the soak was found to be
    testing a different game than the one shipping (no seed, wrong capture
    model, missing systems), a log-recovery incident (LOOP_LOG.md itself was
    silently emptied by its own "record the commit" step for 33 rounds, R53),
    six mutation-testing sweeps across the whole game, and the first piece of
    R6 (Lexicon persistence) - the save FORMAT, proven to round-trip through
    real JSON, with no DataStoreService call yet.
  Full detail for any of this is in LOOP_LOG.md, which outranks this file and
  is searched by round number (e.g. "## R54").

- R78-R116 (summary) - catching this file up again. Nothing here needs you
  except where it says so.
  - R83-R92: players can no longer dodge the monster by respelling a word
    (leetspeak, s-t-r-e-t-c-h-i-n-g, spaced letters), or by switching between
    singular/plural/past tense ("wires", "knives", "stopped", "batteries").
    Ordinary chat was re-checked after every widening: 0 of 45 everyday lines
    trip a secret (a standing test, R91).
  - R93-R94: every line of text a player can read was scanned for giveaways.
    Two of the Operator's own lines say "number" -- filed below as a question.
  - R95: those matching rules had made a worst-case chat line cost 120 ms on
    the server; now 4.6 ms (faster than before they were added).
  - R97-R103: planted-bug sweeps of every module. About 20 places where a bug
    could hide unnoticed now have tests. No game bugs were found.
  - R104-R116: the server script held logic no test could run -- the loss
    condition, the silence punishment, capture, keypad rules, room positions.
    All of it moved into testable modules. Doing so exposed that the soak
    simulation had been measuring hand-copied versions that had drifted
    (R111, R112); the corrected figure is filed under the R54 question below.
  Still owed and only possible in Roblox Studio (blocked on this machine): a
  first playtest -- parts anchored, the world builds without error, and how
  any of it FEELS.

## Open questions — filed by the loop, waiting on you

> **R124 - the loop has converged on everything it can do alone.** Every
> module is swept, every piece of logic that can run headlessly does, and
> every kind of on-screen text is scanned. What would unblock real progress,
> roughly in order of value:
> 1. **A first Studio playtest** (blocked on this machine): does the world
>    build, are parts anchored, and above all how does it FEEL.
> 2. ~~R93 + R122~~ answered: station labels renamed (R126), both station
>    instructions reworded (R127-R128), the Operator's "number" lines reworded
>    (R129). No on-screen text gives a secret away now.
> 3. ~~R85~~ answered: the middle net (R130). 11 of R85's 13 missed paraphrases
>    are plain now; `run away`, `wire` and a bare `line` stay free by choice.
> Anything you write under "## Next" above outranks all of this.

Nothing below blocks the build; each is either a feel question Studio would
answer (device-blocked all session) or a design choice with real trade-offs on
both sides. Full detail for each is in LOOP_LOG.md at the round named.

- **R21 - does being caught in a corner read as unfair?** The Operator's reach
  covers 66% of a room's floor by radius; the corners are further. Feel
  question.
- **R36 - does deferring a call read as patience, or as ignoring you?** Same
  category as R21.
- **The stemming pair - RESOLVED in R85/R86, nothing left for you here.**
  Plain words in the plural are understood (35 of 35), and a burned multi-word
  coinage still works in the plural ("the blue wires" for "blue wire"). No
  suffix rule had to be chosen: a match on any reading of a word counts.
  Irregular plurals (leaf/leaves) still slip; that needs a word list, not a rule.
- **R46: ANSWERED (2026-09-16) -- "build 5b". Done in R131.** Heat is now
  forgotten once per round (`Config.CoolPerRound = 0.32`) instead of per
  second. Measured: a codeword said about twice before each solve is understood
  in its 4th round at any pace, ordinary chat is left alone, and a retired word
  is safe again next round. It depends on how the group talks (once per solve:
  never learned; a third time at the press: burns in round one). The three
  dials this entry named were each measured and none gives four rounds alone.
  Want it harsher or gentler? 0.30 gives 3 rounds, 0.34 gives 5.
  **Correction (R132 playtest):** "4th round" is when the PANEL turns red. The
  round-start cool drops the word back under the line before it is next said,
  so the Operator first actually comes for it around its 9th round. Top of the
  playtest backlog (PLAYTESTS.md PT1); being fixed in the next FIX round.
- **R50-51's boolean-guards-hiding-a-degree family, including
  `anyFinishable`'s margin.** Several yes/no checks in the suite (is the round
  finishable, is the hum audible) may be hiding an unasked question of DEGREE
  (finishable by how much, audible how loud) rather than kind.
- **R54 - three questions from building the Supervisor:** whether the
  corridor should be a place silence goes unpunished (it currently is, by
  omission); whether `SpeakEvery` (45s) is the right pressure; whether the
  Supervisor needs a body distinct from the Operator's.
  *R112 correction for the pressure question:* the soak had been counting 28
  Supervisor calls in a normal session; 7 of those chased players already
  caught (its copy of the capture step never told the Supervisor to forget
  them; the real server always did). The true figure is **21**. The other
  numbers here (225 corridor misses, 21 of 28 rounds lost) re-measured the
  same after R110-R112.
- **R59/R62 - two numbers, not decisions:** a silent player standing in the
  corridor is unreachable by the Supervisor 225 times in one measured
  session; a group with one quiet member in four loses 21 of 28 simulated
  rounds. Whether either number is a problem is a balance call.
- **R63 - a room somebody gives away while the Operator is already busy is
  silently dropped, never visited.** Keep it as decoration, take it up on
  arrival instead of only when idle, or drop the queue and let the newest
  giveaway win.
- **R73 - what counts as "the same group" for Lexicon persistence to key on**
  across separate server instances: a private-server code, a passphrase, or
  Roblox's friends graph. The save format itself does not depend on the
  answer.
- **R77 - `Layout.reach()` and `Layout.cornerDistance()` have no production
  caller** (superseded by room-based capture, R23). Delete, keep as a
  documented primitive, or repurpose for a future entity.
- **R83 - does a word read backwards count as shared context?** Players can no
  longer dodge the Operator by spelling a giveaway out (`j a c k`), leeting it
  (`j4ck`) or stretching it (`jackkk`); those were beating it 30 times out of
  30. Reversal (`kcaj`) was left alone on purpose: it is closer to a cipher two
  players agree on than to a typo. Catch it too, or leave it as a trick a group
  can discover?
- **R85: ANSWERED (2026-09-15) -- the middle net. Done in R130.** Asked in
  chat as middle / wide / leave it; the question was interrupted and you said
  "continue", taken as the recommended middle. Plain now: `cable`, `phone line`,
  `circuit`, `electrical`, `doorway`, `stairwell`, `backdoor`, `phonebook`,
  `take cover`, `crouch`, `underneath` (11 of R85's 13 misses heard, from 0).
  Left free on purpose: `run away`, `wire` and a bare `line`, with no
  prefix/suffix matching (`support` is still not the port). Want the wide net,
  or a word back out? Each is one word in `Round.luau`; `tests/heuristic.luau`
  lists what stays free. Not decided by this: the un- prefix (`unplug`) and
  irregular verbs (`left`, `took cover`), which would need word lists.

- **R93: ANSWERED (2026-09-14) -- reword them. Done in R129.** `greeting`
  ("Number, please.") and `givingUp` ("I'll try that number again later.")
  gave the jack away when quoted. They are now "Operator. Go ahead, please."
  and "I'll try that call again later.", checked clean, and the test no
  longer allows ANY Operator line to give a secret away.

- **R122: ANSWERED (2026-09-14) -- rename them. Done in R126.** The prompts
  that read "Directory", "Switchboard" and "Breaker" each gave their own
  secret away when read aloud. They are now "Card Index", "Exchange Desk" and
  "Cutoff" (verbs unchanged: Read, Patch, Throw), each checked clean against
  the Operator's vocabulary, and the test no longer allows ANY label to give a
  secret away. Prefer different words? Any name works as long as
  `tests/wiring.luau` stays green.
