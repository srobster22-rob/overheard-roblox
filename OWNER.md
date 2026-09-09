# OWNER.md — my direction for this project

The agent reads this file at the start of EVERY round (AGENT_LOOP.md, Stage 0).
Write in plain English. One item per line. Top item goes first.

## Next
<!-- e.g. "the lobby is boring" or "the monster never feels close" -->

## Never
<!-- standing constraints -->

## Done
<!-- the agent moves finished items here with the round number and result -->

- R4 � the Operator now forgets. Heat bleeds off in real time, so a phrase
  your group retires becomes safe to say again after about 40 seconds. It
  never did this before: once a phrase was burned it stayed burned for the
  life of the server. Also added a test that fails if a tuning dial is not
  actually read by the game (three of them were not).

- R5 - the second station (the breaker) is in, and the round's two lists were
  wired together. Before this, 4 servers in 10 ran the only objective for a
  concept the monster was not listening for: you could shout the jack number
  and nothing happened. Now the stations decide what it listens for.
  ONE THING FOR YOU: when a player joins mid-round, should the lines be
  re-dealt (holders reshuffled) or should whoever knows a number keep it?
  The code currently reshuffles. That is a design call, not a bug.

- R6 - the test that is supposed to catch dead settings could be fooled by a
  comment. One setting (the list of rooms the Operator can be sent to) had been
  dead for two rounds while the suite said it was fine. The test now ignores
  comments, and the room list is checked against the rooms the game actually
  builds - in both directions - so a room named in settings but never built
  can no longer make the Operator silently never show up.
  ONE THING FOR YOU (new, small): with only one player in the server, nobody
  can finish a round - both lines deal to that player, and the rule is that the
  holder may not enter their own answer. Should there be a minimum player
  count, or should a solo player be allowed to solve their own?

- R8 - if the player holding a line disconnected, that line was stranded for
  good. Nobody else had ever been shown the answer, so it could never be
  entered and the round could never be completed by the people still in the
  server - the station just sat there being useless. Now a line whose holder
  has left is passed to somebody still playing. Only stranded lines move;
  everyone else keeps what they were already holding, so this does not answer
  your open question about what should happen when someone JOINS mid-round.
  Nothing to decide here.
