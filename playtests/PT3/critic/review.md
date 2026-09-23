# OVERHEARD: review

**Score: 4/10**

**Headline: "It learns every word you say, except the only ones you need"**

*Played: build 818fb92, headless through `tools/play`, text only. There was no art and no audio, and Roblox Studio was not connected. I played two groups of four (all four players were me) for six full rounds of natural play: game 1 on seed 7 and game 2 on seed 21, three rounds each. On top of that I ran about 25 short probe sessions and two scripted runs of 11 rounds each to check what I suspected. I did not read the code. The score is for the design as it plays here; it says nothing about how the game will look or sound.*

---

## Verdict

OVERHEARD has the best idea in Roblox horror this year: the thing hunting you learns your group's language. Three rules make it work:

- Every code has to go through the chat, because the player who was told a code can't enter it (`you were told this one - somebody else has to patch it`).
- You can't go quiet, because a silent line gets traced.
- Whatever you keep saying before a line comes back goes up on a wall, the Lexicon, until the Operator understands it.

Our nickname for the board room, "piano", was marked understood the first time a line was restored after we made it up. A round later, one slip put two of us on the line.

The first two rounds with a fresh group are really good. Both of my groups lost round 1, and both times the word "out" did it: first "2 out of 3", then "lets get out of here" typed while the phone was already ringing. That's a story people will retell.

By round 3 both groups had found a way around the listener, and after that the game is a chore: read two digits, type them, walk to the lobby, wait ten seconds. The Operator never gets faster or smarter, the rooms never change, and nothing ends the night. Round 12 is dealt exactly like round 2. It's a great ten-minute idea sitting inside a game that hasn't been built yet.

**How a round works, as a player learns it:**
- There are three rooms (board room, archive, lobby), each with one station: the board, the breaker and the latch. Ana and Bo always start in the board room, Cy and Dee in the archive.
- Three players each get a private two-digit code (`only you can see this`). The fourth gets nothing. Whoever was told a code can't enter it.
- The Operator listens to the chat. When it understands a word, it walks to that room (6.2 s) and puts everyone inside "on the line": they can still talk but can't act. If you say nothing for about 45 s, the Supervisor traces your line and sends the Operator to you anyway.
- Once all three lines are restored, everyone still free has to be in the lobby when the call rings 10 s later.

---

## Three reasons not to play it

### 1. Two digits beat it
- **Numbers are invisible to it.** The Operator doesn't hear numbers: `88`, `8 8` and `eighty eight` all pass unheard, and no number ever appears on the wall by itself.
- **Nothing else needs saying.** The stations never move and the seating never changes, so a two-digit code plus a hint like "our room" is all a group has to send.
- **Digits count as talking.** Four one-digit messages every 40 s kept the Supervisor away for two minutes and left the wall empty (`repro_digit_chatter.txt`).

My first group found this without trying. After round 2, Cy says `"it never got the numbers. it got the room names"`. Their round 3 took **39 seconds** from the deal to getting out, with all four out and the Operator never moving (G1 lines 82–105).

I then ran a script in which every chat line is a bare number (`x19_driver_digits_only.ps1`). It won **11 rounds of 11, with 44 of 44 players out**. The Operator didn't take a single step, and the Lexicon stayed `(empty)` the whole time. So the core mechanic is optional, and players will work that out in their first session.

### 2. What hunts you is a word list you can't see, and you can't escape it
The learning system is the feature on the box, but it did very little of the hunting. In six natural rounds the Operator caught players five times:

| Catch | Word that caused it | Built-in or learned |
|---|---|---|
| 1 | "board" | built-in |
| 2 | "name" | built-in |
| 3 | "out" | built-in |
| 4 | "out" | built-in |
| 5 | "piano" | learned |

Both lost rounds were "out". The built-in words come in families:
- **Board room:** board, jack, number, plug, cable, socket, port
- **Archive:** name, list, book, address
- **Lobby:** out, door, exit, leave, escape, outside, stairs

None of these built-in words ever shows up on the Lexicon wall. After "lets get out of here" threw away a round the group had already won, the best they could manage was `"the wall doesnt even show what Bo typed"`.

Once a word has been heard, nothing you do matters:
- The Operator arrives in 6.2 s, and walking to another room takes 7.2 s.
- There is nowhere to hide.
- It holds everyone in the room, for the rest of the round, and I found no way to free a held player.

In `repro_no_escape.txt`, Ana starts walking the moment she says the word and is still held 1.3 s before she would have arrived. The only skill the game tests is not typing a word nobody ever showed you. A horror game needs something to do in the seconds after a mistake, and this one has nothing.

### 3. There's nothing left once you've learned the trick
- **Same deal every time.** In every round I played and every seed I dealt (1, 7, 21, 99, 2026): the same three rooms, the same starting pairs, the same three panel sentences with new digits, and one player who always gets nothing.
- **One monster behaviour.** The Operator walks to a room, holds everyone in it, stays 20 s and leaves. It was no faster in round 3 than in round 1 (6.2 s both times), and the game opens with `Secrets it listens for: 4` every time.
- **No structure.** There is no night, no ending, no score and no escalation. The scripted run was still dealing identical rounds at round 12.
- **Its memory fades.** Between rounds an unburned word loses about two-thirds of its score: 50% becomes 18%, and anything at 30% or less disappears. The burned "say" slid from 100% to 36%, no longer understood, by round 4. So the "it remembers you" hook barely lasts beyond the round where it happened.
- **The wall reads like a debug dump.** It should be the star of the game. Instead it holds up to **201** unlabelled rows of word stems and word pairs (`"someth called"  25%`, `"whatev that"  25%`, `"nev type"  25%`), and the same word can appear two or three times with different percentages.

---

## What's genuinely new, and does the first session show it?

**What's new:** the Operator learns your group's own language from what you say together. When a line is restored, the words used before it get credited to that secret, climbing by about 25% per use. Once a word crosses the threshold, it summons the Operator. Your slang becomes its vocabulary, so the group has to keep making up new euphemisms.

The design around it is tight:
- Whoever is told a code can't act on it, so the information has to go through the channel the Operator is watching.
- Silence gets traced, so you can't simply go quiet.
- The wall shows how much of your language the monster already understands.

I don't know of another Roblox horror game that does this. The theme fits it well. The voice lines are telephone-operator lines: `"Hold the line, please."`, `"I'm connecting you now."`, and on a loss, `"I'm sorry, your call cannot be completed as dialled."`

Held players keep their voice, which pulls in two directions:
- **They can still help.** Ana passes her code from inside the Operator's room.
- **They can still get you caught.** Dee, held in the archive, slips on a burned word and pulls it to the board room that Ana had just left (G1 line 66: `>> THE OPERATOR UNDERSTOOD 'jack_number' (100%) and is walking to the board room`).

**Does the first session show it?** Yes, within the first minute:
- In game 1, the very first restore burned a word: `>> BURNED: "say" now means jack_number. "I'm connecting you now."`
- In game 2, the group's first nickname was marked understood at the first restore after they made it up.

But what a first session mostly shows is the hidden word list, not the learning: it caused four of the five catches. By round 3 both groups were playing around the system rather than against it. You can see the new idea right away; it just isn't what drives the game.

---

## The same moment elsewhere

**The moment:** Bo types "lets get out of here" while the phone rings. The group has done everything right, and 6.2 seconds later all four players are on the line.

- **DOORS: the Library at door 50.** Figure is blind and hunts by sound while the team puts the padlock code together from hint books. It's the closest thing in the genre to passing a code under a listener. A careless sprint turns Figure toward you, but that starts a scene you can still play: crouch, freeze, get into a closet, win the heartbeat minigame. In OVERHEARD a mistake ends the scene instead. OVERHEARD has the better reason for the monster to come (your own words) and no answer once it does.
- **99 Nights in the Forest: the Deer at night.** You can see it coming, and a flashlight beam stuns it, so the threat has a body, a direction and a counter. In OVERHEARD, "the hum: you can hear it" shows on every screen in every room while the Operator walks. When it's standing in your room holding you, your screen says "silence".
- **Blair: the spirit box.** The ghost listens too, but you choose when to talk to it; the spirit box answers questions you decided to ask. In OVERHEARD every chat line is a spirit-box question you didn't mean to ask, which is the better idea. But when Blair's ghost hunts, you can still run and hide.

**How it compares:** of the four games, OVERHEARD has the best reason for the monster to show up and the worst answer to "what do we do now?"

---

## Store-page screenshots: four, not five

1. **"Don't say it."** Game 2, round 1: all three lines restored, all four players in the lobby, the phone ringing.
   ```
   [  29.0s]    every line is through. "Ringing your party now. One moment, please."
   [  29.0s] Bo: "lets get out of here"
   [  29.0s]    >> THE OPERATOR UNDERSTOOD 'exit' (100%) and is walking to the lobby room
   [  35.2s]    >> "Hold the line, please." On the line now: Ana, Bo, Cy, Dee
   ```
   The shot: four players frozen on the lobby floor, with that chat line still on screen.

2. **Your nickname on its wall.** Game 2, round 2: one restore after the group made up the nickname, the Lexicon reads `"piano"  75%  understood`. Next round:
   ```
   [  96.0s] Cy: "53. piano"
   [  96.0s]    >> BURNED: "piano" now means jack_number. "I'm connecting you now."
   ```
   The game's main selling point in one frame.

3. **The rule that broke the rule.** Game 1, round 2: the group's safety briefing calls the Operator twice.
   ```
   [  44.0s] Ana: "ok new rule. numbers only. do not name anything"
   [  44.0s]    >> THE OPERATOR UNDERSTOOD 'directory' (100%) and is walking to the archive room
   [  44.0s]    >> THE OPERATOR UNDERSTOOD 'jack_number' (100%) and queues the board room
   ```

4. **The held player is still a teammate.** Game 2, round 3. Ana's screen says `You are ON THE LINE: you can still talk, but you cannot act.`, and from inside the Operator's room she types:
   ```
   [ 103.0s] Ana: "91 is mine. the cold room. you two finish it"
   [ 127.5s]    ROUND WON: 2 of 2 still free got out. "Your call has been completed."
   ```

**Why not five:**
- **The other candidates repeat a beat.** Game 1's `"DEE. that worked, 2 out of 3"` is shot 1 again, and the first "say" burn is shot 2 again.
- **The one distinct fifth beat isn't earned in normal play.** That beat is the Supervisor tracing a silent player (`>> THE SUPERVISOR put a call through to a silent player. "I have a silent line. Putting you through."`). It never fired in six natural rounds; I only saw it by sitting idle on purpose.
- **All four shots are the same mechanic underneath:** a word in chat makes the Operator walk. The build has one monster behaviour, three rooms that are never described, and a wall nobody can read.

So four is the honest count, and it's also a fair measure of how much range this build has.

---

## Samey, confusing, broken

All session files are in this folder. **G1** is `game1_seed7.txt` and **G2** is `game2_seed21.txt`; line numbers refer to those files.

### Samey
- **Every round is dealt the same way.** The same rooms, starting pairs, stations and panel sentences every round and every seed. Only the digits and who holds them change: compare any `look` after `next round` (G1 lines 49 and 81, G2 lines 40 and 73).
- **A solved round is 40 seconds of chores with no decisions** (G1 lines 82–105).
- **Nothing escalates and nothing ends.** The Operator has one behaviour and there is no night structure: `x19_session.txt` is eleven rounds of the same thing, and a twelfth dealt the same way.

### Confusing
- **The wall can't explain a catch.** Built-in trigger words never appear on it: in `repro_hidden_trigger.txt`, `Ana: board` sends the Operator walking and the Lexicon stays `(empty)`. The wall also only updates when a line is restored, so the words that lost G2 round 1 (line 32) never show up (G2 line 37).
- **Duplicate rows with different values.** They look like separate tallies for each secret, with the secret's name hidden: `"say"  100%  understood | "say"  56%` (the look at G1 line 33), and two or three separate `"mine"` rows (the looks at G2 lines 18 and 34).
- **Word stems instead of words.** The wall shows `someth`, `whatev`, `nev` and `percentag`, and lists `"nicknam"` and `"nickname"` as separate rows (the look at G2 line 54). Also, "electric" is a trigger word but "electricity" isn't (`repro_stemming.txt`).
- **"Understood" goes live without warning.** "piano" was marked understood at 75% with no announcement (G2 lines 42–48), and at 75% it was used against the group (G2 line 75). The BURNED voice line only plays at 100%, after the damage. "yep" became understood the same way and was never announced (`repro_silent_understood_yep.txt`: in round 4, `Cy: yep` produces `UNDERSTOOD 'exit' (75%)`).
- **The hum doesn't point anywhere.** It's identical on every screen in every room while the Operator walks, and it reads "silence" while the Operator is standing in your room holding you (`repro_hum.txt`: the look at 3.0 s against the look at 8.0 s).
- **"Secrets it listens for: 4", but there are only three jobs.** The fourth secret, 'directory' (name, list, book, address), has no station; it exists only to catch you (G1 line 51).
- **"Everyone to the lobby" is under-explained.** If one player straggles in after the ring, the Operator comes to the lobby and holds the players who arrived on time. The loss appears as system text, `the round stalls out (counted as lost)`, in a game that otherwise speaks in operator lines (`x5_numbers.txt`).

### Broken (reproducible)
| # | What happens | How to reproduce it |
|---|---|---|
| 1 | Digits are inaudible, so the whole listening system can be skipped | `repro_digits_win.txt` (every chat line is a bare number: 4 of 4 out, the Operator never moves, the wall stays `(empty)`); `x19_driver_digits_only.ps1` (11/11 rounds, 0 Operator moves) |
| 2 | Chatting only in digits satisfies the silence rule | `repro_digit_chatter.txt` (1/2/3/4 every 40 s: no trace in 120 s, the wall stays empty) |
| 3 | There is no escape once it's called | `repro_no_escape.txt` lines 3–4 (`Ana: board`, `Ana goes to archive`): held at 6.2 s, but the walk needed until 7.5 s |
| 4 | A word marked understood is already dangerous before any announcement | G2 lines 42–48, then line 75; `repro_silent_understood_yep.txt`, last 3 lines |
| 5 | The hum's meaning is backwards | `repro_hum.txt` |
| 6 | The Lexicon shows unlabelled duplicate rows | G2 lines 1–18 |
| 7 | Minor, text build only: a player who walks into the Operator's room gets 0.3 s before being held, and the keypad is instant, so a line can be restored right under its nose | `repro_walk_in.txt`: `Cy restores the board line` at 7.5 s, held at 7.8 s |

### Harness notes (not the game's fault)
- **Walks are one at a time.** The session language moves one player at a time, so a four-person regroup costs about 29 s of game time; in a live server everyone would walk together in about 7 s. That made my rounds longer, but it didn't change any result reported here.
- **There's nothing to see or hear.** The rooms are never described, and "the hum" is the only sense you get. The voice lines carry the whole atmosphere, and they're good.

---

## Session files (this folder)
- `game1_seed7.txt`: group 1, three rounds (lost / 2 of 4 out / 4 of 4 out). Output in `game1_seed7.out.txt`.
- `game2_seed21.txt`: group 2, three rounds (lost / 4 of 4 out / 2 of 4 out). Output in `game2_seed21.out.txt`.
- `repro_*.txt` (outputs in `repro_*.out.txt`), `x*.txt`, `x14_driver.ps1`, `x19_driver_digits_only.ps1`: the probe sessions and scripts cited above.
