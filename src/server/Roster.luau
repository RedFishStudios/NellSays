-- Party membership, slots, strikes, life state and spawning.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Fx = State.Fx

local Roster = {}
Roster.onThirdStrike = nil -- set by Main: function(player, reason)
Roster.inSession = false

pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
end)
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

Players.CharacterAutoLoads = false

local function setGroup(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end)
end

function Roster.resetAttributes(p)
	p:SetAttribute("Strikes", 0)
	p:SetAttribute("Alive", true)
	p:SetAttribute("Hidden", false)
	p:SetAttribute("HideSpot", "")
	p:SetAttribute("Crouching", false)
	p:SetAttribute("Exited", false)
	p:SetAttribute("Cause", "")
	p:SetAttribute("Outcome", "")
	p:SetAttribute("InCutscene", false)
end

local function setup(p)
	p:SetAttribute("Slot", 0)
	Roster.resetAttributes(p)
	p.CharacterAdded:Connect(function(char)
		setGroup(char)
		local hum = char:WaitForChild("Humanoid")
		hum.WalkSpeed = Config.WalkSpeed
		hum.UseJumpPower = false
		hum.JumpHeight = 2.5
		hum.BreakJointsOnDeath = false
		hum.Died:Connect(function()
			-- Falling out of the map etc: treat as a lethal catch so the run stays consistent
			if Roster.inSession and p:GetAttribute("Alive") and Roster.onThirdStrike then
				Roster.onThirdStrike(p, "Fell out of the house", "fall")
			end
		end)
	end)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do
	setup(p)
end

function Roster.all()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, p)
	end
	table.sort(list, function(a, b)
		local sa, sb = a:GetAttribute("Slot") or 0, b:GetAttribute("Slot") or 0
		if sa == 0 then
			sa = 99
		end
		if sb == 0 then
			sb = 99
		end
		if sa ~= sb then
			return sa < sb
		end
		return a.UserId < b.UserId
	end)
	return list
end

function Roster.isLiving(p)
	return p.Parent == Players and p:GetAttribute("Alive") == true and p:GetAttribute("Exited") ~= true
end

-- Alive, still inside, connected; in slot order.
function Roster.living()
	local list = {}
	for _, p in ipairs(Roster.all()) do
		if Roster.isLiving(p) then
			table.insert(list, p)
		end
	end
	return list
end

-- Alive (inside or exited)
function Roster.alive()
	local list = {}
	for _, p in ipairs(Roster.all()) do
		if p:GetAttribute("Alive") then
			table.insert(list, p)
		end
	end
	return list
end

function Roster.bySlot(slot)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Slot") == slot then
			return p
		end
	end
	return nil
end

-- Current owner of a numbered job: the slot holder if living, otherwise reassigned in party order.
function Roster.jobOwner(slot)
	local p = Roster.bySlot(slot)
	if p and Roster.isLiving(p) then
		return p
	end
	local living = Roster.living()
	if #living == 0 then
		return nil
	end
	-- deterministic reassignment: rotate through living players by slot index
	return living[((slot - 1) % #living) + 1]
end

function Roster.root(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

function Roster.humanoid(p)
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function Roster.spawn(p, cf)
	p:LoadCharacter()
	local char = p.Character or p.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		char:PivotTo(cf)
	end
end

function Roster.teleport(p, cf)
	local char = p.Character
	if char and char.PrimaryPart then
		char:PivotTo(cf)
	end
end

function Roster.addStrike(p, reason, room)
	if not Roster.isLiving(p) then
		return 0
	end
	local n = (p:GetAttribute("Strikes") or 0) + 1
	p:SetAttribute("Strikes", n)
	p:SetAttribute("LastMistake", reason)
	State.Fx.toast(("Player %d strike %d: %s"):format(p:GetAttribute("Slot") or 0, n, reason))
	require(ReplicatedStorage.Shared.Net).fire(p, "Strike", n, reason, room)
	if n == 2 then
		Fx.say("Nell", "I can see your strings.", "TV", { players = { p } })
	end
	if n >= Config.MaxStrikes and Roster.onThirdStrike then
		Roster.onThirdStrike(p, reason, "strike")
	end
	return n
end

function Roster.name(p)
	local slot = p:GetAttribute("Slot") or 0
	return ("Player %d (%s)"):format(slot, p.DisplayName)
end

return Roster
