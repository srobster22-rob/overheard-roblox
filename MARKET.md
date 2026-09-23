# MARKET — OVERHEARD

**Category:** Roblox co-op horror (4-player, voice/chat-driven).
Research: WebSearch on 2026-09-22 (sources at the bottom), re-checked in R139
after COACH.md's review. Anything not found there is marked `(memory, ≤ Jun
2026)`. Roblox Studio is device-blocked in this session (no Studio MCP), so
none of OUR rows can cite a screenshot yet.

## Comparables
| | Hook | First 10 minutes | Content volume | Retention | Praise / complaints |
|---|---|---|---|---|---|
| **99 Nights in the Forest** (leader by audience; Grandma's Favourite Games) | survive 99 nights in a forest with friends while something hunts you | camp, gather, build; the first night comes within minutes (memory) | classes, crafting, a day/night cycle to 99 nights (memory) | classes and currency, badges (memory) | peak 14.2 M concurrent players; 25.9 B visits (29.7 B in later counts); Best Horror Experience and Best Adventure Experience, 2025 Roblox Innovation Awards |
| **DOORS** (leader of the genre's shape, LSPLASH) | open 100 doors in a haunted hotel; every entity has one learnable tell | lobby → elevator → room 1 in <60 s; first entity (Rush) inside 2-3 min, dies teach the tell | 2 floors + 5 subfloors (Hotel, Mines, Outdoors, Archives, Stairwell); 20+ hostile entities (one guide counts ~14 before the Mines added 4 and the Outdoors 5 more); modes: Daily Runs, Chaos, Rush, Endless (2026) | Knobs currency, shop items, achievements with rewards, modifiers that trade difficulty for Knobs, revives | 7.2 B visits and 7.6 M favorites (R136 wrote 7.6 B visits: that was favorites); praised for readable entity tells (memory); complaints: grind for Knobs, modes feel like modifiers (memory) |
| **Pressure** (close in spirit, small studio punching up) | a deep-sea facility, 115 rooms, hide in lockers/vents | door → room with a puzzle, key, or monster; lockers taught immediately | 115 rooms; many monsters; safe / entity / puzzle rooms; voice acting and lore documents | Roblox achievements tied to progression | 7/10 review: charming characters, unique style; "monsters and small mechanics are not unique" |
| **Blair** (Spooky Scary Games; on-platform version of the voice mechanic) | hunt a ghost with up to 3 friends and gather evidence | truck, gear, walk in; the Spirit Box answers questions TYPED in chat ("Where are you?") | several maps and ghost types (memory) | levels, gear unlocks (memory) | the typed Spirit Box is the closest thing on Roblox to our listener; it answers a fixed set of questions |
| **Phasmophobia** (off-platform note on voice; paid) | investigate a ghost that reacts to what you SAY | van, gear, walk in, ask the ghost questions | 30 ghost types (Phasmophobia Wiki, Jul 2026; 27 in Jan 2026), many maps; ~2 dozen recognised questions per device | levels, unlocks, contracts | voice recognition praised when it works; bugs and a fixed phrase list are the complaint |
| **The Mimic** (CTStudio; fits least: linear chapters, no round loop) | Japanese folklore horror told in chapters | cinematic intro, first chase in minutes (memory) | 9 chapters in 3 books over 5 years | chapter unlocks, story (memory) | praised for atmosphere and lore; linear, low replay (memory) |
| **"be quiet."** (Roblox, small, closest mechanic) | the monster hears your real voice chat | a house, stay silent | 2 maps: the house, and a warehouse that needs voice chat (since 15 Sep 2024) | none found | clips on TikTok ("the monster can hear me"); single idea |

Silent Mansion and West Wood also have monsters that hear the mic (checked by
WebSearch in R140), so "the monster hears you" is a sub-genre on Roblox, not one
small game (COACH.md C4).
None of them hears what you MEAN.

## Parity matrix (0-5; weights for Roblox co-op horror)
Our scores cite evidence or are capped at 1. Comparable scores are from the
research above and memory.

| Dimension | W | Us | Evidence for us | 99N | DOORS | Pressure | Blair | Phasmo | Mimic | be quiet | gap value |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Hook & onboarding | 3 | 1 | PT1: plain speech in round 1 costs nothing (arrives 0.2 s after the solve); no tutorial or lobby | 5 | 5 | 4 | 3 | 3 | 4 | 3 | **12** |
| Core loop depth | 3 | 1 | PT3: a protocol of bare digits and seat order keeps the Operator still (38 of 39 rounds won), and both unscripted veteran groups solved the game by round 3; the one decision (how to name the station) has a dominant answer: don't | 4 | 4 | 4 | 4 | 5 | 3 | 2 | **12** |
| Content volume | 3 | 1 | CONTENT.md: 3 stations, 3 rooms, 2 entities; far below every comparable but be quiet | 5 | 5 | 5 | 3 | 5 | 4 | 1 | **12** |
| Variety across a session | 2 | 1 | every round deals the same three stations (Round.secretsPerRound); R137's evidence measured pressure, not variety (C7) | 4 | 4 | 4 | 3 | 4 | 3 | 1 | 6 |
| Progression & meta | 2 | 0 | no persistence wired (LexiconSave format only), no currency or unlocks | 5 | 5 | 4 | 3 | 5 | 3 | 1 | 10 |
| Game feel | 1 | 1 | no evidence (device-blocked) | 4 | 5 | 4 | 3 | 4 | 4 | 2 | 4 |
| Art direction | 2 | 1 | primitive parts, 4 Material uses; no screenshot possible | 4 | 5 | 5 | 3 | 4 | 5 | 2 | 8 |
| Audio | 3 | 1 | 1 Sound instance in src (the hum, a built-in `rbxasset://` sound); no voice, stingers or ambience | 4 | 5 | 5 | 4 | 5 | 5 | 3 | **12** |
| UI/UX & settings | 1 | 1 | 9 TextLabels, no settings screen | 4 | 4 | 4 | 3 | 4 | 3 | 2 | 3 |
| Performance & stability | 1 | 1 | soak: stable logic over long sessions, but fps never measured and the game has never run on the platform (C7) | 4 | 4 | 3 | 3 | 3 | 3 | 3 | 3 |
| Accessibility & input | 2 | 1 | tests/hud.luau lays the HUD out from 640×360 up; "understood" is text, not colour alone; ProximityPrompts take touch and gamepad natively (C7) | 4 | 4 | 3 | 2 | 2 | 3 | 2 | 6 |
| Social & shareability | 3 | 1 | 4-player co-op by design, but never run with 2 clients (CLAUDE.md's own bar); no invite or party feature; the clip-shaped moment is a text trace (C7) | 5 | 5 | 4 | 4 | 5 | 4 | 4 | **12** |
| Release readiness | 2 | 0 | no icon, thumbnails, description, or published place | 5 | 5 | 5 | 4 | 5 | 5 | 3 | 10 |
| **Differentiator: learned language** | 2 | 2 | PT3: visible in the first minute (a nickname understood at the first restore), but learned words caused 1 of the critic's 5 catches and 2 burns in the veteran's 10 rounds, and a protocol starves the learner | 0 | 0 | 0 | 2 | 2 | 0 | 1 | — (ours is best) |

**Market score:** us **18.7/100** (28/150, R140: PT3 re-scored core loop and the
differentiator down; 22.0 at R139, 24.7 at R137). DOORS **87.3**, 99 Nights 83.3, Phasmophobia 82.7,
Pressure 79.3, The Mimic 72.0, Blair 64.7, be quiet 44.0.

**Top gaps by value:** hook 12, core loop 12, content 12, audio 12,
social 12, progression 10, release 10.
- Audio is in the loop's hands. Built-in `rbxasset://` sounds play without an
  upload (the hum is one), and Roblox's Text-to-Speech is fully released
  (RESEARCH.md). R136 filed it as owner-only on a false premise (COACH.md C3).
- Publishing needs the owner. The icon, thumbnails and description do not.
- Hook, content, audio and social are all in the loop's hands.

## Differentiator
**The Operator learns your group's words.** Every other game on this shelf
listens for volume (be quiet, Silent Mansion) or a fixed phrase list
(Phasmophobia, Blair's Spirit Box). Ours reads meaning, and it learns the
codewords a specific group invents, then hunts them. Every BIG SWING must close
a top gap or deepen this.

## Launch checklist (Roblox discovery)
| Item | State | Evidence |
|---|---|---|
| Game name | ✅ | "OVERHEARD" in Config.GameName |
| Icon (512², one readable subject) | ❌ | none in repo |
| 3+ thumbnails showing the hook | ❌ | device-blocked; nothing captured |
| Description that sells the hook in one line | ❌ | none |
| First 90 s delivers the icon's promise | ❌ | PT1: first 18 s has no cost for plain speech |
| Mobile / touch controls | ❌ | ProximityPrompts take touch natively; nothing else checked on a phone |
| Co-play hooks (invite, party) | ❌ | none; co-play is weighted in 2026 recommendations |
| D1 retention reason (unlock, streak, persistent Lexicon) | ❌ | no DataStore wiring; R73 open |
| Published place, age rating, voice-chat eligibility | ❌ | owner-only |
| Stable 2-player replication playtest | ❌ | device-blocked |
| Players who cannot chat can still play (age check to chat, `CanUserChatAsync`) | ❌ | chat needs an age check since Jan 2026; the code never asks (COACH.md C10) |
| Codes survive the chat filter for every account | ❌ | codes are two digits; the filter may hash numbers for under-13 accounts; device-blocked (C10, OWNER.md R139) |
| Text players type is filtered before others see it | ✅ | R139: the Lexicon panel sends only `TextService` filtered phrases (Censor, tests/censor.luau); never seen on a device |

## Market score history
| round | us | best (DOORS) | note |
|---|---|---|---|
| R136 | 23.3 | 87.3 | setup |
| R137 | 24.7 | 87.3 | variety 1→2 (third line and room); content unchanged at 1 |
| R139 | 22.0 | 87.3 | COACH.md C7: variety, performance and social 2→1, accessibility 0→1; core loop and differentiator keep 2 and 3 because R139 feeds chat on the server (C1); 99 Nights and Blair added |
| R140 | 18.7 | 87.3 | PT3: core loop 2→1 (digits and seat order beat the listener), differentiator 3→2 (seen at once, rarely bites) |

Sources: [DOORS Floors](https://doors-game.fandom.com/wiki/Floors), [DOORS (Roblox Wiki)](https://roblox.fandom.com/wiki/LSPLASH/DOORS), [DOORS stats](https://www.game.guide/roblox-codes/doors), [DOORS hostile entities](https://bloxguidesgg.com/games/doors), [The Outdoors](https://doors-game.fandom.com/wiki/The_Outdoors), [Mines Update](https://doors-game.fandom.com/wiki/The_Mines_Update), [DOORS modifiers](https://doors-game.fandom.com/wiki/Modifiers), [99 Nights: 14.2 M players](https://games.gg/news/99-nights-forest-14-million-roblox/), [List of Roblox games](https://en.wikipedia.org/wiki/List_of_Roblox_games), [Blair Spirit Box](https://blair-roblox.fandom.com/wiki/Spirit_Box), [Blair (Roblox Wiki)](https://roblox.fandom.com/wiki/Spooky_Scary_Games/Blair), [Pressure guide](https://www.exitlag.com/blog/how-many-rooms-pressure-roblox/), [Pressure wiki](https://pressure.fandom.com/wiki/Pressure), [Pressure review](https://lva-accolades.net/4468/arts-and-entertainment/game-review-pressure/), [The Mimic wiki](https://mimic.fandom.com/wiki/The_Mimic), [Phasmophobia ghosts](https://phasmophobia.fandom.com/wiki/Ghost), [Phasmophobia: 27 ghosts](https://www.pcgamesn.com/phasmophobia/ghost-types-all), [Phasmophobia voice recognition](https://screenrant.com/phasmophobia-ghost-voice-recognition-phrases-talking-microphone-chat/), [be quiet. on Roblox](https://www.roblox.com/games/130673851809455/be-quiet), [be quiet. maps](https://allroblox.com/en/game/be-quiet/), [Silent Mansion and other mic monsters](https://www.tiktok.com/discover/roblox-games-where-the-monster-can-hear-your-mic), [West Wood voice chat](https://www.youtube.com/watch?v=KGtY3YosopY), [Age check to chat](https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101), [Roblox: optimizing discovery (2026)](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [Recommended-for-you 28-day retention](https://zehn-studio26.com/news/recommended-for-you-retention-update/).
