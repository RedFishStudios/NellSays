-- Shared 7.5s death scene for third strikes and lethal catches, and the persistent TV puppets.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Hiding = require(script.Parent.Hiding)
local Kit = require(script.Parent.Build.Kit)
local Clock, Fx = State.Clock, State.Fx

local Death = {}
Death.onAfter = nil -- function() after the queue empties
Death.onVictim = nil -- function(player) as soon as a death is confirmed (close sessions etc.)
local H
local queue = {}
local running = false
local puppetCount = 0

function Death.bind(house)
	H = house
end

function Death.busy()
	return running or #queue > 0
end

function Death.puppetCount()
	return puppetCount
end

local function nearestDoor(pos)
	local best, bestD
	for _, d in ipairs(H.doors) do
		if math.abs(d.pos.Y - (pos.Y - 3)) < 6 then
			local dist = (Vector3.new(d.pos.X, 0, d.pos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if dist > 2 and (not bestD or dist < bestD) then
				best, bestD = d, dist
			end
		end
	end
	return best and best.pos or (pos + Vector3.new(6, -3, 0))
end

local function stripScripts(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") or d:IsA("Sound") then
			d:Destroy()
		end
	end
end

-- Build an upright, motionless puppet of the victim on the next mark beside or behind Nell.
local function makePuppet(snapshot, player, slot)
	local studio = H.studio
	puppetCount += 1
	local idx = math.min(puppetCount, #studio.puppetMarks)
	local mark = studio.puppetMarks[idx]
	local m = snapshot
	if not m then
		return
	end
	m.Name = "Puppet_" .. slot
	m:SetAttribute("Slot", slot)
	m:SetAttribute("PlayerName", player and player.DisplayName or "?")
	m:SetAttribute("Index", idx)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
		hum.PlatformStand = true
	end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = false
			d.CollisionGroup = "Default"
		end
	end
	if not hrp then
		return
	end
	hrp.Anchored = true
	hrp.Transparency = 1
	-- head lowered, arms hanging
	for _, j in ipairs(m:GetDescendants()) do
		if j:IsA("Motor6D") then
			j.Transform = CFrame.new()
			if j.Name == "Neck" then
				j.C0 = j.C0 * CFrame.Angles(math.rad(-28), 0, 0)
			end
		end
	end
	local cf, size = m:GetBoundingBox()
	local footOffset = hrp.Position.Y - (cf.Position.Y - size.Y / 2)
	local target = CFrame.new(mark.Position + Vector3.new(0, footOffset + 0.5, 0))
	m:PivotTo(target * (hrp.CFrame:Inverse() * m:GetPivot()))
	hrp.CFrame = target
	m.Parent = studio.puppets
	-- pale strings to crown, shoulders and wrists
	task.wait()
	local top = mark.Position.Y + 13
	local function str(partName, dx)
		local part = m:FindFirstChild(partName)
		if part then
			local a = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
			Kit.string(m, a, Vector3.new(a.X + (dx or 0), top, a.Z), Color3.fromRGB(235, 228, 210), 0.05)
		end
	end
	str("Head")
	str("LeftUpperArm", -0.3)
	str("RightUpperArm", 0.3)
	str("LeftHand", -0.5)
	str("RightHand", 0.5)
	str("Left Arm", -0.5)
	str("Right Arm", 0.5)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "String" then
			d.Anchored = true
		end
	end
end

local function playOne(entry)
	local p = entry.player
	local slot = entry.slot
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pos = hrp and hrp.Position or entry.pos or H.spawns[1].Position
	local door = nearestDoor(pos)
	local studio = H.studio
	-- everyone is in the cutscene; graded input pauses
	for _, other in ipairs(Players:GetPlayers()) do
		other:SetAttribute("InCutscene", true)
	end
	Fx.cine("Death", {
		userId = p.UserId,
		name = p.DisplayName,
		slot = slot,
		pos = pos,
		door = door,
		cause = entry.reason,
		kind = entry.kind,
		darkCam = studio.darkCam,
		darkDoor = studio.darkDoorPos,
		stageCam = studio.wideCam,
	})
	local snapshot
	if char then
		char.Archivable = true
		local ok, c = pcall(function()
			return char:Clone()
		end)
		if ok and c then
			stripScripts(c)
			snapshot = c
		end
	end
	if hrp then
		hrp.Anchored = true
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
		end
		-- 0-1.2: jerk backwards as the string snaps taut
		local away = (pos - door)
		away = Vector3.new(away.X, 0, away.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
		local lying = CFrame.lookAt(pos, pos + away) * CFrame.Angles(math.rad(70), 0, 0)
		TweenService:Create(
			hrp,
			TweenInfo.new(0.35, Enum.EasingStyle.Back),
			{ CFrame = lying + away * 1.2 - Vector3.new(0, 1.6, 0) }
		):Play()
		Fx.sfx("StringTwang", pos)
		task.wait(1.2)
		-- 1.2-3.5: dragged across the floor to the doorway
		Fx.sfx("Drag", pos)
		local doorPos = Vector3.new(door.X, pos.Y - 1.6, door.Z)
		local dragCF = CFrame.lookAt(doorPos, doorPos + away) * CFrame.Angles(math.rad(70), 0, 0)
		TweenService
			:Create(hrp, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = dragCF })
			:Play()
		task.wait(2.3)
		-- 3.5-5.2: into the dark room on the set; Puppeteer seizes them; door slams
		local dd = studio.darkDoorPos
		hrp.CFrame = CFrame.lookAt(dd + Vector3.new(0, 1.4, -2.5), dd + Vector3.new(0, 1.4, -6))
			* CFrame.Angles(math.rad(70), 0, 0)
		TweenService:Create(hrp, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.lookAt(dd + Vector3.new(0, 3, 3.5), dd + Vector3.new(0, 3, 0)),
		}):Play()
		task.wait(1.25)
		local hinge = studio.darkHinge
		TweenService:Create(studio.darkDoor, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = hinge * CFrame.new(3, 0, 0),
		}):Play()
		Fx.sfx("DoorSlam", dd)
		task.wait(0.25)
		Fx.sfx("Impact")
		task.wait(0.2)
	else
		task.wait(5)
	end
	-- remove the body; the player now spectates
	if p.Character then
		p.Character:Destroy()
		p.Character = nil
	end
	-- 5.2-7.5: TV stage reveal with the new puppet
	makePuppet(snapshot, p, slot)
	State.set("PuppetCount", puppetCount)
	task.wait(0.6)
	Fx.say("Nell", "There you are.", "TV")
	task.wait(1.7)
	-- reopen the dark door for the next time
	studio.darkDoor.CFrame = studio.darkHinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(3, 0, 0)
end

local function process()
	if running then
		return
	end
	running = true
	Clock.hold("death")
	while #queue > 0 do
		local entry = table.remove(queue, 1)
		playOne(entry)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		other:SetAttribute("InCutscene", false)
	end
	running = false
	Clock.release("death")
	if Death.onAfter then
		task.spawn(Death.onAfter)
	end
end

-- kind: "strike" (third strike), "catch" (Puppeteer), "fall", "exit" (missed timed exit)
function Death.kill(player, reason, kind, room)
	if player:GetAttribute("Alive") ~= true then
		return
	end
	player:SetAttribute("Alive", false)
	player:SetAttribute("Outcome", "Puppet")
	local cause = kind == "catch" and ("Caught by the Puppeteer in the " .. (room or "house"))
		or (kind == "strike" and ("Third strike: " .. tostring(reason)) or tostring(reason))
	player:SetAttribute("Cause", cause)
	Hiding.exit(player, true)
	Hiding.forget(player)
	if Death.onVictim then
		Death.onVictim(player)
	end
	local hrp = Roster.root(player)
	table.insert(queue, {
		player = player,
		slot = player:GetAttribute("Slot") or 0,
		reason = cause,
		kind = kind,
		pos = hrp and hrp.Position,
	})
	-- stable party order when deaths land together
	table.sort(queue, function(a, b)
		return a.slot < b.slot
	end)
	task.spawn(process)
end

function Death.reset()
	queue = {}
	puppetCount = 0
	State.set("PuppetCount", 0)
	if H and H.studio then
		H.studio.puppets:ClearAllChildren()
	end
end

return Death
