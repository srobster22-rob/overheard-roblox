

## R51 — the hum sounds the same coming and going

**Stage 0.** `OWNER.md` `## Next` still empty. Owner questions untouched.

**Stage 1 — shortlist.** Followed R50's lead: which boolean guards are sitting
on a defect of degree?

0. **`isAudible` on VOLUME: no defect, measured and recorded.** R50 counted the
   seconds `isAudible` is true; it never asked how loud the hum is at that
   distance. Computed from `Presence`'s own settings (volume 0.35, rolloff
   12..140, Roblox's default Inverse mode, so heard = 0.35 * 12 / distance):
   12 studs -> 0.350, 42 -> 0.100, 60 -> 0.070, 84 -> 0.050. Across the whole
   approach as heard by a player at the board station, **3.9s of 3.9s** are above
   a 0.05 floor. The warning is real for all of it. **Recorded so this is not
   re-probed.**
1. *(picked)* **The approach and the retreat are the same sound.** `isAudible`
   is true for `approaching` and for `leaving`, and `Presence` plays one hum at
   one volume for both. R26 built the retreat precisely so players could hear it
   GO — and flagged, in its own log entry, that whether the hum reads as
   retreating rather than approaching was the claim it could not make.
   It cannot: they are acoustically identical. A player who hears the hum knows
   the Operator is moving and cannot tell which way. GAME.md's tell is "you hear
   it come and you hear it go", and half of that is not delivered — the same
   defect of degree R50 described, in its purest form: a boolean that answers
   "is it making noise" for two opposite events.
2. `Heat.isUnderstood` on degree — that is R46's learning gap, already measured
   and **filed**.
3. `anyFinishable` on degree — the MARGIN, how many able players can still
   finish. Worth a round of its own; **filed** rather than folded in here.

**Stage 2 — built.** New `src/shared/Hum.luau` answers what the Operator sounds
like per state: approaching and leaving are both loud, and told apart by PITCH —
`1.0` coming, `0.72` going. `Presence` now asks it instead of carrying
`if isAudible() then 0.35 else 0`.

**Pitch rather than volume, deliberately.** Volume is already spoken for by
distance rolloff, so a quieter retreat would be indistinguishable from a further
-away approach. A falling tone is the ordinary way a thing sounds when it is
leaving, and it cannot be confused with distance.

**Stage 3 — review.**
- Full suite green: lexicon 22, heuristic 40, objectives 122, pursuit 90,
  round 56, config 57, wiring 241, connected 32, ordering 4, heat 20,
  layout 73, lifecycle 75, hud 16, readout 29, soak 12, **hum 21**, plus the
  operator assertions. `suite passed`.
- **The states are swept from the real tracker**, not from a list typed in the
  test: a whole cycle is walked, five states are seen, each is required to have
  a voice, and exactly two are required to make a sound. A sixth state added
  later cannot arrive silent by omission.
- **Silence is asserted as zero**, not as "quieter" — the silence between the
  two sounds is the scare, and a low volume is not it.
- **Proved it fails, three ways.** A, the retreat pitched the same as the
  approach (the shipped behaviour until now): four failures including
  `...and they are told apart by ear`. B, a detune of 0.03 — audible in theory,
  not in a corridor: `...and by enough to hear, not a detune`. C, `Presence`
  going back to its own volume: `...and asks it per state` and `...and no longer
  carries its own volume`. All restored, both files sha256 byte-identical.
- **Recorded as a non-defect**: the hum's VOLUME over an approach. R50 counted
  the seconds `isAudible` is true and never asked how loud it is; computed from
  Presence's own settings, all 3.9 seconds are above a 0.05 floor. The warning is
  real for its whole length.

**Stage 4 — shipped.** `selene src` 0/0, `rojo build` clean, suite green with
output pasted above. Studio DEVICE-BLOCKED: whether 0.72 reads as "leaving"
rather than "broken" is exactly the claim this cannot make, and it is the second
item on the list for whoever first runs this with sound.

**Commit** `%%HASH%%`.

**R26 wrote down what it could not check, and it took twenty-five rounds to
come back to it.** That entry ended: *"whether the hum reads as RETREATING
rather than approaching — same sound, opposite meaning — is exactly the claim
this round cannot make."* It was not a hedge, it was a defect report, and it sat
in the log until R50 gave it a name. Worth treating past "could not verify"
notes as a backlog rather than as prose.

**Next round.** Reading the log that way, the unchecked claims still standing
are: whether being caught in a corner reads as unfair (R21), whether the doorway
is wide enough to run through under pressure (R22), and whether deferring a call
by a whole walk home reads as patience or as the monster ignoring you (R36).
Each is a FEEL question that needs Studio — but each may also have a measurable
half, the way this one did.
