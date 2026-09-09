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

- R9 - a player could just guess. The code you enter at a station is two digits,
  and there was no penalty for a wrong one, so anybody standing at a keypad
  could hold Enter and open a line in about half a minute without a word being
  said - which is the one thing this game is not allowed to let you do. Now a
  wrong answer jams that line for the player who gave it, and each jam is
  longer than the last: three typos costs 20 seconds, but guessing your way to
  the answer costs over half an hour. It never punishes the person who was
  actually told the number, and one player guessing cannot lock anyone else out.
  ONE THING FOR YOU: I fixed this with a timer, which is quiet. The other option
  is to make guessing LOUD - a wrong code trips something the Operator hears, so
  the cost of brute-forcing is that it comes looking for you. That is probably
  the better horror game, but it might make the keypad frightening to use even
  when you are doing it honestly. Your call; I did not make it.

- R10 - the keypad had one red line under it, and it was being written by the
  monster. When the Operator understood somebody, or a word of yours burned, or
  it arrived somewhere, the server told EVERY player - and whoever happened to
  be standing at a keypad got that message painted into their error slot, in
  red, where "that line is jammed" goes. So you would be typing the number
  your friend just gave you and the keypad would say jack_number at you. You
  could never see this alone: you cannot be typing at a keypad and be the one
  talking. With two people it happens on a good round, because the whole game
  is one of you talking while the other stands at the keypad. The monster's
  voice and your keypad are now separate channels, and a keypad message is also
  tagged with which station it is about, so the breaker cannot answer for the
  switchboard. Nothing to decide here.

- R11 - the monster was supposed to go quiet when it got close to you. That
  silence is the scare; the hum is just it crossing the building. But every
  time it understood something, the hum switched back on wherever it happened
  to be - and it understands you every time you talk about the thing you have
  to talk about. So on a normal round it was standing right on top of you,
  still humming, and announcing itself over and over. It now works out whether
  it should be making noise from where it actually is, so it goes quiet once
  and stays quiet, and it only announces arriving once. Nothing to decide here.

- R12 - the game never checked that you were actually standing at the keypad you
  were typing into. Your computer told the server which station it was, and the
  server believed it. The two stations sit in different rooms 120 studs apart on
  purpose - that walk is what forces somebody to talk - but nothing stopped a
  player from clearing the breaker without ever leaving the switchboard, so the
  second room and the corridor were free. The server now remembers which station
  you last walked up to and refuses a code for any other one. Walking to the
  breaker gives up the switchboard, so you hold one at a time.
  Also: winning a round used to make the Operator say the exact same sentence it
  says when the monster walks into your room - "Go ahead, caller." Winning now
  has its own line. Nothing to decide here.

- R13 - when two of you enter the same number at the same keypad within a
  moment of each other, the second one was told off for it. The Operator said
  "That line is busy." straight into their ear - the same sentence it uses for a
  jammed line - for typing the number they had been told correctly, at the exact
  moment everyone else heard the round was won. You can only ever see this with
  two people, and it happens on a GOOD round, because two people both knowing
  the number and both reaching for the keypad is what a group that is talking
  properly looks like. The refusal itself was right - the line was already
  fixed - but the blame was not. The game now knows the difference between "you
  did something wrong" and "somebody beat you to it", and the Operator is only
  allowed to say the busy line to the first kind. Nothing to decide here.
