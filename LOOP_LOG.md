

## R42 — the panel for players holding nothing names a live giveaway

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Ran R41's guard over every OTHER piece of text the
game puts in front of a player. Six leak plain terms for `jack_number`:

| text | where |
|---|---|
| `"Number, please."` | the Operator's greeting |
| `"I'll try that number again later."` | the Operator giving up |
| `"nothing on your line - someone else has a number for you"` | Your Line panel |
| `"The board"` | keypad panel title |
| `"enter the jack number you were told"` | keypad hint |
| `"The board was restored."` | win text |

Most are COHERENT by R41's own rule and stay: naming your own concept is the
game (the keypad hint is about the jack, the panel title labels the board
station), and the win text is spoken during an intermission when the Operator is
not listening at all (R32).

1. *(picked)* **`Readout.NOTHING_HELD` conveys `jack_number` to the players who
   hold nothing.** *"nothing on your line - someone else has a number for you"*
   is shown precisely to the people with no line — the ones most likely to be
   talking, and the ones with no connection to that concept. It is R41's defect
   in the client: text that gives away a concept it is not about, read by a
   player who has no way to link cause to effect. Worse than the prompt case in
   one respect — the prompt was at least shown to somebody who had a line.
2. **The Operator's own lines are NOT a defect**, but the reason has to be
   checked rather than assumed: they are delivered by RemoteEvent and never
   routed back through `operator:hear`, so the Operator cannot summon itself.
   That is now asserted rather than believed — the exemption has to earn itself.
3. The `%` in a server prompt, geometry-blind movement, no player light, the
   stemming pair, the false "gamble" comment — **all still filed.**

**Stage 2 — built.** `NOTHING_HELD` becomes *"nothing on your line - listen for
somebody else's"*. The guard sweeps `Readout`'s exported strings BY ITERATION,
so a string added later is covered without anyone remembering to list it, and it
also checks the rows the panel ASSEMBLES — a giveaway could be reintroduced at
render time rather than in a constant.

**The held-line exemption is stated and asserted**: a row showing your own line
IS allowed to name its own concept, because its text is the station prompt R41
already guards, and it is the one thing that should.

**The Operator's exemption is earned, not assumed.** Its greeting really is
*"Number, please."*, which is plain language for `jack_number`. That is harmless
only because its speech goes out by RemoteEvent and never returns through
`hear` — so `tests/wiring.luau` now counts the call sites of `operator:hear` and
requires exactly one, inside the chat handler. Planting a line that feeds the
Operator its own greeting fails `nothing but the chat handler feeds the
Operator`.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 99, pursuit 90,
  round 56, config 56, wiring 217, connected 32, ordering 4, heat 20,
  layout 59, lifecycle 59, hud 16, readout 29, plus the operator assertions.
  `suite passed`.
- **Proved it fails, both halves.** Plant A restored the old wording:
  `'NOTHING_HELD' gives nothing away (jack_number)` and `no assembled row gives
  anything away (1)` — 27/29. Plant B fed the Operator its own voice:
  `nothing but the chat handler feeds the Operator` — 216/217. Both restored,
  both sha256 byte-identical.
- **The control is there**: "give me the number" must still give away the jack,
  or the sweep would pass against a reader that had stopped understanding.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED.

**Commit** `%%HASH%%`.

**What R41 and R42 are really about.** Both found the same thing in different
files: the game's own text and the words the monster listens for were written
separately and never compared. Neither list was wrong. The defect was the SEAM.
R41 fixed the seam for station prompts, R42 for the panel — and in both cases
the useful move was not the reword but the guard, because the next person to
write a sentence for this game will reach for exactly the same vocabulary.

**Next round.** The last unswept surface of that seam is the client's own inline
literals — panel titles, the keypad hint, the between-rounds text. The R42 probe
showed four of them convey `jack_number`, and by R41's rule each looked coherent
(they name the board station, which IS the concept). Worth a closer look than
that, because "coherent" was judged by eye and not by a rule anything enforces.
