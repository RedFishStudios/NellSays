-- Station missions: assignment, challenge sessions, validation and wave clocks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Props = require(script.Parent.Props)
local Cues = require(script.Parent.Cues)
local Clock, Fx = State.Clock, State.Fx

local Stations = {}
local H
local sessions = {} -- [player] = session
local jobs = {} -- [stationName] = job (current wave / console round)
local rng = Random.new()

function Stations.bind(house)
	H = house
	Props.listen(function(player, propId)
		local station = propId:match("^Station_(.+)$")
		if station then
			Stations.tryStart(player, station)
		end
	end)
end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function pickSymbols(n)
	local pool = table.clone(Config.SymbolOrder)
	shuffle(pool)
	local out = {}
	for i = 1, n do
		out[i] = pool[i]
	end
	return out
end

-- The challenge chosen for a station's role (lobby choice), default = first option.
function Stations.challengeFor(station)
	local slot = Config.StationInfo[station].slot
	if slot == 0 then
		return "ReelTiming"
	end
	local choice = State.slotFolder(slot):GetAttribute("Challenge") or 1
	return Config.Slots[slot].challenges[choice] or Config.Slots[slot].challenges[1]
end

---------------------------------------------------------------- challenge generation
local function generate(kind)
	if kind == "Timing" then
		return { public = { hits = 3, period = 1.8, band = 0.2 }, need = 3 }
	elseif kind == "Sequence" then
		local syms = pickSymbols(4)
		local order = shuffle(table.clone(syms))
		return { public = { buttons = syms, flash = order }, answer = order, need = 1 }
	elseif kind == "Tuning" then
		local syms = pickSymbols(2)
		local a = rng:NextNumber(0.12, 0.42)
		local b = rng:NextNumber(0.58, 0.88)
		local targets = { { symbol = syms[1], pos = a }, { symbol = syms[2], pos = b } }
		if rng:NextNumber() < 0.5 then
			targets = { targets[2], targets[1] }
		end
		return { public = { targets = targets, hold = 1.2, tolerance = 0.045 }, need = 2 }
	elseif kind == "Match" then
		local screens = {}
		for i = 1, 3 do
			local opts = pickSymbols(4)
			screens[i] = { symbol = opts[rng:NextInteger(1, 4)], buttons = opts }
		end
		return { public = { screens = screens }, need = 3 }
	elseif kind == "Patch" then
		local shapes = { "Star", "Circle", "Triangle", "Square" }
		local left = shuffle(table.clone(shapes))
		local right = shuffle(table.clone(shapes))
		return { public = { left = left, right = right }, need = 4 }
	elseif kind == "Channel" then
		local channels = {}
		for c = 1, 12 do
			channels[c] = pickSymbols(3)
		end
		local a = rng:NextInteger(2, 6)
		local b = rng:NextInteger(8, 12)
		return {
			public = { channels = channels, targets = { channels[a], channels[b] } },
			answer = { [a] = true, [b] = true },
			need = 2,
		}
	end
	return { public = {}, need = 1 }
end

---------------------------------------------------------------- sessions
local function closeSession(player, why)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	s.closed = true
	Net.fire(player, "MgClose", s.id, why)
end
Stations.closeSession = closeSession

function Stations.closeAll(why)
	for p in pairs(sessions) do
		closeSession(p, why)
	end
end

local function completeJob(job, player)
	if job.done then
		return
	end
	job.done = true
	job.doneBy = player
	local f = State.stationFolder(job.station)
	f:SetAttribute("Done", true)
	Props.setEnabled("Station_" .. job.station, false)
	f:SetAttribute("Active", false)
	local count = 0
	for _, j in pairs(jobs) do
		if j.done and j.round == job.round then
			count += 1
		end
	end
	Fx.result(
		"ding",
		Config.StationInfo[job.station].label,
		("Locked by P%d"):format(player:GetAttribute("Slot") or 0),
		{ player }
	)
	Fx.toast(("%s locked (%d done)"):format(Config.StationInfo[job.station].label, count))
	if job.onDone then
		task.spawn(job.onDone, player)
	end
end

function Stations.tryStart(player, station)
	local job = jobs[station]
	if not job or job.done or not job.active then
		Fx.toast("This station is not live right now.", { player })
		return
	end
	if not Roster.isLiving(player) then
		return
	end
	if job.owner ~= player then
		local o = job.owner
		Fx.toast(
			o and ("This job belongs to Player %d."):format(o:GetAttribute("Slot") or 0) or "No owner yet.",
			{ player }
		)
		return
	end
	local zoneName = station
	if not Cues.inZone(player, zoneName) then
		Fx.toast("Stand inside the station's use zone.", { player })
		return
	end
	if sessions[player] then
		if sessions[player].station == station then
			return
		end
		closeSession(player, "switched")
	end
	local challenge = job.challenge
	local kind = Config.ChallengeInfo[challenge].kind
	local gen = generate(kind)
	local s = {
		id = HttpService:GenerateGUID(false),
		player = player,
		station = station,
		challenge = challenge,
		kind = kind,
		gen = gen,
		progress = 0,
		startT = Clock.now(),
		lastInput = Clock.now(),
		job = job,
		matched = {},
	}
	sessions[player] = s
	local minDur = Config.StationInfo[station].minDuration
	Net.fire(player, "MgOpen", {
		id = s.id,
		station = station,
		label = Config.StationInfo[station].label,
		challenge = challenge,
		challengeLabel = Config.ChallengeInfo[challenge].label,
		kind = kind,
		data = gen.public,
		minDuration = minDur,
		help = Config.ChallengeHelp[kind],
	})
	-- occupancy + minimum duration watcher
	task.spawn(function()
		while not s.closed do
			if not Roster.isLiving(player) or job.done or not job.active then
				closeSession(player, job.done and "done" or "closed")
				return
			end
			if not Cues.inZone(player, zoneName) then
				closeSession(player, "You left the use zone. Progress was reset.")
				Fx.toast("Left the station zone - progress reset.", { player })
				return
			end
			if s.progress >= gen.need then
				local elapsed = Clock.now() - s.startT
				Net.fire(player, "MgLocking", math.max(0, minDur - elapsed))
				if elapsed >= minDur then
					closeSession(player, "done")
					completeJob(job, player)
					return
				end
			end
			task.wait(0.2)
		end
	end)
end

local function tick(s, n, msg)
	Net.fire(s.player, "MgTick", s.id, n or s.progress, s.gen.need, msg)
end

Net.on("Mg", function(player, id, action, a, b)
	local s = sessions[player]
	if not s or s.id ~= id or s.closed then
		return
	end
	local now = Clock.now()
	local gen = s.gen
	if s.kind == "Timing" and action == "hit" then
		if now - s.lastInput >= 0.6 and s.progress < gen.need then
			s.progress += 1
			s.lastInput = now
			tick(s)
		end
	elseif s.kind == "Sequence" and action == "answer" and type(a) == "table" then
		local ok = #a == #gen.answer
		for i = 1, #gen.answer do
			if a[i] ~= gen.answer[i] then
				ok = false
			end
		end
		if ok then
			s.progress = 1
			tick(s)
		else
			Net.fire(player, "MgWrong", s.id, "Wrong order - watch again")
		end
	elseif s.kind == "Tuning" and action == "lock" and type(a) == "number" then
		local i = s.progress + 1
		if a == i and now - s.lastInput >= 1.1 then
			s.progress = i
			s.lastInput = now
			tick(s)
		end
	elseif s.kind == "Match" and action == "answer" and type(a) == "number" then
		local screen = gen.public.screens[a]
		if a == s.progress + 1 and screen then
			if b == screen.symbol then
				s.progress = a
				tick(s)
			else
				Net.fire(player, "MgWrong", s.id, "Not a match")
			end
		end
	elseif s.kind == "Patch" and action == "pair" then
		if a == b and not s.matched[a] and table.find(gen.public.left, a) then
			s.matched[a] = true
			s.progress += 1
			tick(s, s.progress, a)
		else
			Net.fire(player, "MgWrong", s.id, "Those shapes do not match")
		end
	elseif s.kind == "Channel" and action == "confirm" and type(a) == "number" then
		if gen.answer[a] and not s.matched[a] then
			s.matched[a] = true
			s.progress += 1
			tick(s, s.progress, a)
		else
			Net.fire(player, "MgWrong", s.id, "That channel's code does not match")
		end
	elseif action == "close" then
		closeSession(player, "closed")
	end
end)

---------------------------------------------------------------- assignment
-- Distribute unfinished station jobs among living players (GDD page 6 groupings).
function Stations.assign(stationList)
	local living = Roster.living()
	local n = math.min(#living, 4)
	if n == 0 then
		return
	end
	local unfinished = {}
	for _, st in ipairs(stationList) do
		local j = jobs[st]
		if j and not j.done then
			table.insert(unfinished, st)
		end
	end
	local groups = {}
	for _, g in ipairs(Config.AssignmentGroups[n]) do
		local filtered = {}
		for _, st in ipairs(g) do
			if table.find(unfinished, st) then
				table.insert(filtered, st)
			end
		end
		if #filtered > 0 then
			table.insert(groups, filtered)
		end
	end
	-- prefer giving each player the group containing their own station
	local free = table.clone(living)
	local assignment = {}
	for _, g in ipairs(groups) do
		local chosen
		for i, p in ipairs(free) do
			local slot = p:GetAttribute("Slot") or 0
			local own = Config.Slots[slot] and Config.Slots[slot].station
			if own and table.find(g, own) then
				chosen = table.remove(free, i)
				break
			end
		end
		assignment[g] = chosen
	end
	for _, g in ipairs(groups) do
		if not assignment[g] then
			assignment[g] = table.remove(free, 1) or living[1]
		end
		for order, st in ipairs(g) do
			local j = jobs[st]
			local owner = assignment[g]
			if j.owner ~= owner and j.owner and sessions[j.owner] and sessions[j.owner].station == st then
				closeSession(j.owner, "Job reassigned")
			end
			j.owner = owner
			local f = State.stationFolder(st)
			f:SetAttribute("Owner", owner.UserId)
			f:SetAttribute("OwnerSlot", owner:GetAttribute("Slot") or 0)
			f:SetAttribute("OwnerName", owner.DisplayName)
			f:SetAttribute("Order", order)
		end
	end
end

function Stations.reassign()
	local list = {}
	for st, j in pairs(jobs) do
		if j.active and not j.done and st ~= "Console" then
			table.insert(list, st)
		end
	end
	if #list > 0 then
		Stations.assign(Config.Stations)
	end
	local cj = jobs.Console
	if cj and cj.active and not cj.done and (not cj.owner or not Roster.isLiving(cj.owner)) then
		local living = Roster.living()
		if living[1] then
			cj.owner = living[1]
			local f = State.stationFolder("Console")
			f:SetAttribute("Owner", cj.owner.UserId)
			f:SetAttribute("OwnerSlot", cj.owner:GetAttribute("Slot") or 0)
			f:SetAttribute("OwnerName", cj.owner.DisplayName)
		end
	end
end

local function clearJobs()
	Stations.closeAll("closed")
	for _, st in ipairs({ "Recorder", "Breaker", "TV", "Radio", "Console" }) do
		Props.setEnabled("Station_" .. st, true)
	end
	table.clear(jobs)
	for _, f in ipairs(State.stations:GetChildren()) do
		f:SetAttribute("Active", false)
		f:SetAttribute("Done", false)
		f:SetAttribute("Owner", 0)
		f:SetAttribute("OwnerSlot", 0)
		f:SetAttribute("OwnerName", "")
	end
end
Stations.clear = clearJobs

-- One Sound Check wave. Returns number of failed jobs.
function Stations.runWave(round, abort)
	clearJobs()
	for _, st in ipairs(Config.Stations) do
		jobs[st] = { station = st, round = round, active = true, done = false, challenge = Stations.challengeFor(st) }
		local f = State.stationFolder(st)
		f:SetAttribute("Challenge", jobs[st].challenge)
		f:SetAttribute("Active", true)
		f:SetAttribute("Done", false)
		f:SetAttribute("Wave", round)
	end
	Stations.assign(Config.Stations)
	local living = #Roster.living()
	local window = Config.WaveWindow[math.clamp(living, 1, 4)]
	State.set("Objective", ("Wave %d: lock your stations"):format(round))
	Clock.setTimer(("Station wave %d"):format(round), window)
	Fx.sfx("Clapper")
	while Clock.timerRemaining() > 0 do
		if abort and abort() then
			break
		end
		local allDone = true
		for _, j in pairs(jobs) do
			if not j.done then
				allDone = false
			end
		end
		if allDone or #Roster.living() == 0 then
			break
		end
		task.wait(0.2)
	end
	Clock.clearTimer()
	local failed = 0
	local failedOwners = {}
	for _, st in ipairs(Config.Stations) do
		local j = jobs[st]
		if j and not j.done then
			failed += 1
			if j.owner and Roster.isLiving(j.owner) then
				failedOwners[j.owner] = failedOwners[j.owner] or {}
				table.insert(failedOwners[j.owner], Config.StationInfo[st].label)
			end
		end
	end
	Stations.closeAll("Wave over")
	for _, j in pairs(jobs) do
		j.active = false
	end
	for _, f in ipairs(State.stations:GetChildren()) do
		f:SetAttribute("Active", false)
	end
	if failed == 0 then
		Fx.result("ding", ("Station wave %d"):format(round), "All four stations locked")
	else
		for owner, labels in pairs(failedOwners) do
			Fx.result("wrong", "Station failed", table.concat(labels, ", ") .. " not locked in time", { owner })
			Roster.addStrike(owner, "failed assigned mission: " .. labels[1], Config.StationInfo.Recorder.room)
		end
	end
	return failed
end

-- A shared-console round in Return Signal: one owner runs a chosen challenge.
function Stations.runConsole(round, challenge, owner, window, abort)
	clearJobs()
	jobs.Console =
		{ station = "Console", round = round, active = true, done = false, challenge = challenge, owner = owner }
	local f = State.stationFolder("Console")
	f:SetAttribute("Challenge", challenge)
	f:SetAttribute("Active", true)
	f:SetAttribute("Done", false)
	f:SetAttribute("Owner", owner.UserId)
	f:SetAttribute("OwnerSlot", owner:GetAttribute("Slot") or 0)
	f:SetAttribute("OwnerName", owner.DisplayName)
	State.set(
		"Objective",
		("Console round %d: Player %d runs %s"):format(
			round,
			owner:GetAttribute("Slot") or 0,
			Config.ChallengeInfo[challenge].label
		)
	)
	Clock.setTimer(("Console round %d"):format(round), window)
	while Clock.timerRemaining() > 0 and not jobs.Console.done do
		if (abort and abort()) or #Roster.living() == 0 then
			break
		end
		task.wait(0.2)
	end
	Clock.clearTimer()
	local done = jobs.Console.done
	local o = jobs.Console.owner
	Stations.closeAll("Round over")
	jobs.Console.active = false
	f:SetAttribute("Active", false)
	if not done and o and Roster.isLiving(o) then
		Fx.result("wrong", "Console round failed", Config.ChallengeInfo[challenge].label .. " not finished", nil)
		Roster.addStrike(o, "failed the console challenge", "Den")
	end
	return done
end

return Stations
