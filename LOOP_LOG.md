

## R34 — the HUD overlaps itself on small screens

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** R33 ended on the observation that every client
assertion in this project is a source grep. Rather than refactor for
testability with nothing observable to fix — AGENT_LOOP forbids shipping a
no-op — I looked for a client defect that is pure ARITHMETIC, because that is
the part of a UI a headless suite can actually judge.

1. *(picked)* **The five HUD panels have no layout rules and collide on small
   viewports.** Every panel is placed with a hand-picked mix of scale and offset
   and nothing checks the result. Computed the real rects from the live values:

   | viewport | overlapping pairs |
   |---|---|
   | 1920x1080 | none |
   | 1366x768 | none |
   | 1024x768 | none |
   | **800x480** | **5 pairs** |
   | **640x360** | **5 pairs** |
   | **480x270** | **6 pairs** |

   At 800x480 the Lexicon and Your Line panels are both under the On The Line
   banner and the Round Over panel; at 480x270 the two top panels overlap each
   other as well. Roblox skews heavily mobile, so this is not an edge case — it
   is a large share of the audience reading the Lexicon through a box that is
   sitting on top of it. And the Lexicon is the instrument the whole game asks
   players to read.
2. Geometry-blind movement — **filed, derivation attached.**
3. No player light, the stemming pair — **still filed**, both owner-shaped.

**Stage 2 — built.** New `src/shared/Hud.luau` holds every panel's rect as
arithmetic, and the client's `panel()` helper now takes a NAME and nothing else.
The fix is not new numbers, it is where the numbers live and what they are
pinned to:
- the centre column (`On the line`, `The board`) moved from a FRACTION of the
  height to an offset below the top row. A scale-based y is exactly what walked
  those panels up into the Lexicon as the window got shorter.
- `Round over` is pinned to the BOTTOM edge, so it cannot drift up into the
  centre column instead.
- the Lexicon lost 60px of height, which is what makes the whole column fit at
  640x360.

`Hud.MinWidth/MinHeight` state the promise (640x360) rather than pretending the
layout is correct on a phone in portrait — below that the honest answer is a
UIScale, which is separate work.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 29, objectives 84, pursuit 74,
  round 49, config 55, wiring 202, connected 32, ordering 4, heat 20,
  layout 47, lifecycle 46, hud 16, plus the operator assertions. `suite passed`.
- **The sweep is ten real viewports x every pair**, asserting both on-screen and
  disjoint. That is the check that could not exist while the rects were typed
  into the client.
- **The exclusion list has to earn itself.** `The board` legitimately shares the
  centre column with `On the line` — the keypad is closed both when you are put
  on the line and when the round ends — so it is exempt. But an exemption is a
  place to hide a panel that simply has nowhere to be, so the test also asserts
  the excluded pair ACTUALLY overlaps. Planting a bogus exclusion
  (`Lexicon`/`Your line`) fails by name.
- **Proved it fails.** Plant A restored the original scale-based y for
  `On the line`: **`nothing collides at any supported size (5 collisions)`**,
  plus two more by name — the same five pairs the Stage 1 probe measured.
  Plant B added the bogus exclusion: `anything not excluded is required to be
  disjoint`. Restored, sha256 byte-identical.
- **The module is only worth having if the client reads it**, so `wiring`
  asserts that too — and sweeps every `panel(...)` call site for stray
  arguments, because a rect typed in the client is a rect the sweep cannot see.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: this proves the panels do not
OVERLAP, and proves nothing about whether the arrangement looks good. Those are
different claims and only the first is made here.

**Commit** `%%HASH%%`.

**Next round.** The client now has real coverage of its geometry but still none
of its BEHAVIOUR — what each panel says for a given payload is still only
checked by grepping for a handler's name. `renderObjectives` and `onPhase` both
compute text from server state and both are pure enough to extract, the way
`Heat` was in R20.
