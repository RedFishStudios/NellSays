-- Simon Says engine. Every scored command is graded on the server.
-- A real command starts with "Nell says"; a fake omits it and passes by restraint.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Props = require(script.Parent.Props)
local Clock, Fx = State.Clock, State.Fx

local Cues = {}
local H
local looks = {} -- [player] = Vector3 camera look
local picks = {} -- [player] = symbol picked during the current symbol cue
local cueCounter = 0
Cues.active = nil

function Cues.bind(house)
	H = house
end

Net.on("Look", function(player, v)
	if typeof(v) == "Vector3" and v.Magnitude > 0.5 and v.Magnitude < 1.5 then
		looks[player] = v.Unit
	end
end)
Net.on("Crouch", function(player, on)
	player:SetAttribute("Crouching", on == true)
end)
Net.on("SymbolPick", function(player, sym)
	if type(sym) == "string" and Cues.active and (Cues.active.kind == "symbol" or Cues.active.kind == "pick") then
		if picks[player] == nil then
			picks[player] = sym
		end
	end
end)

local function hrp(p)
	return Roster.root(p)
end

function Cues.markUnder(p)
	local r = hrp(p)
	if not r then
		return nil
	end
	local pos = r.Position
	for _, m in ipairs(H.marks) do
		local mp = m.part.Position
		if math.abs(pos.X - mp.X) <= 1.5 and math.abs(pos.Z - mp.Z) <= 1.5 and pos.Y - mp.Y < 6 and pos.Y > mp.Y then
			return m
		end
	end
	return nil
end

function Cues.inZone(p, zoneName)
	local z = H.zones[zoneName]
	local r = hrp(p)
	if not (z and r) then
		return false
	end
	local d = Vector3.new(r.Position.X - z.center.X, 0, r.Position.Z - z.center.Z).Magnitude
	return d <= z.radius and math.abs(r.Position.Y - 3 - z.y) < 6
end

local function lookAwayFromTV(p)
	local look = looks[p]
	local r = hrp(p)
	if not (look and r) then
		return false
	end
	local toTv = (H.tvPos - r.Position)
	toTv = Vector3.new(toTv.X, 0, toTv.Z).Unit
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return true -- looking straight up or down
	end
	return flat.Unit:Dot(toTv) < math.cos(math.rad(55))
end
Cues.lookAwayFromTV = lookAwayFromTV

local function lookingAtTV(p, point)
	local look = looks[p]
	local r = hrp(p)
	if not (look and r) then
		return false
	end
	local to = ((point or H.tvPos) - r.Position)
	to = Vector3.new(to.X, 0, to.Z).Unit
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return false
	end
	return flat.Unit:Dot(to) > math.cos(math.rad(35))
end
Cues.lookingAtTV = lookingAtTV

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Plain line with caption (no grading). Waits for the line.
function Cues.say(text, speaker, source, opts)
	local dur = Fx.say(speaker or "Nell", text, source or "TV", opts)
	Clock.wait(dur)
	return dur
end

local function participants(spec)
	local list = {}
	if spec.target then
		local owner = Roster.jobOwner(spec.target)
		if owner and not owner:GetAttribute("InCutscene") then
			table.insert(list, owner)
		end
		return list
	end
	for _, p in ipairs(Roster.living()) do
		if not p:GetAttribute("InCutscene") and p ~= spec.exclude then
			table.insert(list, p)
		end
	end
	return list
end

--[[
spec = {
	text, real, kind, window, practice, label, hint, source, speaker,
	color (mark), props (touch/fake), steps (seq), zone, zoneFor(p) (zone), target (slot number)
}
Returns { passed = {players}, failed = {players}, allPassed = bool }
]]
function Cues.run(spec)
	cueCounter += 1
	local id = cueCounter
	local kind = spec.kind
	local window = spec.window or Config.Windows[kind] or 8
	if not spec.real and not spec.window then
		window = Config.Windows.fake
	end
	-- Speak first; the response window starts after the complete line and caption.
	State.set("CueId", id)
	State.set("CueText", spec.text)
	State.set("CueSource", spec.source or "TV")
	State.set("CueKind", "")
	State.set("CueHint", spec.hint or "")
	State.set("CueColor", spec.color or "")
	State.set("CueTarget", spec.target or 0)
	State.set("CueOptions", spec.options and table.concat(spec.options, ",") or "")
	State.set("CueRemaining", 0)
	local dur = Fx.say(spec.speaker or "Nell", spec.text, spec.source or "TV", { pos = spec.pos })
	Clock.wait(dur)

	local players = participants(spec)
	local state = {}
	local startT = Clock.now()
	table.clear(picks)
	for _, p in ipairs(players) do
		local r = hrp(p)
		state[p] = {
			fail = false,
			pass = false,
			reason = nil,
			startPos = r and r.Position or Vector3.zero,
			startLook = looks[p] or Vector3.new(0, 0, -1),
			crouchedAtStart = p:GetAttribute("Crouching") == true,
			hold = 0,
			step = 1,
		}
	end
	Cues.active = { id = id, kind = kind, spec = spec }
	State.set("CueKind", kind)
	State.set("CueWindow", window)
	State.set("CueReal", nil)

	-- Prop interactions
	local unlisten
	unlisten = Props.listen(function(player, propId)
		local s = state[player]
		if not s or s.fail then
			return
		end
		local elapsed = Clock.now() - startT
		if elapsed > window then
			return
		end
		if spec.real then
			if kind == "touch" or kind == "seq" then
				local steps = spec.steps or {}
				local want = steps[s.step]
				if want and want.type == "touch" and want.id == propId then
					s.step += 1
					Net.fire(player, "CueTick", s.step - 1, #steps)
					if s.step > #steps then
						s.pass = true
						if spec.any then
							-- one player completes it for the whole party
							for _, other in pairs(state) do
								if not other.fail then
									other.pass = true
								end
							end
						end
					end
				end
			end
		else
			for _, pid in ipairs(spec.props or {}) do
				if pid == propId then
					s.fail = true
					s.reason = "followed a fake: " .. spec.text
				end
			end
		end
	end)

	Cues._unlisten = unlisten
	local last = Clock.now()
	while true do
		local now = Clock.now()
		local elapsed = now - startT
		local dt = now - last
		last = now
		State.set("CueRemaining", math.max(0, window - elapsed))
		if elapsed >= window then
			break
		end
		local allDone = true
		for _, p in ipairs(players) do
			local s = state[p]
			if Roster.isLiving(p) and not s.fail then
				local r = hrp(p)
				if kind == "mark" then
					local m = Cues.markUnder(p)
					if not spec.real and m and m.color == spec.color and elapsed > 0.4 then
						s.fail = true
						s.reason = "stepped on " .. spec.color .. " without Nell says"
					end
				elseif kind == "crouch" and spec.real then
					if p:GetAttribute("Crouching") then
						s.hold += dt
						if s.hold >= 2 then
							s.pass = true
						end
					else
						s.hold = 0
					end
				elseif kind == "uncrouch" and not spec.real then
					if s.crouchedAtStart and not p:GetAttribute("Crouching") and elapsed > 0.3 then
						s.fail = true
						s.reason = "stood up without Nell says"
					end
				elseif kind == "still" and spec.real then
					if elapsed < 0.7 then
						s.startPos = r and r.Position or s.startPos
					elseif r and flatDist(r.Position, s.startPos) > 1.2 then
						s.fail = true
						s.reason = "moved during Nell's freeze"
					end
				elseif kind == "move" and not spec.real then
					if elapsed < 0.3 then
						s.startPos = r and r.Position or s.startPos
					elseif r and flatDist(r.Position, s.startPos) > 2.4 then
						s.fail = true
						s.reason = "ran without Nell says"
					end
				elseif kind == "lookaway" and spec.real then
					if elapsed > 0.7 and lookAwayFromTV(p) then
						s.hold += dt
						if s.hold >= 2 then
							s.pass = true
						end
					else
						s.hold = 0
					end
				elseif kind == "climb" and not spec.real then
					if r and r.Position.Y > 7 then
						s.fail = true
						s.reason = "followed the voice upstairs"
					end
				elseif kind == "pick" and spec.real then
					local pick = picks[p]
					if pick ~= nil and not s.pass and not s.fail then
						if pick == spec.answer then
							s.pass = true
						else
							s.fail = true
							s.reason = "picked " .. pick .. " instead of " .. spec.answer
						end
					end
				elseif kind == "lookat" and spec.real then
					if lookingAtTV(p, spec.point) then
						s.hold += dt
						if s.hold >= 2 then
							s.pass = true
						end
					else
						s.hold = 0
					end
				elseif kind == "lookback" and not spec.real then
					local look = looks[p]
					if look and elapsed > 0.5 then
						local a = Vector3.new(look.X, 0, look.Z)
						local b = Vector3.new(s.startLook.X, 0, s.startLook.Z)
						if a.Magnitude > 0.1 and b.Magnitude > 0.1 and a.Unit:Dot(b.Unit) < -0.35 then
							s.fail = true
							s.reason = "looked behind without Nell says"
						end
					end
				elseif kind == "seq" and spec.real then
					local want = spec.steps[s.step]
					if want and want.type == "mark" then
						local m = Cues.markUnder(p)
						if m and m.color == want.color then
							s.step += 1
							Net.fire(p, "CueTick", s.step - 1, #spec.steps)
							if s.step > #spec.steps then
								s.pass = true
							end
						end
					end
				elseif kind == "symbol" and spec.real then
					local pick = picks[p]
					if pick ~= nil and not s.pass then
						local m = Cues.markUnder(p)
						if m and m.symbol == pick then
							s.pass = true
						else
							s.fail = true
							s.reason = m and ("picked the wrong symbol (" .. m.symbol .. " was under you)")
								or "was not standing on a mark"
						end
					end
				end
				if not spec.real or not s.pass then
					allDone = false
				end
			end
		end
		-- Real one-shot commands end early when everyone has passed (hand the time to the next cue)
		if
			spec.real
			and allDone
			and kind ~= "mark"
			and kind ~= "zone"
			and kind ~= "still"
			and kind ~= "away"
			and elapsed > 0.5
		then
			break
		end
		task.wait(0.1)
	end
	unlisten()
	Cues.active = nil
	State.set("CueKind", "")
	State.set("CueRemaining", 0)

	-- Final evaluation for end-of-window checks
	local passed, failed = {}, {}
	for _, p in ipairs(players) do
		local s = state[p]
		if Roster.isLiving(p) and not p:GetAttribute("InCutscene") then
			if spec.real and not s.fail and not s.pass then
				if kind == "mark" then
					local m = Cues.markUnder(p)
					s.pass = m ~= nil and m.color == spec.color
					s.reason = s.pass and nil or ("was not on a " .. spec.color .. " mark")
				elseif kind == "still" then
					s.pass = true
				elseif kind == "away" then
					local r = hrp(p)
					s.pass = r ~= nil and flatDist(r.Position, spec.point) > spec.radius
					s.reason = s.pass and nil or "stayed too close"
				elseif kind == "zone" then
					local zn = spec.zoneFor and spec.zoneFor(p) or spec.zone
					s.pass = zn == nil or Cues.inZone(p, zn)
					s.reason = s.pass and nil or ("did not reach " .. (spec.zoneLabel or zn or "the spot"))
				else
					s.reason = s.reason or ("missed: " .. spec.text)
				end
			elseif not spec.real and not s.fail then
				s.pass = true
			end
			if s.pass and not s.fail then
				table.insert(passed, p)
			else
				s.reason = s.reason or ("missed: " .. spec.text)
				table.insert(failed, { player = p, reason = s.reason })
			end
		end
	end

	local label = spec.label or (spec.real and "Command" or "Restraint")
	if #failed == 0 then
		if #passed > 0 then
			Fx.result("ding", label, ("%d/%d passed"):format(#passed, #passed))
		end
	else
		local names = {}
		for _, f in ipairs(failed) do
			table.insert(names, ("P%d"):format(f.player:GetAttribute("Slot") or 0))
		end
		Fx.result("wrong", label, table.concat(names, ", ") .. ": " .. failed[1].reason)
		if not spec.practice then
			for _, f in ipairs(failed) do
				local r = hrp(f.player)
				Roster.addStrike(f.player, f.reason, r and H.roomAt(r.Position) or "")
			end
		end
	end
	-- Short beat so the result sound is clear before the next scoring cue
	Clock.wait(1.0)
	State.set("CueText", "")
	return { passed = passed, failed = failed, allPassed = #failed == 0 }
end

-- Called when a chapter thread is cancelled mid-cue.
function Cues.abort()
	if Cues._unlisten then
		Cues._unlisten()
		Cues._unlisten = nil
	end
	Cues.active = nil
	State.set("CueKind", "")
	State.set("CueText", "")
	State.set("CueRemaining", 0)
end

-- Convenience builders -------------------------------------------------------------
local C = {}
Cues.C = C
function C.mark(color, real, text)
	return {
		kind = "mark",
		real = real,
		color = color,
		text = text
			or (
				real and ("Nell says, stand on a " .. color:lower() .. " mark.")
				or ("Change to " .. color:lower() .. ".")
			),
		hint = color .. " mark (" .. Config.MarkColors[color].pattern .. ")",
	}
end
function C.crouch(real)
	return real
			and { kind = "crouch", real = true, text = "Nell says, crouch.", hint = "Hold crouch (C) for 2 seconds" }
		or { kind = "uncrouch", real = false, text = "Stand up now.", hint = "Crouch / stand" }
end
function C.still(real)
	return real
			and {
				kind = "still",
				real = true,
				text = "Nell says, hold still.",
				window = 3.2,
				hint = "Do not walk. Looking is fine.",
			}
		or { kind = "move", real = false, text = "Run.", hint = "Run / stay" }
end
function C.lookAway()
	return {
		kind = "lookaway",
		real = true,
		text = "Nell says, look away from the TV.",
		hint = "Turn your view away from the TV",
	}
end
function C.lookAt(point, text, hint)
	return {
		kind = "lookat",
		real = true,
		point = point,
		text = text or "Nell says, face the television.",
		hint = hint or "Look at the TV for 2 seconds",
	}
end
function C.away(point, radius, text)
	return { kind = "away", real = true, point = point, radius = radius, text = text, window = 6, hint = "Move away" }
end
function C.climb(text)
	return { kind = "climb", real = false, text = text, window = 6, hint = "Stairs" }
end
function C.pick(answer, options, text)
	return {
		kind = "pick",
		real = true,
		answer = answer,
		options = options,
		text = text,
		window = 9,
		hint = "Pick " .. answer,
	}
end
function C.any(propId, text)
	return {
		kind = "seq",
		real = true,
		any = true,
		steps = { { type = "touch", id = propId } },
		text = text,
		window = 15,
		hint = "Anyone can press it",
	}
end
function C.lookBack()
	return { kind = "lookback", real = false, text = "Look behind you.", hint = "Look behind" }
end
function C.touch(ids, text, real, window)
	local steps = {}
	for _, id in ipairs(ids) do
		table.insert(steps, { type = "touch", id = id })
	end
	if real == false then
		return { kind = "touch", real = false, props = ids, text = text, window = window, hint = "Touch" }
	end
	return {
		kind = "seq",
		real = true,
		steps = steps,
		text = text,
		window = window or (#ids > 1 and 12 or 8),
		hint = #ids > 1 and "Two steps, in order" or "Touch it",
	}
end
function C.seq(steps, text, window)
	return { kind = "seq", real = true, steps = steps, text = text, window = window or 12, hint = "Two steps, in order" }
end
function C.named(slot, propId, text)
	local s = C.touch({ propId }, text, true, 6)
	s.target = slot
	s.hint = ("Only Player %d"):format(slot)
	return s
end
function C.symbol()
	return {
		kind = "symbol",
		real = true,
		text = "Nell says, match the symbol under your feet.",
		hint = "Pick the symbol on your mark",
		options = { "Star", "Circle", "Triangle", "Square" },
	}
end
function C.zone(zone, text, label, window)
	return {
		kind = "zone",
		real = true,
		zone = zone,
		zoneLabel = label,
		text = text,
		window = window or 12,
		hint = label,
	}
end

return Cues
