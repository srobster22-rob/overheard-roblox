--!strict
-- THE SUPERVISOR — GAME.md entity #4. It punishes silence.
--
-- The Operator hunts by meaning, which made saying nothing the strongest
-- strategy in the game. Measured, four players, 600 simulated seconds: a silent
-- group won 20 rounds to a talking group's 16, took zero captures, and the
-- Operator never left its post. The monster was opt-in, and a group on a voice
-- call outside the game played an unopposed fetch quest.
--
-- So this watches the one thing the Operator cannot: who has NOT spoken. Every
-- player carries a clock that only their own voice resets. Run it out and the
-- Supervisor puts a call through -- and the call is answered by the Operator,
-- which is the whole point of the pairing. Whatever you say to keep your clock
-- down is still heard by the thing that hunts meaning.
--
-- `GAME.md`: "Inverts everything: babble continuously, convey nothing."
--
-- It decides WHO. It does not decide what happens to them; the server sends the
-- Operator. Same split as `Pursuit` and `Presence`: one thinks, one acts.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Silence = require(game:GetService("ReplicatedStorage").Shared.Silence)
local Layout = require(game:GetService("ReplicatedStorage").Shared.Layout)

local Supervisor = {}
Supervisor.__index = Supervisor

export type Tracker = {
	-- When each player last said anything at all. Absent means "not being
	-- watched", which is not the same as "silent since time zero" -- see `watch`.
	lastSpoke: { [number]: number },
	-- When a call was last put through to them, so one overdue player is not
	-- punished on every tick of the clock.
	lastCalled: { [number]: number },
	shown: { [number]: string },
	watch: (self: Tracker, userId: number, at: number) -> (),
	forget: (self: Tracker, userId: number) -> (),
	hear: (self: Tracker, userId: number, at: number) -> (),
	quietFor: (self: Tracker, userId: number, now: number) -> number?,
	band: (self: Tracker, userId: number, now: number) -> Silence.Band?,
	overdue: (self: Tracker, now: number) -> { number },
	called: (self: Tracker, userId: number, at: number) -> (),
	reset: (self: Tracker, at: number) -> (),
}

function Supervisor.new(): Tracker
	return setmetatable({
		lastSpoke = {},
		lastCalled = {},
		shown = {},
	}, Supervisor) :: any
end

-- Start watching a player, from now. A player who has just joined has not been
-- silent for the whole round, and starting their clock at zero would call them
-- the instant they loaded in -- punished for a silence that happened before
-- they arrived.
function Supervisor.watch(self: Tracker, userId: number, at: number)
	if self.lastSpoke[userId] == nil then
		self.lastSpoke[userId] = at
	end
end

function Supervisor.forget(self: Tracker, userId: number)
	self.lastSpoke[userId] = nil
	self.lastCalled[userId] = nil
	self.shown[userId] = nil
end

-- Anything at all resets the clock. Deliberately NOT gated on the Operator
-- understanding it: the Supervisor's demand is that you speak, and the trap is
-- that speaking safely is hard, not that speaking is disallowed.
function Supervisor.hear(self: Tracker, userId: number, at: number)
	-- Only for players being watched. Chat during an intermission arrives here
	-- too and must not quietly enroll somebody the round has not started for.
	if self.lastSpoke[userId] == nil then
		return
	end
	self.lastSpoke[userId] = at
end

function Supervisor.quietFor(self: Tracker, userId: number, now: number): number?
	local last = self.lastSpoke[userId]
	if last == nil then
		return nil
	end
	return math.max(0, now - last)
end

function Supervisor.band(self: Tracker, userId: number, now: number): Silence.Band?
	local quiet = self:quietFor(userId, now)
	if quiet == nil then
		return nil
	end
	return Silence.band(quiet)
end

-- Everyone whose clock has run out and who is not inside the cooldown, LONGEST
-- QUIET FIRST. Ordered, and tie-broken on userId, for the reason `Heuristic`
-- orders its concepts: an unordered answer makes the game's behaviour depend on
-- table iteration order, which is not stable and cannot be tested.
function Supervisor.overdue(self: Tracker, now: number): { number }
	local due: { number } = {}
	for userId, last in self.lastSpoke do
		if not Silence.isOverdue(math.max(0, now - last)) then
			continue
		end
		local called = self.lastCalled[userId]
		if called ~= nil and now - called < Config.SupervisorCooldown then
			continue
		end
		table.insert(due, userId)
	end
	table.sort(due, function(a: number, b: number): boolean
		local qa, qb = now - self.lastSpoke[a], now - self.lastSpoke[b]
		if qa ~= qb then
			return qa > qb
		end
		return a < b
	end)
	return due
end

function Supervisor.called(self: Tracker, userId: number, at: number)
	self.lastCalled[userId] = at
end

-- A new round starts everyone's clock again. Without this, a player who was
-- quiet through the intermission is called in the first seconds of the round --
-- R31's whole lesson, per-round state crossing the round boundary.
function Supervisor.reset(self: Tracker, at: number)
	for userId in self.lastSpoke do
		self.lastSpoke[userId] = at
	end
	table.clear(self.lastCalled)
	-- A new round re-tells every panel: the client hid them all when the round
	-- ended, and a band equal to the last one pushed would otherwise never be
	-- sent again (R115; this was one easily-lost line in init.server).
	table.clear(self.shown)
end

-- The band to TELL this player now, or nil if it has not changed since they
-- were last told (R11: announce once, not four times a second). Also returns
-- how long they have been quiet, for the bar. R115 moved the memory of what was
-- shown in here, so `reset` and `forget` clear it by construction.
function Supervisor.bandNews(self: Tracker, userId: number, now: number): (Silence.Band?, number)
	local band = self:band(userId, now)
	local quiet = self:quietFor(userId, now) or 0
	if band == nil or self.shown[userId] == band then
		return nil, quiet
	end
	self.shown[userId] = band
	return band, quiet
end

-- Put through ONE silent line: the longest-quiet overdue player who is standing
-- in a room. Returns the userId it called (nil if none) and whether the call is
-- NEWS worth announcing. R110 moved this out of init.server, where the suite
-- could only check the ORDER of its statements by text, and where the soak ran
-- a hand-copied twin "as the server runs it" that could drift from the real one.
--
-- The rules, unchanged (R54/R55):
--   * no body yet (loading, dead): skipped, and NOT forgiven;
--   * standing in the corridor: skipped (filed, R54), and the next overdue
--     player is considered;
--   * the Operator committed elsewhere: the request only lands in `pending`,
--     so NOTHING happened -- nobody forgiven, nothing said, and it stops;
--   * a trip already under way to that room answers the silence: forgiven,
--     but not announced again.
function Supervisor.putThrough(
	self: Tracker,
	pursuit: any,
	rooms: { [string]: Layout.Point },
	roomOrder: { string },
	positions: { [number]: Layout.Point },
	now: number
): (number?, boolean)
	for _, userId in self:overdue(now) do
		local standing = positions[userId]
		if not standing then
			continue
		end
		for _, room in roomOrder do
			local centre = rooms[room]
			if centre and Layout.inRoom(centre, standing) then
				local alreadyComing = pursuit.targetName == room
				local _, onItsWay = pursuit:sendTo(room)
				if not onItsWay then
					return nil, false
				end
				self:called(userId, now)
				return userId, not alreadyComing
			end
		end
	end
	return nil, false
end

return Supervisor
