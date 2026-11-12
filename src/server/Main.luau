--@script:server
-- Hush Hour server entry point.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Server = script.Parent

local State = require(Server.State)
local Roster = require(Server.Roster)
local House = require(Server.Build.House)
local Props = require(Server.Props)
local Cues = require(Server.Cues)
local Stations = require(Server.Stations)
local Hiding = require(Server.Hiding)
local Puppeteer = require(Server.Puppeteer)
local Death = require(Server.Death)
local Lights = require(Server.Lights)
local Director = require(Server.Director)
local Lobby = require(Server.Lobby)
local Clock, Fx = State.Clock, State.Fx

local H = House.build()
Props.bind(H)
Cues.bind(H)
Stations.bind(H)
Hiding.bind(H)
Puppeteer.bind(H)
Death.bind(H)
Lights.bind(H)
Director.bind(H)
Lobby.bind(H)

State.set("IsStudio", RunService:IsStudio())
State.set("TV", "off")
State.set("NellExpr", "idle")

Roster.onThirdStrike = function(p, reason, kind)
	Death.kill(p, reason, kind == "fall" and "fall" or "strike")
end
Puppeteer.onCatch = function(p, room)
	Death.kill(p, "caught", "catch", room)
end
Death.onVictim = function(p)
	Stations.closeSession(p, "eliminated")
end
Death.onAfter = function()
	Stations.reassign()
	Director.checkEnd()
end
Lobby.onStart = function(mode)
	Director.start(mode)
end

Players.PlayerRemoving:Connect(function(p)
	if Roster.inSession and p:GetAttribute("Alive") then
		p:SetAttribute("Alive", false)
		p:SetAttribute("Outcome", "Left")
		Hiding.forget(p)
		Stations.closeSession(p, "left")
		task.defer(function()
			Stations.reassign()
			Director.checkEnd()
		end)
	end
end)

local function restart()
	Director.stopAll()
	Death.reset()
	Hiding.releaseAll(true)
	Clock.releaseAll()
	Director.resetWorld()
	for _, n in ipairs({ "Rain", "Clock", "HouseHum", "Ambience", "Heartbeat", "MusicBox", "Static" }) do
		Fx.loop(n, false)
	end
	State.set("Ending", "")
	State.set("Chapter", "Lobby")
	State.set("ChapterIndex", 0)
	Lobby.reset(false)
	Fx.cine("Reset", {})
	Lobby.spawnAll()
end

Net.on("Ping", function(p, pos, label)
	if typeof(pos) == "Vector3" and type(label) == "string" and #label < 24 and p:GetAttribute("Alive") then
		Net.fireAll("Ping", p:GetAttribute("Slot") or 0, pos, label)
	end
end)

Net.on("Replay", function(p)
	if State.get("Phase") == "Results" then
		restart()
	end
end)

-- Studio-only test panel actions
Net.on("Admin", function(p, action, arg)
	if not RunService:IsStudio() then
		return
	end
	if action == "jump" and type(arg) == "number" then
		if State.get("Phase") == "Lobby" then
			Lobby.forceStart()
			task.wait(5)
		end
		Director.jump(math.clamp(arg, 1, 7))
	elseif action == "strike" and type(arg) == "number" then
		local target = Players:GetPlayerByUserId(arg)
		if target then
			Roster.addStrike(target, "test panel strike", "Test panel")
		end
	elseif action == "hide" then
		if State.get("Phase") == "Lobby" then
			Lobby.forceStart()
			task.wait(5)
		end
		Director.testPatrol()
	elseif action == "restart" then
		restart()
	elseif action == "start" then
		Lobby.forceStart()
	elseif action == "kill" and type(arg) == "number" then
		local target = Players:GetPlayerByUserId(arg)
		if target then
			Death.kill(target, "test panel elimination", "strike")
		end
	end
end)

State.set("Chapter", "Lobby")
State.set("ChapterIndex", 0)
Lobby.spawnAll()
print("[HushHour] server ready")
