# Platform capability research — AI features

Checked 2026-09-08. These constrain every design below, so re-verify before
building rather than trusting this file blindly.

## What Roblox gives us first-party (no API key, no external billing)

- **Text Generation API** — open-source LLMs, in beta with access expanding.
  Contextual NPC dialogue without HttpService or an external provider.
- **Speech-to-Text (`AudioSpeechToText`)** — FULL RELEASE May 2026. Turns player
  voice into text the server can read. "Extended Services" lets us buy more
  usage past the free allotment.
- **Text-to-Speech** — full release, multiple voices and languages.

Chained, those three are a real-time talk-to-it loop: player speaks -> STT ->
LLM -> TTS -> entity speaks back. That is the Verity loop, and it is buildable
on-platform.

## Hard limits that kill certain designs

- **No raw microphone access.** Developers cannot read voice audio, only the
  STT transcript. So MIMESIS's actual trick — cloning your friend's *voice* — is
  IMPOSSIBLE here. TTS voices come from a fixed set. Any "impostor" design must
  mimic *text and behavior*, not vocal timbre.
- **Voice chat requires verified 13+.** Any voice-driven mechanic must degrade
  gracefully to typed input, or we lose a huge share of the Roblox audience.
- **HttpService is server-only** and off by default (Experience Settings >
  Security > Allow HTTP Requests). External LLMs are possible but add per-call
  cost we pay in real money while revenue arrives in Robux.
- **Latency is the real enemy.** An STT->LLM->TTS round trip is seconds. Design
  the wait as diegetic — the thing pauses, breathes, considers — so latency
  reads as dread instead of lag. Never gate a jumpscare on a network round trip.
- **Moderation.** Generated text shown to players must be safe; run anything
  player-influenced through text filtering. Assume prompt injection: players
  WILL try to talk the entity into breaking character or saying slurs. The
  entity's prompt must be adversarially hardened and its output filtered.

## Design constraints from genre + platform research

- Fear is audio and pacing, not polygons. Silence before the hit is the scare.
- The monster needs ONE learnable rule or it reads as unfair.
- Roblox discovery weights 24-48h session return rate, so the round must end in
  a way that makes tomorrow interesting.
- An LLM is uniquely good at three things a script cannot fake: judging whether
  what a player *actually said* satisfies a demand, remembering and citing a
  specific player's past behavior, and lying persuasively. If the AI feature is
  not doing one of those three, a state machine would be cheaper and better.
