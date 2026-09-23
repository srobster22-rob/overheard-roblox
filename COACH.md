# COACH — roblox-game (OVERHEARD)

Notes from the outside coach: the coordinator session reviews every project
from outside its loop. Rules are in AGENT_LOOP.md v3.1, sections 1 and 6.
- Fix every `C` (CORRECTION) note this round or the next.
- Rank every `S` (SUGGESTION) note by gap value beside your own candidates.
- Under each note, append one line: `-> R<n>: taken` / `-> R<n>: ranked (gap <v>)` / `-> R<n>: rejected: <reason>`.
- Never delete or rewrite a note.
- This file arrives untracked: `git add COACH.md` before you append to it.
- `P` notes are process notes for the coordinator. P2 and P5 below also bind this project.

## DO FIRST: two ship-blocking defects (coordinator, 2026-09-22)
Treat these as owner-reported bugs. Each one ends the current round: fix it, prove it, then resume the cycle.

1. **C1 — on a real server, the chat hook is never called.**
   - `TextChatService.OnIncomingMessage` is a client-side callback, and it is assigned in a SERVER script (init.server.luau:308). So on live Roblox nothing feeds the Operator or the Supervisor:
     - no codeword is ever learned;
     - every player counts as silent, so the Supervisor sends the Operator after them about 45 s into every round.
   - The headless suites pass only because the harness calls the hook directly, and tests/wiring.luau:652 *requires* the wrong hook.
   - **Fix:** feed chat through a server-side path (`TextChannel.ShouldDeliverCallback`, or `Player.Chatted`), and flip the wiring test so it rejects `OnIncomingMessage` on the server.
   - **Prove it:** cite the Roblox doc line for the side each chat API runs on (P2), and add a harness check that fails if a client-only callback is assigned in server code.
   → R139: taken (see C1 under Corrections).
2. **C2 — unfiltered player text is shown to other players.**
   - The Lexicon panel broadcasts raw typed phrases to every client (init.server.luau:118-119), and nothing in src calls `TextService:FilterStringAsync`. That breaks Roblox's rules.
   - **Fix:** filter each phrase for each recipient (`GetNonChatStringForBroadcastAsync` or `GetChatForUserAsync`) before any client sees it. Test that nothing unfiltered is ever sent.
   → R139: taken (see C2 under Corrections).
3. **C11 — tools/playtest.luau:188 calls `escape:release`, which no longer exists.** Every PLAYTEST depends on that tool. Add a short playtest run to test.cmd (P4) so this can't recur.
   → R138: taken (see C11 under Corrections).

## Review 1 — COACH REVIEW — roblox-game (OVERHEARD) — 2026-09-22 — HEAD e2768fc
Scope: R136 (market setup), R137 (committed) and R138 (staged but not committed; more edits landed while I was reading). I only read files. Nothing was run. Web facts come from WebSearch, with sources at the end.

## Corrections (must fix: wrong facts, unsupported/inflated scores, arithmetic errors, broken rules)
- C1 **On a live server the game hears nothing.**
  - Evidence: `src/server/init.server.luau:308` (HEAD) sets `TextChatService.OnIncomingMessage` in a server Script. Roblox's text-chat docs say this callback "should be defined on the client only".
  - That callback is the only caller of `supervisor:hear` and `operator:hear` (:333-334). So in the shipped build no plain word summons the Operator and no codeword is ever learned.
  - Every player also counts as silent, so about 45 s into every round the Supervisor starts sending the Operator after them, whatever they type.
  - `tests/wiring.luau:652` *requires* this hook, and tools/playtest drives the modules without it. That is how ~138 green rounds missed it.
  - Fix: move the feed to a server-side hook: `TextChannel.ShouldDeliverCallback` on RBXGeneral (dedupe by MessageId, return true) or `Player.Chatted`. Invert the wiring guard. Make this the first check of any Studio session.
  → R139: taken. Chat is heard through `Player.Chatted` in ChatFeed, which follows the Players service (tests/chatfeed.luau drives it with fake players). The wiring check that REQUIRED `OnIncomingMessage` now rejects it through PLATFORM.md: each side-restricted API with its source, and tests/wiring.luau sweeps every source file against that table (plants Q10, Q14).
- C2 **Unfiltered player text goes to every client.** `init.server.luau:118-119` sends `operator:snapshot()` to all clients for the Lexicon panel, and that snapshot holds raw typed `phrase` n-grams plus `coinedBy` (Operator.luau:287-298). There are 0 `TextService`/`FilterStringAsync` calls in src.
  - Roblox requires text one user creates to pass `FilterStringAsync` → `GetNonChatStringForBroadcastAsync` before other users see it. Fix: filter each phrase by its author before broadcasting it, and add this to the launch checklist.
  → R139: taken. Censor filters each phrase for the player who typed it (FilterStringAsync, then GetNonChatStringForBroadcastAsync), leaves out any it cannot filter, and sends only the newest panel (tests/censor.luau; plants Q5-Q9, Q11, Q12).
- C3 **Audio is not owner-gated** (MARKET.md:43-44, OWNER.md:258-264). `Presence.luau:52` already plays a built-in `rbxasset://sounds/…` sound with no upload, and RESEARCH.md:10-13 records Speech-to-Text (full release 11 May 2026) and Text-to-Speech as fully released.
  - `AudioTextToSpeech` can speak the Operator's lines, and stingers can come from built-in sounds plus Audio API effects. Fix: withdraw the audio half of R136. Audio (gap 12, tied for top) is the loop's own work.
  → R139: taken. MARKET.md and OWNER.md no longer call audio owner-gated: built-in `rbxasset://` sounds and Text-to-Speech are the loop's to use.
- C4 **The category leader is missing from the comparables.** MARKET.md:11 names DOORS as leader.
  - 99 Nights in the Forest: 26 B visits in Apr 2026 (29.5 B in later counts), 14 M+ peak concurrent players, and Best Horror Experience at the 2025 Roblox Innovation Awards.
  - Blair is Roblox's own ghost hunt: players type questions to the Spirit Box in chat. It is the on-platform version of the Phasmophobia row.
  - Silent Mansion and West Wood also have monsters that hear your mic, so that is a whole sub-genre rather than one small game ("be quiet.").
  - Fix: add 99 Nights as leader, and add Blair. Keep Phasmophobia (off-platform, paid) as a note on voice. The Mimic (linear chapters, no round loop) fits least well.
  → R139: taken. 99 Nights (leader by audience) and Blair (the typed Spirit Box) added; Phasmophobia kept as the voice note; The Mimic marked as the weakest fit; Silent Mansion and West Wood noted as the mic sub-genre.
- C5 **Six numbers spot-checked; four are wrong or out of date.**
  - DOORS "7.6 B visits": searches give 7.2 B visits and 7.6 M *favourites*.
  - DOORS "~14 hostile entities" is one guide page's count, and it is low: the Mines update alone added 4, and the Outdoors has 5 instakill entities.
  - Phasmophobia has had 27 ghost types since Winter's Jest (16 Dec 2025), not ~24.
  - "be quiet." has had a second map (a warehouse that needs voice chat) since 15 Sep 2024, not one map.
  - Pressure's 115 rooms and The Mimic's 9 chapters in 3 books both check out.
  → R139: taken, one number corrected further: DOORS 7.2 B visits (7.6 M was favorites), 20+ entities, "be quiet." 2 maps; Phasmophobia is at 30 ghost types by July 2026 per its wiki, not 27.
- C6 **Arithmetic.** Variety's gap value still reads 6 (MARKET.md:26), but R137 moved us 1→2, so it is 2×(4−2) = **4**. Everything else adds up: us 37/150 = 24.7, DOORS 131 = 87.3, Phasmophobia 124 = 82.7, Pressure 119 = 79.3, The Mimic 108 = 72.0, be quiet. 66 = 44.0.
  → R139: taken. tools/market.luau computes every total and gap value from the matrix, and test.cmd fails if MARKET.md states any other number (plants M1-M3).
- C7 **Inflated rows.**
  - Variety 2 → 1: every round deals all three stations (`Round.secretsPerRound` = #STATIONS+1 at Round.luau:156-157; init.server.luau:72-73). R137's own evidence says "rounds still one shape", and captures and Supervisor calls measure pressure, not variety.
  - Performance 2 → 1: fps has never been measured and the game has never run on the platform.
  - Social 2 → 1: it has never run with 2 clients, which is CLAUDE.md's own minimum bar. There is no invite or party feature, and the "clip-shaped" moment is a text trace.
  - Core loop 2 and Differentiator 3 → 1 each until C1 is fixed: their evidence is module traces, and the shipped build cannot feed those modules.
  - Deflated: Accessibility 0 → 1. tests/hud.luau:32-43 checks layouts from 640×360 landscape up, "understood" is shown as text rather than colour alone, and ProximityPrompts work natively with touch and gamepad.
  → R139: taken. Variety, performance and social 2 to 1, accessibility 0 to 1. Core loop and differentiator keep 2 and 3 because R139 fixes C1, which their evidence rests on. Market score 24.7 to 22.0.
- C8 **VISION was not re-targeted (§2b step 8).** VISION.md:21-32 kept the v2 numbers and only added a comparable column: rooms 5 against "procedural rooms by the hundred", entities 4 against 27 ghost types.
  - Hitting every target would still leave Content volume at 1. Fix: next to each target, state the matrix score it would earn.
  → R139: taken. Each VISION.md target now states the matrix score hitting it would earn; hitting all of them moves content volume from 1 to 2 at most.
- C9 **"0 of 45 everyday lines trip a secret" (OWNER.md:169) claims more than it tests.** The corpus (tests/heuristic.luau:639-684) avoids every word in the pool, so it tests over-eager stemming, not how people actually chat.
  - Since D4, `exit` is dealt every round and `out` is one of its whole-word plain terms (Round.luau:44-59). So "watch out", "get out", "I'm out" and "figure it out" all send the Operator to the lobby, and nobody has measured how often. Fix: relabel the claim and measure a realistic corpus (P3).
  → R139: taken. The OWNER.md claim is corrected. 160 lines written blind to the word lists name a secret 30 times (17 name a station, 13 are panic or ending chatter), and tests/heuristic.luau keeps that as a ceiling (plant Q15).
- C10 **The launch checklist (MARKET.md:54-66) misses three Roblox gates.** (a) Since 7 Jan 2026, chat requires an age check and only works within similar age bands. OVERHEARD cannot be played without chat, and the code never calls `CanUserChatAsync`.
  - (b) A 2026 guide says the chat filter tags nearly all numbers for under-13 accounts, and every answer in the game is a 2-digit code; check this on a device. (c) Text filtering (C2).
  → R139: taken. Three launch-checklist rows: chat needs an age check (CanUserChatAsync, not yet asked), codes against the number filter (OWNER.md question 2), and player text filtered before others see it (done, R139).
- C11 **§5 duplication in R138 (staged).** The escape tick exists in three copies: `workTheWayOut` in init.server, `workTheWayOut` in tests/soak.luau (which also reads the private `escape.openedAt`), and tools/playtest.luau:187-197. That is the drift R110-R112 had to fix (OWNER.md:177-181).
  → R138: taken. One rule in `Escape.step`, called by the server, the soak and the bots; the soak no longer reads `openedAt`. tests/wiring.luau pins that the soak and tools/playtest.luau call `escape:step(`, and test.cmd now runs 2 bot rounds: planting the old `escape:release` call fails the gate (plant P23).
  - The unstaged tree is folding the logic into `Escape.step`, but tools/playtest.luau:188 still calls `escape:release`, which the working-tree Escape.luau no longer defines. test.cmd never runs tools/, so the gate will not notice.

## Suggestions (ranked by expected market-score gain per round)
- S1 **The Operator says your word back.** Rows: Hook (W3), Differentiator (W2).
  - Why: in round 1 a group only sees that plain words bring it, plus a panel of percentages. The first real bite comes in a codeword's 4th or 5th round (MARKET.md:36), long after the first-play bounce that Roblox's 2026 recommendation algorithm scores.
  - First slice: the first time a coinage is credited, the Operator repeats it once, e.g. "'Blue kettle.' Thank you, caller." (a new `Round.LINES` entry, filtered per C2). The round-over screen gains `Readout.heardTonight`: which plain words brought it and who said them, plus the 3 coinages it is learning. It is all pure code and testable headlessly.
  - Est. gain: +2.0 (hook 1→2), plus +1.3 if the differentiator row also rises. This is not in the backlog.
  → R139: ranked (gap 12, hook), with the differentiator; a candidate for the R142 BIG SWING panel.
  → R142: partly taken. A heard CODE is read back ("Four seven. I have that party for you."); a plain word never is, by the owner's R93 answer; a group's own word waits on the swing's next slice, read from Censor's filtered phrase.
- S2 **Give the Operator a voice and give every event a sound.** Rows: Audio (W3), Hook.
  - Why: C3, and GAME.md:140 says "The sound design is the game." The audio gap is tied for top, and it was parked on a false premise.
  - First slice: a pure `Voice.luau` (line key → TTS text, voice and speed, plus a telephone band-pass) spoken through `AudioTextToSpeech` at the Operator's body. Add a `Cues` table with a built-in sound plus an effect for burn, arrival, capture, ring, win, loss and each silence band, and a test that every `Round.LINES` key and every event has a cue.
  - Est. gain: +2.0 (audio 1→2, backed by the coverage test). This is not in the backlog.
  → R139: ranked (gap 12, audio).
- S3 **Make "Out" a relay: GAME.md's Four Doors (GAME.md:69-70).** Rows: Core loop (W3), Variety (W2).
  - Why: R138's escape shows its destination on screen (Readout.ESCAPE_NOTE: "everyone to the lobby"), so nobody has to talk. A group that runs at once has about 9 s to spare (Config.luau:88-97). Pillar 1 says every objective forces a fact across the building.
  - First slice: 3-4 street doors defined as data, one live per round, shown only to a player outside the lobby. The relay happens while the call rings, and saying an `exit` word brings the Operator.
  - Est. gain: +3.3 over 2 rounds.
  → R139: ranked (gap 9, core loop).
- S4 **Answer R73 with the evidence, then key the Lexicon to the private server.** Rows: Progression (W2), Social.
  - Why: Roblox's 2026 recommendation algorithm scores D1, D2-7 and D8-28 retention, and "intentional co-play days" (joins, invites, private servers). GAME.md:115-123 already calls the Lexicon the retention engine, and LexiconSave exists but is not wired up.
  - First slice: put R73 to the owner as one A/B line with a recommendation (the private-server id, else the sorted set of UserIds). Then build a DataStore adapter, faked in tests.
  - Est. gain: +2.7 over 2 rounds once the owner answers.
  → R139: ranked (gap 10, progression); the choice is OWNER.md question 3.
- S5 **Deal 3 of 5 stations each round.** Rows: Variety (W2), Content.
  - Why: every round currently asks the same three things.
  - First slice: add 2 station entries (data only, thanks to R137's registries) and deal a different subset each round. A trace should show round 2 differs from round 1.
  - Est. gain: +1.3 (variety 1→2); the stations axis goes 3→5.
  → R139: ranked (gap 12, content).
- S6 **A way to play without free text.** Rows: Accessibility (W2), Hook.
  - Why: C10 (a) and (b).
  - First slice: call `CanUserChatAsync` when a player joins and show an honest HUD line if they cannot chat. Make answers 1950s exchange names (KLONDIKE, BUTTERFIELD) instead of digits: they fit the tone and survive the number filter. Later, a lamp-signal board with fixed symbols that the Operator learns the way it learns coinages.
  - Est. gain: +1.3. Not in the backlog.
  → R139: ranked (gap 6, accessibility); its exchange-name half is OWNER.md question 2.

## Direction check
- **R136 (market setup):**
  - The format is complete, but four errors now steer the picks: the missing leader, audio wrongly filed as owner-only, VISION not re-targeted, and "release needs the owner" (the icon and description are loop work, MARKET.md:58-60).
  - Progression also waits on R73, so 3 of the top-5 gaps are parked. The drift has moved from rewording (none since R129) to labelling gaps owner-gated.
- **R137 (expand):**
  - Correct pick: content was the top gap by value (12). It shipped what it claimed: stations, rooms and interactables each +1, plus a real registry refactor (Health +1).
  - It over-claimed variety 1→2 (C7).
  - It was committed after two REJECTs, with the note "No third pass was run" (LOOP_LOG.md:8723).
- **R138 (expand, uncommitted):**
  - Swapping the PLAYTEST slot for an EXPAND is legal: there was only one building round (§3, "no empty slots").
  - It picks phases (the axis furthest below target) and core loop (gap 9) rather than a top-3 row. Hook (12, "fully in the loop's hands", MARKET.md:46) has now gone three rounds untouched.
  - Planned P2/R3 is fair. H is −1 as staged (C11), and 0 only if every driver calls `Escape.step`.
  - The inventory counts one mechanic as two phases: "the call" counts because `CallRingSeconds > 0` (tools/inventory.luau:65). So phases 1→3 is really 1→2.

## Code quality
- **Duplication:** C11. There should be one `Escape.step`, and tools/playtest must call it too.
- **Growing monsters:**
  - init.server.luau grew from 591 to 622 lines. R104-R116 existed to empty it, yet `workTheWayOut` is another top-level function there.
  - tests/soak.luau grew from 884 to 1,057 lines (+20% in one round).
  - tests/wiring.luau is 1,779 lines, with at least 77 regexes over source text (57 `string.find` and 20 `string.match`). R138 adds about 5 more. These prove text exists, not behaviour, and :652 locks in C1.
- **Magic numbers that decide the evidence:** tools/playtest.luau:80-81 sets `RUN_AFTER = {firsttimer=10, returning=3, quiet=6}` and `RUN_TRAVEL_SECONDS = 6`, although Config's own walk estimate is 7 s. These values produce the escape results the round cites. World's `placeAt` also hard-codes a station height of `4`.
- **Content as data:** rooms 4 and 5 (VISION targets 5) will each need hand-built geometry. The lobby's passage and corridor cut are special cases (Layout.passageWalls, passageFloor and corridorWalls), and the steps are only listed in a comment above `Layout.rooms`. Put doors and passages in the room registry.
- **Types:** `Escape.step` and `everyoneOut` take `line: any` and `pursuit: any` inside `--!strict` modules.
- **A test that cannot fail:** the TRY at PLAYBOOK.md:17 asks whether "PT2 saw the new content without being steered". But the same round writes the bots' route to the new content (R138's tools/playtest hunk), and PT2 already ran at R133.

## Process notes (for AGENT_LOOP.md)
- **P1 Spell out the unblock.** "Device-blocked" appears 70 times in LOOP_LOG. The 8 Sep setup notes say the unblock is two owner clicks: Studio › File › Studio Settings › Beta Features › MCP Server, then Connect in the Rojo plugin. OWNER.md never says so. §7 should require every device block to be filed at the top of OWNER.md as numbered steps, with the rows and claims it blocks.
  → R139: taken. The Studio unblock is OWNER.md question 1, as numbered steps.
- **P2 Check the platform, not just the mock.** C1, C2 and C10 survived because the harness mocks Roblox. Add to the Roblox SHIP gate a PLATFORM.md row for every engine API the game uses, giving the side it runs on and the doc line that says so. The reviewer rejects any new API without a row.
  → R139: taken. PLATFORM.md, swept by tests/wiring.luau.
- **P3 Don't let the builder write the evidence.** The bots, their timings and the "ordinary chat" corpus are all written in the same round that ships the feature. For a language game, PLAYTEST personas should be subagents that write chat using only what a player can see, with the real Heuristic and Operator judging it. Report how often natural chat trips a secret and how long a group takes to coin its first word.
  → R139: taken in part. The corpus was written by a subagent blind to the word lists; the unscripted playtest persona is R140's.
- **P4 Gate the playtest tool.** tools/ is not run by test.cmd, so the PLAYTEST instrument can break without anyone noticing (C11). Add a 2-round smoke run of `tools/playtest` to test.cmd.
  → R138: taken. test.cmd runs 2 bot rounds and fails if they crash or win none.
- **P5 Make "owner-gated" cite its reason.** A gap labelled owner-gated must name the platform fact behind it, and the blind re-scorer at RETRO should check it. R136's audio label contradicted RESEARCH.md and Presence.luau.
  → R139: taken. OWNER.md's parked line and MARKET.md's gap notes name the owner action or platform fact behind every owner-gated label.

## Market score as you would score it: 17.3/100 (theirs: 24.7/100)
- **Rows I changed:** Core loop 2→1, Variety 2→1, Performance 2→1, Social 2→1, Differentiator 3→1, Accessibility 0→1 (reasons in C7). Σ(weight × score) = 26/150.
- **Once C1 is fixed** (feed on a server-side hook, guard inverted): core loop goes back to 2 and differentiator to 3, giving 33/150 = **22.0**.
- **Gap values on my scores:** hook, core loop, content, audio and social are 12 each. Progression and release are 10, art 8, variety and accessibility 6, game feel 4, UI and performance 3. The best comparable is DOORS at 87.3 today; add 99 Nights before the next re-score.
- **(d) Dimensions for Roblox discovery:** Roblox's 2026 recommendations use play-through rate and first-play bounce, D1/D2-7/D8-28 retention, intentional co-play days, and spending. The matrix should change as follows:
  - Split out "Store page: icon, thumbnails, one-line description" at W3.
  - Promote Progression to "Return reasons" at W3.
  - Add "Co-play loop: invites, private servers, rejoining with the same group" at W2.
  - Add monetisation readiness as a W1 context row; a private-server price is the natural first product.
  - We would score 0 on all of these today.
- **(f) Is the differentiator visible in a first session? Not within one round.**
  - Even with C1 fixed, a group can only notice two things: a plain word brings the Operator (like "be quiet.", but triggered by meaning), and their phrases appear on a panel with percentages.
  - It only hears typed chat. There are 0 `AudioSpeechToText` calls in src, although RESEARCH.md:10 records Speech-to-Text as fully released. So a group on voice chat, the default for co-op horror at 13+, is never heard.
  - To sharpen it: do S1 now, then add Speech-to-Text. The mic-monster sub-genre is a proven discovery lane, and none of those games hear *meaning*.

Sources: [text chat docs](https://create.roblox.com/docs/chat/in-experience-text-chat) · [OnIncomingMessage not firing](https://devforum.roblox.com/t/onincomingmessage-not-firing/2810743) · [text filtering](https://create.roblox.com/docs/ui/text-filtering) · [STT full release](https://devforum.roblox.com/t/full-release-speech-to-text-api/4357786) · [TTS full release](https://devforum.roblox.com/t/build-more-immersive-experiences-text-to-speech-api-full-release/3986607) · [age check to chat](https://ir.roblox.com/news/news-details/2026/Roblox-Requires-Users-Worldwide-to-Age-Check-to-Access-Chat/default.aspx) · [chat filter and numbers](https://halosafe.app/blog/roblox-chat-filter) · [Optimizing Discovery 2026](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)
[RIA 2025 winners](https://variety.com/2025/awards/news/grow-a-garden-roblox-innovation-awards-2025-winners-1236510387/) · [List of Roblox games](https://en.wikipedia.org/wiki/List_of_Roblox_games) · [99 Nights 29.5 B](https://movieweb.com/99-nights-in-the-forest-roblox-sam-raimi-movie/) · [DOORS stats](https://www.game.guide/roblox-codes/doors) · [DOORS 14-entity guide](https://bloxguidesgg.com/games/doors) · [The Outdoors](https://doors-game.fandom.com/wiki/The_Outdoors) · [Mines Update](https://doors-game.fandom.com/wiki/The_Mines_Update) · [Phasmophobia 27 ghosts](https://gamerant.com/phasmophobia-new-ghosts-when-obambo-gallu-dayan-evidence/) · [be quiet. maps](https://allroblox.com/en/game/be-quiet/) · [Blair Spirit Box](https://blair-roblox.fandom.com/wiki/Spirit_Box) · [The Mimic](https://mimic.fandom.com/wiki/The_Mimic) · [Pressure](https://roblox.fandom.com/wiki/Urbanshade:_Hadal_Division/Pressure)
