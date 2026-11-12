-- Pre-game lobby: choose Player 1-4, choose a challenge, choose Full Episode or Quick Test, ready up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Fx = State.Fx

local Lobby = {}
Lobby.onStart = nil -- function(mode)
local H
local starting = false

local function slotOwner(i)
	return State.slotFolder(i):GetAttribute("Owner") or 0
end

local function refreshReady()
	local players = Players:GetPlayers()
	local ready = 0
	for _, p in ipairs(players) do
		if p:GetAttribute("Ready") then
			ready += 1
		end
	end
	State.set("ReadyCount", ready)
	State.set("PlayerCount", #players)
	return ready, #players
end

local function release(p)
	local s = p:GetAttribute("Slot") or 0
	if s > 0 then
		local f = State.slotFolder(s)
		if f:GetAttribute("Owner") == p.UserId then
			f:SetAttribute("Owner", 0)
			f:SetAttribute("OwnerName", "")
		end
	end
	p:SetAttribute("Slot", 0)
end

function Lobby.reset(keepSlots)
	starting = false
	State.set("Phase", "Lobby")
	State.set("Countdown", 0)
	for i = 1, 4 do
		local f = State.slotFolder(i)
		if not keepSlots then
			f:SetAttribute("Owner", 0)
			f:SetAttribute("OwnerName", "")
			f:SetAttribute("Challenge", 1)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Ready", false)
		Roster.resetAttributes(p)
		if not keepSlots then
			p:SetAttribute("Slot", 0)
		end
	end
	refreshReady()
end

function Lobby.spawnAll()
	for i, p in ipairs(Players:GetPlayers()) do
		task.spawn(Roster.spawn, p, H.spawns[(i - 1) % 4 + 1])
	end
end

local function autoAssign()
	for _, p in ipairs(Players:GetPlayers()) do
		if (p:GetAttribute("Slot") or 0) == 0 then
			for i = 1, 4 do
				if slotOwner(i) == 0 then
					local f = State.slotFolder(i)
					f:SetAttribute("Owner", p.UserId)
					f:SetAttribute("OwnerName", p.DisplayName)
					p:SetAttribute("Slot", i)
					break
				end
			end
		end
	end
end

local function tryStart(force)
	if starting or State.get("Phase") ~= "Lobby" then
		return
	end
	local ready, total = refreshReady()
	if not force and (ready < total or total == 0) then
		return
	end
	starting = true
	for t = 3, 1, -1 do
		State.set("Countdown", t)
		Fx.sfx("Click")
		task.wait(1)
		if State.get("Phase") ~= "Lobby" then
			return
		end
	end
	State.set("Countdown", 0)
	autoAssign()
	State.set("Phase", "Playing")
	if Lobby.onStart then
		Lobby.onStart(State.get("Mode") or "Full")
	end
end

function Lobby.bind(house)
	H = house
	State.set("Mode", "Full")
	Lobby.reset()
	Net.on("ClaimSlot", function(p, i)
		if State.get("Phase") ~= "Lobby" or type(i) ~= "number" or i < 1 or i > 4 then
			return
		end
		local owner = slotOwner(i)
		if owner ~= 0 and owner ~= p.UserId then
			Fx.toast("That slot is taken.", { p })
			return
		end
		release(p)
		local f = State.slotFolder(i)
		f:SetAttribute("Owner", p.UserId)
		f:SetAttribute("OwnerName", p.DisplayName)
		p:SetAttribute("Slot", i)
		p:SetAttribute("Ready", false)
		refreshReady()
	end)
	Net.on("ReleaseSlot", function(p)
		if State.get("Phase") == "Lobby" then
			release(p)
			p:SetAttribute("Ready", false)
			refreshReady()
		end
	end)
	Net.on("SetChallenge", function(p, i, choice)
		if State.get("Phase") ~= "Lobby" or type(i) ~= "number" or (choice ~= 1 and choice ~= 2) then
			return
		end
		local owner = slotOwner(i)
		-- owners pick their own; anyone may pick for an empty slot (solo/small parties)
		if owner == 0 or owner == p.UserId then
			State.slotFolder(i):SetAttribute("Challenge", choice)
		end
	end)
	Net.on("SetMode", function(p, mode)
		if State.get("Phase") == "Lobby" and (mode == "Full" or mode == "Quick") then
			State.set("Mode", mode)
			Fx.toast(("%s selected %s"):format(p.DisplayName, mode == "Full" and "FULL EPISODE" or "QUICK TEST"))
		end
	end)
	Net.on("Ready", function(p, on)
		if State.get("Phase") ~= "Lobby" then
			return
		end
		if on and (p:GetAttribute("Slot") or 0) == 0 then
			Fx.toast("Pick a player number first.", { p })
			return
		end
		p:SetAttribute("Ready", on == true)
		refreshReady()
		tryStart(false)
	end)
	Players.PlayerAdded:Connect(function(p)
		refreshReady()
		if State.get("Phase") == "Lobby" then
			task.wait(1)
			Roster.spawn(p, H.spawns[#Players:GetPlayers() % 4 + 1])
		else
			p:SetAttribute("Alive", false)
			p:SetAttribute("Outcome", "Joined late")
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if State.get("Phase") == "Lobby" then
			release(p)
		end
		task.defer(refreshReady)
	end)
end

Lobby.forceStart = function()
	tryStart(true)
end

return Lobby
