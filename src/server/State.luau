-- Server-owned state replicated to clients through attributes on ReplicatedStorage.GameState.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Net = require(ReplicatedStorage.Shared.Net)

local State = {}

local gs = ReplicatedStorage:FindFirstChild("GameState")
if gs then
	gs:Destroy()
end
gs = Instance.new("Folder")
gs.Name = "GameState"
local stations = Instance.new("Folder")
stations.Name = "Stations"
stations.Parent = gs
local slots = Instance.new("Folder")
slots.Name = "Slots"
slots.Parent = gs
gs.Parent = ReplicatedStorage

State.folder = gs
State.stations = stations
State.slots = slots

function State.set(name, value)
	gs:SetAttribute(name, value)
end
function State.get(name)
	return gs:GetAttribute(name)
end

function State.stationFolder(name)
	local f = stations:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = stations
	end
	return f
end

function State.slotFolder(i)
	local f = slots:FindFirstChild("Slot" .. i)
	if not f then
		f = Instance.new("Folder")
		f.Name = "Slot" .. i
		f:SetAttribute("Index", i)
		f.Parent = slots
	end
	return f
end

---------------------------------------------------------------- pausable clock
-- The shared stage clock stops during death cutscenes (and other holds).
local Clock = {}
State.Clock = Clock
local gameTime = 0
local holds = {}

local function paused()
	return next(holds) ~= nil
end
Clock.paused = paused

RunService.Heartbeat:Connect(function(dt)
	if not paused() then
		gameTime += dt
	end
end)

function Clock.now()
	return gameTime
end
function Clock.hold(reason)
	holds[reason] = true
	gs:SetAttribute("Paused", true)
end
function Clock.release(reason)
	holds[reason] = nil
	gs:SetAttribute("Paused", paused())
end
function Clock.releaseAll()
	table.clear(holds)
	gs:SetAttribute("Paused", false)
end
-- Wait in stage time (pauses while held). Returns early if `abort()` becomes true.
function Clock.wait(seconds, abort)
	local target = gameTime + seconds
	while gameTime < target do
		if abort and abort() then
			return false
		end
		task.wait()
	end
	return true
end
-- Real-time wait that ignores holds (cutscenes themselves).
function Clock.realWait(seconds)
	task.wait(seconds)
end

-- Visible countdown on the HUD
local timer = { ends = nil, label = "" }
function Clock.setTimer(label, seconds)
	timer.ends = gameTime + seconds
	timer.label = label
	gs:SetAttribute("TimerLabel", label)
	gs:SetAttribute("TimerTotal", seconds)
end
function Clock.clearTimer()
	timer.ends = nil
	gs:SetAttribute("TimerLabel", "")
	gs:SetAttribute("TimerRemaining", 0)
end
function Clock.timerRemaining()
	return timer.ends and math.max(0, timer.ends - gameTime) or 0
end
function Clock.extendTimer(seconds)
	if timer.ends then
		timer.ends += seconds
	end
end
task.spawn(function()
	while true do
		if timer.ends then
			gs:SetAttribute("TimerRemaining", math.max(0, timer.ends - gameTime))
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------- effects bus
local Fx = {}
State.Fx = Fx

-- Sound effect for everyone (pos optional = 3D)
function Fx.sfx(name, pos, volume)
	Net.fireAll("Sfx", name, pos, volume)
end
function Fx.sfxTo(player, name, pos, volume)
	Net.fire(player, "Sfx", name, pos, volume)
end
function Fx.loop(name, on, volume)
	Net.fireAll("Loop", name, on, volume)
end

-- Spoken line + caption. speaker: "Nell", "Mum", "Host", "Friend", "Copy", "Narrator".
-- source: location badge, e.g. "TV", "PHONE", "UPSTAIRS". Returns estimated duration.
function Fx.estimate(text)
	return 0.6 + #text * 0.058
end
function Fx.say(speaker, text, source, opts)
	opts = opts or {}
	local dur = opts.duration or Fx.estimate(text)
	local payload = {
		speaker = speaker,
		text = text,
		source = source or "TV",
		duration = dur,
		pos = opts.pos,
		style = opts.style,
		silent = opts.silent,
		-- spoken variant when Roblox's TTS text filter blocks the caption wording
		voiceText = opts.voiceText,
	}
	if opts.players then
		for _, p in ipairs(opts.players) do
			Net.fire(p, "Say", payload)
		end
	else
		Net.fireAll("Say", payload)
	end
	return dur
end

-- Mission results: kind "ding" or "wrong". audience: list of players or nil (= all)
function Fx.result(kind, title, detail, audience)
	if audience then
		for _, p in ipairs(audience) do
			Net.fire(p, "Result", kind, title, detail)
		end
	else
		Net.fireAll("Result", kind, title, detail)
	end
end

function Fx.toast(text, audience)
	if audience then
		for _, p in ipairs(audience) do
			Net.fire(p, "Toast", text)
		end
	else
		Net.fireAll("Toast", text)
	end
end

function Fx.cine(name, args)
	Net.fireAll("Cine", name, args or {})
end

return State
