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

	print("[TestOperator] all assertions passed")
	return true
end
