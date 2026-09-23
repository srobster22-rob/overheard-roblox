# PT5 — the critic — build 39c2fd6

Blind, unscripted, stepped clock, text only. 10 rounds in two sessions, won 10 of 10, plus four probes.

## Sessions
**s1.txt** (seed 11, 6 rounds, 253 s stepped, about 4.2 min)
- R1 won, Dee taken. `"it wants 78"` → `UNDERSTOOD 'exit' (100%)… "Seven eight."`, code spent. Riddles then worked ("ate sicks", "a dozen plus three"). Dee walked into the archive after it had arrived: `[27.0s] Dee restores the breaker line` / `[27.2s] On the line now: Dee`; still `ROUND WON: 3 of 3 still free got out`.
- R2 won, 0 taken. `"grandma wants three two"` → `"Three two."`; then a riddle ("a dollar minus a dime, in cents") and a decoy ("lever lever lever").
- R3 won, 0 taken. Riddles for all three ("one less than a score", "the famous route", "a quinceanera"); two codes entered within the first second.
- R4 won, Bo taken, 2 Supervisor calls. `"is it 28 or 29 in a leap year"` → `"Two eight."`, `[146.2s] On the line now: Bo`; Ana and Dee silent until `THE SUPERVISOR put a call through to a silent player` at 168.0 s and 181.0 s.
- R5 won, 0 taken. "eighty-three" caught; `Bo: "it heard "number" again…"` → `UNDERSTOOD 'jack_number'`; "three then four" caught.
- R6 won, 0 taken. "toaster" said four times → `BURNED: "toast" now means breaker.`; `Dee: "toaster done"` then sent it to the archive.

**s2.txt** (seed 5, 4 rounds, 150 s stepped, 2.5 min)
- R1 won, Cy and Dee taken at 6.2 s (codes read out plainly). `"ninety three minus one"` (for 92) spent Dee's board code 90 (`"Nine zero."`). The Operator learned Ana's name for the breaker (`"ana" 74% understood`) and `Bo: "ana you still ok?"` sent it to the archive. Still `ROUND WON: 2 of 2 still free got out`.
- R2, R3 won, 0 taken. Solved in 8 s each; the Operator never moved.
- R4 won, 0 taken. `Cy: "the panel says it understands "front" now…"` → `UNDERSTOOD 'exit' (78%)`; `"one less than thirty"` → `"Two nine."`; "leave" pinned it to the lobby and "lever" pulled it away.

Probes (seed 5): p1_silent.txt (nobody speaks: 2 Supervisor calls, then `ROUND LOST` at 64.2 s); p2_directory.txt, p3_directory2.txt, p4_bo_ok.txt (what 'directory' is: "name", "book", and "bo ok" read as "book").

## Numbers
Won 10 of 10 (idle probe excluded). Taken per round: s1 1,0,0,1,0,0; s2 2,0,0,0 — every take from a digit or number word, or walking into its room; none from an invented word. Supervisor: 2 in s1 R4, 0 elsewhere (2 in the idle probe). Invented words understood 3 times ("toaster" twice, "front" once), catching nobody; the name "ana" understood once.

## Felt samey
All 10 rounds dealt the same layout (Ana and Bo in the board room, Cy and Dee in the archive); the board and breaker codes never need a walk, only the latch; every round ends "the door is open" then `ROUND WON` within 0-3.2 s; the Operator's lines never change.

## Confusing
1. The hum reads the same on every screen: "you can hear it" whenever it walks anywhere, "silence" when it stands still, even in your own room (s1 146.2 s: Bo's screen `the hum: silence` with it waiting in his room).
2. 'directory' is on no panel, yet `UNDERSTOOD 'directory'… walking to the archive room` after "lol bo. ok new number…" (s1 155.0 s); it reacts to "name" and "book".
3. Which maths is safe: "one less than thirty" heard as 29; "fifty five minus eleven", "three dozen minus four", "seven sevens" not.
4. A riddle can burn someone else's code: "ninety three minus one" spent Dee's 90 (s2 15.0 s).
5. Warnings trigger it: "it heard "number" again" (s1 207.0 s), "stop saying numbers" (s2 8.0 s), "understands "front" now" (s2 118.0 s).
6. The lexicon files words under the wrong station: "grandma" (the board nickname) learned for the Night Latch at 48% (s1 57.0 s); "doormat" (the latch nickname) for the Exchange Desk (s2 118.0 s).
7. "understood" without a BURNED line: "porch 68% understood", "front 78% understood"; only "toast" got one.
8. The Supervisor names no player or room; two screens showed SILENT LINE - TRACED and nothing visible followed (s1 168.0 s, 181.0 s).
9. Being taken has no stakes; `ROUND WON: 2 of 2 still free got out`; taken players back next round.
10. "Secrets it listens for: 4" never explained.

## Broken
1. Player names become station words: "ana" 74% understood as breaker; `"ana you still ok?"` sent it to the archive (s2 21.0 s). The entrant is named right before a code, so this happens in almost every group.
2. Words joined across a full stop: "bo ok" and "bo. ok" both read as "book" → 'directory' (p4_bo_ok.txt).
3. Wrong learned number: `"cards" = 93` (s2, about 15 s).
4. Harness limits: two "go to" lines walk one after the other (s1 59.0-65.0 s); a walk cannot be cancelled (s1 21.8-27.2 s).

## Best and worst
- Best: s2 21.0 s, `Bo: "ana you still ok?"` → `UNDERSTOOD 'breaker' (73%) and is walking to the archive room`, `Cy: "WAIT it went for the dusty room when you said her name"` (also Broken 1).
- Worst: s1 37.0 s, `the door is open and it is coming for the lobby.` and `ROUND WON` on the same tick: the climax never happens.

## Store review: 5/10
"The idea is great, but the Operator is easy to beat."
1. Any riddle beats the Operator: s2 R2 from `[54.0s] ===== ROUND 2 =====` to `[62.0s] every line is through` in 8 s, with no Operator line.
2. It barely learns across rounds: `"porch" 36%` at the start of s1 R5, down from 68%; a word burned only when said four times in one round (s1 234.0 s).
3. Nothing at stake and no climax: `ROUND WON: 2 of 2 still free got out` with half the team taken (s2 45.0 s); the same deal every round; no end to the night.

Store shots: only 4 moments of play plus 1 UI shot (a finding):
1. `Cy: "mine's about the night latch, it wants 78"` → `UNDERSTOOD 'exit' (100%)… "Seven eight. I have that party for you."`
2. `BURNED: "toast" now means breaker. "I'm connecting you now."`
3. `"ana you still ok?"` → `walking to the archive room`.
4. `Dee restores the breaker line.` / `every line is through` / `"Hold the line, please." On the line now: Dee`
5. The lexicon panel: `-> Night Latch | "front" 78% understood | -> Exchange Desk | "trombone" 50% | "doormat" 25%…`
