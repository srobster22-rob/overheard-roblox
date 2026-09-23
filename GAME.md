# OVERHEARD

> Every horror game teaches the player the monster's rule.
> This one teaches the monster the player's.

## Premise

The Vale Street Telephone Exchange connected every call in town for forty years.
Operators sat in rows and listened to all of it — births, affairs, deaths,
arguments at 3am. The building heard more human speech than any room ever built.

In 1961 the exchange was cut over to automatic switching and the operators went
home. Something stayed at the board. It had spent forty years doing one thing,
and it had gotten very good at it.

It does not see. It does not smell. It **listens, and it understands.**

## The core mechanic

The Operator hunts by *meaning*, not by volume.

Say "the key is in the kitchen" and it walks to the kitchen. Whisper it and it
still walks to the kitchen. Say "the thing that opens things is in the room
with the stove" and it still walks to the kitchen, because it understands
synonyms, paraphrase, and circumlocution.

What defeats it is **shared context it was never present for**:

- "It's where Jake fell last round."
- "Same place as the blue one."
- "Do the Tuesday thing."

So the game is: **four players inventing a private language under time
pressure.** Your group's history is the encryption key. Strangers are nearly
helpless together. Friends who have played twenty rounds are formidable.

## The escalation — why it stays tense

The Operator **learns.** Every time a novel phrase reliably precedes players
acting on a fact, it binds the phrase to the concept. "The blue one" works
beautifully for four rounds and then, one night, it doesn't.

On screen, a coined term you rely on shifts from white, to amber, to red.
Red means **burned** — it understands now. You have to coin a new one, mid-run,
while being hunted.

That is the whole feel of the game: your language decaying under you.

> **As built (R131).** R46 measured that no codeword could be learned in normal
> play: heat cooled per second, and a round took more out than one solve put in.
> The owner's answer was to forget once per ROUND instead (`Config.CoolPerRound`).
> A codeword the holder says about twice before each solve now works for three
> rounds, turns red at its fourth solve, and brings the Operator the next time
> it is said (R134); a word the group leaves unused for a round is safe again. It depends on how the group talks: said
> once per solve it is never learned, said a third time as the button is pressed
> it burns in its first round. Headless measurement only; how it feels is unplayed.

## Why the objectives force you to speak

Every objective is an **information-transfer problem** — one player holds a
fact another player needs, and they are in different rooms. You cannot stay
silent and win.

- **The Board.** Restoring a line needs a jack number one player can read and
  another must patch.
- **The Breakers.** The fusebox is unlabeled; the schematic is three rooms away.
- **The Ledger.** A subscriber's address is needed to place the call out; only
  one player can see the directory.
- **The Route.** One player has the floor plan. Nobody else can see the exit.
- **The Four Doors.** Three are safe. The person who knows can't reach them.

> **As built (R142).** A line's code is a secret too. The Operator hears it in
> the forms people type two digits in without shared context (digits, digits
> apart or glued to a word, number words, simple sums, turned round; the list is
> pinned in tests/codes.luau) and it is spent: the holder gets a new one. The deal is shuffled, so
> who says a code does not say which station it is for, and a player's second
> wrong code in a round rings through to that station's room. What still works
> is context the group shares and the Operator was never present for ("Bo's age
> plus 34"), plus a word of the group's own for the station, which it learns.
>
> **As built (R147): it learns to count.** A group's word for a number is
> worked out from the codes it carried: "five dozen minus two" said before 58
> is entered means dozen = 12 (one unknown per phrase, whole values 1-99). The
> value learns and cools at the station words' rates, and once it is understood
> the Operator says "Thank you, caller. I will count it that way."
> and hears a code said that way like one said in digits. The wall lists the
> word and its value under "counts as a number". Still safe: a fact said once,
> letters and NATO words (one word per digit), and anything with two unknowns.

## Round shape

Four players, roughly ten minutes, one exchange building.

1. **Cutover.** The lights go. The board wakes up. It says "Operator. Go ahead,
   please." (It said "Number, please." until R129: quoting it gave the jack away.)
2. **Work.** Complete three switchboard objectives. Each needs a transfer.
3. **The Call.** Place the outside call. This is loud and it *will* come.
4. **Out.** Reach the street door before it reaches you.

> **As built (R138):** Cutover is only the Operator's greeting. Work is three
> stations in three rooms. When the last line is restored the call rings for
> `Config.CallRingSeconds` with the street door shut; then the door opens and
> the Operator is sent for the lobby, which holds it. The round is won the
> moment everyone still free stands in the lobby with the door open; anyone in
> there when it arrives is taken. A group that waits in the lobby for the door
> must not say the lobby's plain words (door, out, leave), which bring the
> Operator to it. `Config.EscapeSeconds` after the door opens the round ends
> anyway: won if anyone still free got out, lost if nobody did (DECISIONS D6,
> D7).

Losing is being **connected** — it puts you on the line and you can only be
heard, not spoken to, for the rest of the round. Your teammates hear you. You
can still help them. You just can't be helped.

That matters: death that removes a player from a horror game removes a player
from the room. Here, dying makes you a voice — which is thematically exact and
keeps everyone playing.

## The roster — one comprehension rule each

The expansion axis of this game is **new ways of understanding.** Every monster
is a different listener. This is the engine that lets the game grow forever
without repeating itself.

| # | Entity | Its rule | What it does to play |
|---|--------|----------|----------------------|
| 1 | **The Operator** | Understands plain meaning; learns your coinages | The baseline. Teaches the language game. |
| 2 | **The Party Line** | Repeats what you said into a teammate's ear, altered | Attacks trust. You stop believing relayed facts. |
| 3 | **The Stenographer** | Anything you *assert* becomes true | "The door is locked" locks it. Speak only in positives. |
| 4 | **The Supervisor** | Punishes **silence** — you must keep talking | Inverts everything: babble continuously, convey nothing. |
| 5 | **The Apprentice** | Starts knowing no language, learns 10x fast | Harmless at minute one, fluent by minute six. |
| 6 | **The Echo** | Only understands what is said **twice** | One shot per phrase. Never repeat yourself. |
| 7 | **The Translator** | Understands only *figurative* speech | Metaphor kills, plain speech is safe. Teaches rule 1 by breaking it. |

Ship with #1. Add one per expansion round. #4 and #7 are the two that will make
people post clips, because they invert a habit the player has already built.

## Progression — The Lexicon

Your group keeps a persistent **Lexicon**: the terms you have coined together,
and how burned each one is.

This is the retention engine, and it is honest rather than manipulative — the
reason to come back tomorrow with the same four people is that you *share
something they don't have with anyone else*. It also matches how Roblox
discovery now works, which weights players returning within 24-48 hours.

Burned terms cool over time — the Operator forgets, a little.

**As built it forgets by the round.** Every term loses `Config.CoolPerRound`
(0.32) when a round begins: a fully burned term is still understood after one
round of disuse, safe after two, and gone from the register after four. Heat
now accumulates across rounds within a session. Cooling "over real days" would
need the Lexicon to outlive the server — the DataStore work that has not been
done, and an answer to what counts as the same group (R73).

## Tone

Not gore. Not jumpscares as the primary instrument. The register is **1950s
municipal infrastructure** — bakelite, brass jacks, cloth cable, a wall of
little lamps. Warm materials, cold intent.

The sound design is the game. The scariest asset in the build is the moment the
switchboard *stops* humming, because that means it is listening to you
specifically.

Its voice is polite. It only ever says operator lines:

> "Operator. Go ahead, please."
> "I'm connecting you now."
> "Go ahead, caller."
> "That line is busy."
> "I have that party for you."

It never threatens. It is helpful. That is what makes it awful.
