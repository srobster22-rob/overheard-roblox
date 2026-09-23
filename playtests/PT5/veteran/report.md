# PT5 — genre veteran (DOORS / 99 Nights / Phasmophobia) — build 39c2fd6

Blind, unscripted, stepped clock, text only. 13 rounds over 2 seeds, 10 won. "By round 4 the game was solved. After that, the Operator only moved when one of us slipped."

## Sessions
**s11.txt** (seed 11, 8 rounds, 0-277 s stepped, about 4.6 min)
- R1 lost, 4 taken. Plain talk; every line heard (`"ok mine says the red lever thing, eighty five"` → `UNDERSTOOD 'breaker' (100%) ... "Eight five..."`, code spent). A made-up word with the number (`"pineapple one five"`) was still heard; reversed digits worked (`"banana 39"`). A decoy (`"the exit door, the night latch..."`) parked it on the exit and the group walked in: `[20.8s] On the line now: Ana, Bo, Cy, Dee`.
- R2 lost, 4 taken. All three lines done in 6 s (addressee name + reversed digits), then `Ana: "out out out"` → `UNDERSTOOD 'exit'`, all four taken at 43.2 s.
- R3 won, 2 taken. `Dee: "Cy you do mine, 19"` → `UNDERSTOOD 'jack_number' (62%)`; "mine" had been learned in R1 (`"mine" 63% understood`).
- R4 won, 0 taken. Flawless in 16 s; the Operator never moved.
- R5 won, 0 taken, 1 Supervisor call (Bo AFK 45 s). Ana and Bo walked out; it reached an empty room at 165.2 s. Dee's decoy (`"the cutoff breaker in the archive dropped"`) sent it to the archive while three walked past it to the board.
- R6, R8 won, 0 taken. Rote; nothing moved.
- R7 won, 2 taken. The latch code was 11 (a palindrome, so reversing hides nothing); `"the loneliest number, twice"` was caught on "number"; `[237.2s] On the line now: Ana, Bo`.

**s42.txt** (seed 42, 5 rounds, 0-143 s stepped, about 2.4 min)
- R1 lost, 4 taken. The cipher collided: Ana's 29 reversed is Dee's live 92, and `Ana: "Bo 92 right here"` → `UNDERSTOOD 'exit' (100%) ... "Nine two."`; pre-planned walks marched into the lobby.
- R2, R3 won, 0 taken. A letter cipher, A=1 to J=0, written glued (`"Bo: GF, here"`, `"Cy, HA"`); never heard.
- R4 won, 0 taken. Riddles (`"fingers on one hand, then days in a week"`); it began learning (`-> counts as a number | "hand" = 57 25%`). `"5 and then 9 at the front"` was caught (on purpose, as a test); Bo decoyed it while Ana and Bo walked past.
- R5 won, 0 taken. "hand" reused, not caught: the lexicon had faded between rounds.

Probes: probe42.txt (a holder cannot key their own code; the Operator gives a room up after 20 s); probe_guess.txt (a wrong code summons it; two wrong codes jam the line for 20 s).

## Numbers
- Rounds won 10/13 (6/8 on seed 11, 4/5 on seed 42).
- Taken: seed 11 4,4,2,0,0,0,2,0; seed 42 4,0,0,0,0 (16 total). Every take after R2 came from a player slip.
- Supervisor calls 1 (seed 11 R5); clean rounds last 6-16 s and the trace fires at 45 s of silence.
- Invented words understood twice ("pineapple", seed 11 R1, took nobody; "mine", seed 11 R3, took 2). "hand" learned as a number at 25%, never understood. "front", "far", "tomb" never above 18-25%.

## Felt samey
- Same layout every round: Ana and Bo in the board room, Cy and Dee in the archive; three 2-digit codes, one player with none.
- The solution never changes: two same-room hand-offs, one walk to the lobby, a 10 s ring. Round 8 looked like round 1; no escalation.
- Downtime is longer than play: 14 s intermission plus a 10 s ring against about 6 s of action.
- The Operator repeats the same lines ("I have that party for you", "Go ahead, caller").

## Confusing
1. Nothing says where the stations are; learned by leaking and watching where it walked, or from `Dee's code at the latch is refused: not at that station`.
2. `Secrets it listens for: 4`, but only 3 codes ever appeared.
3. The lexicon files words under the wrong station: Dee's breaker decoy (understood as 'breaker') shows as `-> Exchange Desk | "archive" 18% | "cutoff" 18% | "dropped" 18%`; Bo's board decoy as `-> Night Latch | "call" | "operator" | "patch" | "please"`; "pineapple" (the breaker word) under Exchange Desk. Words seem filed under whichever line is restored next.
4. The lexicon is hard to read: fragments and name pairs (`"gett"`, `"oth"`, `"fing"`, `"lett"`, `"cy 67"`, `"dee" 25%`); nothing says what 18% or 25% means.
5. `the lobby is not safe yet: wait for it to walk off` gives no duration (a probe showed it leaves after 20 s).
6. `ROUND WON: 2 of 2 still free got out` feels the same as a flawless win; taken players carry no cost. The screen says `ROUND RESTORED` where the trace says `ROUND WON`.
7. `The door is open and it is coming for the lobby.` is followed instantly by the win; expected a final chase.
8. Travel times: 6.2 s from idle, 12.8-13.0 s room to room, unexplained.
9. "the hum: you can hear it" is the same for every player and gives no direction.

## Broken
The lexicon misfiling in Confusing 3 (s11.txt, Dee's line at 171.0 s; s42.txt, Bo's line at 97.0 s).

## Best and worst
- Best: the cipher collision, seed 42 R1: `Ana: "Bo 92 right here"` → `"Nine two. I have that party for you."`, the group's own trick turning her code into a teammate's live one ("the only real 'oh no' of the night"). Runner-up: seed 11 R5, the decoy sending it to the archive while three walked past.
- Worst: seed 11 R4, `[84.0s] ===== ROUND 4 =====` to `[100.0s] ROUND WON: 4 of 4`, the hum silent throughout. Solved.

## Versus DOORS
The exit moment. In DOORS the end is a Seek chase: lights flicker, eyes on the walls, a sprint and a door chosen under pressure, the reason you queue again. Here, once the lines are through you stand silently in the lobby for 10 s, the trace says "it is coming for the lobby", and you win on the same tick. The idea (a monster that learns your group's slang) is better than anything DOORS has, but once known, silence plus a cipher means it never shows up.

Would this group come back tomorrow? Probably not as a regular game: the lexicon forgets between rounds and never learns reversal or letters, there is no threat independent of chat and no escalation, and a group on Discord voice bypasses chat entirely. One more try if later rounds added stations or rooms, or the Operator caught cipher patterns.
