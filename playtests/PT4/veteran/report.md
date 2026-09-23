# PT4 genre veteran: report (R145, build f679b1c)

Blind and unscripted, via `tools/play` on a stepped clock, text only. A player with hundreds of hours in DOORS and 99 Nights in the Forest, who knows Phasmophobia. Sessions: s1.txt (seed 11, 7 rounds, 260 s), s2.txt (seed 23, 6 rounds, 209 s), repro_hum_queue.txt. Nothing in the repo was edited.

Summary: 13 rounds, 11 won, 2 lost. By round 2 of session 1 the group had a code the Operator never broke; 8 of the 13 rounds were the same 16-second win with the Operator never moving. Both losses came from ordinary exit words ("leaving", "leave", "out") and from arriving at the lobby at the wrong moment around the ring, never from a word the group invented.

## Rounds
- s1 R1 won (33 s): paraphrasing the panel set it off (`Bo: "...patch to some number..."` → jack_number). "nine times nine plus four" got through; `Cy: "eighty minus two"` → `"Seven eight. I have that party for you."` spent the latch code. Won while running out of the lobby: `[33.2s] ROUND WON: 4 of 4`.
- s1 R2, R3 won (17 s, 16 s): digits as letters ("bee ay" = 21); the Operator never moved.
- s1 R4 won with 2 taken (70 s): silence on purpose; `[153.0s] THE SUPERVISOR put a call through` → `[159.2s] On the line now: Bo`; Ana walked into the room it was waiting in (`[168.2s]`).
- s1 R5-R7 won (16 s each); R6-R7 used nicknames (fridge, piano, mailbox).
- s2 R1 lost (12 s): `Dee: "bo is leaving..."` → exit; bait "PATCH THAT NUMBER THROUGH" only queued; it arrived in the lobby 0.2 s after Ana and Bo.
- s2 R2, R3 won (NATO letters).
- s2 R4 lost (52 s): "three nine" read back; "wait for it to leave" set it off; with 3/3 the panel said "everyone to the lobby" at 121 s; `[123.0s] the call has rung... coming for the lobby`, `[126.0s] ARRIVED`, `[127.2s] On the line now: Ana, Bo, Cy, Dee`.
- s2 R5 won (43 s): a one-digit-up code worked; `Bo: "heading out now"` → exit parked it at the latch, and the group watched a panel for 20 s.
- s2 R6 won (16 s).

## Numbers
Won 11/13. Taken per round: s1 0,0,0,2,0,0,0; s2 4,0,0,4,0,0 (one of R4's four a harness artifact). Supervisor calls: 1 in 13 rounds, only from 45 s of deliberate silence. Group-invented words understood or catching anyone: 0. None passed about 50% on the Lexicon, which empties within about two rounds; the only "understood" row was "mine" (61% → Cutoff), which never moved the Operator.

## Felt samey
Same three stations in the same rooms, same start, one player with nothing, three 2-digit codes, one walk and a 10 s ring. Once you have a code: type, type, walk, wait 10.

## Confusing
1. Won while running from "it is coming for the lobby" (s1 R1, 33.2 s).
2. "Everyone to the lobby", then the ring calls it back 2 s later (s2 R4, 121 s → 126 s).
3. The hum is not distance: it plays only while it walks; silent with it in your room (s1 R4) and 0.3 s before it arrives (repro_hum_queue.txt).
4. The Supervisor names nobody: every panel reads "SILENT LINE - TRACED"; Bo was taken though he had spoken 3 s before (156.0 → 159.2 s).
5. Bait does not redirect: "queues the board room" did nothing for 39 s.
6. No position while it walks: after "it gives the room up", no clue where it went.
7. Word triggers look inconsistent: "leaving", "heading out", "out out", "dead line" set it off; naming all three stations in one line with nicknames did not.
8. The Lexicon files words under whichever station was restored first ("mailbox" and "piano" both under Cutoff).
9. A wrong code costs nothing: you only see "that line is dead".

## Broken
- Harness: walks run one after another, so two players cannot split to different rooms at once (s2 R4, 81.0 s → 81.2 s).
- The hum is silent with the Operator in your room (s1 around 162-168 s; repro_hum_queue.txt).
- A round won mid-flight (s1 R1, 33.2 s).
- Possibly intentional: a player on the line can still set it off by chatting (s2 107.0 s).

## Best and worst
- Best: `"Seven eight. I have that party for you."`: it did the sum from "eighty minus two" and said the code back.
- Worst: s2 R4, all lines restored, the panel says "everyone to the lobby", then `[127.2s] On the line now: Ana, Bo, Cy, Dee — ROUND LOST`.

## Versus DOORS
The moment: s2 R5, twenty seconds of four people watching "the Operator is waiting by the Night Latch" until it gave the room up. In DOORS, when Rush comes the lights flicker and the sound builds; you have about 3 s to choose a closet, it screams past, and you are moving again within 10 s. The threat has a direction and a duration, and hiding is something you do. Here it is a static line on a panel: nothing to do, no sense of where it is, no timer. By minute 2 of DOORS you have met Rush; by round 2 here the group had beaten the game.

Would the group come back tomorrow? Probably not. The hook is great (it hears your slang and repeats your number back), but it never learned the group's code, so skill hit a ceiling at round 2. They would come back if it learned codes across rounds, or if codes, stations or rooms shuffled.
