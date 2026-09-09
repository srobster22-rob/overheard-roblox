--!strict
-- Proves the acquisition loop end to end. Needs a Roblox runtime, so run it
-- from Studio (or via MCP run_code):
--
--   require(game.ServerScriptService.Server.systems.TestOperator)()
--
-- It asserts the behaviour the whole game rests on: plain speech is understood
-- immediately, a coinage is not, and a coinage becomes understood only after
-- the group repeatedly succeeds right after saying it.

local Operator = require(script.Parent.Operator)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

return function()
	local secrets = {
		{
			concept = "exit",
			plain = { "exit", "door", "stair" },
			payload = "lobby",
		},
	}

	local fakeSpeaker = { UserId = 1 } :: any
	local understood: { string } = {}
	local burned: { string } = {}

	local op = Operator.new(secrets)
	op.onUnderstood = function(concept: string)
		table.insert(understood, concept)
	end
	op.onBurned = function(coinage)
		table.insert(burned, coinage.phrase)
	end

	local t = 0
	local function say(text: string)
		t += 1
		op:hear({ speaker = fakeSpeaker, text = text, at = t })
	end

	-- 1. Plain speech is understood at once.
	say("the exit is past the stair")
	assert(#understood == 1, "plain speech must be understood immediately")

	-- 2. A coinage is NOT understood, however often it is said.
	understood = {}
	for _ = 1, 5 do
		say("meet me at jakes spot")
	end
	assert(#understood == 0, `coinage must not be understood on sight, got {#understood}`)

	-- 3. But saying it and then succeeding teaches the Operator.
	local uses = math.ceil(1 / Config.HeatPerCredit) + 1
	for _ = 1, uses do
		say("head for jakes spot")
		op:credit("exit", t + 0.5)
	end
	assert(#burned > 0, "repeated success after a coinage must burn it")

	-- 4. Once burned, the same phrase now gives the group away.
	understood = {}
	say("everyone to jakes spot")
	assert(#understood > 0, "a burned coinage must be understood like plain speech")

	-- 5. Cooling gives it back, slowly.
	op:cool(1)
	understood = {}
	say("everyone to jakes spot")
	assert(#understood == 0, "a fully cooled coinage must be forgotten again")

	-- 6. Real-time decay gives it back too, without waiting for a round to end.
	-- Re-burn the phrase, then let clock time pass with no further credit.
	for _ = 1, uses do
		say("head for jakes spot")
		op:credit("exit", t + 0.5)
	end
	understood = {}
	say("everyone to jakes spot")
	assert(#understood > 0, "setup: the phrase must be burned again before decay")

	local clock = 1000
	assert(op:decay(clock) == false, "the first decay tick only takes a timestamp")

	-- Not yet enough elapsed time to drop under the act threshold.
	local partial = (1 - Config.ActThreshold) / Config.CoolPerSecond
	assert(op:decay(clock + partial * 0.5) == true, "decay must report that heat moved")
	understood = {}
	say("everyone to jakes spot")
	assert(#understood > 0, "a partly cooled coinage is still understood")

	-- Past the threshold, the phrase is safe to say again.
	op:decay(clock + partial + 10)
	understood = {}
	say("everyone to jakes spot")
	assert(#understood == 0, "a coinage left alone long enough must be forgotten")

	-- Time going backwards (or standing still) must never ADD heat.
	assert(op:decay(clock) == false, "decay must not credit heat for negative elapsed time")

	-- 7. Stale evidence must not be credited, or unrelated chatter would burn.
	local fresh = Operator.new(secrets)
	fresh:hear({ speaker = fakeSpeaker, text = "purple lantern", at = 0 })
	fresh:credit("exit", Config.CreditWindow + 10)
	assert(#fresh:snapshot() == 0, "evidence older than the credit window must be dropped")

	-- 8. An utterance teaches at most ONE concept. Two stations exist now, and
	-- both can be solved inside the same credit window; if `credit` did not
	-- consume its observations, everything said beforehand would be burned
	-- twice, into two different concepts, at double speed.
	local two = Operator.new({
		{ concept = "exit", plain = { "exit" }, payload = "archive" },
		{ concept = "breaker", plain = { "breaker" }, payload = "archive" },
	} :: any)
	two:hear({ speaker = fakeSpeaker, text = "purple lantern", at = 0 })
	two:credit("exit", 1)
	two:credit("breaker", 2)
	local creditedTo: { [string]: boolean } = {}
	for _, c in two:snapshot() do
		creditedTo[c.concept] = true
	end
	assert(creditedTo.exit == true, "the solve inside the window must be credited")
	assert(creditedTo.breaker == nil, "one utterance must not also be credited to a second concept")

	-- 9. A TERM THAT REACHES ZERO LEAVES THE REGISTER. Until R14 forgetting was
	-- true of the heat and false of the entry: the coinage stayed forever at
	-- zero, was replicated to every client on every change, and was drawn in
	-- the Lexicon panel at "0%" beside words that will get the group killed.
	local gone = Operator.new(secrets)
	gone:hear({ speaker = fakeSpeaker, text = "purple lantern", at = 0 })
	gone:credit("exit", 1)
	assert(#gone.lexicon > 0, "setup: the coinage must exist before it is cooled (guard)")
	local before = #gone.lexicon
	assert(gone:cool(0.0001) == true, "a partial cool must report movement")
	assert(#gone.lexicon == before, "a warm coinage must NOT be dropped")
	gone:cool(1)
	assert(#gone.lexicon == 0, "a coinage cooled to zero must leave the register")
	assert(#gone:snapshot() == 0, "and must not be replicated to any client")

	-- 10. Dropping it is observationally NEUTRAL for comprehension, which is
	-- what makes it safe to drop. Asserted against the backend directly rather
	-- than left as an argument in a comment: `understand` scores a coinage as
	-- heat/BURNED_AT and only takes it `if confidence > best.confidence` from a
	-- floor of 0, so a zero-heat coinage can never be the concept it picks.
	local Heuristic = require(script.Parent.Heuristic)
	local atZero = { { phrase = "purple lantern", concept = "exit", heat = 0, sightings = 9, coinedBy = 1 } }
	local cold = Heuristic.understand(
		{ speaker = fakeSpeaker, text = "meet at the purple lantern", at = 0 } :: any,
		secrets :: any,
		atZero :: any
	)
	assert(cold.concept == nil, "a zero-heat coinage must convey nothing, so removing it changes nothing")
	local warm = Heuristic.understand(
		{ speaker = fakeSpeaker, text = "meet at the purple lantern", at = 0 } :: any,
		secrets :: any,
		{ { phrase = "purple lantern", concept = "exit", heat = 1, sightings = 9, coinedBy = 1 } } :: any
	)
	assert(warm.concept == "exit", "guard: the same phrase HOT must be understood, or 10 proves nothing")

	-- 11. Removal must NOT be conditional on the heat having moved this tick.
	-- An entry already resting at zero cools to zero, so an "only if it
	-- changed" test would leave behind exactly the entries this clears. Reached
	-- through the real boundary that creates one: an utterance exactly
	-- `CreditWindow` seconds before the solve is inside the window by one tick
	-- and scores recency 0, so it enters the register already at zero heat.
	local edge = Operator.new(secrets)
	edge:hear({ speaker = fakeSpeaker, text = "purple lantern", at = 0 })
	edge:credit("exit", Config.CreditWindow)
	assert(#edge.lexicon > 0, "setup: an utterance at exactly the window edge is still credited (guard)")
	for _, c in edge.lexicon do
		assert(c.heat == 0, `setup: window-edge terms enter at zero heat, '{c.phrase}' has {c.heat}`)
	end
	assert(edge:cool(0.01) == true, "clearing a resting-at-zero entry must report a change, or it is never replicated")
	assert(#edge.lexicon == 0, "a coinage resting at zero must still be dropped")

	-- 12. THE PLAYER-FACING CASE, END TO END. One chat message inside Roblox's
	-- ~200-character cap offers dozens of candidate terms, and one solve inside
	-- the credit window wrote every one of them into the register permanently.
	-- It must now drain on its own.
	local words: { string } = {}
	for i = 1, 40 do
		table.insert(words, `zzz{i}`)
	end
	local flood = Operator.new(secrets)
	flood:hear({ speaker = fakeSpeaker, text = table.concat(words, " "), at = 0 })
	flood:credit("exit", 0.5)
	assert(#flood.lexicon > 20, `setup: one long message must flood the register, got {#flood.lexicon} (guard)`)
	-- Real time passes with nobody saying any of it again.
	flood:decay(2000)
	flood:decay(2000 + (1 / Config.CoolPerSecond))
	assert(#flood.lexicon == 0, `the flood must drain with time, {#flood.lexicon} left`)
	assert(#flood:snapshot() == 0, "and the client must stop being sent it")

	print("[TestOperator] all assertions passed")
	return true
end
