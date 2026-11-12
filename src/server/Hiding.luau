-- Hide slots. Valid concealment = used the Hide prompt, finished the entry beat, occupies a slot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Fx = State.Fx

local Hiding = {}
local H
local occupant = {} -- [spotId] = player
local saved = {} -- [player] = { spot, transparencies }

local function setVisible(char, visible, store)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if visible then
				local t = store and store[d]
				if t ~= nil then
					d.Transparency = t
				end
			else
				if store then
					store[d] = d.Transparency
				end
				d.Transparency = 1
			end
		end
	end
end

function Hiding.spotById(id)
	for _, s in ipairs(H.hideSpots) do
		if s.id == id then
			return s
		end
	end
end

function Hiding.exit(player, silent)
	local info = saved[player]
	if not info then
		return
	end
	saved[player] = nil
	occupant[info.spot.id] = nil
	info.spot.prompt.ActionText = "Hide"
	player:SetAttribute("Hidden", false)
	player:SetAttribute("HideSpot", "")
	local char = player.Character
	if char and char.Parent then
		setVisible(char, true, info.store)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
			char:PivotTo(info.spot.exit)
		end
	end
	if not silent then
		Fx.sfx("WoodClick", info.spot.part.Position, 0.4)
	end
	Net.fire(player, "HideExit")
end

function Hiding.enter(player, spot)
	if occupant[spot.id] then
		Fx.toast("Someone is already hiding there.", { player })
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	occupant[spot.id] = player
	local store = {}
	saved[player] = { spot = spot, store = store }
	spot.prompt.ActionText = "Leave"
	hrp.Anchored = true
	char:PivotTo(spot.inside)
	setVisible(char, false, store)
	Fx.sfx("WoodClick", spot.part.Position, 0.5)
	Net.fire(player, "HideEnter", spot.peek, spot.id, spot.room)
	-- entry animation beat before the concealment counts
	task.delay(0.6, function()
		if saved[player] and saved[player].spot == spot then
			player:SetAttribute("Hidden", true)
			player:SetAttribute("HideSpot", spot.id)
		end
	end)
end

function Hiding.bind(house)
	H = house
	for _, spot in ipairs(H.hideSpots) do
		spot.prompt.Triggered:Connect(function(player)
			if saved[player] then
				if saved[player].spot == spot then
					Hiding.exit(player)
				end
				return
			end
			if not Roster.isLiving(player) or player:GetAttribute("InCutscene") then
				return
			end
			Hiding.enter(player, spot)
		end)
	end
	Net.on("HideExit", function(player)
		Hiding.exit(player)
	end)
end

function Hiding.releaseAll(silent)
	for p in pairs(saved) do
		Hiding.exit(p, silent)
	end
end

function Hiding.forget(player)
	local info = saved[player]
	if info then
		occupant[info.spot.id] = nil
		info.spot.prompt.ActionText = "Hide"
		saved[player] = nil
	end
	player:SetAttribute("Hidden", false)
	player:SetAttribute("HideSpot", "")
end

function Hiding.isHidden(player)
	return player:GetAttribute("Hidden") == true
end

return Hiding
