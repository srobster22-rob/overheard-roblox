# OVERHEARD: min-maxer playtest (r140)
(Saved by the main loop from the agent's returned text: the environment blocked the subagent from writing this file itself.)

All four players played blind: no source, tests or docs, only the tools/play command. Build 818fb92.

## Five-line summary
1. The game is solved: type only the two-digit codes, read the station from seat order (the deal is always one of four rotations), and have everyone in the lobby before the last line. The Operator never moves.
2. Across 16 rounds in 5 sessions (13.5 stepped minutes) 15 won. The min-max team won 13 of 14; the one loss was a mistimed Supervisor filler, not the monster. A survey bot using the same protocol won 25 of 25.
3. Fastest win 17.2 s (two players fed to the Operator on purpose; "2 of 2 still free" still counts as a win); fastest 4 of 4 is 31.8 s, and every clean round lands exactly there.
4. Exploits: numbers are never heard, a word glued to its code ("door48") is never heard, one "." satisfies the Supervisor, taken players cost nothing and can still steer the Operator by speaking, and the learner is inert if each phrase is said once.
5. Verdict: the learning monster can be ignored by any team with a protocol. It only bites casual teams that repeat a word ("archive" reached 68% across two rounds and took 2 players), and even they get told they won.

## 1. Sessions
| File | Seed | Rounds | Result | Stepped time | How it was played |
|---|---|---|---|---|---|
| s03_silent_lobbyrush.txt | 7 | 1 | W 4/4 | 0.8 min | no chat at all; codes entered as if passed by voice |
| s05_match_seed5_digits.txt | 5 | 6 | 6 W (five 4/4, one 2/2 speedrun) | 3.9 min | digits only; the enterer finds the station by trial |
| s06_match_seed3_glued.txt | 3 | 4 | 3 W, 1 L | 3.8 min | station word glued to the code (board26) |
| s07_control_seed11_natural.txt | 11 | 2 | 2 W (2/2 and 1/1) | 1.7 min | control: a team that talks normally |
| s08_match_seed12_seatcode.txt | 12 | 3 | 3 W 4/4 | 3.3 min | seat code: digits only, station read from seat order |
| Total | | 16 | 15 W, 1 L | 13.5 min | |

- Partial experiments s01_recon, s02_silent, s04_plain_naming left rounds unfinished on purpose. probes\ holds 454 throwaway sessions (vocabulary, timings, the learner, the Supervisor, wrong codes), built by probe.ps1. Survey bot autoplay.ps1 played the seat-code protocol 25 rounds on seeds 9, 20, 42, 99 and won all 25, each 4/4 in 31.8 s, the Operator never moving.
- Unscripted: each round's moves were written only after its deal was on screen.

## 2. Measurements
| | Min-max rounds (A, B, D, s03) | Control team (C) |
|---|---|---|
| Rounds won / lost | 13 / 1 | 2 / 0 (the win message hides the losses) |
| Players taken | 4 in 14 rounds (2 fed on purpose, 2 from a Supervisor slip) | 5 of a possible 8 |
| Supervisor calls | 2 | 0 |
| Times the Operator moved | 3 (one lure, two Supervisor calls) | 4 |
| Highest Lexicon entry | 25%, never understood | "archive" at 68%, understood |
| Did the learning cost anything? | Never | Yes: 2 players in round 2 |
Fastest win 17.2 s (2 of 2, two players fed on purpose); fastest 4 of 4 31.7-31.8 s (three walks one after another plus the 10 s ring).

## 3. How the Operator works (measured by experiment)
- Hears fixed word lists for four concepts per seed. Board room (jack_number): board(s), board room, switchboard, jack(s), plug(s), number(s), cable, socket. Archive (breaker): breaker(s), switch(es), lever, fuse(s), fusebox, power, circuit, electric. Lobby (exit): door(s), doorway, street, exit, out, outside, leave(s)/leaving, escape, "way out", "front door" (and "stairs" on seed 3). The fourth concept depends on the seed and points at the archive: directory (book(s), ledger, directory, phonebook, list, names) or hiding (hide, hiding, lock(ed/er), closet, under, cabinet, behind).
- Never hears: any number (digits or words), the panel's own nouns (patch, caller, cutoff, latch, night latch, desk), "archive" and "lobby".
- Reading: capitals, punctuation and spaced letters ignored ("not the door" calls it: no negation); number-for-letter spellings heard (d00r, b0ard); a hyphen splits ("switch-board" goes to the archive). Not heard: words glued to digits (door48, board88, 88board), dropped vowels (dr, brd), stretched spellings (doooor), misspellings (bord, fuze), joined words (boardroom).
- Movement: sits still until a heard word, a Supervisor call, or the ring; never patrols; reaches any room in 6.2 s from rest; takes everyone in the room plus anyone walking in over the next 20 s; a new word while it holds a room pulls it out at once; a word while walking is queued. A player's walk takes 7.2 s and they count as in the old room until they arrive, so nobody can escape a named room.
- The learner: every message within 20 s before a successful entry adds up to 25% to each word and pair, credited to that station's concept; at 60% a phrase is understood and stays so for later rounds; below 60% phrases fade at the round's end (50% → 18%, 25% → gone). A phrase said once per round is harmless forever.
- The Supervisor: "say something" at 30 s of silence, the call at 45 s, per player; the Operator goes to the silent player's room; any single character counts as speaking.
- The ring: 10 s after the last line; if every free player is in the lobby at that moment the round is won on the spot; otherwise the Operator heads for the lobby, and the door closes 45 s after the ring.
- Wrong codes: two misses per station are free; a wrong third try jams that station 20 s, then 40 s.
- The deal: always one of four rotations; the seat after the empty one holds the board, then the cutoff, then the latch; Ana and Bo start in the board room, Cy and Dee in the archive; nothing gets harder over 10 rounds.

## 4. The dominant strategy: seat code plus lobby pre-stage
Won 13 of 14 rounds, 38 of 39 counting the survey bot. Code holders type only their two digits; the seat order tells the station. Board and cutoff are entered at once from the starting rooms; three walk to the lobby and one turns the latch; the fourth arrives inside the 10 s window; the ring finds everyone in the lobby and the escape phase never happens. Every player types one character within each 45 s. Nothing is heard or learned: the Lexicon stays empty and the Operator never moves.

## 5. Exploits (each with reproducing lines)
- E1 No words at all (seat code), s08 round 1: `seed 12` / `Ana: 37` / `Bo: 15` / `Cy: 38` / `Bo enters board 37` / `Dee enters breaker 15` / `Ana goes to lobby` / `Bo goes to lobby` / `Dee goes to lobby` / `Ana enters latch 38` / `Cy goes to lobby` / `wait 4` → [31.8s] ROUND WON: 4 of 4.
- E2 Stand in the lobby and turn the latch last: the win is checked at the ring, so the Operator's trip never starts.
- E3 Glue the station word to the code: `Cy: door48` is not heard; `Cy: door 48` is.
- E4 One character keeps the Supervisor away (`Ana: .` every 40 s), and nothing ends a stalled round.
- E5 Feed two players for a faster win: players taken don't count at the ring (17.2 s, "2 of 2 still free").
- E6 Taken players can still steer the Operator by speaking (Ana, taken at 6.2 s, sends it to the archive at 7.0 s).
- E7 Starve the learner by saying each phrase once (25%, gone next round).
- E8 Trying codes never needs the station said: two wrong tries are free.
- E9 The game never checks that a code was said (a silent team won 4 of 4): with voice chat or Discord the mechanic is bypassed.
- E10 The screens hand over the answer key: "Secrets it listens for: 4", the trace names the concept and confidence, and the Lexicon shows which phrases are near 60%.

## 6. Samey / confusing / broken
- Samey: all ~55 deals had the same shape; once solved, every round is the same 12 commands ending at 31.8 s; no escalation, score or end; a careful team never hears the monster.
- Confusing: `next round` typed mid-round silently forfeits it (tool); a refused walk still costs 7.2 s and prints "walks from" first; the Lexicon is noisy and often wrong (35 entries from one round of chat, garbled glued fragments, chatter credited to the wrong room); the hum is the same for everyone and gives no direction; hearing quirks ("switch-board" → archive, "not the door" calls it, everyday words like under/behind/out/list/number call it).
- Broken (design): numbers can't be heard, so typing only digits solves it; losing players costs nothing ("ROUND WON: 1 of 1" scores like 4 of 4); punctuation satisfies the Supervisor; the Operator is faster than a walk, so every slip is certain capture; the harness runs walks one after another.

## 7. Best moment
The control team, s07 round 2: "archive" had carried over at 18% and was said twice more, reaching 68%. Then:
```
[  40.8s] Dee: "ok leaving the archive"
[  40.8s]    >> THE OPERATOR UNDERSTOOD 'exit' (100%) and is walking to the lobby room
[  40.8s]    >> THE OPERATOR UNDERSTOOD 'breaker' (68%) and queues the archive room
[  48.2s]    >> "Hold the line, please." On the line now: Ana
[  67.0s]    >> it gives the room up. "I'll try that call again later."
[  79.8s]    >> "Hold the line, please." On the line now: Ana, Cy, Dee
```
The learned word came back 40 s later, after the team watched the monster leave: the only time the learner showed real teeth.

## 8. Verdict
The learning monster can be ignored by any team with a protocol: words are optional (digits carry the codes, seat order carries the stations), and a protocol never repeats a phrase. It creates one decision, "how do we name the station?", with a dominant answer: don't. Changes that would make the learner matter: hear numbers or its own codes; ignore digits when hearing (door48 counts as "door"); shuffle the deal and the starting rooms; count taken players in the result; require a real word to satisfy the Supervisor; let the Operator move on its own sometimes, so silence isn't safe.
