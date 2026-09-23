# PT4 critic: review and report (R145, build f679b1c)

Blind and unscripted, via `tools/play` on a stepped clock, text only. Sessions: s1.txt (seed 31, 7 rounds, 275 s) and s2.txt (seed 8, 5 rounds, 159 s). Probes: probe_loss.txt and probe_trace.txt. Nothing in the repo was edited.

## Score: 4/10

> OVERHEARD has one clever idea: a monster that hears your chat, so you have to talk in code. It also has two or three very funny moments, like when your own maths gives away a friend's code. But the Operator only really listens for plain words and numbers. After two rounds, nicknames plus "dozens" means it almost never moves, and every round is the same three codes in the same rooms. Good for one evening with friends, not a second one.

## Three reasons not to play
1. **Solved by round 2.** s1 R4 runs from `[150.0s] Cy: "dee toaster. five dozen minus two"` to `[156.0s] every line is through`, and the Operator never moves. s1 R7 and s2 R4-R5 are the same.
2. **The promised learning barely happens.** Invented words were understood on 2 lines in 12 rounds (`"grandma" 68% understood`). The Lexicon fades between rounds and fills with chat filler (`-> Night Latch | "fat" 25% | "fingered" 25% | "oop" 25%`).
3. **The threat is easy to steer and costs nothing.** Any plain word pulls it away (`[229.0s] Dee: "bait: the plugs on the big wall, operator"` → walking to the board room). Being taken still counts as a win (`ROUND WON: 2 of 2 still free got out`), and taken players are back next round.

## Store screenshots
Only 4 distinct moments were worth showing, which is itself a finding; all are text (Studio not connected).
1. The secret split: Ana's `Patch them through to 18.` / `only you can see this` beside Cy's `nothing on your line - listen for somebody else's`.
2. The echo: `"One eight. I have that party for you."` / `the board code was heard, so it is spent`.
3. Traced: `silence: SILENT LINE - TRACED`, then `"Hold the line, please." On the line now: Ana, Bo`.
4. It learned the word: `"grandma" 68% understood`, Dee's warning, `On the line now: Cy`.
5. (The same mechanic as 2.) `"bo spaghetti is four dozen and three"` → `"Four three."` spends Ana's latch.

## Rounds
- s1 R1 won 4/4: plain speech, every number read back and spent; then dozens ("five dozen" 60, "an hour minus a minute" 59) and nothing more was spent.
- s1 R2 won 4/4: room and station nicknames (kitchen/library/porch; toaster/spaghetti/bouncer), never understood; "say", learned in R1, fired it (`'breaker' (70%)`).
- s1 R3 won 2/2: silence, `[106.0s] THE SUPERVISOR put a call through`, `[112.2s] On the line now: Ana, Bo`.
- s1 R4 won 4/4 in 6 s; s1 R5 won ("two less than two dozen" heard as "Two two", a plain-word lure); s1 R6 won (Cy's "four dozen and three" spent Ana's 43); s1 R7 won 4/4 in 6 s.
- s2 R1 lost: plain speech, `[6.2s] On the line now: Cy, Dee`, Ana walked into it at 14.2 s, `[21.2s] ROUND LOST.` with no reason given.
- s2 R2 won: letter code (A=1 ... O=0) and pet names; explaining the scheme set it off twice; "leave the way out" → exit.
- s2 R3 won 3/3: `"grandma" 68% understood`, `[88.2s] On the line now: Cy`.
- s2 R4, R5 won 4/4: "auntie is thurty sevvn" passed unheard.

## Numbers
11 won of 12; taken 6 (s1 R3: 2; s2 R1: 3; s2 R3: 1); Supervisor calls 2 in play (3 more in probes); invented words understood on 2 lines (grandma), catching 1; 33 understood lines in all, 31 from plain words or numbers; 7 codes spent by hearing a number.

## Confusing
1. A wrong code says `that line is dead` (expected "wrong number").
2. `ROUND LOST.` with Bo free and 2/3 restored, no reason given.
3. The Supervisor puts through "a silent player" but every panel shows `SILENT LINE - TRACED`.
4. The hum reads the same wherever it is going, while the trace names the room.
5. Everyday words are station words: "whats the number" → jack; "read my number out loud" → exit; "should we move" / "leaves me alone" → exit.
6. Any two number words in a message are read as a code: "two less than two dozen" → 22.

## Broken
- B1. Losing is inconsistent: s2 R1 ends as soon as it cannot be won; probe_loss.txt, the same situation (Bo the only free player, holding Cutoff 64), runs 177 s until the Supervisor takes Bo.
- B2. The trace says it "is walking to the archive room" while it is waiting there (s2 8.0 s), and takes Ana at 14.2 s with no ARRIVED line; again at 37.0 s and 49.0 s.
- B3. The Lexicon files words under the wrong station (kitchen/library/porch under Cutoff; "cat", the latch word, under Exchange Desk).
- B4. Misspelled numbers pass ("thurty sevvn", "ate-tee sevvn").
- Tool: a walk runs the shared clock, so nobody else can speak while someone walks.

## Best and worst
- Best (s2 R3): `Dee: "IT LEARNED GRANDMA. its coming to us, run"` → `UNDERSTOOD 'breaker' (68%)` → `[88.2s] On the line now: Cy` → `Cy: "wait really? it only heard it like twice"`.
- Worst (s2 R1): Bo free, two lines restored, and only `ROUND LOST. "I'm sorry, your call cannot be completed as dialled."`
