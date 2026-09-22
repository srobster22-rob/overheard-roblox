# MARKET — OVERHEARD

**Category:** Roblox co-op horror (4-player, voice/chat-driven).
Research: WebSearch on 2026-09-22 (sources at the bottom). Anything not found
there is marked `(memory, ≤ Jun 2026)`. Roblox Studio is device-blocked in this
session (no Studio MCP), so none of OUR rows can cite a screenshot yet.

## Comparables
| | Hook | First 10 minutes | Content volume | Retention | Praise / complaints |
|---|---|---|---|---|---|
| **DOORS** (leader, LSPLASH) | open 100 doors in a haunted hotel; every entity has one learnable tell | lobby → elevator → room 1 in <60 s; first entity (Rush) inside 2-3 min, dies teach the tell | 2 floors + 5 subfloors (Hotel, Mines, Outdoors, Archives, Stairwell); ~14 hostile entities; modes: Daily Runs, Chaos, Rush, Endless (2026) | Knobs currency, shop items, achievements with rewards, modifiers that trade difficulty for Knobs, revives | 7.6 B visits; praised for readable entity tells (memory, ≤ Jun 2026); complaints: grind for Knobs, modes feel like modifiers (memory) |
| **Pressure** (close in spirit, small studio punching up) | a deep-sea facility, 115 rooms, hide in lockers/vents | door → room with a puzzle, key, or monster; lockers taught immediately | 115 rooms; many monsters; safe / entity / puzzle rooms; voice acting and lore documents | Roblox achievements tied to progression | 7/10 review: charming characters, unique style; "monsters and small mechanics are not unique" |
| **The Mimic** (CTStudio) | Japanese folklore horror told in chapters | cinematic intro, first chase in minutes (memory) | 9 chapters in 3 books over 5 years | chapter unlocks, story (memory) | praised for atmosphere and lore; linear, low replay (memory) |
| **Phasmophobia** (off-platform reference for voice) | investigate a ghost that reacts to what you SAY | van, gear, walk in, ask the ghost questions | ~24 ghost types (memory), many maps; ~2 dozen recognised questions per device | levels, unlocks, contracts | voice recognition praised when it works; bugs and a fixed phrase list are the complaint |
| **"be quiet."** (Roblox, small, closest mechanic) | the monster hears your real voice chat | one house, stay silent | one map | none found | clips on TikTok ("the monster can hear me"); single idea |

## Parity matrix (0-5; weights for Roblox co-op horror)
Our scores cite evidence or are capped at 1. Comparable scores are from the
research above and memory.

| Dimension | W | Us | Evidence for us | DOORS | Pressure | Mimic | Phasmo | be quiet | gap value |
|---|---|---|---|---|---|---|---|---|---|
| Hook & onboarding | 3 | 1 | PT1: plain speech in round 1 costs nothing (arrives 0.2 s after the solve); no tutorial or lobby | 5 | 4 | 4 | 3 | 3 | **12** |
| Core loop depth | 3 | 2 | PT2: coining words is a real decision, but a quiet group met 0 opposition in 14 rounds | 4 | 4 | 3 | 5 | 2 | 9 |
| Content volume | 3 | 1 | CONTENT.md: 3 stations, 3 rooms (R137), 2 entities, 1 phase; still far below any comparable | 5 | 5 | 4 | 5 | 1 | **12** |
| Variety across a session | 2 | 2 | R137 trace (`playtest firsttimer 14 11`): 3 lines in 3 rooms; Supervisor calls 0 → 14, captures 6 → 22, 3 of 14 rounds lost; rounds still one shape | 4 | 4 | 3 | 4 | 1 | 6 |
| Progression & meta | 2 | 0 | no persistence wired (LexiconSave format only), no currency or unlocks | 5 | 4 | 3 | 5 | 1 | 10 |
| Game feel | 1 | 1 | no evidence (device-blocked) | 5 | 4 | 4 | 4 | 2 | 4 |
| Art direction | 2 | 1 | primitive parts, 4 Material uses; no screenshot possible | 5 | 5 | 5 | 4 | 2 | 8 |
| Audio | 3 | 1 | 1 Sound instance in src (the hum); no voice, stingers or ambience | 5 | 5 | 5 | 5 | 3 | **12** |
| UI/UX & settings | 1 | 1 | 9 TextLabels, no settings screen | 4 | 4 | 3 | 4 | 2 | 3 |
| Performance & stability | 1 | 2 | soak: 7 seeds, 0 unfinishable ticks, bounded Lexicon; fps unmeasured | 4 | 3 | 3 | 3 | 3 | 2 |
| Accessibility & input | 2 | 0 | 0 touch/gamepad references in src; Roblox is mobile-majority | 4 | 3 | 3 | 2 | 2 | 8 |
| Social & shareability | 3 | 2 | 4-player co-op; PT1's best moment (four BURNED lines mid-sentence) is clip-shaped, but no capture tool | 5 | 4 | 4 | 5 | 4 | 9 |
| Release readiness | 2 | 0 | no icon, thumbnails, description, or published place | 5 | 5 | 5 | 5 | 3 | 10 |
| **Differentiator: learned language** | 2 | 3 | R134 trace: a codeword burns in round 4 and is hunted in round 5; plain speech hunted at once | 0 | 0 | 0 | 2 | 1 | — (ours is best) |

**Market score:** us **24.7/100** (37/150, R137; 23.3 at R136). DOORS **87.3**, Phasmophobia 82.7,
Pressure 79.3, The Mimic 72.0, be quiet 44.0.

**Top gaps by value:** hook 12, content 12, audio 12, progression 10,
release 10.
- Audio can't be closed from here: Roblox plays only uploaded audio assets, and
  uploading needs the owner's account. Filed in OWNER.md.
- Release readiness needs the owner to publish.
- Hook and content are fully in the loop's hands.

## Differentiator
**The Operator learns your group's words.** Every other game on this shelf
listens for volume (be quiet) or a fixed phrase list (Phasmophobia). Ours reads
meaning, and it learns the codewords a specific group invents, then hunts them.
Every BIG SWING must close a top gap or deepen this.

## Launch checklist (Roblox discovery)
| Item | State | Evidence |
|---|---|---|
| Game name | ✅ | "OVERHEARD" in Config.GameName |
| Icon (512², one readable subject) | ❌ | none in repo |
| 3+ thumbnails showing the hook | ❌ | device-blocked; nothing captured |
| Description that sells the hook in one line | ❌ | none |
| First 90 s delivers the icon's promise | ❌ | PT1: first 18 s has no cost for plain speech |
| Mobile / touch controls | ❌ | 0 references in src |
| Co-play hooks (invite, party) | ❌ | none; co-play is weighted in 2026 recommendations |
| D1 retention reason (unlock, streak, persistent Lexicon) | ❌ | no DataStore wiring; R73 open |
| Published place, age rating, voice-chat eligibility | ❌ | owner-only |
| Stable 2-player replication playtest | ❌ | device-blocked |

## Market score history
| round | us | best (DOORS) | note |
|---|---|---|---|
| R136 | 23.3 | 87.3 | setup |
| R137 | 24.7 | 87.3 | variety 1→2 (third line and room); content unchanged at 1 |

Sources: [DOORS Floors](https://doors-game.fandom.com/wiki/Floors), [DOORS (Roblox Wiki)](https://roblox.fandom.com/wiki/LSPLASH/DOORS), [DOORS hostile entities](https://bloxguidesgg.com/games/doors), [DOORS modifiers](https://doors-game.fandom.com/wiki/Modifiers), [Pressure guide](https://www.exitlag.com/blog/how-many-rooms-pressure-roblox/), [Pressure wiki](https://pressure.fandom.com/wiki/Pressure), [Pressure review](https://lva-accolades.net/4468/arts-and-entertainment/game-review-pressure/), [The Mimic wiki](https://mimic.fandom.com/wiki/The_Mimic), [Phasmophobia voice recognition](https://screenrant.com/phasmophobia-ghost-voice-recognition-phrases-talking-microphone-chat/), [be quiet. on Roblox](https://www.roblox.com/games/130673851809455/be-quiet), [Roblox: optimizing discovery (2026)](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [Recommended-for-you 28-day retention](https://zehn-studio26.com/news/recommended-for-you-retention-update/).
