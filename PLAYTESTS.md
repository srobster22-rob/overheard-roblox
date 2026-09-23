# PLAYTESTS — newest first. Bots: `lune run tools/playtest <persona> <rounds> <seed>`. Unscripted play: `lune run tools/play <session file>` (sessions and reports under playtests/).

### PT5 · R150 · personas: genre veteran (DOORS / 99 Nights / Phasmophobia), phone players (rotated after PT1's first-timers, PT2's returning group, PT3's min-maxer and PT4's struggling players), critic · build 39c2fd6
Sessions: all three played BLIND (no source, no word lists) through `tools/play` on a STEPPED clock, text only (Roblox Studio not connected: no screenshots, no sound). All three were UNSCRIPTED and wrote every chat line and move from what was on screen.
- Genre veteran: two groups, 13 rounds, 7.0 stepped minutes (seeds 11 and 42), plus two probes.
- Phone players: four casual friends, 3-6 word messages with 2-4 s gaps, reading only the top of their screens; 7 rounds, 7.3 stepped minutes (seed 11), plus two repros.
- Critic: two groups, 10 rounds, 6.7 stepped minutes (seeds 11 and 5), plus four probes.
- Sessions and reports: playtests/PT5/. R149's blind session (seed 53, 9 rounds, same rules) is kept beside them.

Headline:
- Rounds won, unscripted: veteran 10/13 (PT4 11/13), phone players 5/7, critic 10/10 (PT4 11/12); R149's blind group 9/9. Bots 5/6/5 of 7 (PT4 5/6/6).
- Players taken per round: veteran 1.2 (16 in 13; PT4 0.8), phone players 1.7 (12 in 7), critic 0.4 (4 in 10; PT4 0.5). Bots 2.5 (PT4 1.9).
- Supervisor calls per round: veteran 0.08 (1 in 13; PT4 0.08), phone players 0.14, critic 0.2 (PT4 0.17). Bots 1.7 (PT4 1.6).
- Codewords the Operator learned and used: veteran "pineapple" and "mine" understood, "mine" took 2 (PT4 0); phone players 0; critic "toaster" burned and "front" understood, 0 caught (PT4 "grandma", 1 caught). A player's NAME was understood as a station word ("ana" 74%). Bots: 7 replaced (PT4 4).
- Codes heard (R142 on): veteran 8, phone players 8, critic 13, nearly all in each group's first rounds.
- Natural chat naming a secret: 30 of 160 (unchanged). Rounds that end: all 30, and R149's 9.
- Won with the Operator never moving (R146's TRY): 12 of 30 (veteran 6 of 13, PT4 8 of 13; phone players 3 of 7; critic 3 of 10); R149's blind group 2 of 9. The TRY fails on one group: the veteran's seed-42 group, 3 of 5, with letters written glued ("GF", "HA").

Versus DOORS: the exit. DOORS ends a run with Seek: lights flicker, eyes open on the walls, and you sprint and pick a door under pressure; it is the climax and the reason you queue again. Here, once the lines are through, the group stands silent in the lobby for 10 s, the trace says "it is coming for the lobby", and the round is won on the same tick (the critic's worst moment too). The veteran: the idea "is better than anything DOORS has", but once known, silence plus a cipher means it never shows up.

Felt samey:
- Every round and seed deals the same layout: Ana and Bo in the board room, Cy and Dee in the archive, three 2-digit codes, one player with nothing. Only the latch ever needs a walk.
- Once a group has its scheme, a round is name the station, send the code, walk, enter, lobby, 10 s ring; round 8 looks like round 1. Downtime (14 s intermission, 10 s ring) is longer than play.
- The Operator's lines never change ("I have that party for you", "Go ahead, caller").

Confusing:
- Warnings call it: "dont say ur numbers", "no numbers ok", "it heard "number" again", "understands "front" now" (phone players, critic; PT4 too). Two of the phone group's warnings cost two players each.
- The hum reads "you can hear it" for any walk anywhere and "silence" while it waits, even in your room; R149's blind group was taken three times reading that silence as safe.
- Nothing says which room holds which station; groups learn it by leaking and watching where it walks. 'directory' is a station word on no panel (critic).
- Which disguises are safe: "four oh" and "fifty five minus eleven" pass, "one five", "90 plus 2", "one less than thirty" do not; a riddle can spend someone else's code ("ninety three minus one" spent 90).
- Codes change silently: the "spent" notice is only in the trace; the holder just sees a new number (phone players).
- The Lexicon: word stems, name pairs, percentages nobody can use; "understood" words with no UNDERSTOOD or BURNED line (critic; R149 blind).
- The Supervisor names nobody; a talker next to a silent player is taken.
- Being taken costs nothing; `ROUND WON: 2 of 2 still free got out` reads like a flawless win (all three).
- "Secrets it listens for: 4" with three codes (veteran, critic; PT4 too); "wait for it to walk off" gives no time.

Broken:
- (1) The Lexicon files a group's words under the wrong station. At a restore every line of the last 20 s is credited to that line, so when two lines are restored about a second apart the first takes both stations' words and the second learns nothing (phone/repro_lexicon_misfile.txt: "big desk", said about the board, under Cutoff; the swapped repro files "flippy" under Exchange Desk). All three personas hit it (veteran s11 171.0 s, critic s1 57.0 s and s2 118.0 s), as PT4 did ("mailbox" and "piano" under Cutoff).
- (2) Player names are learned as station words: "ana" reached 74% for the breaker and `Bo: "ana you still ok?"` sent it to the archive (critic/s2.txt 21.0 s); "dee" and "ana" under Cutoff (phone players). The entrant is named right before most codes.
- (3) "bo ok" and "bo. ok" are read as "book", a directory word: words are joined across a full stop (critic/p4_bo_ok.txt).
- (4) A wrong number learned: `"cards" = 93` (critic/s2.txt).
- Tool limits, not the game: two walks run one after the other, and a walk cannot be cancelled (critic s1).

Critic: 5/10 (PT4 4/10). Reasons not to play:
- (1) Any riddle beats the Operator: s2 R2 is 8 s from the round start to every line through, with no Operator line.
- (2) It barely learns across rounds: "porch" 68% fades to 36% by the next round; a word burned only when said four times in one round.
- (3) Nothing at stake and no climax: a win with half the team taken, the same deal every round, no end to the night.
Store shots: only 4 moments of play plus 1 UI shot (the "Seven eight." read-back; BURNED "toast"; "ana you still ok?" sending it off; a restore with a player on the line; the Lexicon panel). 0 real screenshots (Studio not connected).

Best moment: the cipher collision. The veteran's group reversed its digits, and Ana's 29 reversed was Dee's live 92: `Ana: "Bo 92 right here"` → `"Nine two. I have that party for you."` (veteran/s42.txt R1), "the only real 'oh no' of the night". Close seconds: the phone group's "four oh" escape by 0.3 s; the critic's "ana you still ok?" sending it to the archive ("WAIT it went for the dusty room when you said her name").

Phone players: they missed what sits below the first two panel lines: the silence warning (the call came at 352.0 s, the Operator 6.2 s later), the read-back and "walking to the board room" (reaction 0.2 s late), and the spent-code notice. The one change: "IT'S COMING TO YOUR ROOM" and "SILENT LINE, TALK NOW" on line 1 with a countdown. Would they play tomorrow? Probably not: after one digit per message, the Operator never moved on its own for four rounds.

Matrix re-scores:
- Core loop depth stays 1. Every group still found a code the listener cannot read by round 2-4: reversed digits, glued letters, one digit per message, riddles, and (R149's blind group) letters with a word between them. What changed: codes read aloud are now heard, so first rounds cost groups (the veteran lost 3 of 13, the phone players 2 of 7), and the Operator moved in 18 of 30 rounds (PT4's veteran: 5 of 13). The critic won 10 of 10.
- Differentiator stays 2. A group's own word was understood on 5 lines in 30 rounds and took 2 players (PT4: 5 lines, 1 player); a player's name read as a station word is a defect, not learning.
- Hook stays 1: warnings call it, and the first round costs a new group everything (the phone players lost rounds 1 and 2 with 8 taken) without saying why.
- Market 18.7 unchanged.

Backlog (ranked by gap value):
1. Core loop (12): every group finds a code the listener cannot read. Each scheme found so far is one encoding (reversed digits, glued letters, a digit per message, riddles, letters with a word between). The swing's next slice should read what the entrant is TOLD across the holder's messages, not one more encoding. BIG SWING candidate.
2. Differentiator (12): broken (1), words credited to the wrong station. The holder's lines belong to the holder's line (R148 already reads letters that way). FIX.
3. Differentiator (12): broken (2), player names learned as station words. The server knows every name. FIX.
4. Core loop (12): the climax lands on the win's tick and nothing escalates (veteran, critic).
5. Hook (12): warnings call it; the hum's silence reads as safe; nothing says which room holds which station.
6. Hook (12): alerts belong on line 1 of the panel (phone players).
7. Core loop (12): being taken costs nothing (owner question 4).
8. Broken (3) and (4): words joined across a full stop; a wrong learned number.
9. "Secrets it listens for: 4"; the Supervisor names nobody.

### PT4 · R145 · personas: genre veteran (DOORS / 99 Nights / Phasmophobia), struggling players (rotated after PT1's first-timers, PT2's returning group and PT3's min-maxer), critic · build f679b1c
Sessions: all three played BLIND (no source, no word lists) through `tools/play` on a STEPPED clock, text only (Roblox Studio not connected: no screenshots, no sound). All three were UNSCRIPTED and wrote every chat line and move from what was on screen.
- Genre veteran: two groups, 13 rounds, 7.8 stepped minutes (seeds 11 and 23).
- Struggling players: four 11-13-year-olds who mostly play obbies, 6 rounds, 5.3 stepped minutes (seed 31), plus four one-line word probes.
- Critic: two groups, 12 rounds, 7.2 stepped minutes (seeds 31 and 8), plus a loss probe and a trace probe.
- Sessions and reports: playtests/PT4/. R144's blind session (seed 31, 5 rounds) is kept beside them.

Headline:
- Rounds won, unscripted: veteran 11/13 (PT3 7/10), struggling players 5/6, critic 11/12 (PT3 4/6). Bots 5/6/6 of 7, unchanged since R143.
- Players taken per round: veteran 0.8 (10 in 13; PT3 1.9), struggling players 0.8 (5 in 6), critic 0.5 (6 in 12). Bots 1.9.
- Supervisor calls per round: veteran 0.08 (1 in 13, and only because the group stayed silent 45 s on purpose; PT3 0.3), struggling players 0.17, critic 0.17. Bots 1.6.
- Codewords the Operator learned and used: veteran 0 (PT3: 2 burns in 10); struggling players "lucky" understood 3 times, 0 caught; critic "grandma" understood twice, 1 caught (PT3: 1 learned catch in 5). Bots: 4 replaced.
- Natural chat naming a secret: 30 of 160 (unchanged). Rounds that end: all 31.
- New: rounds won with the Operator never moving, veteran 8 of 13 (every one a 16 s win).

Versus DOORS: Rush. The lights flicker and the sound builds; you have about 3 s to choose a closet; it screams past; you are moving again within 10 s. The threat has a direction and a duration, and hiding is something you do. Here, the same beat is four players watching "the Operator is waiting by the Night Latch" for 20 s until it gives the room up: nothing to do, no sense of where it is going, no timer. By minute 2 of DOORS you have met Rush; by round 2 here the veteran's group had a code the Operator never broke.

Felt samey:
- The same three stations in the same rooms and the same starting pairs every round and seed; one player with nothing (Dee four rounds running); codes repeat (89 and 77 came back).
- Once a group has a scheme (digits as letters, NATO words, "dozens", a relative's age), a round is type, type, walk, wait 10.
- The ending never varies. The Lexicon fades between rounds (59% → 27%) and "empties within about two rounds", so round 7 is no harder than round 2.

Confusing:
- Everyday words are station words: "number", "leave", "out", "heading out", "should we move". Telling each other the rule ("nobody say the numbers again") breaks it.
- Numbers are read across clue words and the game's own text. "two less than two dozen" is heard as 22; "four dozen and three" spends another player's 43; typing the panel's progress "2/3" spends code 23.
- "Waiting by the Exchange Desk" does not say which room that is ("whats that"). Each station has four names: prompt, command, label, and the concept id in the trace.
- The hum plays only while it walks. It is silent with the Operator in your room and silent 0.3 s before it arrives; it gives no direction.
- The way out:
  - There is a hidden 45 s door timer. The struggling players waited as the panel said and lost 1 s before arriving.
  - "Everyone to the lobby", then the ring sends the Operator for the lobby 2 s later. The veteran's s2 R4: all four taken at 127.2 s.
  - The veteran's group won while running out of the lobby, because they were in it at the moment the door opened.
- The Supervisor names nobody: every panel reads "SILENT LINE - TRACED", and a player who spoke 3 s before was still taken.
- The Lexicon files filler ("lol", "mine", "fat", "oop") and puts group words under the wrong station ("mailbox" and "piano" both under Cutoff).
- Being taken is a dead end: you sit out the round, and your chat still counts.

Broken:
- (1) A round that cannot be won runs on. The only free player holds the one line nobody else may enter, and the round lasts another 177 s until the Supervisor takes him (critic/probe_loss.txt, 15 s → 192.2 s). When the other lines are already restored, the same position ends at once (critic/s2.txt R1, 21.2 s).
- (2) The trace says it "is walking to the archive room" while it is already waiting there (critic/s2.txt 8.0 s). Harness wording.
- (3) Misspelled numbers pass: "thurty sevvn" (critic/s2.txt R5).
- Tool faults, not the game:
  - One walk freezes everyone's clock, so a split move runs one player after another (veteran/s2.txt R4).
  - Arriving and acting happen in the same instant, which is why "Bo restored the last line beside it" and was taken 0.2 s later (struggler/s1.txt 111.0 s: the Operator had been waiting in that room since 99.2 s).

Critic: 4/10 (PT3: 4/10). Reasons not to play:
- (1) Solved by round 2: s1 R4 is 6 s from first clue to every line through, and the Operator never moves.
- (2) The promised learning barely happens: invented words were understood on 2 lines in 12 rounds, and the Lexicon fades and fills with chat filler.
- (3) The threat is easy to steer and costs nothing: a plain word pulls it away, being taken still counts as a win, and taken players are back next round.
Store shots: only 4 distinct moments found, all text (the secret split; the echo "One eight. I have that party for you."; SILENT LINE - TRACED; "grandma" 68% understood → a player taken). 0 real screenshots (Studio not connected).

Best moment: the warning is the trigger. `Dee: "IT LEARNED GRANDMA. its coming to us, run"` → UNDERSTOOD 'breaker' → `On the line now: Cy` → `Cy: "wait really? it only heard it like twice"` (critic/s2.txt R3). Close seconds:
- the kids' lure, "lucky lucky lucky" → "BO GO NOW" → 4 of 4 out;
- "Seven eight. I have that party for you.", the Operator doing the group's sum and saying it back.

Learning (struggling players): half-understood in round 1 (`"wait maybe it hears us say the numbers??"`), used on purpose by round 3 (the lure). Their rule in one sentence: "dont say the room stuff or the numbers, say it like a riddle". What would have taught them sooner: the voice saying back the plain word it heard, the way it says back digits ("the single best teacher they got"). Would they play again tomorrow? Probably not: sitting out a round when taken is boring, and the last rounds had no threat.

Matrix re-scores:
- Core loop depth 2→1. All three solved it by round 2 with a number scheme, and the Operator stopped moving: the veteran's 8 of 13 rounds were 16 s wins; the critic "solved by round 2", 11 of 12; the struggling players' rounds 4 and 6 took 6 s.
- Differentiator stays 2, at the edge. In 31 unscripted rounds a group's own word was understood on 5 lines and caught 1 player, and the veteran's invented codes never passed about 50%. But it still reacts to what players say, which is more than Blair's and Phasmophobia's fixed lists; the RETRO's blind re-score decides.
- Market 20.7→18.7.

Backlog (ranked by gap value):
1. Core loop (12): a protocol beats the listener from round 2. The Operator must learn what carries a code (the clue words and schemes: "dozen", "bee ay", "grandma"), or the deal must change (stations, rooms, codes). Veteran: they would come back "if it learned codes across rounds, or if codes, stations or rooms shuffled". Next BIG SWING candidate.
2. Core loop / hook (12): being taken is a dead end. Capture needs a cost and a way back (PT1 #4, PT2 #3).
3. Hook (12): the voice says back the plain word that moved it (struggling players; COACH S1). This touches the owner's R93 answer, so it is to be filed as an owner question.
4. Core loop (12): the way out needs a visible clock. The 45 s door timer and the call bringing it back to the lobby are hidden (struggling players' R4 loss, the veteran's s2 R4, R144 blind #9).
5. Core loop: broken (1), a round that cannot be won runs on.
6. Hook: everyday words are station words ("number", "out", "leave"). The plain lists are the owner's R85 answer, so this goes to the owner.
7. The number reader reads across clue words and the game's own "2/3" (R142's backlog); misspellings pass.
8. Stations: one name per station, and "waiting by the X" should say which room.
9. Lexicon: filler filed at the first restore, words under the wrong station, gone within two rounds.

### PT3 · R140 · personas: genre veteran (DOORS / 99 Nights), min-maxer, critic · build 818fb92
Sessions: all three played BLIND (no source, no word lists) through `tools/play`, on a STEPPED clock, text only (Roblox Studio not connected: no screenshots, no sound). Genre veteran, UNSCRIPTED: two groups, 10 rounds, 9.2 stepped minutes, furthest round 6, plus a 15-round silent probe. Min-maxer, UNSCRIPTED: 16 rounds in 5 sessions, 13.5 stepped minutes, plus 454 probe sessions and a 25-round survey bot. Critic: two groups, 6 natural rounds, about 25 probes, two 12-round scripts. Reports and sessions: playtests/PT3/.
Headline: rounds won, unscripted groups: veteran 7/10, min-maxer 15/16 (its protocol 13/14; survey bot 25/25), critic 4/6 (bots at R139: 5/6/6 of 7, unchanged). Players taken per round: veteran 1.9 (19 in 10) (bots 1.7). Supervisor calls per round: veteran 0.3 (bots 1.9). Codewords the Operator learned and used: 2 burns in 10 veteran rounds, 1 learned catch in 5 for the critic (bots: 4 replaced). Natural chat naming a secret: 30 of 160 (unchanged). Rounds that end: all. New: the game is solved by round 3 (both veteran groups; every solved round 39 s).
Versus DOORS: the Library at door 50, where Figure hunts by sound while the team pieces a code together. A slip there starts a scene you can play (a closet, the heartbeat); here, being named ends it. OVERHEARD has the better reason for the monster to come (your own words) and a thinner answer once it does: nowhere to hide, and caught for the rest of the round.
Felt samey: the same three rooms, stations and starting pairs every round and seed, and only four deal rotations; once solved, a round is 30-40 s of chores; nothing escalates and no night ends; unburned words fade between rounds. | Confusing: built-in trigger words never appear on the Lexicon wall, so a catch cannot be explained; the wall reads like a debug dump (word stems, one unlabelled row per room for the same word, 100-200 rows); a word turns dangerous at 60% with no announcement (BURNED is said only at 100%); the hum gives no direction and reads "silence" while the Operator holds your room (the design's tell, but unexplained); "Secrets it listens for: 4" with three stations; the station labels are not its words ("Cutoff" vs "breaker"); a queued room bites much later; losing players costs nothing ("ROUND WON: 1 of 1"). | Broken: (1) numbers are never heard, so bare digits pass every code and the station is read from seat order: 11/11 rounds (critic), 25/25 (survey bot), the Operator never moving (critic/repro_digits_win.txt, minmaxer/s08); (2) a word glued to its code ("door48") is not heard (minmaxer/report.md E3); (3) one character (".") satisfies the Supervisor (critic/repro_digit_chatter.txt); (4) every station's refusal says "patch it" (veteran/repro_refusal_text.txt). Tool faults, fixed in this round: a walker stayed in the room they were leaving for the whole walk, which produced the report "no escape once it is called": live, a player is out of the room in 1.5 s, and the fixed tool shows the walker getting away and only the one who stayed being taken (critic/repro_no_escape.txt, veteran/repro_walk_caught.txt, each rerun with 3 s more); walks ran one player at a time (a regroup cost 29 s instead of 7 s, inflating every round time above); a caught player's refused walk cost 7 s; `next round` forfeited a live round.
Critic: 4/10 — two digits beat it; the hunter is a word list you cannot see; nothing after the trick. Store shots: only 4 found, all the same mechanic (a word sends the Operator walking); 0 real screenshots (Studio not connected).
Best moment: caught teammates as bait. With the Operator parked on the board Dee needs, Cy (already on the line) types "breaker breaker breaker", it walks to the archive, and Dee restores the board and wins the round: "being dead is a job in this game" (veteran, session 2 round 1).
Matrix re-scores: core loop depth 2→1 (a protocol of digits and seat order keeps the Operator still: 38 of 39 rounds won; both veteran groups solved it by round 3); differentiator 3→2 (visible in the first minute, but learned words caused 1 of the critic's 5 catches and 2 burns in the veteran's 10 rounds, and a protocol starves the learner). Market 22.0→18.7.
Backlog (ranked by gap value): 1. The code has to be SAID: codes the Operator can hear (numbers, or exchange names: OWNER.md question 2) and a shuffled deal and seating, so the station must be named too (core loop 12, hook 12, differentiator). 2. The Lexicon wall as the star: built-in words shown once they bite, one row per word with its room, whole words, "understood" announced when it goes live (hook 12, UI 3). 3. A night with an arc: something new after round 3, escalation, a Lexicon that lasts the night (progression 10, variety 6). 4. Taken players count against the win; a real word to satisfy the Supervisor; glued words heard (core loop). 5. Station-specific refusal text.

### PT2 · R133 · persona: returning group, then a quiet group · build 48502e2
Session: `tools/playtest returning 14 23` (10.3 min) and `tools/playtest quiet 14 5` (8.4 min): 28 rounds in all. The returning group opens with a codeword; the quiet group says each codeword once per solve.
Metrics: returning: won 14/14, the Operator moved in ONE round of 14 (round 9), 2 captures, 2 codeword swaps. Quiet: won 14/14, Operator understood 0 lines, captures 0, Supervisor calls 0: eight minutes with the monster standing at its post. Content seen 2/2 stations, 2/2 rooms, lines: greeting and completed only (quiet).
Felt samey: everything. A group that never says a plain word has no opponent for 8 rounds out of 9; a quiet group has none at all. Every round is the same two asks in the same order of magnitude of time (36-44s).
Confusing: the panel climbs (40, 48, 55, 63%!) and turns red and nothing happens for five more rounds; a returning player would conclude the panel is decoration.
Broken: (1) PT1 #1 confirmed on a second persona and seed: red on the panel in round 4, first hunted in round 9. (2) One mention per solve is a complete, free, permanent defence (0 understood in 14 rounds). (3) The Supervisor cannot fire: no player is silent for 45s inside a 40s round, and a round restart resets every clock.
Best moment: none for the quiet group. That is the finding.
Backlog (ranked): 1. A red codeword must bite (FIX, R134). 2. The game needs pressure that does not depend on the group making a mistake: a longer round with more to do (third station, own room and concept) so the Supervisor's 45s can land. 3. A quiet group's single mention should still teach (credit by success count, not only recency-weighted heat). 4. Capture needs a cost. 5. A closing phase so rounds have an arc.

### PT1 · R132 · persona: first-timer group · build 2158fd0 + setup
Session: 4 bots, 14 rounds, 10.3 simulated minutes (`tools/playtest firsttimer 14 11`). Round 1 in plain words, then one codeword per line, kept until the Operator came for it.
Metrics: won 14/14, lost 0. Captures 4 (rounds 1 and 10 only). Operator understood 8 lines, 4 of them plain speech in round 1. Supervisor calls 0. Codeword swaps 2. A round lasts 44s. Content seen: 2/2 stations, 2/2 rooms, 8/10 Operator lines (never `lost`, never `traced`).
Felt samey: rounds 2-9 are identical: same two asks, same two sentences, 44 seconds, win. Nothing varies but the digits.
Confusing: the panel shows a codeword red ("63%!") from its 4th round, but the Operator does NOT act on it: the round-start cool (0.32) drops it under 0.6 before it is next said, and it re-crosses only at the solve. The word first actually gives the group away in its 9TH round of use (round 10). So "burns in four rounds" (R131) is true of the panel and false of the monster.
Broken: (1) plain speech in round 1 costs nothing: it arrives at 18.2s, after the line was restored at 18.0s, takes two players, and the round is still won 18s later. (2) Being on the line has no cost to the group: caught players keep relaying and rounds are won with half the group taken. (3) The Supervisor never fires: rounds end before its 45s deadline.
Best moment: round 10, when "blue kettle" finally brings it to the board room mid-sentence and four BURNED lines land at once.
Backlog (ranked): 1. A learned codeword must bite when the panel says red (FIX: R131's number measured the panel, not the hunt). 2. Rounds are too short and identical: a third station with its own concept and room. 3. Capture needs a cost (a caught holder cannot relay, or the round needs N free players to win). 4. A closing phase (The Call / Out) so a round has an arc. 5. Supervisor deadline unreachable in a 44s round.
