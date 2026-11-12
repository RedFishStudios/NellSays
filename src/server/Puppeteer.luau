-- The Puppeteer: one physical, kinematic creature. Patrols door to door, confirms sight of exposed
-- players for 0.6s, then sprints at 21 studs/s and kills on clear contact at any strike count.
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Figures = require(script.Parent.Build.Figures)
local Clock, Fx = State.Clock, State.Fx

local M = Config.Monster
local Puppeteer = {}
Puppeteer.onCatch = nil -- function(player, room)

local H
local model
local pos = Vector3.new(0, -200, 0)
local yaw = 0
local fold = 0
local active = false
local runToken = 0
local chaseTarget = nil
local sightTime = {}
local renderConn

local PARK = Vector3.new(0, -300, 0)

local function render()
	if not model then
		return
	end
	local rot = CFrame.Angles(0, yaw, 0)
	model.Lower:PivotTo(CFrame.new(pos) * rot)
	model.Upper:PivotTo(CFrame.new(pos + Vector3.new(0, 5 - fold * 4.5, 0)) * rot * CFrame.Angles(-fold * 0.35, 0, 0))
end

function Puppeteer.bind(house)
	H = house
	if model then
		model:Destroy()
	end
	model = Figures.puppeteer(workspace, "Puppeteer")
	pos = PARK
	render()
	if renderConn then
		renderConn:Disconnect()
	end
	local acc = 0
	renderConn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 30 then
			acc = 0
			-- fold to 8 studs near doorways (bar held level)
			local target = 0
			if active then
				for _, d in ipairs(H.doors) do
					if
						math.abs(d.pos.Y - pos.Y) < 4
						and Vector3.new(d.pos.X - pos.X, 0, d.pos.Z - pos.Z).Magnitude < 5.5
					then
						target = 1
						break
					end
				end
				if pos.Y > 0.5 and pos.Y < 13.5 then
					target = 1 -- stairs
				end
			end
			fold += (target - fold) * 0.25
			render()
		end
	end)
end

function Puppeteer.model()
	return model
end
function Puppeteer.position()
	return pos
end
function Puppeteer.isActive()
	return active
end

local function eye()
	return pos + Vector3.new(0, 11.6 - fold * 4.5, 0)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function excludeList()
	local list = { model }
	local hides = H.root:FindFirstChild("HideSpots")
	if hides then
		table.insert(list, hides)
	end
	local zones = H.root:FindFirstChild("Zones")
	if zones then
		table.insert(list, zones)
	end
	return list
end

-- Clear line from a point to a player's character (never through walls)
local function clearLine(from, player, aimPart)
	local char = player.Character
	local part = char and (char:FindFirstChild(aimPart or "Head") or char:FindFirstChild("HumanoidRootPart"))
	if not part then
		return false
	end
	local to = part.Position
	local dir = to - from
	rayParams.FilterDescendantsInstances = excludeList()
	local hit = workspace:Raycast(from, dir.Unit * (dir.Magnitude + 1), rayParams)
	return hit ~= nil and hit.Instance:IsDescendantOf(char)
end

local function canSee(player)
	if player:GetAttribute("Hidden") or player:GetAttribute("InCutscene") then
		return false
	end
	local hrp = Roster.root(player)
	if not hrp then
		return false
	end
	local e = eye()
	local to = hrp.Position - e
	if to.Magnitude > M.SightRange then
		return false
	end
	local facing = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local flat = Vector3.new(to.X, 0, to.Z)
	if flat.Magnitude > 3 and flat.Unit:Dot(facing) < math.cos(M.SightHalfAngle) then
		return false
	end
	return clearLine(e, player, "Head") or clearLine(e, player, "HumanoidRootPart")
end

local function faceTowards(target, rate)
	local d = target - pos
	if Vector3.new(d.X, 0, d.Z).Magnitude < 0.05 then
		return
	end
	local want = math.atan2(-d.X, -d.Z)
	local diff = (want - yaw + math.pi) % (2 * math.pi) - math.pi
	yaw += diff * (rate or 1)
end

local function computePath(target)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 7,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(pos + Vector3.new(0, 1.5, 0), target + Vector3.new(0, 1.5, 0))
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		local pts = {}
		for _, w in ipairs(path:GetWaypoints()) do
			table.insert(pts, w.Position)
		end
		return pts
	end
	return nil
end

-- Moves along points at speed. stopCheck() is polled each frame; returns "stop" or "done".
local function follow(points, speed, stopCheck, token)
	for _, wp in ipairs(points) do
		while true do
			if token ~= runToken then
				return "cancel"
			end
			if stopCheck and stopCheck() then
				return "stop"
			end
			local dt = task.wait()
			if not Clock.paused() then
				local d = wp - pos
				local dist = d.Magnitude
				local step = speed * dt
				if dist <= step then
					pos = wp
					break
				end
				pos += d.Unit * step
				faceTowards(wp, 0.35)
			end
		end
	end
	return "done"
end

local function roomOf(p)
	local hrp = Roster.root(p)
	return hrp and H.roomAt(hrp.Position) or "the house"
end

-- Sight accumulation; returns a player to commit to, or nil.
local lastSight = 0
local function sightTick()
	local now = os.clock()
	local dt = now - lastSight
	if dt < 0.1 then
		return nil
	end
	lastSight = now
	if Clock.paused() then
		return nil
	end
	for _, p in ipairs(Roster.living()) do
		if canSee(p) then
			sightTime[p] = (sightTime[p] or 0) + math.min(dt, 0.2)
			if sightTime[p] >= M.SightConfirm then
				return p
			end
		else
			sightTime[p] = 0
		end
	end
	return nil
end

Puppeteer.spotted = {}

local function chase(target, token)
	chaseTarget = target
	Puppeteer.spotted[target] = true
	State.set("ChaseSlot", target:GetAttribute("Slot") or 0)
	Fx.result("wrong", "Spotted", "The Puppeteer saw you - RUN", { target })
	Fx.sfx("Stinger")
	Fx.sfx("Footsteps", pos)
	local started = Clock.now()
	local caught = false
	while token == runToken do
		if not Roster.isLiving(target) or target.Parent == nil then
			break
		end
		if Clock.now() - started > M.ChaseGiveUp then
			Fx.toast("The Puppeteer lost the trail.")
			break
		end
		local hrp = Roster.root(target)
		if not hrp then
			break
		end
		local tpos = hrp.Position - Vector3.new(0, 3, 0)
		-- contact check
		local flat = Vector3.new(tpos.X - pos.X, 0, tpos.Z - pos.Z).Magnitude
		if flat <= M.KillRange + 1.6 and math.abs(tpos.Y - pos.Y) < 5 and not Clock.paused() then
			local chest = pos + Vector3.new(0, 4, 0)
			if clearLine(chest, target, "HumanoidRootPart") or target:GetAttribute("Hidden") then
				caught = true
				break
			end
		end
		local points = computePath(tpos) or { tpos }
		local t0 = os.clock()
		local res = follow(points, M.SprintSpeed, function()
			if os.clock() - t0 > 0.35 then
				return true
			end
			local h2 = Roster.root(target)
			if not h2 then
				return true
			end
			local p2 = h2.Position - Vector3.new(0, 3, 0)
			return Vector3.new(p2.X - pos.X, 0, p2.Z - pos.Z).Magnitude <= M.KillRange + 1.6
				and math.abs(p2.Y - pos.Y) < 5
		end, token)
		if res == "cancel" then
			break
		end
		if (os.clock() - t0) % 1 < 0.05 then
			Fx.sfx("Footsteps", pos, 0.8)
		end
	end
	chaseTarget = nil
	State.set("ChaseSlot", 0)
	sightTime = {}
	if caught and token == runToken and Puppeteer.onCatch then
		Puppeteer.onCatch(target, roomOf(target))
		-- wait for the shared death scene to finish
		task.wait(0.2)
		while Clock.paused() do
			task.wait(0.1)
		end
	end
end

-- Run a patrol. route: nodes list; loopFrom: index to loop back to. duration: stage seconds (nil = until stopped).
function Puppeteer.run(route, loopFrom, duration, startIndex)
	runToken += 1
	local token = runToken
	active = true
	sightTime = {}
	Puppeteer.spotted = {}
	State.set("MonsterActive", true)
	local first = route[startIndex or 1]
	pos = first.pos
	yaw = 0
	render()
	Fx.sfx("WoodTaps", pos)
	local endsAt = duration and (Clock.now() + duration) or math.huge
	local i = (startIndex or 1) + 1
	local function timeUp()
		return Clock.now() >= endsAt
	end
	while token == runToken do
		if timeUp() and not chaseTarget then
			break
		end
		if i > #route then
			i = loopFrom or 1
		end
		local nodeInfo = route[i]
		local points = computePath(nodeInfo.pos) or { nodeInfo.pos }
		local spotted
		local res = follow(points, M.WalkSpeed, function()
			if timeUp() then
				return true
			end
			spotted = sightTick()
			return spotted ~= nil
		end, token)
		if res == "cancel" then
			return
		end
		if spotted then
			chase(spotted, token)
		elseif not timeUp() then
			-- stop at the doorway: pause, listen, deliberate mask turn into the room
			if nodeInfo.look then
				Fx.sfx("WoodTaps", pos, 0.7)
				local t0 = Clock.now()
				while Clock.now() - t0 < (nodeInfo.wait or 1) and token == runToken do
					faceTowards(nodeInfo.look, 0.15)
					local s = sightTick()
					if s then
						chase(s, token)
						break
					end
					task.wait()
				end
			end
			i += 1
		end
	end
	if token == runToken then
		Puppeteer.park()
	end
end

function Puppeteer.park()
	runToken += 1
	active = false
	chaseTarget = nil
	pos = PARK
	State.set("MonsterActive", false)
	State.set("ChaseSlot", 0)
	render()
end

-- Brief staged appearance (never hunts)
function Puppeteer.stageAt(cf, seconds)
	runToken += 1
	active = false
	pos = cf.Position
	local _, y = cf:ToOrientation()
	yaw = y
	render()
	task.delay(seconds or 2, function()
		if not active then
			pos = PARK
			render()
		end
	end)
end

function Puppeteer.isChasing()
	return chaseTarget ~= nil
end

return Puppeteer
