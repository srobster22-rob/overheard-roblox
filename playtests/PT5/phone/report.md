# PT5 — phone players (rotated after PT1 first-timers, PT2 returning, PT3 min-maxer, PT4 struggling) — build 39c2fd6

Blind, unscripted, stepped clock, text only. Four casual friends on phones: messages of 3-6 words, no punctuation, gaps of 2-4 s, reading only the top of their own screen. Seed 11, 7 rounds, 438 s stepped (about 7.3 min): won 5 of 7, 12 taken, 1 Supervisor call, 0 invented-word catches. From round 4 the group sent codes one digit per message, and the Operator never moved on its own again.

## Rounds
- R1 lost at 32 s. Codes read out in plain words, all understood (`[3.0s] Ana: "cutoff 85 someone do it"` → `UNDERSTOOD 'breaker' (100%)`); Cy and Dee taken at 9.2 s. `"it said my number"`, `"my number changed"` and `"ana its 3 then 1"` ("Three one") all read as the board. All four taken.
- R2 lost at 112.8 s, 1/3 restored. `[45.0s] Ana: "dont say ur numbers"` → jack_number; Ana and Bo taken at 51.2 s. It does arithmetic (`"90 plus 2"` → "Nine two", `"8 times 8"` → "Six four"). `"four oh"` got past it and Dee restored the latch at 89.0 s; it arrived at 92.8 s to an empty room. `[100.0s] Cy: "dee put one five here"` → "One five"; Dee's entry refused at 103 s ("that code was overheard"). `"it herd run"` at 113.0 s, 0.2 s after they were taken.
- R3 won, 2 of 2 free. `[125.0s] Ana: "no numbers ok"` → jack_number; Ana and Bo taken at 131.2 s. Then one digit per message (`"dee do the flippy"`, `"3"`, `"8"`); none caught; all three restored by 179 s.
- R4, R5, R7 won 4 of 4. The same digit-per-message method (`"4"`, `"again"`, `"big desk"`, `"flippy"`); the Operator never moved.
- R6 won, 2 of 2 free. Ana had nothing to do and stayed quiet: `[352.0s] THE SUPERVISOR put a call through to a silent player`; Ana and Bo taken at 358.2 s.

| Round | Result | Taken | Supervisor | Plain-talk catches | Invented-word catches |
|---|---|---|---|---|---|
| 1 | lost | 4 | 0 | 6 | 0 |
| 2 | lost | 4 | 0 | 7 | 0 |
| 3 | won | 2 | 0 | 1 | 0 |
| 4 | won | 0 | 0 | 0 | 0 |
| 5 | won | 0 | 0 | 0 | 0 |
| 6 | won | 2 | 1 | 0 | 0 |
| 7 | won | 0 | 0 | 0 | 0 |

Invented words: learned but never acted on (`"again" 40%`, `"again" = 11 15%` under Cutoff, `"flippy" 11%`). The lexicon mostly resets each round (round 4 started empty).

## Felt samey
Same room layout, same three panel sentences, one player with "nothing on your line"; once the digit-per-message method was found every round was the same relay.

## Confusing
1. Talking about numbers calls it: `"it said my number"`, `"my number changed"`, `"dont say ur numbers"`, `"no numbers ok"` were each understood as the board; two cost Ana and Bo (51.2 s, 131.2 s).
2. Inconsistent disguises: `"four oh"` ignored, `"one five"`, `"two seven"`, `"90 plus 2"`, `"3 then 1"` caught; nothing says why.
3. Taken for someone else's words: Cy and Dee taken at 9.2 s because Ana read out her code (`"wait im stuck"`).
4. Codes change silently: a heard code is replaced and the holder just sees a new number; `"my number changed"` then called the Operator.
5. The Supervisor line names nobody; Bo was taken for standing next to Ana (`[383.0s] "wat happend to us"`).
6. The lexicon panel is unreadable at phone speed (`-> counts as a number | "again" = 11 15%`).

## Broken
- The lexicon files words under the wrong station when two stations are restored about a second apart: the first takes all the recent chat and the second learns nothing. repro_lexicon_misfile.txt (breaker first: "big desk" under Cutoff); repro_lexicon_misfile_swapped.txt (board first: "flippy" under Exchange Desk). Also rounds 4, 5 and 7 of s1.txt.
- Balance: one digit per message defeats the Operator completely (never caught in 5 rounds, never learned).
- Names learned as station words (`"dee" 11%`, `"ana" 14%` under Cutoff).
- Minor: `evry1` stored as `"evryi"`.

## Best and worst
- Best: round 2, `"four oh"` got past it, `[89.0s] Dee restores the latch line.`, Cy and Dee out of the lobby at 92.5 s, `[92.8s] it has ARRIVED... waiting by the Night Latch` to an empty room: escaped by 0.3 s.
- Worst: `[125.0s] Ana: "no numbers ok"` → `UNDERSTOOD 'jack_number' (100%)`, the third round running where the group's own safety reminder got two of them taken.

## Phone
What they missed or could not act on in time:
1. The silence warning (`silence: say something`, then `SILENT LINE - TRACED`) sits on the 3rd or 4th line of the panel; the call came at 352.0 s and it arrived 6.2 s later.
2. The read-back (`"One five. I have that party for you."`, `is walking to the board room`) at 100.0 s left 12.8 s; the phone reaction (`"it herd run"`, 113.0 s) was 0.2 s late.
3. The spent-code notice is only in the event trace; the holder's panel just shows a new number, and Dee typed the old one at 103 s.

The one change that would help most: "IT'S COMING TO YOUR ROOM" and "SILENT LINE, TALK NOW" on line 1 of the affected players' panels, with a countdown. Every player taken after round 1 was taken on information below the first two lines.

Would they play again tomorrow? Probably not: rounds 1-3 were tense and funny, but after the digit-per-message method the Operator never moved on its own for four rounds, and the only danger left was forgetting to talk.
