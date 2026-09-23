# OVERHEARD playtest: the genre veteran (r140)
(Saved by the main loop from the agent's returned text: the environment blocked the subagent from writing this file itself.)

Persona: a DOORS / 99 Nights veteran playing a first night with three friends, typing every line for all four players (Ana, Bo, Cy, Dee). Build: tools/play at commit 818fb92; session 1 replays identically. Played blind: never opened, listed or searched the repo; ran only the play command.

## Five-line summary
1. Played: 10 rounds unscripted over about 9.2 stepped minutes: seed 7 had 6 rounds (won 4, lost 2), seed 21 had 4 (won 3, lost 1). 19 of 40 player-rounds ended "on the line"; the Supervisor put 3 calls through and 2 words were burned ("say", "pizza").
2. Best: talking is both required and deadly. Our own DOORS jokes, rule explanations and complaints summoned the Operator. Teammates already caught acted as bait and won a round. Burned slang is the best idea in the game, but it fired once in 10 rounds.
3. Samey: the same 3 rooms, stations and spawns every round, and only 4 role layouts. By round 3 both groups had a routine (name plus digits, filler chat, everyone at the exit) that switches the Operator off, and each round became a 39-second chore. A 15-round probe showed no escalation and no end of night.
4. Broken: you get caught in the room you already left. A caught player's refused walk burns about 7 s of everyone's clock, which cost a round. The Lexicon shows duplicate words with no label, every station's refusal says "patch it", and the play tool can't move two players at once.
5. Verdict: one more night yes, a third no. It needs a Lexicon that persists across the night, new things after round 3, a real race during the ring, and a hum that tells you where the Operator is going.

## Sessions
Played unscripted: every line was written after reading the previous run's trace and screens.
- Session 1 (seed 7, session1.txt): a loud group that read its panels out loud and joked about DOORS. 6 rounds (4 won, 2 lost), 0:00 to 5:33 stepped. A refusal taught them the relay rule; "say" got burned from reading panels aloud; round 2 lost by explaining the rules with trigger words; a terse routine found in round 3; round 4 lost to the Supervisor when Dee went AFK; rounds 5 and 6 won with junk chat and a decoy.
- Session 2 (seed 21, session2.txt): a careful group that began in total silence. 4 rounds (3 won, 1 lost), 0:00 to 3:40. The Supervisor punished their silence at 0:45; they invented bait-calling by caught teammates; found the keypad can't be brute-forced; played rounds 3 and 4 in their own slang until "pizza" was burned and turned on them.
- Totals: 10 rounds, about 150 chat lines, 553 s (about 9.2 stepped minutes). Furthest point: round 6.
- Not play: probe_rounds.txt ran 15 silent rounds to check whether a night ever ends or changes (it does neither), plus six minimal repro files.
- Caveats: typing costs 0 s on the stepped clock (a real group would take 15-25 minutes to type 150 lines); the play tool moves one player at a time, so a four-player regroup costs about 29 s here versus about 7 s live; player screens never show where the Operator is or what it heard, so the event trace was treated as what players see and hear.

## Metrics
| Round | Result | Got out | Taken | Supervisor calls | Words understood | Burn | Length |
|---|---|---|---|---|---|---|---|
| S1 R1 | WON | 2 of 2 free | 2 | 0 | 12 | "say" | 45.0 s |
| S1 R2 | LOST | 0 | 4 | 0 | 4 | – | 34.3 s |
| S1 R3 | WON | 4 of 4 | 0 | 0 | 0 (never moved) | – | 39.0 s |
| S1 R4 | LOST | 0 | 4 | 2 | 0 | – | 64.3 s |
| S1 R5 | WON | 4 of 4 | 0 | 0 | 0 (never moved) | – | 39.0 s |
| S1 R6 | WON | 4 of 4 | 0 | 0 | 1 (decoy) | – | 39.0 s |
| S2 R1 | WON | 2 of 2 free | 2 | 1 | 3 | – | 90.8 s |
| S2 R2 | WON | 1 of 1 free | 3 | 0 | 6 | – | 39.0 s |
| S2 R3 | WON | 4 of 4 | 0 | 0 | 0 (never moved) | – | 39.0 s |
| S2 R4 | LOST | 0 | 4 | 0 | 3 | "pizza" | 25.0 s |

- 19 captures: 11 caused by the group's own words (3 of those typed by teammates already caught), 6 by silence (the Supervisor), 2 players arriving late to the open door.
- Supervisor calls: 3, all after 45 s with no chat; none in any round where the group kept typing.
- Words understood: 29 times. Built-in triggers never shown in the Lexicon: "door", "doors", "out", "leave" (exit, the lobby); "number", "numbers" (the board room); "name", "names" ('directory', the archive); "breaker" (the archive). Did nothing: "lobby", "latch", "cutoff", "archive", "garage", bare digits.
- First understood what to do: S1 relay rule 0:00, threat 0:12, door rule 1:29, silence rule 3:14 (full picture only by round 4); S2 relay rule 0:00, silence rule 0:45, "it hears words not noise" 0:52, bait-calling 1:13.
- First fun: S1 0:35 (Bo's run for the latch); S2 1:13 (the "breaker breaker breaker" bait).
- Solved: both groups found the routine in round 3; every round played that way took exactly 39.0 s, 29 s of it walking.

## Versus DOORS / 99 Nights
- 0:00, private panel, own code refused: mixed. The refusal is a one-line tutorial, but there is nothing to explore; stations are found by guessing ("not at that station").
- 0:00-0:12, first time the monster moves (a DOORS joke understood as 'exit'): funnier and more personal than Rush's first pass, but less fair: no warning of where it goes, nowhere to hide, and its first trip can't be outrun.
- 0:07.5, first capture ("Hold the line, please."): better than spectating, but nothing explains the capture.
- The Supervisor: about equal to Hide/Seek pressure; well warned, but junk chat ("skibidi", "bing bong") beats it every time.
- The last station and the open door: worse than DOORS' Door 100 breaker puzzle or Door 50's library code under Figure. The 10 s ring is dead time once gathered in the lobby.
- The solved rounds: much worse than DOORS by doors 30-50 or 99 Nights' growing base. Round 15 is round 1 with different digits.
- The burned slang biting ("pizza"): nothing like it in either game, and better than both, but it took 13 rounds and a deliberately chatty group to trigger it.

## Felt samey
- Same map every round: 3 rooms, 3 stations, the same spawns (Ana and Bo in the board room, Cy and Dee in the archive).
- Only 4 role layouts, each a rotation of patch, cutoff, latch and nothing (seed 7 round 1 equals round 6, down to the same latch code 48).
- The routine turns the monster off: the Operator never moved in 3 of 10 rounds, and in a fourth only because they baited it into an empty room.
- The Lexicon forgets between rounds: unburned words fade 50% → 18% → gone; even burned "say" went 100% → 68% → 36% → 4%.
- Nothing escalates (15-round probe): no new stations, rooms or entities, no speed-up, no end of night, score or unlock.

## Confusing
- You can't tell where the Operator is; the hum gives one bit, the same for everyone.
- Trigger words are invisible until they get you; the Lexicon never shows built-in ones; "Secrets it listens for: 4" is never explained (3 stations; the fourth idea, 'directory', has no station).
- The Lexicon panel is unreadable: about 100 fragments after the first fix ("anyth until", "is giv", "explod i"), duplicate words with no label, an unclear "understood" threshold.
- The open door kills whoever waits for a teammate; nothing says everyone still free must be in the lobby.
- "Queues the board room" appears to do nothing, then kills much later (repro_queue.txt: a word at 0:00 took Ana and Bo at 0:39).
- "silence: your line is open" is the safe state but reads like a warning (low confidence on a lag after a walk).
- The words don't match the stations: the panel says "Cutoff" but the station is "breaker", and the Operator understands "breaker" but not "cutoff". Nothing says the latch is in the lobby.

## Broken, with reproductions
1. Caught in the room you already left: a walk only moves you when it ends (7.2 s); the Operator's first trip takes 6.2 s. repro_walk_caught.txt: `seed 7` / `Bo: numbers` / `Bo goes to lobby` / `look` → [0.0s] Bo walks... [6.2s] On the line now: Ana, Bo [7.2s] Bo is on the line and cannot walk. Happened 3 times in session 2.
2. A caught player's walk wastes about 7 s of everyone's clock: the walk is accepted and printed, the clock moves, then it is refused (repro_online_walk.txt). Cost session 1 round 2.
3. The Lexicon shows the same word twice with no label (repro_lexicon_dupes.txt: `"pizza" 25% | "pizza" 25% | "pizza 11" 25% | "pizza 88" 25%`).
4. Every station's refusal says "patch it" (repro_refusal_text.txt).
5. The play tool can't move two players at once ("Cy and Dee go to lobby" is not a command; syntax_test.txt).

## Best moment
Session 2, round 1: the two caught players volunteer as bait while the Operator sits on the board Dee needs.
```
[  66.2s] Ana: "big brain time. bo go back to dee. then me and cy yell a word so it comes back to us. we are already caught anyway"
[  73.5s] Cy: "breaker breaker breaker"
[  73.5s]    >> THE OPERATOR UNDERSTOOD 'breaker' (100%) and is walking to the archive room
[  73.5s]    Dee walks from the lobby room to the board room
[  80.8s]    Dee restores the board line.
[  80.8s]    every line is through. "Ringing your party now. One moment, please."
[  90.8s]    ROUND WON: 2 of 2 still free got out. "Your call has been completed."
```
Cy: "BAIT CALLERS lets gooo. being dead is a job in this game". Nothing in DOORS or 99 Nights gives dead players a job like that.

## Would your group play a second night?
One more night, yes; a third, no. Yes: talking is both required and deadly; caught players still have a job; brute force is blocked (a jam after two wrong codes). Not a third: by round 3 a routine switches the Operator off; nothing new arrives; burned slang mostly resets between rounds. What would change it: a Lexicon that persists across the night, something new after round 3, an Operator that comes for the lobby during the ring so the last station is a race, a hum that says where it's going, and a first trip slow enough that walking out can save you.
